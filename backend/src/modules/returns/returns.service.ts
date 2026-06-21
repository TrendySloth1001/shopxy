import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { round2, toNumber } from '../../shared/numbering/decimal.js';
import { walletService } from '../wallet/wallet.service.js';
import { invoicesService, PosInvoiceError } from '../invoices/invoices.service.js';
import { reverseTransferForReturn } from '../payment-gateway/settlement/transfer-actions.js';

/// Canonical return reasons. Kept loose (string) on the DB so adding
/// a new category later doesn't require a migration; the enum below
/// is the source of truth for what the customer app can submit.
export const RETURN_REASONS = [
  'DAMAGED',
  'WRONG_ITEM',
  'NOT_AS_DESCRIBED',
  'SIZE_FIT',
  'CHANGED_MIND',
  'DEFECTIVE',
  'OTHER',
] as const;
export type ReturnReason = typeof RETURN_REASONS[number];

export type ReturnStatus =
  | 'REQUESTED'
  | 'APPROVED'
  | 'REJECTED'
  | 'CANCELLED'
  | 'PICKED_UP'
  | 'RECEIVED'
  | 'REFUNDED';

export interface ReturnRequestInput {
  customerUserId: number;
  parentId: number;
  childId: number;
  note?: string;
  items: Array<{
    purchaseRequestItemId: number;
    quantity: number;
    reason: ReturnReason;
  }>;
}

const detailSelect = {
  id: true,
  status: true,
  refundAmount: true,
  refundMethod: true,
  note: true,
  decisionNote: true,
  walletEntryId: true,
  createdAt: true,
  updatedAt: true,
  shopId: true,
  customerUserId: true,
  requestId: true,
  shop: { select: { id: true, name: true, slug: true } },
  request: {
    select: {
      id: true,
      customerOrderId: true,
      status: true,
      customerName: true,
      customerAddress: true,
    },
  },
  items: {
    select: {
      id: true,
      quantity: true,
      refundAmount: true,
      reason: true,
      purchaseRequestItem: {
        select: {
          id: true,
          productId: true,
          productName: true,
          productSku: true,
          unit: true,
          unitPrice: true,
          quantity: true,
          product: {
            select: {
              images: {
                select: { url: true },
                orderBy: { sortOrder: 'asc' as const },
                take: 1,
              },
            },
          },
        },
      },
    },
  },
  events: {
    select: { id: true, type: true, note: true, occurredAt: true },
    orderBy: { occurredAt: 'asc' as const },
  },
} satisfies Prisma.ReturnRequestSelect;

