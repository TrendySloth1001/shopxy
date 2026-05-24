import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import crypto from 'crypto';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

const app = buildApp();
const uuid = () => crypto.randomBytes(8).toString('hex');

async function seed(productId: number, userId: number, type: string, when?: Date) {
  await prisma.productEvent.create({
    data: {
      clientUuid: uuid(),
      eventType: type as 'IMPRESSION' | 'TAP' | 'VIEW' | 'PURCHASE',
      productId,
      userId,
      occurredAt: when ?? new Date(),
    },
  });
}

describe('analytics — /me/analytics/products', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('rejects unauthenticated callers', async () => {
    const res = await request(app).get('/me/analytics/products');
    expect(res.status).toBe(401);
  });

  it('aggregates per-product within the requested window', async () => {
    const merchant = await createTestUser();
    try {
      const p = await createTestProduct(merchant.shopId);
      // inside window
      await seed(p.id, merchant.userId, 'IMPRESSION');
      await seed(p.id, merchant.userId, 'IMPRESSION');
      await seed(p.id, merchant.userId, 'TAP');
      await seed(p.id, merchant.userId, 'VIEW');
      await seed(p.id, merchant.userId, 'PURCHASE');
      // outside (50 days ago)
      await seed(p.id, merchant.userId, 'TAP', new Date(Date.now() - 50 * 86_400_000));

      const res = await request(app)
        .get('/me/analytics/products')
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      expect(res.status).toBe(200);
      const row = res.body.products.find(
        (r: { productId: number }) => r.productId === p.id,
      );
      expect(row.impressions).toBe(2);
      expect(row.taps).toBe(1); // outside-window tap excluded
      expect(row.views).toBe(1);
      expect(row.purchases).toBe(1);
      // CTR = 1/2 = 0.5; CVR = 1/1 = 1.0
      expect(row.ctr).toBe(0.5);
      expect(row.cvr).toBe(1);
    } finally {
      await prisma.productEvent.deleteMany({ where: { userId: merchant.userId } });
      await cleanupTestUser(merchant);
    }
  });

  it('cross-tenant: shop B never sees shop A events', async () => {
    const a = await createTestUser();
    const b = await createTestUser();
    try {
      const pA = await createTestProduct(a.shopId);
      await seed(pA.id, a.userId, 'TAP');
      await seed(pA.id, a.userId, 'PURCHASE');

      const resB = await request(app)
        .get('/me/analytics/products')
        .set('Authorization', `Bearer ${b.accessToken}`);
      expect(resB.status).toBe(200);
      expect(
        resB.body.products.find((r: { productId: number }) => r.productId === pA.id),
      ).toBeUndefined();
      expect(resB.body.totals.purchases).toBe(0);
    } finally {
      await prisma.productEvent.deleteMany({ where: { userId: a.userId } });
      await cleanupTestUser(a);
      await cleanupTestUser(b);
    }
  });

  it('rejects ranges longer than 90 days', async () => {
    const merchant = await createTestUser();
    try {
      const from = new Date(Date.now() - 200 * 86_400_000).toISOString();
      const to = new Date().toISOString();
      const res = await request(app)
        .get(`/me/analytics/products?from=${from}&to=${to}`)
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      expect(res.status).toBe(400);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('rejects to <= from', async () => {
    const merchant = await createTestUser();
    try {
      const from = new Date().toISOString();
      const to = new Date(Date.now() - 86_400_000).toISOString();
      const res = await request(app)
        .get(`/me/analytics/products?from=${from}&to=${to}`)
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      expect(res.status).toBe(400);
    } finally {
      await cleanupTestUser(merchant);
    }
  });
});

describe('analytics — /me/analytics/flash-deals/:id', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('returns sold + traffic series inside the flash window', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const start = new Date(Date.now() - 3 * 3_600_000);
      const end = new Date(Date.now() + 3 * 3_600_000);
      const sale = await prisma.flashSale.create({
        data: {
          productId: product.id,
          flashPrice: 50,
          stockLimit: 5,
          startAt: start,
          endAt: end,
        },
      });
      await seed(product.id, merchant.userId, 'PURCHASE', new Date(Date.now() - 60_000));
      await seed(product.id, merchant.userId, 'TAP', new Date(Date.now() - 60_000));
      // out-of-window
      await seed(product.id, merchant.userId, 'PURCHASE', new Date(Date.now() - 4 * 3_600_000));

      const res = await request(app)
        .get(`/me/analytics/flash-deals/${sale.id}`)
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.flashSaleId).toBe(sale.id);
      const totalSold = res.body.series.reduce(
        (s: number, r: { sold: number }) => s + r.sold,
        0,
      );
      expect(totalSold).toBe(1);
    } finally {
      await prisma.productEvent.deleteMany({ where: { userId: merchant.userId } });
      await cleanupTestUser(merchant);
    }
  });

  it('404s on a flash deal that belongs to another shop', async () => {
    const a = await createTestUser();
    const b = await createTestUser();
    try {
      const productOfA = await createTestProduct(a.shopId);
      const sale = await prisma.flashSale.create({
        data: {
          productId: productOfA.id,
          flashPrice: 50,
          stockLimit: 5,
          startAt: new Date(Date.now() - 3_600_000),
          endAt: new Date(Date.now() + 3_600_000),
        },
      });
      const res = await request(app)
        .get(`/me/analytics/flash-deals/${sale.id}`)
        .set('Authorization', `Bearer ${b.accessToken}`);
      expect(res.status).toBe(404);
    } finally {
      await cleanupTestUser(a);
      await cleanupTestUser(b);
    }
  });
});
