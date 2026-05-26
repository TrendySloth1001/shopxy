import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { walletService } from '../wallet/wallet.service.js';

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
  /// caller must own the order (customerUserId match) and the parent
  /// must have been delivered (we don't gate on a specific
  /// PurchaseRequest event here — merchants might use the legacy
  /// CONFIRMED state without a DELIVERED row; the orders module is
  /// where the eligibility window is enforced).
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
    if (!child.shop.returnsEnabled) return { error: 'RETURNS_DISABLED' };

    // Eligibility window: if the merchant has a window > 0, the
    // delivery (or confirmation, when no DELIVERED event was ever
    // emitted) must be within that many days. Window=0 means no limit.
    const windowDays = child.shop.returnWindowDays;
    if (windowDays > 0) {
      const start = child.events[0]?.occurredAt ?? child.decidedAt;
      if (start) {
        const ageMs = Date.now() - start.getTime();
        const ageDays = ageMs / 86_400_000;
        if (ageDays > windowDays) return { error: 'WINDOW_EXPIRED' };
      }
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
    const walletPaid = parent ? Number(parent.walletPaid) : 0;
    // Wallet credits are reusable money — so they get refunded in full
    // back to the wallet. Only the coupon discount is non-recoverable.
    const refundableSubtotal = Math.max(0, grossSubtotal - couponDiscount);
    const paidFactor = grossSubtotal > 0
      ? refundableSubtotal / grossSubtotal
      : 1;

    const itemMap = new Map(child.items.map((i) => [i.id, i]));
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
      if (!(it.quantity > 0) || it.quantity > Number(original.quantity)) {
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

  /// REFUND — terminal transition. Credits the wallet inside the same
  /// transaction as the status flip so a partial failure can't leave
  /// the row REFUNDED without a ledger entry.
  async refund(opts: {
    shopId: number;
    id: number;
    actorId: number;
    method?: string;
    note?: string | null;
  }): Promise<
    | { ok: true; walletEntryId: number | null; refundAmount: number }
    | { error: 'NOT_FOUND' | 'BAD_STATE' }
  > {
    return prisma.$transaction(async (tx) => {
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
          // Reach into the parent order so we know how much of the
          // original payment came from wallet credit. We must credit
          // wallet money BACK to the wallet regardless of refund method.
          request: {
            select: {
              customerOrder: {
                select: {
                  estimatedTotal: true,
                  walletPaid: true,
                },
              },
            },
          },
        },
      });
      const refundAmount = Number(row.refundAmount);
      const method = (opts.method ?? 'WALLET').toUpperCase();

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
      const walletPaid = parent ? Number(parent.walletPaid) : 0;
      const walletShare =
        gross > 0 && walletPaid > 0 ? Math.min(walletPaid / gross, 1) : 0;
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

      if (entry) {
        await tx.returnRequest.update({
          where: { id: row.id },
          data: { walletEntryId: entry.id },
        });
      }
      await tx.returnRequestEvent.create({
        data: {
          returnId: row.id,
          type: 'REFUNDED',
          actorId: opts.actorId,
          note: opts.note ?? null,
        },
      });
      return {
        ok: true as const,
        walletEntryId: entry?.id ?? null,
        refundAmount,
      };
    });
  }
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export const returnsService = new ReturnsService();
