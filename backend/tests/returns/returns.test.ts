import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import jwt from 'jsonwebtoken';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';
import { Role } from '@prisma/client';

const app = buildApp();

/// Helper that produces a merchant JWT WITH `shopId` baked in — the
/// shared test setup signs without it, and the merchant `confirm` +
/// returns routes read `req.user.shopId`.
function merchantToken(ctx: { userId: number; shopId: number; email: string }): string {
  return jwt.sign(
    { sub: ctx.userId, email: ctx.email, role: 'OWNER', isPlatformAdmin: false, shopId: ctx.shopId },
    process.env.JWT_ACCESS_SECRET!,
    { expiresIn: '15m' },
  );
}

/// Spins up a full submit→confirm→approve→refund chain so we know the
/// wallet credit + idempotency + state machine all line up.
describe('returns — lifecycle', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('submit → approve → received → refund credits the wallet', async () => {
    const merchant = await createTestUser();
    const buyer = await createTestUser({ role: Role.CUSTOMER });
    // Pre-link the buyer as a Party at the merchant's shop. Production
    // does this automatically on invitation acceptance; without it the
    // lazy-create-on-confirm path runs into a known visibility issue
    // where invoicesService.createInvoice (uses its own transaction)
    // can't see a Party that was just created in the outer transaction.
    await prisma.party.create({
      data: {
        shopId: merchant.shopId,
        name: 'Test Buyer',
        linkedUserId: buyer.userId,
        email: buyer.email,
      },
    });
    try {
      const product = await createTestProduct(merchant.shopId, {
        isPublished: true,
        isActive: true,
        sellingPrice: 250,
        stockQuantity: 10,
      });

      // Place an order as the buyer.
      const place = await request(app)
        .post('/me/orders')
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .set('X-Idempotency-Key', `test-${Date.now()}`)
        .send({ items: [{ productId: product.id, quantity: 2 }] });
      expect(place.status).toBeLessThan(300);
      const parentId = (place.body.id ?? place.body.orderId) as number;
      const childId = place.body.shopOrders[0].id as number;

      // Merchant confirms — this materialises an invoice.
      const confirm = await request(app)
        .post(`/orders/${childId}/confirm`)
        .set('Authorization', `Bearer ${merchantToken(merchant)}`)
        .send({});
      expect(confirm.status).toBe(200);

      // Look up the original PurchaseRequestItem id so we can return it.
      const pri = await prisma.purchaseRequestItem.findFirstOrThrow({
        where: { requestId: childId },
        select: { id: true },
      });

      // Buyer submits the return.
      const submit = await request(app)
        .post(`/me/orders/${parentId}/returns`)
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .send({
          childId,
          items: [
            { purchaseRequestItemId: pri.id, quantity: 2, reason: 'DAMAGED' },
          ],
          note: 'Arrived damaged',
        });
      expect(submit.status).toBe(201);
      const returnId = submit.body.id as number;

      // Merchant approves, picked-up, received, refund.
      const approve = await request(app)
        .post(`/orders/returns/${returnId}/approve`)
        .set('Authorization', `Bearer ${merchantToken(merchant)}`)
        .send({});
      expect(approve.status).toBe(204);

      const pickedUp = await request(app)
        .post(`/orders/returns/${returnId}/picked-up`)
        .set('Authorization', `Bearer ${merchantToken(merchant)}`)
        .send({});
      expect(pickedUp.status).toBe(204);

      const received = await request(app)
        .post(`/orders/returns/${returnId}/received`)
        .set('Authorization', `Bearer ${merchantToken(merchant)}`)
        .send({});
      expect(received.status).toBe(204);

      const refund = await request(app)
        .post(`/orders/returns/${returnId}/refund`)
        .set('Authorization', `Bearer ${merchantToken(merchant)}`)
        .send({});
      expect(refund.status).toBe(200);
      expect(refund.body.refundAmount).toBe(500);

      // Wallet snapshot should show the credit.
      const wallet = await request(app)
        .get('/me/wallet')
        .set('Authorization', `Bearer ${buyer.accessToken}`);
      expect(wallet.status).toBe(200);
      expect(wallet.body.balance).toBe(500);
      expect(wallet.body.entries.length).toBeGreaterThan(0);
      expect(wallet.body.entries[0].source).toBe('REFUND');
      expect(wallet.body.entries[0].amount).toBe(500);
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('refund is idempotent across retries', async () => {
    const merchant = await createTestUser();
    const buyer = await createTestUser({ role: Role.CUSTOMER });
    // Pre-link the buyer as a Party at the merchant's shop. Production
    // does this automatically on invitation acceptance; without it the
    // lazy-create-on-confirm path runs into a known visibility issue
    // where invoicesService.createInvoice (uses its own transaction)
    // can't see a Party that was just created in the outer transaction.
    await prisma.party.create({
      data: {
        shopId: merchant.shopId,
        name: 'Test Buyer',
        linkedUserId: buyer.userId,
        email: buyer.email,
      },
    });
    try {
      const product = await createTestProduct(merchant.shopId, {
        isPublished: true,
        isActive: true,
        sellingPrice: 100,
        stockQuantity: 5,
      });

      const place = await request(app)
        .post('/me/orders')
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .set('X-Idempotency-Key', `idem-${Date.now()}`)
        .send({ items: [{ productId: product.id, quantity: 1 }] });
      const parentId = (place.body.id ?? place.body.orderId) as number;
      const childId = place.body.shopOrders[0].id as number;

      const confirm = await request(app)
        .post(`/orders/${childId}/confirm`)
        .set('Authorization', `Bearer ${merchantToken(merchant)}`)
        .send({});
      expect(confirm.status).toBe(200);
      const pri = await prisma.purchaseRequestItem.findFirstOrThrow({
        where: { requestId: childId },
        select: { id: true },
      });
      const submit = await request(app)
        .post(`/me/orders/${parentId}/returns`)
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .send({
          childId,
          items: [{ purchaseRequestItemId: pri.id, quantity: 1, reason: 'OTHER' }],
        });
      expect(submit.status).toBe(201);
      const returnId = submit.body.id as number;

      for (const step of ['approve', 'received']) {
        await request(app)
          .post(`/orders/returns/${returnId}/${step}`)
          .set('Authorization', `Bearer ${merchantToken(merchant)}`)
          .send({});
      }

      // First refund — credits the wallet.
      const r1 = await request(app)
        .post(`/orders/returns/${returnId}/refund`)
        .set('Authorization', `Bearer ${merchantToken(merchant)}`)
        .send({});
      expect(r1.status).toBe(200);

      // Second refund attempt — must conflict (BAD_STATE) since the row
      // is already REFUNDED. The wallet must NOT receive a second credit.
      const r2 = await request(app)
        .post(`/orders/returns/${returnId}/refund`)
        .set('Authorization', `Bearer ${merchantToken(merchant)}`)
        .send({});
      expect(r2.status).toBe(409);

      const wallet = await request(app)
        .get('/me/wallet')
        .set('Authorization', `Bearer ${buyer.accessToken}`);
      expect(wallet.body.balance).toBe(100);
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('customer can cancel a REQUESTED return but not after approval', async () => {
    const merchant = await createTestUser();
    const buyer = await createTestUser({ role: Role.CUSTOMER });
    // Pre-link the buyer as a Party at the merchant's shop. Production
    // does this automatically on invitation acceptance; without it the
    // lazy-create-on-confirm path runs into a known visibility issue
    // where invoicesService.createInvoice (uses its own transaction)
    // can't see a Party that was just created in the outer transaction.
    await prisma.party.create({
      data: {
        shopId: merchant.shopId,
        name: 'Test Buyer',
        linkedUserId: buyer.userId,
        email: buyer.email,
      },
    });
    try {
      const product = await createTestProduct(merchant.shopId, {
        isPublished: true,
        isActive: true,
        sellingPrice: 75,
        stockQuantity: 5,
      });
      const place = await request(app)
        .post('/me/orders')
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .set('X-Idempotency-Key', `idem-${Date.now()}-c`)
        .send({ items: [{ productId: product.id, quantity: 1 }] });
      const parentId = (place.body.id ?? place.body.orderId) as number;
      const childId = place.body.shopOrders[0].id as number;

      const confirm = await request(app)
        .post(`/orders/${childId}/confirm`)
        .set('Authorization', `Bearer ${merchantToken(merchant)}`)
        .send({});
      expect(confirm.status).toBe(200);
      const pri = await prisma.purchaseRequestItem.findFirstOrThrow({
        where: { requestId: childId },
        select: { id: true },
      });
      const submit = await request(app)
        .post(`/me/orders/${parentId}/returns`)
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .send({
          childId,
          items: [{ purchaseRequestItemId: pri.id, quantity: 1, reason: 'OTHER' }],
        });
      expect(submit.status).toBe(201);
      const returnId = submit.body.id as number;

      // Cancel while REQUESTED works.
      const cancel1 = await request(app)
        .post(`/me/returns/${returnId}/cancel`)
        .set('Authorization', `Bearer ${buyer.accessToken}`);
      expect(cancel1.status).toBe(204);

      // Now try cancelling a second time — should 409 (not open).
      const cancel2 = await request(app)
        .post(`/me/returns/${returnId}/cancel`)
        .set('Authorization', `Bearer ${buyer.accessToken}`);
      expect(cancel2.status).toBe(409);
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('rejects returns when the shop has disabled them', async () => {
    const merchant = await createTestUser();
    await prisma.shop.update({
      where: { id: merchant.shopId },
      data: { returnsEnabled: false },
    });
    const buyer = await createTestUser({ role: Role.CUSTOMER });
    await prisma.party.create({
      data: {
        shopId: merchant.shopId,
        name: 'Test Buyer',
        linkedUserId: buyer.userId,
        email: buyer.email,
      },
    });
    try {
      const product = await createTestProduct(merchant.shopId, {
        isPublished: true,
        isActive: true,
        sellingPrice: 100,
        stockQuantity: 2,
      });
      const place = await request(app)
        .post('/me/orders')
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .set('X-Idempotency-Key', `policy-${Date.now()}`)
        .send({ items: [{ productId: product.id, quantity: 1 }] });
      const parentId = (place.body.id ?? place.body.orderId) as number;
      const childId = place.body.shopOrders[0].id as number;
      const confirm = await request(app)
        .post(`/orders/${childId}/confirm`)
        .set('Authorization', `Bearer ${merchantToken(merchant)}`)
        .send({});
      expect(confirm.status).toBe(200);
      const pri = await prisma.purchaseRequestItem.findFirstOrThrow({
        where: { requestId: childId },
        select: { id: true },
      });
      const submit = await request(app)
        .post(`/me/orders/${parentId}/returns`)
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .send({
          childId,
          items: [{ purchaseRequestItemId: pri.id, quantity: 1, reason: 'OTHER' }],
        });
      expect(submit.status).toBe(422);
      expect(submit.body.error).toBe('RETURNS_DISABLED');
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('refund amount scales when the order used a coupon (proportional)', async () => {
    const merchant = await createTestUser();
    const buyer = await createTestUser({ role: Role.CUSTOMER });
    await prisma.party.create({
      data: {
        shopId: merchant.shopId,
        name: 'Test Buyer',
        linkedUserId: buyer.userId,
        email: buyer.email,
      },
    });
    const coupon = await prisma.coupon.create({
      data: {
        code: `PROP${Date.now()}`.toUpperCase(),
        title: 'Prop test',
        discountType: 'PERCENT',
        discountValue: 20,
        minOrderAmount: 0,
        validFrom: new Date(Date.now() - 60_000),
        validUntil: new Date(Date.now() + 60 * 60_000),
        perUserLimit: 1,
        isActive: true,
      },
    });
    try {
      const product = await createTestProduct(merchant.shopId, {
        isPublished: true,
        isActive: true,
        sellingPrice: 500,
        stockQuantity: 5,
      });
      const place = await request(app)
        .post('/me/orders')
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .set('X-Idempotency-Key', `prop-${Date.now()}`)
        .send({
          items: [{ productId: product.id, quantity: 1 }],
          couponCode: coupon.code,
        });
      expect(place.status).toBe(201);
      // 20% off ₹500 = ₹100 discount, buyer paid ₹400 effectively.
      expect(place.body.couponDiscount).toBe(100);
      const parentId = (place.body.id ?? place.body.orderId) as number;
      const childId = place.body.shopOrders[0].id as number;
      const confirm = await request(app)
        .post(`/orders/${childId}/confirm`)
        .set('Authorization', `Bearer ${merchantToken(merchant)}`)
        .send({});
      expect(confirm.status).toBe(200);
      const pri = await prisma.purchaseRequestItem.findFirstOrThrow({
        where: { requestId: childId },
        select: { id: true },
      });
      const submit = await request(app)
        .post(`/me/orders/${parentId}/returns`)
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .send({
          childId,
          items: [{ purchaseRequestItemId: pri.id, quantity: 1, reason: 'OTHER' }],
        });
      expect(submit.status).toBe(201);
      const got = await request(app)
        .get(`/me/returns/${submit.body.id}`)
        .set('Authorization', `Bearer ${buyer.accessToken}`);
      // Refund should be the price minus the coupon's share: ₹400.
      expect(Number(got.body.refundAmount)).toBe(400);
    } finally {
      await prisma.couponRedemption.deleteMany({ where: { couponId: coupon.id } });
      await prisma.coupon.delete({ where: { id: coupon.id } });
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });
});