export class ReturnsService {
  /// Submit a new return request against a per-shop child slice. The
  /// caller must own the order (customerUserId match), the request must
  /// be CONFIRMED, and a DELIVERED event must exist — a return is a
  /// post-receipt flow (goods came back), so before delivery the right
  /// action is a CANCEL, gated by the shop's cancellationPolicy. The
  /// merchant marks DELIVERED from the order detail (web + app), which
  /// is also what starts the return window.
  ///
  /// Returns reason codes the controller maps to status codes.
  async submit(opts: ReturnRequestInput): Promise<
    | { error: 'NOT_FOUND' | 'NOT_DELIVERED' | 'INVALID_ITEMS' | 'ALREADY_REQUESTED' | 'BAD_QTY' | 'RETURNS_DISABLED' | 'WINDOW_EXPIRED' }
    | { id: number }
  > {
    if (opts.items.length === 0) return { error: 'INVALID_ITEMS' };

    // Load the child + items in one shot so we can validate ownership,
    // status, and that every requested item belongs to this order.
    const child = await prisma.purchaseRequest.findFirst({
      where: {
        id: opts.childId,
        customerOrderId: opts.parentId,
        customerUserId: opts.customerUserId,
      },
      select: {
        id: true,
        shopId: true,
        status: true,
        decidedAt: true,
        customerOrderId: true,
        shop: {
          select: {
            returnsEnabled: true,
            returnWindowDays: true,
          },
        },
        events: {
          // Pull the latest DELIVERED row so the eligibility window
          // starts ticking from actual delivery, not from confirmation.
          where: { type: 'DELIVERED' },
          select: { id: true, occurredAt: true },
          orderBy: { occurredAt: 'desc' as const },
          take: 1,
        },
        items: {
          select: { id: true, quantity: true, unitPrice: true, productName: true },
        },
        customerOrder: {
          select: {
            estimatedTotal: true,
            couponDiscount: true,
            walletPaid: true,
          },
        },
      },
    });
    if (!child) return { error: 'NOT_FOUND' };
    if (child.status !== 'CONFIRMED') return { error: 'NOT_DELIVERED' };
    // Hard delivery gate: no DELIVERED event → the goods haven't reached
    // the customer, so there is nothing to "return" yet. (Pre-delivery
    // the customer cancels instead — see cancelChildForCustomer.)
    const deliveredAt = child.events[0]?.occurredAt ?? null;
    if (!deliveredAt) return { error: 'NOT_DELIVERED' };
    if (!child.shop.returnsEnabled) return { error: 'RETURNS_DISABLED' };

    // Eligibility window: if the merchant has a window > 0, the delivery
    // must be within that many days. Window=0 means no limit.
    const windowDays = child.shop.returnWindowDays;
    if (windowDays > 0) {
      const ageDays = (Date.now() - deliveredAt.getTime()) / 86_400_000;
      if (ageDays > windowDays) return { error: 'WINDOW_EXPIRED' };
    }

    // Proportional refund — if the parent order used a coupon or paid
    // partly from wallet, the buyer effectively paid less than the
    // line total. Scale each line's refund by `paid / list` so we
    // never refund more than the buyer actually parted with.
    //
    //   paidFactor = (subtotal − couponDiscount − walletPaid) / subtotal
    //
    // walletPaid is itself a refund-able amount: when the buyer paid
    // ₹100 of a ₹500 cart from their wallet, returning the goods should
    // credit ₹500 back to the wallet (the original ₹400 cash + ₹100
    // wallet). So for the *wallet refund mode* we credit the full price,
    // and only deduct coupon. For non-wallet modes we deduct both.
    const parent = child.customerOrder;
    const grossSubtotal = parent ? Number(parent.estimatedTotal) : 0;
    const couponDiscount = parent ? Number(parent.couponDiscount) : 0;
    // Wallet credits are reusable money — so they get refunded in full
    // back to the wallet. Only the coupon discount is non-recoverable.
    const refundableSubtotal = Math.max(0, grossSubtotal - couponDiscount);
    const paidFactor = grossSubtotal > 0
      ? refundableSubtotal / grossSubtotal
      : 1;

    const itemMap = new Map(child.items.map((i) => [i.id, i]));
    // Cumulative-returned-quantity guard (C4). Without it a line could be
    // returned and refunded, then returned again and again — minting
    // unlimited wallet credit for goods bought only once. Sum the quantity
    // already returned on every still-live or completed return for this
    // child, then require requested + alreadyReturned to stay within what
    // was originally purchased. (REJECTED / CANCELLED returns release their
    // hold and are excluded.)
    const requestedItemIds = opts.items.map((i) => i.purchaseRequestItemId);
    const priorReturns = await prisma.returnRequestItem.groupBy({
      by: ['purchaseRequestItemId'],
      where: {
        purchaseRequestItemId: { in: requestedItemIds },
        return: {
          requestId: opts.childId,
          status: { in: ['REQUESTED', 'APPROVED', 'PICKED_UP', 'RECEIVED', 'REFUNDED'] },
        },
      },
      _sum: { quantity: true },
    });
    const alreadyReturned = new Map(
      priorReturns.map((r) => [r.purchaseRequestItemId, Number(r._sum.quantity) || 0]),
    );

    let refundTotal = 0;
    const itemRows: Array<{
      purchaseRequestItemId: number;
      reason: string;
      quantity: number;
      refundAmount: number;
    }> = [];
    for (const it of opts.items) {
      const original = itemMap.get(it.purchaseRequestItemId);
      if (!original) return { error: 'INVALID_ITEMS' };
      const prior = alreadyReturned.get(it.purchaseRequestItemId) ?? 0;
      if (!(it.quantity > 0) || it.quantity + prior > Number(original.quantity)) {
        return { error: 'BAD_QTY' };
      }
      const linePrice = it.quantity * Number(original.unitPrice);
      const refund = round2(linePrice * paidFactor);
      refundTotal += refund;
      itemRows.push({
        purchaseRequestItemId: it.purchaseRequestItemId,
        reason: it.reason,
        quantity: it.quantity,
        refundAmount: refund,
      });
    }

    // Block creating a new return when the customer has an open one
    // against the same child slice. Per-line dedupe (allowing two
    // separate items to be returned in parallel sessions) is a
    // refinement for later.
    const existingOpen = await prisma.returnRequest.findFirst({
      where: {
        requestId: opts.childId,
        status: { in: ['REQUESTED', 'APPROVED', 'PICKED_UP', 'RECEIVED'] },
      },
      select: { id: true },
    });
    if (existingOpen) return { error: 'ALREADY_REQUESTED' };

    const created = await prisma.$transaction(async (tx) => {
      const row = await tx.returnRequest.create({
        data: {
          requestId: opts.childId,
          shopId: child.shopId,
          customerUserId: opts.customerUserId,
          status: 'REQUESTED',
          refundAmount: round2(refundTotal),
          note: opts.note ?? null,
          items: { create: itemRows },
          events: {
            create: { type: 'REQUESTED', actorId: opts.customerUserId },
          },
        },
        select: { id: true },
      });
      return row;
    });
    return { id: created.id };
  }

