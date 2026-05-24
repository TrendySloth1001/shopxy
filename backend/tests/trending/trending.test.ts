import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import crypto from 'crypto';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { trendingService } from '../../src/modules/trending/trending.service.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
  recordTestPurchase,
} from '../helpers/setup.js';

const app = buildApp();

const uuid = () => crypto.randomBytes(8).toString('hex');

async function seedEvent(opts: {
  productId: number;
  userId: number;
  type:
    | 'IMPRESSION'
    | 'TAP'
    | 'VIEW'
    | 'ADD_TO_CART'
    | 'PURCHASE'
    | 'WISHLIST_ADD';
  occurredAt?: Date;
}) {
  await prisma.productEvent.create({
    data: {
      clientUuid: uuid(),
      eventType: opts.type,
      productId: opts.productId,
      userId: opts.userId,
      occurredAt: opts.occurredAt ?? new Date(),
    },
  });
}

async function makePublishedProduct(shopId: number, categoryId?: number | null) {
  const product = await createTestProduct(shopId, { isPublished: true });
  if (categoryId !== undefined) {
    await prisma.product.update({
      where: { id: product.id },
      data: { categoryId },
    });
  }
  return product;
}

describe('trending — recomputeWindow + listTrending', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('recompute produces non-zero scores when events exist', async () => {
    const user = await createTestUser();
    try {
      const p = await makePublishedProduct(user.shopId);
      await seedEvent({ productId: p.id, userId: user.userId, type: 'TAP' });
      await seedEvent({ productId: p.id, userId: user.userId, type: 'PURCHASE' });

      const result = await trendingService.recomputeWindow();
      expect(result.products).toBeGreaterThanOrEqual(1);

      const score = await prisma.trendingScore.findFirst({
        where: { productId: p.id, categoryId: null },
        orderBy: { windowEnd: 'desc' },
      });
      expect(score).not.toBeNull();
      expect(Number(score!.score)).toBeGreaterThan(0);
    } finally {
      await prisma.productEvent.deleteMany({ where: { userId: user.userId } });
      await cleanupTestUser(user);
    }
  });

  it('PURCHASE outranks TAP for the same product', async () => {
    const user = await createTestUser();
    try {
      const pBuy = await makePublishedProduct(user.shopId);
      const pTap = await makePublishedProduct(user.shopId);
      // 1 PURCHASE = 10 points; 5 TAPs = 1.5 points
      await seedEvent({ productId: pBuy.id, userId: user.userId, type: 'PURCHASE' });
      for (let i = 0; i < 5; i++) {
        await seedEvent({ productId: pTap.id, userId: user.userId, type: 'TAP' });
      }
      await trendingService.recomputeWindow();
      const rows = await trendingService.listTrending({ categoryId: null });
      const buyIdx = rows.findIndex((r) => r.product.id === pBuy.id);
      const tapIdx = rows.findIndex((r) => r.product.id === pTap.id);
      expect(buyIdx).toBeGreaterThanOrEqual(0);
      expect(tapIdx).toBeGreaterThan(buyIdx); // tap comes after purchase
    } finally {
      await prisma.productEvent.deleteMany({ where: { userId: user.userId } });
      await cleanupTestUser(user);
    }
  });

  it('GET /products/trending?categoryId filters to that category', async () => {
    const user = await createTestUser();
    try {
      const catA = await prisma.category.create({
        data: { name: `T-A-${uuid()}`, slug: `t-a-${uuid()}` },
      });
      const catB = await prisma.category.create({
        data: { name: `T-B-${uuid()}`, slug: `t-b-${uuid()}` },
      });
      const pA = await makePublishedProduct(user.shopId, catA.id);
      const pB = await makePublishedProduct(user.shopId, catB.id);
      await seedEvent({ productId: pA.id, userId: user.userId, type: 'TAP' });
      await seedEvent({ productId: pB.id, userId: user.userId, type: 'TAP' });
      await trendingService.recomputeWindow();

      const res = await request(app)
        .get(`/products/trending?categoryId=${catA.id}`);
      expect(res.status).toBe(200);
      const ids = res.body.data.map(
        (r: { product: { id: number } }) => r.product.id,
      );
      expect(ids).toContain(pA.id);
      expect(ids).not.toContain(pB.id);
    } finally {
      await prisma.productEvent.deleteMany({ where: { userId: user.userId } });
      await cleanupTestUser(user);
    }
  });

  it('listTrending hides unpublished products', async () => {
    const user = await createTestUser();
    try {
      const draft = await createTestProduct(user.shopId, { isPublished: false });
      await seedEvent({ productId: draft.id, userId: user.userId, type: 'PURCHASE' });
      await trendingService.recomputeWindow();

      const rows = await trendingService.listTrending({ categoryId: null });
      expect(rows.find((r) => r.product.id === draft.id)).toBeFalsy();
    } finally {
      await prisma.productEvent.deleteMany({ where: { userId: user.userId } });
      await cleanupTestUser(user);
    }
  });
});

