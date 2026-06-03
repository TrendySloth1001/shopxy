/**
 * Integration test for the order-payment → merchant-ledger reconciler.
 *
 * The bug class: a customer pays for an order (wallet at checkout, and/or online
 * via the gateway), the merchant later confirms (minting the per-shop invoice),
 * and the invoice shows UNPAID because no RECEIPT was ever posted. Covers wallet,
 * gateway, both-together, both timing paths, and idempotency.
 *
 * Uses the real test DB (localhost:5433) + the real service methods, so it
 * exercises the actual cross-module money flow (gateway/wallet → purchase-requests
 * → invoice → payment ledger). Fixtures follow tests/helpers/setup.ts.
 */
import { describe, it, expect, afterEach } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { purchaseRequestsService } from '../../src/modules/purchase-requests/purchase-requests.service.js';
import { ensureOrderInvoiceReceipts } from '../../src/modules/payment-gateway/order-receipts.js';
import { settlementFor } from '../../src/modules/payment-gateway/settlement/settlement.js';
import {
  createTestUser,
  createTestProduct,
  cleanupTestUser,
  type TestUserCtx,
} from '../helpers/setup.js';

// Track fixtures + orders for teardown so we don't litter the shared dev DB.
const merchants: TestUserCtx[] = [];
const buyers: TestUserCtx[] = [];
const orderIds: number[] = [];

async function setup(price = 100) {
  const merchant = await createTestUser(); // OWNER + shop
  const buyer = await createTestUser({ role: 'CUSTOMER' as never });
  merchants.push(merchant);
  buyers.push(buyer);
  const product = await createTestProduct(merchant.shopId, {
    sellingPrice: price,
    stockQuantity: 10,
  });
  return { merchant, buyer, product };
}

async function placeOrder(
  buyerId: number,
  productId: number,
  unitPrice: number,
  opts: { useWallet?: boolean } = {},
) {
  const res = await purchaseRequestsService.createForCustomer({
    customerUserId: buyerId,
    items: [{ productId, quantity: 1, expectedUnitPrice: unitPrice }],
    useWallet: opts.useWallet,
  });
  if ('error' in res) throw new Error(`placeOrder failed: ${res.error}`);
  orderIds.push(res.order.id);
  return res.order; // { id, shopOrders: [{ id, shopId }], walletPaid, ... }
}

async function confirm(shopId: number, requestId: number, decidedById: number) {
  const conf = await purchaseRequestsService.confirmRequest({
    shopId,
    requestId,
    decidedById,
  });
  if (!('invoice' in conf)) throw new Error(`confirm failed: ${JSON.stringify(conf)}`);
  return conf.invoice;
}

/** Give a user wallet balance directly (simulates prior refunds/top-ups). */
async function fundWallet(userId: number, amount: number) {
  await prisma.user.update({
    where: { id: userId },
    data: { walletBalance: amount },
  });
}

/** Simulate the DB state a successful gateway capture produces (no Razorpay). */
async function fakeCapture(orderId: number, amount: number) {
  await prisma.gatewayPayment.create({
    data: {
      provider: 'RAZORPAY',
      status: 'CAPTURED',
      amount,
      currency: 'INR',
      targetType: 'ORDER',
      targetId: orderId,
      providerOrderRef: `order_test_${orderId}`,
      providerPaymentRef: `pay_test_${orderId}`,
    },
  });
  await prisma.customerOrder.update({
    where: { id: orderId },
    data: { paymentStatus: 'PAID' },
  });
}

function receiptsFor(invoiceId: number) {
  return prisma.payment.findMany({
    where: { invoiceId, type: 'RECEIPT', voidedAt: null },
    orderBy: { id: 'asc' },
  });
}

