import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
  recordTestPurchase,
} from '../helpers/setup.js';

const app = buildApp();

describe('product reviews — gating', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('rejects review when the caller has not purchased the product', async () => {
    const merchant = await createTestUser();
    const buyer = await createTestUser({ role: 'CUSTOMER' });
    try {
      const product = await createTestProduct(merchant.shopId);

      const res = await request(app)
        .post(`/products/${product.id}/reviews`)
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .send({ rating: 5, body: 'Trying to bypass the gate' });

      expect(res.status).toBe(403);
      expect(res.body.error).toMatch(/purchased/i);
    } finally {
      await cleanupTestUser(buyer);
      await cleanupTestUser(merchant);
    }
  });

  it('accepts review after a CONFIRMED invoice exists for the buyer', async () => {
    const merchant = await createTestUser();
    const buyer = await createTestUser({ role: 'CUSTOMER' });
    try {
      const product = await createTestProduct(merchant.shopId);
      await recordTestPurchase({
        shopId: merchant.shopId,
        buyerUserId: buyer.userId,
        productId: product.id,
      });

      const res = await request(app)
        .post(`/products/${product.id}/reviews`)
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .send({ rating: 4, title: 'Solid', body: 'Works as advertised' });

      expect(res.status).toBe(200);
      expect(res.body.rating).toBe(4);
      expect(res.body.title).toBe('Solid');
      expect(res.body.user.id).toBe(buyer.userId);
    } finally {
      await cleanupTestUser(buyer);
      await cleanupTestUser(merchant);
    }
  });

  it('DRAFT invoice does NOT unlock review (CONFIRMED-only gate)', async () => {
    const merchant = await createTestUser();
    const buyer = await createTestUser({ role: 'CUSTOMER' });
    try {
      const product = await createTestProduct(merchant.shopId);
      // Backdoor: write a DRAFT invoice directly. Service must reject.
      const party = await prisma.party.create({
        data: { name: 'Draft buyer', linkedUserId: buyer.userId },
      });
      await prisma.invoice.create({
        data: {
          invoiceNo: 'DRAFT/TEST',
          type: 'SALE',
          financialYear: '25-26',
          status: 'DRAFT',
          partyId: party.id,
          subtotal: 100,
          total: 100,
          items: {
            create: {
              productId: product.id,
              productName: product.name,
              productSku: product.sku,
              quantity: 1,
              unitPrice: 100,
              taxableValue: 100,
              total: 100,
            },
          },
        },
      });

      const res = await request(app)
        .post(`/products/${product.id}/reviews`)
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .send({ rating: 5 });

      expect(res.status).toBe(403);
    } finally {
      await cleanupTestUser(buyer);
      await cleanupTestUser(merchant);
    }
  });

  it('write requires authentication', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const res = await request(app)
        .post(`/products/${product.id}/reviews`)
        .send({ rating: 5 });
      expect(res.status).toBe(401);
    } finally {
      await cleanupTestUser(merchant);
    }
  });
});

