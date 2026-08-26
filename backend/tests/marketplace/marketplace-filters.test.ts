import { describe, it, expect, afterAll, beforeAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

const app = buildApp();

describe('marketplace — filters & facets', () => {
  let merchant: Awaited<ReturnType<typeof createTestUser>>;
  let categorySlug = '';
  let createdCategoryId: number | null = null;
  const productIds: number[] = [];

  beforeAll(async () => {
    merchant = await createTestUser();
    let cat = await prisma.category.findFirst({ select: { id: true, slug: true } });
    if (!cat) {
      const made = await prisma.category.create({
        data: {
          name: `Filter Fixture Cat ${Date.now()}`,
          slug: `filter-fixture-${Date.now()}`,
        },
        select: { id: true, slug: true },
      });
      cat = made;
      createdCategoryId = made.id;
    }
    categorySlug = cat.slug;

    const p1 = await createTestProduct(merchant.shopId, {
      name: 'FilterFixture A', sku: `FF-${Date.now()}-A`,
      sellingPrice: 50,  mrp: 60,   stockQuantity: 0,  isPublished: true,
    });
    const p2 = await createTestProduct(merchant.shopId, {
      name: 'FilterFixture B', sku: `FF-${Date.now()}-B`,
      sellingPrice: 200, mrp: 220,  stockQuantity: 10, isPublished: true,
    });
    const p3 = await createTestProduct(merchant.shopId, {
      name: 'FilterFixture C', sku: `FF-${Date.now()}-C`,
      sellingPrice: 500, mrp: 600,  stockQuantity: 10, isPublished: true,
    });
    const p4 = await createTestProduct(merchant.shopId, {
      name: 'FilterFixture D', sku: `FF-${Date.now()}-D`,
      sellingPrice: 1500, mrp: 1800, stockQuantity: 10, isPublished: true,
    });
    productIds.push(p1.id, p2.id, p3.id, p4.id);

    await prisma.product.updateMany({
      where: { id: { in: productIds } },
      data: { categoryId: cat.id },
    });
    await prisma.product.update({ where: { id: p2.id }, data: { ratingAvg: 2.5, ratingCount: 4 } });
    await prisma.product.update({ where: { id: p3.id }, data: { ratingAvg: 4.2, ratingCount: 12 } });
    await prisma.product.update({ where: { id: p4.id }, data: { ratingAvg: 4.8, ratingCount: 80 } });
  });

  afterAll(async () => {
    await prisma.product.deleteMany({ where: { id: { in: productIds } } });
    await cleanupTestUser(merchant);
    if (createdCategoryId != null) {
      await prisma.category.delete({ where: { id: createdCategoryId } });
    }
    await prisma.$disconnect();
  });

  it('priceMin/priceMax narrows the listing', async () => {
    const res = await request(app)
      .get(`/marketplace/categories/${categorySlug}/products`)
      .query({ priceMin: 100, priceMax: 600, sort: 'newest', limit: 60 });
    expect(res.status).toBe(200);
    const ours = res.body.data.filter((r: { id: number }) =>
      productIds.includes(r.id),
    );
    const prices = ours.map((p: { sellingPrice: string }) => Number(p.sellingPrice));
    expect(prices).not.toContain(50);
    expect(prices).not.toContain(1500);
    expect(prices).toEqual(expect.arrayContaining([200, 500]));
  });

  it('ratingMin filters out below-threshold products', async () => {
    const res = await request(app)
      .get(`/marketplace/categories/${categorySlug}/products`)
      .query({ ratingMin: 4, sort: 'newest', limit: 60 });
    expect(res.status).toBe(200);
    const ourIds = res.body.data
      .filter((r: { id: number }) => productIds.includes(r.id))
      .map((r: { id: number }) => r.id);
    expect(ourIds).not.toContain(productIds[0]);
    expect(ourIds).not.toContain(productIds[1]);
    expect(ourIds).toEqual(expect.arrayContaining([productIds[2], productIds[3]]));
  });

  it('inStock filter drops zero-stock products', async () => {
    const res = await request(app)
      .get(`/marketplace/categories/${categorySlug}/products`)
      .query({ inStock: true, sort: 'newest', limit: 60 });
    expect(res.status).toBe(200);
    const ourIds = res.body.data
      .filter((r: { id: number }) => productIds.includes(r.id))
      .map((r: { id: number }) => r.id);
    expect(ourIds).not.toContain(productIds[0]);
    expect(ourIds).toEqual(
      expect.arrayContaining([productIds[1], productIds[2], productIds[3]]),
    );
  });

  it('returns facets payload when includeFacets=true', async () => {
    const res = await request(app)
      .get(`/marketplace/categories/${categorySlug}/products`)
      .query({ includeFacets: true });
    expect(res.status).toBe(200);
    expect(res.body.facets).toBeDefined();
    expect(res.body.facets.priceMin).toBeGreaterThanOrEqual(0);
    expect(res.body.facets.priceMax).toBeGreaterThan(0);
    expect(res.body.facets.ratingBuckets).toBeDefined();
    expect(typeof res.body.facets.inStockCount).toBe('number');
    expect(Array.isArray(res.body.facets.brands)).toBe(true);
  });

  it('omits facets when includeFacets is absent', async () => {
    const res = await request(app)
      .get(`/marketplace/categories/${categorySlug}/products`);
    expect(res.status).toBe(200);
    expect(res.body.facets).toBeUndefined();
  });
});
