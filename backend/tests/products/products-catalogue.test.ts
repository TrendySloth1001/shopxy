import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { productsService } from '../../src/modules/products/products.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

const app = buildApp();
const CATALOGUE_LIMIT = 5_000;

describe('products catalogue', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('returns only the caller shop, never another merchant', async () => {
    const shopA = await createTestUser();
    const shopB = await createTestUser();
    try {
      const [a1, a2] = await Promise.all([
        createTestProduct(shopA.shopId, { name: 'Alpha Sugar' }),
        createTestProduct(shopA.shopId, { name: 'Alpha Rice' }),
      ]);
      const b1 = await createTestProduct(shopB.shopId, { name: 'Beta Secret' });

      const res = await productsService.listCatalogue({
        shopId: shopA.shopId,
        limit: CATALOGUE_LIMIT,
      });

      const skus = res.products.map((p) => p.sku);
      expect(skus).toContain(a1.sku);
      expect(skus).toContain(a2.sku);
      expect(skus).not.toContain(b1.sku);
      expect(res.total).toBe(2);
    } finally {
      await cleanupTestUser(shopA);
      await cleanupTestUser(shopB);
    }
  });

  it('carries everything needed to price a line, and nothing heavy', async () => {
    const shop = await createTestUser();
    try {
      await createTestProduct(shop.shopId, { name: 'Line Priceable' });

      const res = await productsService.listCatalogue({
        shopId: shop.shopId,
        limit: CATALOGUE_LIMIT,
      });
      const row = res.products[0] as Record<string, unknown>;

      for (const field of [
        'id',
        'name',
        'sku',
        'unit',
        'sellingPrice',
        'purchasePrice',
        'taxPercent',
        'stockQuantity',
        'createdAt',
        'updatedAt',
      ]) {
        expect(row, `missing ${field}`).toHaveProperty(field);
      }

      for (const heavy of [
        'description',
        'specs',
        'offers',
        'contentBlocks',
        'variantAxes',
        'variants',
        'images',
      ]) {
        expect(row, `${heavy} must stay out of the catalogue projection`).not.toHaveProperty(
          heavy,
        );
      }
    } finally {
      await cleanupTestUser(shop);
    }
  });

  it('omits archived products', async () => {
    const shop = await createTestUser();
    try {
      const live = await createTestProduct(shop.shopId, { isActive: true });
      const archived = await createTestProduct(shop.shopId, { isActive: false });

      const res = await productsService.listCatalogue({
        shopId: shop.shopId,
        limit: CATALOGUE_LIMIT,
      });

      const skus = res.products.map((p) => p.sku);
      expect(skus).toContain(live.sku);
      expect(skus).not.toContain(archived.sku);
    } finally {
      await cleanupTestUser(shop);
    }
  });

  it('flags a shop that does not fit, and never returns a partial list unmarked', async () => {
    const shop = await createTestUser();
    try {
      await Promise.all([
        createTestProduct(shop.shopId),
        createTestProduct(shop.shopId),
        createTestProduct(shop.shopId),
      ]);

      const full = await productsService.listCatalogue({
        shopId: shop.shopId,
        limit: CATALOGUE_LIMIT,
      });
      expect(full.truncated).toBe(false);
      expect(full.products).toHaveLength(full.total);

      const capped = await productsService.listCatalogue({ shopId: shop.shopId, limit: 2 });
      expect(capped.truncated).toBe(true);
      expect(capped.products).toHaveLength(2);
      expect(capped.total).toBe(3);
    } finally {
      await cleanupTestUser(shop);
    }
  });

  it('refuses an unauthenticated caller', async () => {
    const res = await request(app).get('/products/catalogue');
    expect(res.status).toBe(401);
  });
});
