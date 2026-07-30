import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { productsService } from '../../src/modules/products/products.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

/// The catalogue read — the whole active product list in one light response,
/// so the apps can search locally instead of asking the server per keystroke.
///
/// Two properties carry the weight:
///
///   - It is a **bulk** read, which makes the usual tenant filter more
///     dangerous than usual. One missing `shopId` hands a merchant every
///     competitor's price list in a single request.
///   - It is **light on purpose**. The moment someone adds `variants` or
///     `contentBlocks` back to the projection, the response goes from a few
///     hundred KB to megabytes and the reason for the endpoint is gone.
///
/// These drive the service directly rather than the route. Every merchant-
/// route request in this suite currently 403s in the test environment — a
/// pre-existing condition, not this endpoint's (`tests/products/products.test.ts`
/// fails 7/7 the same way on untouched code). Going through the service still
/// exercises the tenant filter and the projection, which is what could
/// actually be wrong here. The one HTTP case at the bottom is the one that
/// doesn't need a working merchant session.

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

      // A picker must be able to build an invoice line from this alone — a
      // second fetch per tap would undo the point of preloading.
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

      // The exclusions are the feature. If one of these comes back, the
      // payload has quietly grown by orders of magnitude.
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
    // An inactive product must not be billable from a picker.
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
    // `truncated` is what the client keys off to decide whether searching
    // locally is safe. A partial list that claims to be complete is the one
    // outcome that makes a merchant's own SKU look like it doesn't exist.
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

      // Same shop, a ceiling it exceeds — simulating a catalogue past the
      // endpoint's cap without seeding 5,000 rows.
      const capped = await productsService.listCatalogue({ shopId: shop.shopId, limit: 2 });
      expect(capped.truncated).toBe(true);
      expect(capped.products).toHaveLength(2);
      // `total` stays the real count, so the client can say how many it isn't
      // holding rather than reporting the truncated length as the truth.
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