describe('order payment → merchant ledger reconcile', () => {
  afterEach(async () => {
    for (const id of orderIds) {
      await prisma.gatewayPayment
        .deleteMany({ where: { targetType: 'ORDER', targetId: id } })
        .catch(() => undefined);
      await prisma.customerOrder.delete({ where: { id } }).catch(() => undefined);
    }
    orderIds.length = 0;
    for (const m of merchants) await cleanupTestUser(m);
    for (const b of buyers) await cleanupTestUser(b);
    merchants.length = 0;
    buyers.length = 0;
  });

  it('gateway pay-then-confirm: confirming a pre-paid order posts a RECEIPT', async () => {
    const { merchant, buyer, product } = await setup(100);
    const order = await placeOrder(buyer.userId, product.id, 100);

    await fakeCapture(order.id, 100); // customer pays online BEFORE confirm

    const invoiceRef = await confirm(merchant.shopId, order.shopOrders[0].id, merchant.userId);
    const invoice = await prisma.invoice.findUniqueOrThrow({
      where: { id: invoiceRef.id },
      select: { id: true, total: true },
    });
    const receipts = await receiptsFor(invoice.id);

    expect(receipts).toHaveLength(1);
    expect(Number(receipts[0].amount)).toBeCloseTo(Math.min(100, Number(invoice.total)), 2);
    expect(receipts[0].idempotencyKey).toBe(`gwrcpt:o${order.id}:i${invoice.id}`);
  });

  it('gateway confirm-then-pay: a later capture posts the RECEIPT', async () => {
    const { merchant, buyer, product } = await setup(100);
    const order = await placeOrder(buyer.userId, product.id, 100);

    const invoiceRef = await confirm(merchant.shopId, order.shopOrders[0].id, merchant.userId);
    expect(await receiptsFor(invoiceRef.id)).toHaveLength(0);

    await fakeCapture(order.id, 100);
    const result = await ensureOrderInvoiceReceipts(order.id);

    expect(result.created).toBe(1);
    expect(await receiptsFor(invoiceRef.id)).toHaveLength(1);
  });

  it('WALLET: a wallet-paid order posts a wallet RECEIPT on confirm', async () => {
    const { merchant, buyer, product } = await setup(100);
    await fundWallet(buyer.userId, 100);
    const order = await placeOrder(buyer.userId, product.id, 100, { useWallet: true });
    // The whole order was covered by wallet.
    expect(Number(order.walletPaid)).toBeCloseTo(100, 2);

    const invoiceRef = await confirm(merchant.shopId, order.shopOrders[0].id, merchant.userId);
    const receipts = await receiptsFor(invoiceRef.id);

    expect(receipts).toHaveLength(1);
    expect(receipts[0].idempotencyKey).toBe(`wltrcpt:o${order.id}:i${invoiceRef.id}`);
    expect(receipts[0].note).toBe('Wallet payment');
    const invoice = await prisma.invoice.findUniqueOrThrow({
      where: { id: invoiceRef.id },
      select: { total: true },
    });
    expect(Number(receipts[0].amount)).toBeCloseTo(Number(invoice.total), 2);
  });

  it('WALLET + GATEWAY split: partial wallet + online remainder posts BOTH receipts summing to the total', async () => {
    const { merchant, buyer, product } = await setup(100);
    await fundWallet(buyer.userId, 40); // wallet covers ₹40 of ₹100
    const order = await placeOrder(buyer.userId, product.id, 100, { useWallet: true });
    expect(Number(order.walletPaid)).toBeCloseTo(40, 2);

    // Customer pays the ₹60 remainder online, then merchant confirms.
    await fakeCapture(order.id, 60);
    const invoiceRef = await confirm(merchant.shopId, order.shopOrders[0].id, merchant.userId);

    const receipts = await receiptsFor(invoiceRef.id);
    expect(receipts).toHaveLength(2);
    const byKey = Object.fromEntries(receipts.map((r) => [r.idempotencyKey, Number(r.amount)]));
    expect(byKey[`wltrcpt:o${order.id}:i${invoiceRef.id}`]).toBeCloseTo(40, 2);
    expect(byKey[`gwrcpt:o${order.id}:i${invoiceRef.id}`]).toBeCloseTo(60, 2);

    const invoice = await prisma.invoice.findUniqueOrThrow({
      where: { id: invoiceRef.id },
      select: { total: true },
    });
    const totalReceipts = receipts.reduce((s, r) => s + Number(r.amount), 0);
    // Receipts never exceed the invoice total (cap), and here cover it fully.
    expect(totalReceipts).toBeLessThanOrEqual(Number(invoice.total) + 0.01);
    expect(totalReceipts).toBeCloseTo(Number(invoice.total), 2);
  });

  it('is idempotent: re-running (or webhook redelivery) creates no duplicate', async () => {
    const { merchant, buyer, product } = await setup(100);
    await fundWallet(buyer.userId, 100);
    const order = await placeOrder(buyer.userId, product.id, 100, { useWallet: true });
    await fakeCapture(order.id, 0.0); // no online slice; wallet covered it
    const invoiceRef = await confirm(merchant.shopId, order.shopOrders[0].id, merchant.userId);

    const a = await ensureOrderInvoiceReceipts(order.id);
    const b = await ensureOrderInvoiceReceipts(order.id);
    expect(a.created).toBe(0);
    expect(b.created).toBe(0);
    // Exactly the one wallet receipt (the 0-amount capture posts nothing).
    expect(await receiptsFor(invoiceRef.id)).toHaveLength(1);
  });

  it('does nothing for an unpaid (COD) order', async () => {
    const { merchant, buyer, product } = await setup(100);
    const order = await placeOrder(buyer.userId, product.id, 100);

    const invoiceRef = await confirm(merchant.shopId, order.shopOrders[0].id, merchant.userId);
    const result = await ensureOrderInvoiceReceipts(order.id);

    expect(result.created).toBe(0);
    expect(await receiptsFor(invoiceRef.id)).toHaveLength(0);
  });

  it('the ORDER settlement handler marks PAID and posts the receipt', async () => {
    const { merchant, buyer, product } = await setup(100);
    const order = await placeOrder(buyer.userId, product.id, 100);
    const invoiceRef = await confirm(merchant.shopId, order.shopOrders[0].id, merchant.userId);

    await prisma.gatewayPayment.create({
      data: {
        provider: 'RAZORPAY',
        status: 'CAPTURED',
        amount: 100,
        currency: 'INR',
        targetType: 'ORDER',
        targetId: order.id,
        providerPaymentRef: `pay_settle_${order.id}`,
      },
    });

    await settlementFor('ORDER').onPaid({
      id: 999999,
      provider: 'RAZORPAY',
      status: 'CAPTURED',
      amount: 100,
      currency: 'INR',
      target: { type: 'ORDER', id: order.id },
      shopId: null,
      customerUserId: buyer.userId,
      providerOrderRef: `order_settle_${order.id}`,
      providerPaymentRef: `pay_settle_${order.id}`,
      idempotencyKey: `order:${order.id}`,
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const updated = await prisma.customerOrder.findUniqueOrThrow({
      where: { id: order.id },
      select: { paymentStatus: true },
    });
    expect(updated.paymentStatus).toBe('PAID');
    expect(await receiptsFor(invoiceRef.id)).toHaveLength(1);
  });
});
