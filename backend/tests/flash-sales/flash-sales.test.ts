import { describe, it, expect, afterAll, beforeAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { pingRedis, closeRedis, getRedis, redisAvailable } from '../../src/infra/redis.js';
import { flashSalesService } from '../../src/modules/flash-sales/flash-sales.service.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

const app = buildApp();

const now = () => new Date();
const minutes = (n: number) => new Date(Date.now() + n * 60_000);

async function clearRedisFlashKeys() {
  if (!redisAvailable()) return;
  // Scan & delete the test-private keys; harmless if none exist.
  const stream = getRedis().scanStream({ match: 'flash:*:sold' });
  const keys: string[] = [];
  for await (const batch of stream) {
    for (const k of batch as string[]) keys.push(k);
  }
  if (keys.length > 0) await getRedis().del(...keys);
}

describe('flash-sales — merchant CRUD scoping', () => {
  beforeAll(async () => {
    await pingRedis().catch(() => undefined);
  });
  afterAll(async () => {
    await clearRedisFlashKeys();
    await closeRedis();
    await prisma.$disconnect();
  });

  it('POST /me/flash-deals creates an active sale on caller-shop product', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const res = await request(app)
        .post('/me/flash-deals')
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send({
          productId: product.id,
          flashPrice: 50,
          stockLimit: 10,
          startAt: minutes(-1).toISOString(),
          endAt: minutes(60).toISOString(),
        });
      expect(res.status).toBe(201);
      expect(res.body.stockLimit).toBe(10);
      expect(res.body.soldCount).toBe(0);
      expect(Number(res.body.flashPrice)).toBe(50);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('rejects creating a flash sale on another shops product (404)', async () => {
    const a = await createTestUser();
    const b = await createTestUser();
    try {
      const productOfA = await createTestProduct(a.shopId);
      const res = await request(app)
        .post('/me/flash-deals')
        .set('Authorization', `Bearer ${b.accessToken}`) // wrong merchant
        .send({
          productId: productOfA.id,
          flashPrice: 50,
          stockLimit: 10,
          startAt: minutes(-1).toISOString(),
          endAt: minutes(60).toISOString(),
        });
      expect(res.status).toBe(404);
    } finally {
      await cleanupTestUser(a);
      await cleanupTestUser(b);
    }
  });

  it('rejects second active sale on the same product (409 active_sale_exists)', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const win = {
        startAt: minutes(-1).toISOString(),
        endAt: minutes(60).toISOString(),
      };
      const first = await request(app)
        .post('/me/flash-deals')
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send({ productId: product.id, flashPrice: 50, stockLimit: 5, ...win });
      expect(first.status).toBe(201);
      const second = await request(app)
        .post('/me/flash-deals')
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send({ productId: product.id, flashPrice: 40, stockLimit: 5, ...win });
      expect(second.status).toBe(409);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('rejects invalid scheduling window (end ≤ start)', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const res = await request(app)
        .post('/me/flash-deals')
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send({
          productId: product.id,
          flashPrice: 50,
          stockLimit: 5,
          startAt: minutes(60).toISOString(),
          endAt: minutes(-1).toISOString(),
        });
      expect(res.status).toBe(400);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('GET /me/flash-deals filters by status (active|scheduled|past)', async () => {
    const merchant = await createTestUser();
    try {
      const p1 = await createTestProduct(merchant.shopId);
      const p2 = await createTestProduct(merchant.shopId);
      const p3 = await createTestProduct(merchant.shopId);
      // active
      await prisma.flashSale.create({
        data: {
          productId: p1.id, flashPrice: 50, stockLimit: 5,
          startAt: minutes(-1), endAt: minutes(60),
        },
      });
      // scheduled
      await prisma.flashSale.create({
        data: {
          productId: p2.id, flashPrice: 50, stockLimit: 5,
          startAt: minutes(60), endAt: minutes(120),
        },
      });
      // past
      await prisma.flashSale.create({
        data: {
          productId: p3.id, flashPrice: 50, stockLimit: 5,
          startAt: minutes(-120), endAt: minutes(-60),
        },
      });

      const auth = { Authorization: `Bearer ${merchant.accessToken}` };
      const a = await request(app).get('/me/flash-deals?status=active').set(auth);
      const s = await request(app).get('/me/flash-deals?status=scheduled').set(auth);
      const p = await request(app).get('/me/flash-deals?status=past').set(auth);
      expect(a.body.data.map((r: { productId: number }) => r.productId)).toEqual([p1.id]);
      expect(s.body.data.map((r: { productId: number }) => r.productId)).toEqual([p2.id]);
      expect(p.body.data.map((r: { productId: number }) => r.productId)).toEqual([p3.id]);
    } finally {
      await cleanupTestUser(merchant);
    }
  });
});

describe('flash-sales — public read', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('GET /flash-deals/active returns only currently-running sales', async () => {
    const merchant = await createTestUser();
    try {
      const p1 = await createTestProduct(merchant.shopId);
      const p2 = await createTestProduct(merchant.shopId);
      await prisma.flashSale.create({
        data: {
          productId: p1.id, flashPrice: 50, stockLimit: 5,
          startAt: minutes(-1), endAt: minutes(60),
        },
      });
      await prisma.flashSale.create({
        data: {
          productId: p2.id, flashPrice: 50, stockLimit: 5,
          startAt: minutes(60), endAt: minutes(120),
        },
      });
      const res = await request(app).get('/flash-deals/active');
      expect(res.status).toBe(200);
      const productIds = res.body.data.map(
        (r: { productId: number }) => r.productId,
      );
      expect(productIds).toContain(p1.id);
      expect(productIds).not.toContain(p2.id);
    } finally {
      await cleanupTestUser(merchant);
    }
  });
});

describe('flash-sales — atomic claim', () => {
  beforeAll(async () => {
    await pingRedis().catch(() => undefined);
  });
  afterAll(async () => {
    await clearRedisFlashKeys();
    await prisma.$disconnect();
  });

  it('claim succeeds under the stock limit', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      await prisma.flashSale.create({
        data: {
          productId: product.id, flashPrice: 50, stockLimit: 5,
          startAt: minutes(-1), endAt: minutes(60),
        },
      });
      const r1 = await flashSalesService.claim(product.id, 2);
      const r2 = await flashSalesService.claim(product.id, 2);
      expect(r1.ok).toBe(true);
      expect(r2.ok).toBe(true);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('claim fails with out_of_stock when stock_limit would be exceeded', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      await prisma.flashSale.create({
        data: {
          productId: product.id, flashPrice: 50, stockLimit: 3,
          startAt: minutes(-1), endAt: minutes(60),
        },
      });
      const ok = await flashSalesService.claim(product.id, 2);
      const overflow = await flashSalesService.claim(product.id, 2); // total would be 4 > 3
      expect(ok.ok).toBe(true);
      expect(overflow.ok).toBe(false);
      expect((overflow as { reason: string }).reason).toBe('out_of_stock');
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('concurrent parallel claims NEVER exceed stock_limit', async () => {
    // 100 parallel claims of 1 unit, limit 20. Exactly 20 must succeed.
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      await prisma.flashSale.create({
        data: {
          productId: product.id, flashPrice: 50, stockLimit: 20,
          startAt: minutes(-1), endAt: minutes(60),
        },
      });
      const attempts = await Promise.all(
        Array.from({ length: 100 }, () => flashSalesService.claim(product.id, 1)),
      );
      const successes = attempts.filter((r) => r.ok).length;
      expect(successes).toBe(20);
      // Either Redis (preferred) or the DB-lock fallback must hold the
      // invariant; never go over the cap.
      const sumSold = attempts
        .filter((r) => r.ok)
        .reduce((s, r) => s + ((r as { soldAfter: number }).soldAfter > 0 ? 1 : 0), 0);
      expect(sumSold).toBe(20);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('release restores headroom for a subsequent claim', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      await prisma.flashSale.create({
        data: {
          productId: product.id, flashPrice: 50, stockLimit: 2,
          startAt: minutes(-1), endAt: minutes(60),
        },
      });
      await flashSalesService.claim(product.id, 2);
      // Sold out.
      const denied = await flashSalesService.claim(product.id, 1);
      expect(denied.ok).toBe(false);
      // Roll one back.
      await flashSalesService.release(product.id, 1);
      const second = await flashSalesService.claim(product.id, 1);
      expect(second.ok).toBe(true);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('flushSoldCountersToDb persists Redis values to Postgres', async () => {
    if (!redisAvailable()) return; // no-op without redis
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const sale = await prisma.flashSale.create({
        data: {
          productId: product.id, flashPrice: 50, stockLimit: 10,
          startAt: minutes(-1), endAt: minutes(60),
        },
      });
      await flashSalesService.claim(product.id, 4);
      await flashSalesService.flushSoldCountersToDb();
      const after = await prisma.flashSale.findUnique({ where: { id: sale.id } });
      expect(after?.soldCount).toBe(4);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('sweepExpired deactivates sales whose endAt has passed', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const sale = await prisma.flashSale.create({
        data: {
          productId: product.id, flashPrice: 50, stockLimit: 5,
          startAt: minutes(-120), endAt: minutes(-60),
        },
      });
      const result = await flashSalesService.sweepExpired();
      expect(result.deactivated).toBeGreaterThanOrEqual(1);
      const after = await prisma.flashSale.findUnique({ where: { id: sale.id } });
      expect(after?.isActive).toBe(false);
    } finally {
      await cleanupTestUser(merchant);
    }
  });
});
