import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';
import { decodeId } from '../../src/shared/ids/publicId.js';

const app = buildApp();

const ORIGINAL = process.env.PUBLIC_IDS;

describe('products — opaque public IDs (PUBLIC_IDS on)', () => {
  beforeAll(() => {
    process.env.PUBLIC_IDS = 'true';
  });
  afterAll(async () => {
    if (ORIGINAL === undefined) delete process.env.PUBLIC_IDS;
    else process.env.PUBLIC_IDS = ORIGINAL;
    await prisma.$disconnect();
  });

  it('emits opaque, non-numeric ids that decode back to the real row', async () => {
    const shop = await createTestUser();
    try {
      const product = await createTestProduct(shop.shopId);

      const res = await request(app)
        .get('/products?limit=50')
        .set('Authorization', `Bearer ${shop.accessToken}`);
      expect(res.status).toBe(200);

      const row = res.body.data.find(
        (p: { id: unknown }) => decodeId(String(p.id)) === product.id,
      );
      expect(row).toBeDefined();
      expect(typeof row.id).toBe('string');
      expect(row.id).not.toBe(String(product.id));
      expect(row.id).not.toMatch(/^\d+$/);
      expect(typeof row.shopId).toBe('string');
      expect(decodeId(String(row.shopId))).toBe(shop.shopId);
    } finally {
      await cleanupTestUser(shop);
    }
  });

  it('resolves GET /products/:token by the opaque id it just emitted', async () => {
    const shop = await createTestUser();
    try {
      const product = await createTestProduct(shop.shopId);

      const list = await request(app)
        .get('/products?limit=50')
        .set('Authorization', `Bearer ${shop.accessToken}`);
      const token = list.body.data.find(
        (p: { id: unknown }) => decodeId(String(p.id)) === product.id,
      ).id;

      const byToken = await request(app)
        .get(`/products/${token}`)
        .set('Authorization', `Bearer ${shop.accessToken}`);
      expect(byToken.status).toBe(200);
      expect(decodeId(String(byToken.body.id))).toBe(product.id);
    } finally {
      await cleanupTestUser(shop);
    }
  });

  it('stays dual-mode: a legacy raw-int path param still resolves', async () => {
    const shop = await createTestUser();
    try {
      const product = await createTestProduct(shop.shopId);
      const res = await request(app)
        .get(`/products/${product.id}`)
        .set('Authorization', `Bearer ${shop.accessToken}`);
      expect(res.status).toBe(200);
      expect(decodeId(String(res.body.id))).toBe(product.id);
    } finally {
      await cleanupTestUser(shop);
    }
  });

  it('404s a garbage token without confirming the id space', async () => {
    const shop = await createTestUser();
    try {
      const res = await request(app)
        .get('/products/not-a-real-token')
        .set('Authorization', `Bearer ${shop.accessToken}`);
      expect([400, 404]).toContain(res.status);
      expect(res.body.id).toBeUndefined();
    } finally {
      await cleanupTestUser(shop);
    }
  });
});