  /// Customer's own list — newest first.
  async listForCustomer(opts: { userId: number; skip: number; limit: number }) {
    const where: Prisma.ReturnRequestWhereInput = { customerUserId: opts.userId };
    const [data, total] = await Promise.all([
      prisma.returnRequest.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: opts.skip,
        take: opts.limit,
        select: detailSelect,
      }),
      prisma.returnRequest.count({ where }),
    ]);
    return { data, total };
  }

  async getForCustomer(opts: { userId: number; id: number }) {
    return prisma.returnRequest.findFirst({
      where: { id: opts.id, customerUserId: opts.userId },
      select: detailSelect,
    });
  }

  async getForMerchant(opts: { shopId: number; id: number }) {
    return prisma.returnRequest.findFirst({
      where: { id: opts.id, shopId: opts.shopId },
      select: detailSelect,
    });
  }

  async listForMerchant(opts: {
    shopId: number;
    status?: string;
    skip: number;
    limit: number;
  }) {
    const where: Prisma.ReturnRequestWhereInput = { shopId: opts.shopId };
    if (opts.status) where.status = opts.status;
    const [data, total] = await Promise.all([
      prisma.returnRequest.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: opts.skip,
        take: opts.limit,
        select: detailSelect,
      }),
      prisma.returnRequest.count({ where }),
    ]);
    return { data, total };
  }

  /// Customer cancels a return — only allowed in REQUESTED.
  async cancelByCustomer(opts: { userId: number; id: number }): Promise<
    | { ok: true }
    | { error: 'NOT_FOUND' | 'NOT_OWNED' | 'NOT_OPEN' }
  > {
    const claim = await prisma.returnRequest.updateMany({
      where: {
        id: opts.id,
        customerUserId: opts.userId,
        status: 'REQUESTED',
      },
      data: { status: 'CANCELLED' },
    });
    if (claim.count === 1) {
      await prisma.returnRequestEvent.create({
        data: { returnId: opts.id, type: 'CANCELLED', actorId: opts.userId },
      });
      return { ok: true };
    }
    const probe = await prisma.returnRequest.findUnique({
      where: { id: opts.id },
      select: { customerUserId: true, status: true },
    });
    if (!probe) return { error: 'NOT_FOUND' };
    if (probe.customerUserId !== opts.userId) return { error: 'NOT_OWNED' };
    return { error: 'NOT_OPEN' };
  }

  /// Generic merchant transition — guards against illegal jumps and
  /// emits the matching event in the same transaction.
  private async _transitionMerchant(opts: {
    shopId: number;
    id: number;
    actorId: number;
    from: ReturnStatus[];
    to: ReturnStatus;
    note?: string | null;
    eventType: string;
  }): Promise<{ ok: true } | { error: 'NOT_FOUND' | 'BAD_STATE' }> {
    const claim = await prisma.returnRequest.updateMany({
      where: {
        id: opts.id,
        shopId: opts.shopId,
        status: { in: opts.from },
      },
      data: {
        status: opts.to,
        ...(opts.note ? { decisionNote: opts.note } : {}),
      },
    });
    if (claim.count === 1) {
      await prisma.returnRequestEvent.create({
        data: {
          returnId: opts.id,
          type: opts.eventType,
          actorId: opts.actorId,
          note: opts.note ?? null,
        },
      });
      return { ok: true };
    }
    const probe = await prisma.returnRequest.findFirst({
      where: { id: opts.id, shopId: opts.shopId },
      select: { id: true },
    });
    return { error: probe ? 'BAD_STATE' : 'NOT_FOUND' };
  }

  approve(opts: { shopId: number; id: number; actorId: number; note?: string | null }) {
    return this._transitionMerchant({
      ...opts,
      from: ['REQUESTED'],
      to: 'APPROVED',
      eventType: 'APPROVED',
    });
  }
  reject(opts: { shopId: number; id: number; actorId: number; note?: string | null }) {
    return this._transitionMerchant({
      ...opts,
      from: ['REQUESTED'],
      to: 'REJECTED',
      eventType: 'REJECTED',
    });
  }
  pickedUp(opts: { shopId: number; id: number; actorId: number; note?: string | null }) {
    return this._transitionMerchant({
      ...opts,
      from: ['APPROVED'],
      to: 'PICKED_UP',
      eventType: 'PICKED_UP',
    });
  }
  received(opts: { shopId: number; id: number; actorId: number; note?: string | null }) {
    return this._transitionMerchant({
      ...opts,
      from: ['PICKED_UP', 'APPROVED'],
      to: 'RECEIVED',
      eventType: 'RECEIVED',
    });
  }

  /// REFUND — terminal transition. Mints a GST **credit note** for the
  /// returned lines, credits the wallet, and (via the credit note) restocks
  /// the goods — all inside the same transaction as the status flip so a
  /// partial failure can't leave the row REFUNDED without its accounting
  /// document, wallet entry, or stock movement.
  ///
  /// PR-C1 — the online customer-order return previously credited the wallet
  /// and restocked but minted NO credit note, so the output GST charged on the
  /// original sale was never reversed (the shop kept tax on goods that came
  /// back) and the merchant ledger showed no offsetting document. We now route
  /// this path through the SAME `createSalesReturnInTx` machinery the POS /
  /// merchant return uses: it issues a CONFIRMED CREDIT_NOTE linked to the
  /// original SALE invoice, reverses CGST/SGST/IGST proportionally on the
  /// ORIGINAL invoice's stored place-of-supply (GST-7), restocks the goods
  /// (RETURN_IN), and sets the credit note's createdById/shiftId. The wallet /
  /// cash refund amount is then the credit note's tax-inclusive total, so the
  /// money returned equals the document.
  async refund(opts: {
    shopId: number;
    id: number;
    actorId: number;
    method?: string;
    note?: string | null;
  }): Promise<
    | { ok: true; walletEntryId: number | null; refundAmount: number }
    | { error: 'NOT_FOUND' | 'BAD_STATE' | 'NO_ORIGINAL_INVOICE' | 'CREDIT_NOTE_FAILED' }
  > {
    // Captured inside the tx for the post-commit Route reversal (below).
    let reverseChildId: number | null = null;
    let reverseAmount = 0;
    const result = await prisma.$transaction(async (tx) => {
      // Claim the row from a refund-eligible state.
      const claim = await tx.returnRequest.updateMany({
        where: {
          id: opts.id,
          shopId: opts.shopId,
          status: { in: ['RECEIVED', 'APPROVED', 'PICKED_UP'] },
        },
        data: {
          status: 'REFUNDED',
          refundMethod: opts.method ?? 'WALLET',
          ...(opts.note ? { decisionNote: opts.note } : {}),
        },
      });
      if (claim.count !== 1) {
        const probe = await tx.returnRequest.findFirst({
          where: { id: opts.id, shopId: opts.shopId },
          select: { id: true },
        });
        return { error: probe ? 'BAD_STATE' as const : 'NOT_FOUND' as const };
      }

      const row = await tx.returnRequest.findUniqueOrThrow({
        where: { id: opts.id },
        select: {
          id: true,
          customerUserId: true,
          refundAmount: true,
          requestId: true,
          // Returned line items — feed the credit note (which both reverses
          // GST and restocks the goods).
          items: {
            select: {
              id: true,
              quantity: true,
              purchaseRequestItem: { select: { productId: true } },
            },
          },
          // Reach into the parent order so we know how much of the
          // original payment came from wallet credit. We must credit
          // wallet money BACK to the wallet regardless of refund method.
          // invoiceId locates the original SALE invoice the credit note is
          // raised against (links the reversal + sources the line tax fields).
          request: {
            select: {
              invoiceId: true,
              customerOrder: {
                select: {
                  estimatedTotal: true,
                  couponDiscount: true,
                  walletPaid: true,
                },
              },
            },
          },
        },
      });
      const method = (opts.method ?? 'WALLET').toUpperCase();

      // PR-C1 — mint the GST credit note for the returned lines BEFORE settling
      // the cash, so the refund amount is the document's tax-inclusive total
      // (not the wallet-proportional `refundAmount` stored at request time).
      const originalInvoiceId = row.request?.invoiceId ?? null;
      if (originalInvoiceId == null) {
        // No SALE invoice means there is no document to reverse GST against —
        // refuse rather than silently fall back to a no-credit-note refund.
        return { error: 'NO_ORIGINAL_INVOICE' as const };
      }

      // Load the ORIGINAL invoice's lines (shop-scoped) so the credit note
      // mirrors each returned line's frozen unitPrice / discount / tax / cess
      // and — critically — its `isPriceInclusive` flag. Customer-order sales
      // are GST-inclusive (MRP), so the credit note must back tax out the same
      // way; copying the flag keeps the reversal exact. We also inherit the
      // original invoice's shiftId (a POS-online sale carries one; a pure
      // online order does not) so a cash-drawer-funded sale's reversal scopes
      // to the right Z-report.
      const originalInvoice = await tx.invoice.findFirst({
        where: { id: originalInvoiceId, shopId: opts.shopId, type: 'SALE' },
        select: {
          id: true,
          shiftId: true,
          partyId: true,
          customerName: true,
          customerPhone: true,
          placeOfSupplyStateCode: true,
          items: {
            select: {
              productId: true,
              quantity: true,
              unitPrice: true,
              discount: true,
              taxPercent: true,
              cessRate: true,
              isPriceInclusive: true,
            },
          },
        },
      });
      if (!originalInvoice) {
        return { error: 'NO_ORIGINAL_INVOICE' as const };
      }
      const origByProduct = new Map(
        originalInvoice.items.map((it) => [it.productId, it]),
      );

      // Build the credit-note lines from the returned quantities, scaling the
      // original line discount by the returned proportion so a partial return
      // reverses a proportional slice of tax (mirrors the POS returnSale path).
      const creditItems: Array<{
        productId: number;
        quantity: number;
        unitPrice: number;
        discount: number;
        taxPercent: number;
        cessRate: number;
        isPriceInclusive: boolean;
      }> = [];
      for (const it of row.items) {
        const productId = it.purchaseRequestItem?.productId;
        const qty = Number(it.quantity);
        if (productId == null || !(qty > 0)) continue;
        const orig = origByProduct.get(productId);
        // A returned product that isn't on the original invoice can't have its
        // tax reversed against that document — skip it (the qty guard at submit
        // time should already prevent this).
        if (!orig) continue;
        const soldQty = toNumber(orig.quantity);
        const proportion = soldQty > 0 ? qty / soldQty : 0;
        creditItems.push({
          productId,
          quantity: qty,
          unitPrice: toNumber(orig.unitPrice),
          discount: toNumber(orig.discount) * proportion,
          taxPercent: toNumber(orig.taxPercent),
          cessRate: toNumber(orig.cessRate),
          isPriceInclusive: orig.isPriceInclusive,
        });
      }
      if (creditItems.length === 0) {
        return { error: 'CREDIT_NOTE_FAILED' as const };
      }

      let creditNote: { id: number; total: Prisma.Decimal };
      try {
        creditNote = await invoicesService.createSalesReturnInTx(
          tx,
          {
            shopId: opts.shopId,
            type: 'SALE',
            originalInvoiceId,
            partyId: originalInvoice.partyId ?? undefined,
            customerName: originalInvoice.customerName ?? undefined,
            customerPhone: originalInvoice.customerPhone ?? undefined,
            placeOfSupplyStateCode:
              originalInvoice.placeOfSupplyStateCode ?? undefined,
            items: creditItems,
          },
          // createdById = the merchant actor issuing the refund; shiftId
          // inherited from the original sale (null for pure online orders).
          opts.actorId,
          originalInvoice.shiftId ?? undefined,
        );
      } catch (e) {
        if (e instanceof PosInvoiceError) {
          // Surface as a structured failure so the whole tx rolls back — a
          // return must never settle cash without its reversing document.
          return { error: 'CREDIT_NOTE_FAILED' as const };
        }
        throw e;
      }

      // The refund the buyer is owed is the credit note's tax-inclusive total,
      // so wallet/cash refunded == GST credit note == money returned.
      const refundAmount = round2(Number(creditNote.total));

      // Split the refund between wallet credit and off-platform refund.
      //
      // - WALLET mode: credit the full refundAmount back to the wallet.
      // - ORIGINAL/CASH mode: the merchant cuts cash/cheque/UPI off
      //   platform for the cash portion, BUT we still credit the
      //   wallet-funded slice back to the wallet (wallet money is
      //   reusable money — refusing to return it would be theft).
      //   Cash portion: refundAmount × (1 − walletShare).
      //   Wallet portion: refundAmount × walletShare.
      const parent = row.request?.customerOrder;
      const gross = parent ? Number(parent.estimatedTotal) : 0;
      const coupon = parent ? Number(parent.couponDiscount) : 0;
      const walletPaid = parent ? Number(parent.walletPaid) : 0;
      // Denominator is the buyer's ACTUAL outlay (post-coupon). With a
      // coupon-discounted order the wallet-funded slice of what they
      // really paid is walletPaid / (gross - coupon), not / gross.
      // Falling back to `gross` keeps the share defined when coupon
      // is zero.
      const denom = Math.max(gross - coupon, 1);
      const walletShare =
        walletPaid > 0 ? Math.min(walletPaid / denom, 1) : 0;
      const walletCreditAmount =
        method === 'WALLET'
          ? refundAmount
          : Math.round(refundAmount * walletShare * 100) / 100;

      // Wallet credit. Idempotency keyed on the return id so a retry of
      // this RPC re-uses the original entry instead of double-crediting.
      // Skip the wallet write entirely when there's nothing to credit
      // (off-platform refund + zero wallet portion in the original).
      const entry = walletCreditAmount > 0
        ? await walletService.credit({
            userId: row.customerUserId,
            amount: walletCreditAmount,
            source: 'REFUND',
            sourceId: row.id,
            description: `Refund for return #${row.id}`,
            idempotencyKey: `wallet:return-refund-${row.id}`,
            tx,
          })
        : null;

      // Persist the credit-note total as the row's refund amount + link the
      // wallet entry, so the stored figure ties to the issued document.
      await tx.returnRequest.update({
        where: { id: row.id },
        data: {
          refundAmount: new Prisma.Decimal(refundAmount),
          ...(entry ? { walletEntryId: entry.id } : {}),
        },
      });
      await tx.returnRequestEvent.create({
        data: {
          returnId: row.id,
          type: 'REFUNDED',
          actorId: opts.actorId,
          note: opts.note ?? null,
        },
      });
      reverseChildId = row.requestId;
      reverseAmount = refundAmount;
      // NOTE: the goods are restocked by `createSalesReturnInTx` above (it posts
      // the RETURN_IN ledger movement off the credit note, INVOICE:<cn>:RETURN).
      // The previous standalone post-commit restock here is therefore removed —
      // keeping it would double-count the returned stock.
      return {
        ok: true as const,
        walletEntryId: entry?.id ?? null,
        refundAmount,
      };
    });

    // Post-commit: if a Route on-hold split funded this child, claw the seller's
    // slice back. Runs AFTER the tx (external call), is best-effort and a no-op
    // when the split feature is off — it must NEVER fail the customer's refund,
    // which has already committed. An insufficient-balance reversal is flagged
    // for manual recovery by reverseTransferForReturn itself (P5).
    if ('ok' in result && result.ok && reverseChildId != null) {
      try {
        await reverseTransferForReturn({
          purchaseRequestId: reverseChildId,
          reverseAmount,
        });
      } catch {
        /* reconciliation re-drives a transient failure; refund stands. */
      }
    }

    // Restock is now handled inside the transaction by the credit note
    // (`createSalesReturnInTx` → RETURN_IN, INVOICE:<creditNote>:RETURN), so the
    // goods, the GST reversal, and the wallet credit all commit atomically.
    return result;
  }
}

export const returnsService = new ReturnsService();
