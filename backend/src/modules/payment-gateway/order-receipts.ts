import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { nextPaymentRef } from '../../shared/numbering/sequences.js';
import { toNumber, round2 } from '../../shared/numbering/decimal.js';
import { notificationsService } from '../notifications/notifications.service.js';
import {
  allocateProportional,
  toMinorUnits,
  fromMinorUnits,
} from './helpers.js';

type Db = Prisma.TransactionClient | typeof prisma;

export interface ReconcileResult {
  created: number;
}

async function invoiceOutstanding(db: Db, invoiceId: number, total: number): Promise<number> {
  const agg = await db.payment.aggregate({
    where: { invoiceId, voidedAt: null },
    _sum: { amount: true },
  });
  return round2(total - toNumber(agg._sum.amount));
}

async function postReceiptOnce(
  db: Db,
  p: {
    shopId: number;
    invoiceId: number;
    partyId: number | null;
    desired: number;
    cap: number;
    modeReference: string | null;
    note: string;
    idempotencyKey: string;
  },
): Promise<number> {
  const amount = round2(Math.min(p.desired, p.cap));
  if (!(amount > 0)) return 0;

  const existing = await db.payment.findFirst({
    where: { shopId: p.shopId, type: 'RECEIPT', idempotencyKey: p.idempotencyKey },
    select: { id: true },
  });
  if (existing) return 0;

  const { referenceNo } = await nextPaymentRef(
    p.shopId,
    'RECEIPT',
    new Date(),
    db as Prisma.TransactionClient,
  );
  try {
    await db.payment.create({
      data: {
        shopId: p.shopId,
        type: 'RECEIPT',
        referenceNo,
        amount: new Prisma.Decimal(amount),
        mode: 'OTHER',
        modeReference: p.modeReference,
        partyId: p.partyId,
        invoiceId: p.invoiceId,
        note: p.note,
        idempotencyKey: p.idempotencyKey,
      },
    });
    return 1;
  } catch (e) {
    if ((e as { code?: string }).code === 'P2002') return 0;
    throw e;
  }
}

