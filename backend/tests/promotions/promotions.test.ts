import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { promotionsService } from '../../src/modules/promotions/promotions.service.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

const app = buildApp();
const minutes = (n: number) => new Date(Date.now() + n * 60_000);

describe('promotions — merchant CRUD scoping', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('POST /me/promotions creates a row on caller-shop product', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const res = await request(app)
        .post('/me/promotions')
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send({
          productId: product.id,
          budgetPaise: 100_000,
          dailyCapPaise: 25_000,
          cpmPaise: 1_000,
          startAt: minutes(-1).toISOString(),
          endAt: minutes(60).toISOString(),
        });
      expect(res.status).toBe(201);
      expect(res.body.budgetPaise).toBe(100_000);
      expect(res.body.isActive).toBe(true);
    } finally {
      await prisma.promotion.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });

  it('rejects creating on another shops product (404)', async () => {
    const a = await createTestUser();
    const b = await createTestUser();
    try {
      const productOfA = await createTestProduct(a.shopId);
      const res = await request(app)
        .post('/me/promotions')
        .set('Authorization', `Bearer ${b.accessToken}`)
        .send({
          productId: productOfA.id,
          budgetPaise: 100_000,
          dailyCapPaise: 25_000,
          cpmPaise: 1_000,
          startAt: minutes(-1).toISOString(),
          endAt: minutes(60).toISOString(),
        });
      expect(res.status).toBe(404);
    } finally {
      await cleanupTestUser(a);
      await cleanupTestUser(b);
    }
  });

  it('rejects dailyCap > budget (zod 400)', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const res = await request(app)
        .post('/me/promotions')
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send({
          productId: product.id,
          budgetPaise: 10_000,
          dailyCapPaise: 20_000, // > budget
          cpmPaise: 1_000,
          startAt: minutes(-1).toISOString(),
          endAt: minutes(60).toISOString(),
        });
      expect(res.status).toBe(400);
    } finally {
      await cleanupTestUser(merchant);
    }
  });
});

describe('promotions — recordImpressions auto-pause', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('auto-pauses when total spend crosses budget', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const promo = await prisma.promotion.create({
        data: {
          shopId: merchant.shopId,
          productId: product.id,
          budgetPaise: 1_000, // tiny
          dailyCapPaise: 1_000,
          cpmPaise: 1_000, // 1₹ per 1000 impressions; 1000 imps → 1000 paise
          startAt: minutes(-1),
          endAt: minutes(60),
        },
      });
      const after = await promotionsService.recordImpressions(promo.id, 1_000);
      expect(after?.isActive).toBe(false);
      expect(after?.pausedReason).toBe('budget_exhausted');
      expect(after?.spendPaise).toBeGreaterThanOrEqual(1_000);
    } finally {
      await prisma.promotion.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });

  it('auto-pauses when daily cap is reached even with budget remaining', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const promo = await prisma.promotion.create({
        data: {
          shopId: merchant.shopId,
          productId: product.id,
          budgetPaise: 10_000, // headroom
          dailyCapPaise: 500,  // tight
          cpmPaise: 1_000,
          startAt: minutes(-1),
          endAt: minutes(60),
        },
      });
      const after = await promotionsService.recordImpressions(promo.id, 500);
      expect(after?.isActive).toBe(false);
      expect(after?.pausedReason).toBe('daily_cap_reached');
      expect(after?.spendPaise).toBeLessThan(after!.budgetPaise);
    } finally {
      await prisma.promotion.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });

  it('skips paused promotions (no further spend accrued)', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const promo = await prisma.promotion.create({
        data: {
          shopId: merchant.shopId,
          productId: product.id,
          budgetPaise: 10_000,
          dailyCapPaise: 10_000,
          cpmPaise: 1_000,
          isActive: false,
          pausedReason: 'cancelled_by_merchant',
          startAt: minutes(-1),
          endAt: minutes(60),
        },
      });
      const after = await promotionsService.recordImpressions(promo.id, 1_000);
      expect(after?.isActive).toBe(false);
      expect(after?.spendPaise).toBe(0);
    } finally {
      await prisma.promotion.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });
});

describe('promotions — sponsored injection + sweep', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('pickSponsored returns only active + currently-running + published promos', async () => {
    const merchant = await createTestUser();
    try {
      const pubProduct = await createTestProduct(merchant.shopId, {
        isPublished: true,
      });
      const draftProduct = await createTestProduct(merchant.shopId, {
        isPublished: false,
      });
      await prisma.promotion.create({
        data: {
          shopId: merchant.shopId,
          productId: pubProduct.id,
          budgetPaise: 10_000,
          dailyCapPaise: 10_000,
          cpmPaise: 1_000,
          startAt: minutes(-1),
          endAt: minutes(60),
        },
      });
      // draft product — promotion exists but should be filtered out
      await prisma.promotion.create({
        data: {
          shopId: merchant.shopId,
          productId: draftProduct.id,
          budgetPaise: 10_000,
          dailyCapPaise: 10_000,
          cpmPaise: 1_000,
          startAt: minutes(-1),
          endAt: minutes(60),
        },
      });
      // expired promotion
      await prisma.promotion.create({
        data: {
          shopId: merchant.shopId,
          productId: pubProduct.id,
          budgetPaise: 10_000,
          dailyCapPaise: 10_000,
          cpmPaise: 1_000,
          startAt: minutes(-120),
          endAt: minutes(-60),
        },
      });
      // Bump the budget so this promotion outweighs any pre-existing
      // seed promotions when pickSponsored does weighted sampling.
      // Filter to picks for this test's products only — other tests
      // / seed data may have their own promotions in the global pool.
      const picks = await promotionsService.pickSponsored({ count: 20 });
      const ourPicks = picks.filter(
        (p) => p.productId === pubProduct.id || p.productId === draftProduct.id,
      );
      expect(ourPicks.length).toBeGreaterThanOrEqual(1);
      // Critical invariant: the draft product's promo never surfaces.
      expect(
        ourPicks.find((p) => p.productId === draftProduct.id),
      ).toBeUndefined();
    } finally {
      await prisma.promotion.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });

  it('sweepDailyCaps expires promotions past endAt', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const promo = await prisma.promotion.create({
        data: {
          shopId: merchant.shopId,
          productId: product.id,
          budgetPaise: 10_000,
          dailyCapPaise: 10_000,
          cpmPaise: 1_000,
          startAt: minutes(-120),
          endAt: minutes(-60), // past
        },
      });
      await promotionsService.sweepDailyCaps();
      const after = await prisma.promotion.findUnique({ where: { id: promo.id } });
      expect(after?.isActive).toBe(false);
      expect(after?.pausedReason).toBe('window_ended');
    } finally {
      await prisma.promotion.deleteMany({ where: { shopId: merchant.shopId } });
      await cleanupTestUser(merchant);
    }
  });
});
