import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

const app = buildApp();

describe('products multi-tenant scoping', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('GET /products returns ONLY caller-shop rows', async () => {
    const shopA = await createTestUser();
    const shopB = await createTestUser();
    try {
      await Promise.all([
        createTestProduct(shopA.shopId),
        createTestProduct(shopA.shopId),
        createTestProduct(shopA.shopId),
        createTestProduct(shopB.shopId),
        createTestProduct(shopB.shopId),
      ]);

      const resA = await request(app)
        .get('/products?limit=50')
        .set('Authorization', `Bearer ${shopA.accessToken}`);
      const resB = await request(app)
        .get('/products?limit=50')
        .set('Authorization', `Bearer ${shopB.accessToken}`);

      expect(resA.body.pagination.total).toBe(3);
      expect(resB.body.pagination.total).toBe(2);

      for (const p of resA.body.data) expect(p.shopId).toBe(shopA.shopId);
      for (const p of resB.body.data) expect(p.shopId).toBe(shopB.shopId);
    } finally {
      await cleanupTestUser(shopA);
      await cleanupTestUser(shopB);
    }
  });

  it('GET /products/:id 404s when product belongs to another shop', async () => {
    const shopA = await createTestUser();
    const shopB = await createTestUser();
    try {
      const product = await createTestProduct(shopA.shopId);

      const ownerRes = await request(app)
        .get(`/products/${product.id}`)
        .set('Authorization', `Bearer ${shopA.accessToken}`);
      expect(ownerRes.status).toBe(200);

      const otherRes = await request(app)
        .get(`/products/${product.id}`)
        .set('Authorization', `Bearer ${shopB.accessToken}`);
      expect(otherRes.status).toBe(404);
    } finally {
      await cleanupTestUser(shopA);
      await cleanupTestUser(shopB);
    }
  });

  it('PATCH /products/:id from wrong shop is rejected', async () => {
    const shopA = await createTestUser();
    const shopB = await createTestUser();
    try {
      const product = await createTestProduct(shopA.shopId, { name: 'Original' });

      const res = await request(app)
        .patch(`/products/${product.id}`)
        .set('Authorization', `Bearer ${shopB.accessToken}`)
        .send({ name: 'Pwned' });
      expect(res.status).toBe(404);

      const after = await prisma.product.findUnique({ where: { id: product.id } });
      expect(after?.name).toBe('Original');
    } finally {
      await cleanupTestUser(shopA);
      await cleanupTestUser(shopB);
    }
  });

  it('POST /products/:id/publish toggles isPublished and scopes by shop', async () => {
    const shopA = await createTestUser();
    const shopB = await createTestUser();
    try {
      const product = await createTestProduct(shopA.shopId);

      const ok = await request(app)
        .post(`/products/${product.id}/publish`)
        .set('Authorization', `Bearer ${shopA.accessToken}`)
        .send({ isPublished: true });
      expect(ok.status).toBe(200);
      expect(ok.body.isPublished).toBe(true);

      const cross = await request(app)
        .post(`/products/${product.id}/publish`)
        .set('Authorization', `Bearer ${shopB.accessToken}`)
        .send({ isPublished: false });
      expect(cross.status).toBe(404);

      const after = await prisma.product.findUnique({ where: { id: product.id } });
      expect(after?.isPublished).toBe(true);
    } finally {
      await cleanupTestUser(shopA);
      await cleanupTestUser(shopB);
    }
  });
});

describe('products heavy-query paths', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('lowStock filter returns ONLY rows where qty>0 AND qty<=threshold', async () => {
    const ctx = await createTestUser();
    try {
      const [low, atLimit, healthy, out] = await Promise.all([
        createTestProduct(ctx.shopId, { stockQuantity: 3, lowStockThreshold: 5 }),
        createTestProduct(ctx.shopId, { stockQuantity: 5, lowStockThreshold: 5 }),
        createTestProduct(ctx.shopId, { stockQuantity: 10, lowStockThreshold: 5 }),
        createTestProduct(ctx.shopId, { stockQuantity: 0, lowStockThreshold: 5 }),
      ]);

      const res = await request(app)
        .get('/products?lowStock=true&limit=50')
        .set('Authorization', `Bearer ${ctx.accessToken}`);

      expect(res.status).toBe(200);
      expect(res.body.pagination.total).toBe(2);
      const returnedIds = (res.body.data as Array<{ id: number }>)
        .map((p) => p.id)
        .sort();
      expect(returnedIds).toEqual([low.id, atLimit.id].sort());
      expect(returnedIds).not.toContain(healthy.id);
      expect(returnedIds).not.toContain(out.id);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('lowStock total matches actual count and respects pagination', async () => {
    const ctx = await createTestUser();
    try {
      await Promise.all(
        Array.from({ length: 6 }).map(() =>
          createTestProduct(ctx.shopId, { stockQuantity: 1, lowStockThreshold: 5 }),
        ),
      );

      const res = await request(app)
        .get('/products?lowStock=true&limit=2')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.pagination.total).toBe(6);
      expect(res.body.data.length).toBe(2);
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});

describe('dashboard scoping', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('only counts products in caller-shop', async () => {
    const shopA = await createTestUser();
    const shopB = await createTestUser();
    try {
      await createTestProduct(shopA.shopId);
      await createTestProduct(shopA.shopId);
      await createTestProduct(shopB.shopId);

      const resA = await request(app)
        .get('/dashboard/stats')
        .set('Authorization', `Bearer ${shopA.accessToken}`);
      expect(resA.status).toBe(200);
      expect(resA.body.totalProducts).toBe(2);
      expect(resA.body.activeProducts).toBe(2);

      const resB = await request(app)
        .get('/dashboard/stats')
        .set('Authorization', `Bearer ${shopB.accessToken}`);
      expect(resB.body.totalProducts).toBe(1);
    } finally {
      await cleanupTestUser(shopA);
      await cleanupTestUser(shopB);
    }
  });
});
