import { describe, it, expect, afterAll, beforeAll } from 'vitest';
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

function userToken(ctx: { userId: number; email: string; role: Role }): string {
  return jwt.sign(
    { sub: ctx.userId, email: ctx.email, role: ctx.role, isPlatformAdmin: false },
    process.env.JWT_ACCESS_SECRET!,
    { expiresIn: '15m' },
  );
}

/// End-to-end coverage: validate preview, apply at checkout, wallet
/// debit on checkout, atomic counter on totalCap.
describe('coupons — validate + redeem + wallet checkout', () => {
  const couponIds: number[] = [];

  afterAll(async () => {
    await prisma.couponRedemption.deleteMany({ where: { couponId: { in: couponIds } } });
    await prisma.coupon.deleteMany({ where: { id: { in: couponIds } } });
    await prisma.$disconnect();
  });

  it('validate previews discount + redeem applies it on order create', async () => {
    const buyer = await createTestUser({ role: Role.CUSTOMER });
    const merchant = await createTestUser();
    await prisma.party.create({
      data: {
        shopId: merchant.shopId,
        name: 'Buyer',
        linkedUserId: buyer.userId,
        email: buyer.email,
      },
    });
    try {
      const product = await createTestProduct(merchant.shopId, {
        isPublished: true,
        sellingPrice: 500,
        stockQuantity: 5,
      });

      const coupon = await prisma.coupon.create({
        data: {
          code: `TEST${Date.now()}`.toUpperCase(),
          title: 'Test 10%',
          discountType: 'PERCENT',
          discountValue: 10,
          maxDiscount: 100,
          minOrderAmount: 100,
          validFrom: new Date(Date.now() - 60_000),
          validUntil: new Date(Date.now() + 60 * 60_000),
          isActive: true,
          perUserLimit: 1,
          totalCap: 0,
        },
      });
      couponIds.push(coupon.id);

      // Preview
      const preview = await request(app)
        .post('/me/coupons/validate')
        .set('Authorization', `Bearer ${userToken(buyer)}`)
        .send({ code: coupon.code, subtotal: 500, shopIds: [merchant.shopId] });
      expect(preview.status).toBe(200);
      expect(preview.body.ok).toBe(true);
      // 10% of 500 = 50, below the ₹100 cap.
      expect(preview.body.coupon.discount).toBe(50);
      // Contract: the validate response must echo the raw coupon params the
      // customer client's `couponSchema` requires — `discountValue` is
      // mandatory there, so omitting it makes every coupon fail to validate.
      expect(preview.body.coupon.discountValue).toBe(10);
      expect(preview.body.coupon.maxDiscountAmount).toBe(100);
      expect(preview.body.coupon.minOrderAmount).toBe(100);
      expect(typeof preview.body.coupon.expiresAt).toBe('string');

      // Place order with coupon
      const place = await request(app)
        .post('/me/orders')
        .set('Authorization', `Bearer ${userToken(buyer)}`)
        .set('X-Idempotency-Key', `idem-${Date.now()}`)
        .send({
          items: [{ productId: product.id, quantity: 1 }],
          couponCode: coupon.code,
        });
      expect(place.status).toBe(201);
      expect(place.body.couponDiscount).toBe(50);

      // Confirm redemption row + counter bump
      const rows = await prisma.couponRedemption.findMany({
        where: { couponId: coupon.id },
      });
      expect(rows.length).toBe(1);
      const counted = await prisma.coupon.findUniqueOrThrow({
        where: { id: coupon.id },
      });
      expect(counted.totalRedemptions).toBe(1);
    } finally {
      await cleanupTestUser(buyer);
      await cleanupTestUser(merchant);
    }
  });

  it('per-user limit blocks a second redemption', async () => {
    const buyer = await createTestUser({ role: Role.CUSTOMER });
    const merchant = await createTestUser();
    await prisma.party.create({
      data: {
        shopId: merchant.shopId,
        name: 'Buyer',
        linkedUserId: buyer.userId,
        email: buyer.email,
      },
    });
    try {
      const product = await createTestProduct(merchant.shopId, {
        isPublished: true,
        sellingPrice: 200,
        stockQuantity: 5,
      });
      const coupon = await prisma.coupon.create({
        data: {
          code: `ONCE${Date.now()}`.toUpperCase(),
          title: 'Once per user',
          discountType: 'FLAT',
          discountValue: 30,
          minOrderAmount: 0,
          validFrom: new Date(Date.now() - 60_000),
          validUntil: new Date(Date.now() + 60 * 60_000),
          perUserLimit: 1,
        },
      });
      couponIds.push(coupon.id);

      const first = await request(app)
        .post('/me/orders')
        .set('Authorization', `Bearer ${userToken(buyer)}`)
        .set('X-Idempotency-Key', `idem-1-${Date.now()}`)
        .send({
          items: [{ productId: product.id, quantity: 1 }],
          couponCode: coupon.code,
        });
      expect(first.status).toBe(201);
      expect(first.body.couponDiscount).toBe(30);

      // Second attempt should fail with COUPON_INVALID.
      const second = await request(app)
        .post('/me/orders')
        .set('Authorization', `Bearer ${userToken(buyer)}`)
        .set('X-Idempotency-Key', `idem-2-${Date.now()}`)
        .send({
          items: [{ productId: product.id, quantity: 1 }],
          couponCode: coupon.code,
        });
      expect(second.status).toBe(400);
      expect(second.body.error).toBe('COUPON_INVALID');
    } finally {
      await cleanupTestUser(buyer);
      await cleanupTestUser(merchant);
    }
  });

  it('wallet usage debits the ledger at checkout', async () => {
    const buyer = await createTestUser({ role: Role.CUSTOMER });
    const merchant = await createTestUser();
    await prisma.party.create({
      data: {
        shopId: merchant.shopId,
        name: 'Buyer',
        linkedUserId: buyer.userId,
        email: buyer.email,
      },
    });
    // Pre-credit the buyer's wallet so the checkout has something to
    // debit. Goes via the service so the denormed balance stays in sync.
    const { walletService } = await import('../../src/modules/wallet/wallet.service.js');
    await walletService.credit({
      userId: buyer.userId,
      amount: 200,
      source: 'MANUAL',
      description: 'test top-up',
    });
    try {
      const product = await createTestProduct(merchant.shopId, {
        isPublished: true,
        sellingPrice: 500,
        stockQuantity: 5,
      });
      const place = await request(app)
        .post('/me/orders')
        .set('Authorization', `Bearer ${userToken(buyer)}`)
        .set('X-Idempotency-Key', `wallet-${Date.now()}`)
        .send({
          items: [{ productId: product.id, quantity: 1 }],
          useWallet: true,
        });
      expect(place.status).toBe(201);
      expect(place.body.walletPaid).toBe(200);

      const wallet = await request(app)
        .get('/me/wallet')
        .set('Authorization', `Bearer ${userToken(buyer)}`);
      expect(wallet.body.balance).toBe(0);
      const checkoutEntry = wallet.body.entries.find(
        (e: { source: string }) => e.source === 'CHECKOUT',
      );
      expect(checkoutEntry).toBeDefined();
      expect(checkoutEntry.amount).toBe(-200);
    } finally {
      await cleanupTestUser(buyer);
      await cleanupTestUser(merchant);
    }
  });
});