describe('trending — recommendations', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('cold-start user falls back to global trending', async () => {
    const merchant = await createTestUser();
    const customer = await createTestUser();
    try {
      const p = await makePublishedProduct(merchant.shopId);
      await seedEvent({ productId: p.id, userId: merchant.userId, type: 'PURCHASE' });
      await trendingService.recomputeWindow();

      const res = await request(app)
        .get('/products/recommended')
        .set('Authorization', `Bearer ${customer.accessToken}`);
      expect(res.status).toBe(200);
      const ids = res.body.data.map((r: { id: number }) => r.id);
      expect(ids).toContain(p.id);
    } finally {
      await prisma.productEvent.deleteMany({
        where: { userId: { in: [merchant.userId, customer.userId] } },
      });
      await cleanupTestUser(merchant);
      await cleanupTestUser(customer);
    }
  });

  it('recomputeForUser prefers user-engaged categories and downranks already-purchased', async () => {
    const merchant = await createTestUser();
    const customer = await createTestUser();
    try {
      const liked = await prisma.category.create({
        data: { name: `L-${uuid()}`, slug: `l-${uuid()}` },
      });
      const ignored = await prisma.category.create({
        data: { name: `I-${uuid()}`, slug: `i-${uuid()}` },
      });

      const pLikedA = await makePublishedProduct(merchant.shopId, liked.id);
      const pLikedB = await makePublishedProduct(merchant.shopId, liked.id);
      const pIgnored = await makePublishedProduct(merchant.shopId, ignored.id);

      // Customer views products in the liked category — both surface
      // as candidates. They've also already purchased pLikedA.
      await seedEvent({ productId: pLikedA.id, userId: customer.userId, type: 'VIEW' });
      await seedEvent({ productId: pLikedB.id, userId: customer.userId, type: 'VIEW' });
      // Equal popularity for the two liked products so the purchase
      // penalty (applied only to pLikedA after the test buys it) is
      // what differentiates them. The ignored category gets its own
      // events so trending has rows there too.
      for (let i = 0; i < 5; i++) {
        await seedEvent({ productId: pLikedA.id, userId: merchant.userId, type: 'TAP' });
        await seedEvent({ productId: pLikedB.id, userId: merchant.userId, type: 'TAP' });
      }
      await seedEvent({ productId: pIgnored.id, userId: merchant.userId, type: 'PURCHASE' });
      await trendingService.recomputeWindow();

      // Mark pLikedA as already-purchased by the customer.
      await recordTestPurchase({
        shopId: merchant.shopId,
        buyerUserId: customer.userId,
        productId: pLikedA.id,
      });

      const result = await trendingService.recomputeForUser(customer.userId);
      expect(result.count).toBeGreaterThan(0);

      const cache = await prisma.recommendationCache.findUniqueOrThrow({
        where: { userId_slot: { userId: customer.userId, slot: 'for_you' } },
      });
      // Recs are pulled from the liked-category trending bucket, so
      // ignored category never makes it in.
      expect(cache.productIds).not.toContain(pIgnored.id);
      // Within the liked bucket, the not-yet-purchased product
      // should outrank the already-purchased one (penalty applied).
      const aIdx = cache.productIds.indexOf(pLikedA.id);
      const bIdx = cache.productIds.indexOf(pLikedB.id);
      expect(bIdx).toBeGreaterThanOrEqual(0);
      if (aIdx >= 0) expect(bIdx).toBeLessThan(aIdx);
    } finally {
      await prisma.recommendationCache.deleteMany({
        where: { userId: { in: [merchant.userId, customer.userId] } },
      });
      await prisma.productEvent.deleteMany({
        where: { userId: { in: [merchant.userId, customer.userId] } },
      });
      await cleanupTestUser(customer);
      await cleanupTestUser(merchant);
    }
  });

  it('warm-cache user reads from cache, not trending', async () => {
    const merchant = await createTestUser();
    const customer = await createTestUser();
    try {
      const p = await makePublishedProduct(merchant.shopId);
      await prisma.recommendationCache.create({
        data: {
          userId: customer.userId,
          slot: 'for_you',
          productIds: [p.id],
        },
      });
      const res = await request(app)
        .get('/products/recommended')
        .set('Authorization', `Bearer ${customer.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.data.map((r: { id: number }) => r.id)).toEqual([p.id]);
    } finally {
      await prisma.recommendationCache.deleteMany({
        where: { userId: customer.userId },
      });
      await cleanupTestUser(customer);
      await cleanupTestUser(merchant);
    }
  });
});
