/**
 * Bridges a customer's order payments to the merchant's per-shop ledger.
 *
 * The problem this solves: order payments settle at the PARENT `CustomerOrder`
 * level — `walletPaid` (debited synchronously at checkout) and an online/gateway
 * capture (`GatewayPayment`, async) — but a merchant's "is this invoice paid?" is
 * derived from `Payment` (RECEIPT) rows allocated to the per-shop `Invoice`.
 * Without receipts, a confirmed invoice reads UNPAID even though the customer
 * already paid: the money sits at the platform but is invisible on the merchant
 * ledger. This reconciler posts the missing receipts.
 *
 * Two payment sources, two receipts per child invoice, each independently
 * idempotency-keyed:
 *   - WALLET   (`wltrcpt:o<order>:i<invoice>`)  — from `CustomerOrder.walletPaid`.
 *   - GATEWAY  (`gwrcpt:o<order>:i<invoice>`)   — from a CAPTURED `GatewayPayment`.
 *
 * `ensureOrderInvoiceReceipts` is the single, idempotent reconciler called from
 * every relevant path:
 *   - `confirmRequest` after minting the invoice (covers wallet always, and the
 *     gateway slice when the customer paid before confirming).
 *   - the ORDER gateway settlement handler on webhook capture (covers the gateway
 *     slice when the customer pays after the merchant confirmed).
 * Whichever runs after a given source is available creates that source's receipt;
 * the others are harmless no-ops. Re-runs / webhook redelivery are no-ops.
 *
 * Imports only prisma + the shared numbering primitive, so it can be imported by
 * both purchase-requests and the gateway settlement without an import cycle.
 */
import { Prisma } from '@prisma/client';
import prisma from '../../infra/db/prisma.js';
import { nextPaymentRef } from '../../shared/numbering/sequences.js';
import { toNumber, round2 } from '../../shared/numbering/decimal.js';

type Db = Prisma.TransactionClient | typeof prisma;

export interface ReconcileResult {
  /** Number of RECEIPT rows created this run (0 when nothing to do). */
  created: number;
}

/** Current unpaid balance on an invoice = total − SUM(non-void payments). */
async function invoiceOutstanding(db: Db, invoiceId: number, total: number): Promise<number> {
  const agg = await db.payment.aggregate({
    where: { invoiceId, voidedAt: null },
    _sum: { amount: true },
  });
  return round2(total - toNumber(agg._sum.amount));
}

/**
 * Post one RECEIPT for `desired`, capped at `cap` (the invoice's current
 * outstanding), unless one with `idempotencyKey` already exists. Returns 1 when
 * it created a row, else 0. P2002 (a concurrent run won the key) counts as 0.
 */
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
        // Payment.mode is a free string; 'OTHER' is the bucket for a
        // platform-collected receipt (wallet or gateway). The gateway ref,
        // when present, lands in modeReference.
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
    if ((e as { code?: string }).code === 'P2002') return 0; // raced — receipt exists
    throw e;
  }
}

/**
 * Ensure each CONFIRMED child invoice of `orderId` carries receipts for the
 * order's wallet + gateway payments, proportional to the child's share of the
 * order. Idempotent. Pass `db` (a tx client) to enrol in an outer transaction —
 * e.g. the gateway settlement handler passes its webhook tx so the status flip +
 * receipts commit together. All writes use the passed client; no interactive tx
 * is opened here.
 */
export async function ensureOrderInvoiceReceipts(
  orderId: number,
  db: Db = prisma,
): Promise<ReconcileResult> {
  // The order + its confirmed children that already have an invoice.
  const order = await db.customerOrder.findUnique({
    where: { id: orderId },
    select: {
      id: true,
      estimatedTotal: true,
      walletPaid: true,
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

  // Source of truth that online money actually moved: a CAPTURED gateway intent
  // for this order. May be absent (pure wallet, COD, or not-yet-paid).
  const gw = await db.gatewayPayment.findFirst({
    where: { targetType: 'ORDER', targetId: orderId, status: 'CAPTURED' },
    select: { amount: true, provider: true, providerPaymentRef: true },
  });

  const parentEst = toNumber(order.estimatedTotal);
  const walletPaid = toNumber(order.walletPaid);
  const gatewayPaid = gw ? toNumber(gw.amount) : 0;
  if (!(walletPaid > 0) && !(gatewayPaid > 0)) return { created: 0 };

  // A child's slice of an order-level amount, keyed on its share of the order.
  // Single-shop orders get the whole amount; multi-shop split proportionally.
  const shareOf = (total: number, childEst: number): number =>
    parentEst > 0 ? round2(total * (childEst / parentEst)) : total;

  let created = 0;
  for (const child of order.shopOrders) {
    const invoice = child.invoice;
    if (!invoice || invoice.status !== 'CONFIRMED') continue;

    const invoiceTotal = toNumber(invoice.total);
    const childEst = toNumber(child.estimatedTotal);
    const partyId = invoice.partyId ?? child.partyId ?? null;

    // 1. WALLET slice — recompute outstanding right before posting so the cap is
    //    correct even if a gateway receipt already landed (any ordering).
    if (walletPaid > 0) {
      created += await postReceiptOnce(db, {
        shopId: child.shopId,
        invoiceId: invoice.id,
        partyId,
        desired: shareOf(walletPaid, childEst),
        cap: await invoiceOutstanding(db, invoice.id, invoiceTotal),
        modeReference: null,
        note: 'Wallet payment',
        idempotencyKey: `wltrcpt:o${orderId}:i${invoice.id}`,
      });
    }

    // 2. GATEWAY slice — capped at whatever outstanding remains after wallet.
    if (gatewayPaid > 0 && gw) {
      created += await postReceiptOnce(db, {
        shopId: child.shopId,
        invoiceId: invoice.id,
        partyId,
        desired: shareOf(gatewayPaid, childEst),
        cap: await invoiceOutstanding(db, invoice.id, invoiceTotal),
        modeReference: gw.providerPaymentRef ?? null,
        note: `Online payment (${gw.provider})`,
        idempotencyKey: `gwrcpt:o${orderId}:i${invoice.id}`,
      });
    }
  }

  return { created };
}