export async function ensureOrderInvoiceReceipts(
  orderId: number,
  db: Db = prisma,
): Promise<ReconcileResult> {
  const order = await db.customerOrder.findUnique({
    where: { id: orderId },
    select: {
      id: true,
      estimatedTotal: true,
      walletPaid: true,
      couponDiscount: true,
      couponShopId: true,
      shopOrders: {
        where: { status: 'CONFIRMED', invoiceId: { not: null } },
        select: {
          id: true,
          shopId: true,
          partyId: true,
          estimatedTotal: true,
          invoice: { select: { id: true, total: true, status: true, partyId: true } },
        },
      },
    },
  });
  if (!order || order.shopOrders.length === 0) return { created: 0 };

  const gw = await db.gatewayPayment.findFirst({
    where: { targetType: 'ORDER', targetId: orderId, status: 'CAPTURED' },
    select: { amount: true, provider: true, providerPaymentRef: true },
  });

  const walletPaid = toNumber(order.walletPaid);
  const gatewayPaid = gw ? toNumber(gw.amount) : 0;
  if (!(walletPaid > 0) && !(gatewayPaid > 0)) return { created: 0 };

  const invoiceTotalSum = round2(
    order.shopOrders.reduce(
      (s, c) => s + (c.invoice ? toNumber(c.invoice.total) : 0),
      0,
    ),
  );

  const childWeightsMinor = order.shopOrders.map((c) =>
    c.invoice ? toMinorUnits(toNumber(c.invoice.total)) : 0,
  );
  const walletAllocMinor = allocateProportional(
    childWeightsMinor,
    toMinorUnits(walletPaid),
  );
  const gatewayAllocMinor = allocateProportional(
    childWeightsMinor,
    toMinorUnits(gatewayPaid),
  );
  const walletShareById = new Map<number, number>();
  const gatewayShareById = new Map<number, number>();
  order.shopOrders.forEach((c, i) => {
    walletShareById.set(c.id, fromMinorUnits(walletAllocMinor[i] ?? 0));
    gatewayShareById.set(c.id, fromMinorUnits(gatewayAllocMinor[i] ?? 0));
  });

  const receivedByShop = new Map<number, { amount: number; modes: Set<string> }>();
  function trackReceived(shopId: number, amount: number, mode: string): void {
    const row = receivedByShop.get(shopId) ?? { amount: 0, modes: new Set<string>() };
    row.amount = round2(row.amount + amount);
    row.modes.add(mode);
    receivedByShop.set(shopId, row);
  }

  let created = 0;
  let postedTotal = 0;
  for (const child of order.shopOrders) {
    const invoice = child.invoice;
    if (!invoice || invoice.status !== 'CONFIRMED') continue;

    const invoiceTotal = toNumber(invoice.total);
    const partyId = invoice.partyId ?? child.partyId ?? null;

    if (walletPaid > 0) {
      const before = await invoiceOutstanding(db, invoice.id, invoiceTotal);
      const desired = walletShareById.get(child.id) ?? 0;
      const n = await postReceiptOnce(db, {
        shopId: child.shopId,
        invoiceId: invoice.id,
        partyId,
        desired,
        cap: before,
        modeReference: null,
        note: 'Wallet payment',
        idempotencyKey: `wltrcpt:o${orderId}:i${invoice.id}`,
      });
      if (n > 0) {
        const posted = round2(Math.min(desired, before));
        postedTotal += posted;
        trackReceived(child.shopId, posted, 'wallet');
      }
      created += n;
    }

    if (gatewayPaid > 0 && gw) {
      const before = await invoiceOutstanding(db, invoice.id, invoiceTotal);
      const desired = gatewayShareById.get(child.id) ?? 0;
      const n = await postReceiptOnce(db, {
        shopId: child.shopId,
        invoiceId: invoice.id,
        partyId,
        desired,
        cap: before,
        modeReference: gw.providerPaymentRef ?? null,
        note: `Online payment (${gw.provider})`,
        idempotencyKey: `gwrcpt:o${orderId}:i${invoice.id}`,
      });
      if (n > 0) {
        const posted = round2(Math.min(desired, before));
        postedTotal += posted;
        trackReceived(child.shopId, posted, gw.provider);
      }
      created += n;
    }
  }

  for (const [shopId, row] of receivedByShop) {
    if (!(row.amount > 0)) continue;
    const modeLabel = [...row.modes].join(' + ');
    prisma.shop
      .findUnique({ where: { id: shopId }, select: { ownerUserId: true } })
      .then((shop) => {
        if (!shop) return;
        return notificationsService.create({
          userId: shop.ownerUserId,
          kind: 'PAYMENT_RECEIVED',
          title: 'Payment received',
          body: `₹${row.amount.toFixed(0)} received via ${modeLabel}.`,
          data: { orderId, shopId, amount: row.amount },
        });
      })
      .catch(() => {});
  }

  const collected = round2(walletPaid + gatewayPaid);
  const platformCoupon =
    order.couponShopId == null ? toNumber(order.couponDiscount) : 0;
  const fullyPaid = collected >= round2(invoiceTotalSum - platformCoupon - 0.01);
  if (fullyPaid) {
    const receiptsSum = toNumber(
      (
        await db.payment.aggregate({
          where: {
            voidedAt: null,
            type: 'RECEIPT',
            invoice: { purchaseRequest: { customerOrderId: orderId } },
          },
          _sum: { amount: true },
        })
      )._sum.amount,
    );
    const expected = round2(invoiceTotalSum - platformCoupon);
    if (Math.abs(receiptsSum - expected) > 0.01) {
      // eslint-disable-next-line no-console
      console.error(
        `[order-receipts] RECONCILE MISMATCH order ${orderId}: ` +
          `Σreceipts=${receiptsSum} expected=${expected} ` +
          `(ΣinvoiceTotal=${invoiceTotalSum}, platformCoupon=${platformCoupon}, ` +
          `collected=${collected}, postedThisRun=${round2(postedTotal)})`,
      );
    }
  }

  return { created };
}