describe('product reviews — denorms + listing', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('recomputes Product.ratingAvg + ratingCount inside the write transaction', async () => {
    const merchant = await createTestUser();
    const b1 = await createTestUser({ role: 'CUSTOMER' });
    const b2 = await createTestUser({ role: 'CUSTOMER' });
    try {
      const product = await createTestProduct(merchant.shopId);
      await recordTestPurchase({
        shopId: merchant.shopId,
        buyerUserId: b1.userId,
        productId: product.id,
      });
      await recordTestPurchase({
        shopId: merchant.shopId,
        buyerUserId: b2.userId,
        productId: product.id,
      });

      await request(app)
        .post(`/products/${product.id}/reviews`)
        .set('Authorization', `Bearer ${b1.accessToken}`)
        .send({ rating: 4 });
      await request(app)
        .post(`/products/${product.id}/reviews`)
        .set('Authorization', `Bearer ${b2.accessToken}`)
        .send({ rating: 2 });

      const p = await prisma.product.findUnique({
        where: { id: product.id },
        select: { ratingAvg: true, ratingCount: true },
      });
      expect(p?.ratingCount).toBe(2);
      expect(Number(p?.ratingAvg)).toBe(3);
    } finally {
      await cleanupTestUser(b1);
      await cleanupTestUser(b2);
      await cleanupTestUser(merchant);
    }
  });

  it('one review per (product, user) — second POST overwrites first', async () => {
    const merchant = await createTestUser();
    const buyer = await createTestUser({ role: 'CUSTOMER' });
    try {
      const product = await createTestProduct(merchant.shopId);
      await recordTestPurchase({
        shopId: merchant.shopId,
        buyerUserId: buyer.userId,
        productId: product.id,
      });

      await request(app)
        .post(`/products/${product.id}/reviews`)
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .send({ rating: 5, title: 'first' });
      await request(app)
        .post(`/products/${product.id}/reviews`)
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .send({ rating: 3, title: 'changed my mind' });

      const reviews = await prisma.productReview.findMany({
        where: { productId: product.id },
      });
      expect(reviews.length).toBe(1);
      expect(reviews[0].rating).toBe(3);
      expect(reviews[0].title).toBe('changed my mind');

      const p = await prisma.product.findUnique({
        where: { id: product.id },
        select: { ratingAvg: true, ratingCount: true },
      });
      expect(p?.ratingCount).toBe(1);
      expect(Number(p?.ratingAvg)).toBe(3);
    } finally {
      await cleanupTestUser(buyer);
      await cleanupTestUser(merchant);
    }
  });

  it('DELETE /products/:id/reviews/mine removes and updates denorms', async () => {
    const merchant = await createTestUser();
    const buyer = await createTestUser({ role: 'CUSTOMER' });
    try {
      const product = await createTestProduct(merchant.shopId);
      await recordTestPurchase({
        shopId: merchant.shopId,
        buyerUserId: buyer.userId,
        productId: product.id,
      });
      await request(app)
        .post(`/products/${product.id}/reviews`)
        .set('Authorization', `Bearer ${buyer.accessToken}`)
        .send({ rating: 4 });

      const del = await request(app)
        .delete(`/products/${product.id}/reviews/mine`)
        .set('Authorization', `Bearer ${buyer.accessToken}`);
      expect(del.status).toBe(204);

      const p = await prisma.product.findUnique({
        where: { id: product.id },
        select: { ratingAvg: true, ratingCount: true },
      });
      expect(p?.ratingCount).toBe(0);
      expect(p?.ratingAvg).toBeNull();
    } finally {
      await cleanupTestUser(buyer);
      await cleanupTestUser(merchant);
    }
  });

  it('GET /products/:id/reviews is public and paginates with cursor', async () => {
    const merchant = await createTestUser();
    const product = await createTestProduct(merchant.shopId);
    const buyers: Array<Awaited<ReturnType<typeof createTestUser>>> = [];
    try {
      // Seed 3 reviews → expect public list to return all 3 newest-first.
      for (let i = 0; i < 3; i++) {
        const b = await createTestUser({ role: 'CUSTOMER' });
        buyers.push(b);
        await recordTestPurchase({
          shopId: merchant.shopId,
          buyerUserId: b.userId,
          productId: product.id,
        });
        await request(app)
          .post(`/products/${product.id}/reviews`)
          .set('Authorization', `Bearer ${b.accessToken}`)
          .send({ rating: 5 - i });
      }

      const page1 = await request(app).get(`/products/${product.id}/reviews?limit=2`);
      expect(page1.status).toBe(200);
      expect(page1.body.data.length).toBe(2);
      expect(page1.body.nextCursor).toBeDefined();

      const page2 = await request(app).get(
        `/products/${product.id}/reviews?limit=2&cursor=${page1.body.nextCursor}`,
      );
      expect(page2.body.data.length).toBe(1);
      expect(page2.body.nextCursor).toBeNull();
    } finally {
      for (const b of buyers) await cleanupTestUser(b);
      await cleanupTestUser(merchant);
    }
  });
});

describe('product tags', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('PATCH /products/:id accepts tags array and product list returns them', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const patch = await request(app)
        .patch(`/products/${product.id}`)
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send({ tags: ['Bestseller', 'Eco-friendly'] });
      expect(patch.status).toBe(200);
      expect(patch.body.tags).toEqual(['Bestseller', 'Eco-friendly']);

      const list = await request(app)
        .get('/products?limit=50')
        .set('Authorization', `Bearer ${merchant.accessToken}`);
      const inList = (list.body.data as Array<{ id: number; tags: string[] }>)
        .find((p) => p.id === product.id);
      expect(inList?.tags).toEqual(['Bestseller', 'Eco-friendly']);
    } finally {
      await cleanupTestUser(merchant);
    }
  });

  it('rejects too many tags (max 20)', async () => {
    const merchant = await createTestUser();
    try {
      const product = await createTestProduct(merchant.shopId);
      const tooMany = Array.from({ length: 21 }, (_, i) => `t${i}`);
      const res = await request(app)
        .patch(`/products/${product.id}`)
        .set('Authorization', `Bearer ${merchant.accessToken}`)
        .send({ tags: tooMany });
      // zod parse fails → ZodError → 500 by default unless handled. Our
      // errorHandler maps zod issues to 400; verify either 400 or 422.
      expect([400, 422]).toContain(res.status);
    } finally {
      await cleanupTestUser(merchant);
    }
  });
});
