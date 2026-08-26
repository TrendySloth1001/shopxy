import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { round2, toNumber } from '../../shared/numbering/decimal.js';
import { invoicesService, PosInvoiceError } from '../invoices/invoices.service.js';
import { reverseTransferForReturn } from '../payment-gateway/settlement/transfer-actions.js';
import { paymentGatewayService } from '../payment-gateway/index.js';
import { enqueueOutbox } from '../../infra/outbox/outbox.js';
import { notifyShopOwner } from '../purchase-requests/purchase-requests.service.js';

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
  async submit(opts: ReturnRequestInput): Promise<
    | { error: 'NOT_FOUND' | 'NOT_DELIVERED' | 'INVALID_ITEMS' | 'ALREADY_REQUESTED' | 'BAD_QTY' | 'RETURNS_DISABLED' | 'WINDOW_EXPIRED' }
    | { id: number }
  > {
    if (opts.items.length === 0) return { error: 'INVALID_ITEMS' };

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
    const deliveredAt = child.events[0]?.occurredAt ?? null;
    if (!deliveredAt) return { error: 'NOT_DELIVERED' };
    if (!child.shop.returnsEnabled) return { error: 'RETURNS_DISABLED' };

    const windowDays = child.shop.returnWindowDays;
    if (windowDays > 0) {
      const ageDays = (Date.now() - deliveredAt.getTime()) / 86_400_000;
      if (ageDays > windowDays) return { error: 'WINDOW_EXPIRED' };
    }

    const parent = child.customerOrder;
    const grossSubtotal = parent ? Number(parent.estimatedTotal) : 0;
    const couponDiscount = parent ? Number(parent.couponDiscount) : 0;
    const refundableSubtotal = Math.max(0, grossSubtotal - couponDiscount);
    const paidFactor = grossSubtotal > 0
      ? refundableSubtotal / grossSubtotal
      : 1;

    const itemMap = new Map(child.items.map((i) => [i.id, i]));
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

    const returnedNames = [
      ...new Set(
        opts.items
          .map((i) => itemMap.get(i.purchaseRequestItemId)?.productName)
          .filter((n): n is string => !!n),
      ),
    ];
    const summary =
      returnedNames.length <= 1
        ? returnedNames[0]
        : `${returnedNames[0]} and ${returnedNames.length - 1} more item${returnedNames.length > 2 ? 's' : ''}`;
    void notifyShopOwner(child.shopId, {
      kind: 'RETURN_REQUESTED',
      title: 'Return requested',
      body: summary
        ? `A return was requested for ${summary}.`
        : `A return was requested on order #${child.id}.`,
      data: { returnId: created.id, requestId: child.id },
    }).catch(() => {});

    return { id: created.id };
  }

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

  async refund(opts: {
    shopId: number;
    id: number;
    actorId: number;
    note?: string | null;
  }): Promise<
    | {
        ok: true;
        refundAmount: number;
        refundStatus: 'REFUNDED' | 'FAILED' | 'NO_PAYMENT' | 'NOTHING_TO_REFUND';
      }
    | { error: 'NOT_FOUND' | 'BAD_STATE' | 'NO_ORIGINAL_INVOICE' | 'CREDIT_NOTE_FAILED' }
  > {
    let reverseChildId: number | null = null;
    let reverseAmount = 0;
    let refundOrderId: number | null = null;
    const result = await prisma.$transaction(async (tx) => {
      const claim = await tx.returnRequest.updateMany({
        where: {
          id: opts.id,
          shopId: opts.shopId,
          status: { in: ['RECEIVED', 'APPROVED', 'PICKED_UP'] },
        },
        data: {
          status: 'REFUNDED',
          refundMethod: 'SOURCE',
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
          items: {
            select: {
              id: true,
              quantity: true,
              purchaseRequestItem: { select: { productId: true } },
            },
          },
          request: {
            select: {
              invoiceId: true,
              customerOrderId: true,
              customerOrder: {
                select: {
                  estimatedTotal: true,
                  couponDiscount: true,
                },
              },
            },
          },
        },
      });

      const originalInvoiceId = row.request?.invoiceId ?? null;
      if (originalInvoiceId == null) {
        return { error: 'NO_ORIGINAL_INVOICE' as const };
      }

      const originalInvoice = await tx.invoice.findFirst({
        where: { id: originalInvoiceId, shopId: opts.shopId, type: 'SALE' },
        select: {
          id: true,
          shiftId: true,
          partyId: true,
          customerName: true,
          customerPhone: true,
          placeOfSupplyStateCode: true,
          invoiceDate: true,
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

      const creditItems: Array<{
        productId: number;
        quantity: number;
        unitPrice: number;
        discount: number;
        taxPercent: number;
        cessRate: number;
        isPriceInclusive: boolean;
      }> = [];
      let returnedListValue = new Prisma.Decimal(0);
      for (const it of row.items) {
        const productId = it.purchaseRequestItem?.productId;
        const qty = Number(it.quantity);
        if (productId == null || !(qty > 0)) continue;
        const orig = origByProduct.get(productId);
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
        returnedListValue = returnedListValue.add(
          new Prisma.Decimal(orig.unitPrice).mul(qty),
        );
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
          opts.actorId,
          originalInvoice.shiftId ?? undefined,
        );
      } catch (e) {
        if (e instanceof PosInvoiceError) {
          return { error: 'CREDIT_NOTE_FAILED' as const };
        }
        throw e;
      }

      await enqueueOutbox(
        {
          aggregateType: 'return_request',
          aggregateId: opts.id,
          eventType: 'return.refunded',
          shopId: opts.shopId,
          payload: {
            returnRequestId: opts.id,
            originalInvoiceId,
            occurredAt: originalInvoice.invoiceDate.toISOString(),
          },
        },
        tx,
      );

      const parent = row.request?.customerOrder;
      const gross = parent ? new Prisma.Decimal(parent.estimatedTotal) : new Prisma.Decimal(0);
      const coupon = parent ? new Prisma.Decimal(parent.couponDiscount) : new Prisma.Decimal(0);
      const creditNoteTotal = new Prisma.Decimal(creditNote.total);

      const buyerOutlay = Prisma.Decimal.max(gross.sub(coupon), new Prisma.Decimal(0));

      const returnFraction = gross.gt(0)
        ? Prisma.Decimal.min(returnedListValue.div(gross), new Prisma.Decimal(1))
        : new Prisma.Decimal(1);

      const buyerRefund = Prisma.Decimal.min(
        buyerOutlay.mul(returnFraction).toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP),
        creditNoteTotal,
      );
      const refundAmount = round2(buyerRefund.toNumber());

      await tx.returnRequest.update({
        where: { id: row.id },
        data: { refundAmount: new Prisma.Decimal(refundAmount) },
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
      refundOrderId = row.request?.customerOrderId ?? null;
      return { ok: true as const, refundAmount };
    });

    if (!('ok' in result) || !result.ok) return result;

    if (reverseChildId != null) {
      try {
        await reverseTransferForReturn({
          purchaseRequestId: reverseChildId,
          reverseAmount,
        });
      } catch {
      }
    }

    let refundStatus: 'REFUNDED' | 'FAILED' | 'NO_PAYMENT' | 'NOTHING_TO_REFUND' =
      'NO_PAYMENT';
    if (refundOrderId != null && result.refundAmount > 0) {
      try {
        const outcome = await paymentGatewayService.refundToSource({
          targetType: 'ORDER',
          targetId: refundOrderId,
          amount: result.refundAmount,
          sourceType: 'RETURN',
          sourceId: opts.id,
          idempotencyKey: `return-refund-${opts.id}`,
          reason: `Refund for return #${opts.id}`,
          notes: { returnId: String(opts.id), orderId: String(refundOrderId) },
        });
        refundStatus = outcome.status;
      } catch {
        refundStatus = 'FAILED';
      }
    }

    return { ...result, refundStatus };
  }
}

export const returnsService = new ReturnsService();
