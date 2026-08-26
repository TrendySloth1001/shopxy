import { describe, it, expect, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

const app = buildApp();

async function linkOwnerToShop(ctx: { userId: number; shopId: number }): Promise<void> {
  await prisma.shopMember.upsert({
    where: { userId: ctx.userId },
    create: { userId: ctx.userId, shopId: ctx.shopId, role: 'OWNER' },
    update: { shopId: ctx.shopId, role: 'OWNER' },
  });
}

describe('product pricingMode', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('defaults new products to TAX_EXCLUSIVE when omitted', async () => {
    const shop = await createTestUser();
    await linkOwnerToShop(shop);
    try {
      const res = await request(app)
        .post('/products')
        .set('Authorization', `Bearer ${shop.accessToken}`)
        .send({ name: 'Plain Product', sku: 'PM-1', mrp: 100, sellingPrice: 100, purchasePrice: 60 });
      expect(res.status).toBe(201);
      expect(res.body.pricingMode).toBe('TAX_EXCLUSIVE');
    } finally {
      await cleanupTestUser(shop);
    }
  });

  it('rejects NO_GST with an explicit non-zero taxPercent', async () => {
    const shop = await createTestUser();
    await linkOwnerToShop(shop);
    try {
      const res = await request(app)
        .post('/products')
        .set('Authorization', `Bearer ${shop.accessToken}`)
        .send({
          name: 'Exempt Product',
          sku: 'PM-2',
          mrp: 100,
          sellingPrice: 100,
          purchasePrice: 60,
          taxPercent: 18,
          pricingMode: 'NO_GST',
        });
      expect(res.status).toBe(422);
      expect(res.body.error?.code ?? res.body.code).toBe('NO_GST_WITH_TAX_PERCENT');
    } finally {
      await cleanupTestUser(shop);
    }
  });

  it('normalizes an omitted taxPercent to 0 for a NO_GST create', async () => {
    const shop = await createTestUser();
    await linkOwnerToShop(shop);
    try {
      const res = await request(app)
        .post('/products')
        .set('Authorization', `Bearer ${shop.accessToken}`)
        .send({
          name: 'Exempt Product 2',
          sku: 'PM-3',
          mrp: 100,
          sellingPrice: 100,
          purchasePrice: 60,
          pricingMode: 'NO_GST',
        });
      expect(res.status).toBe(201);
      expect(res.body.pricingMode).toBe('NO_GST');
      expect(Number(res.body.taxPercent)).toBe(0);
    } finally {
      await cleanupTestUser(shop);
    }
  });

  it('an HSN code that resolves a non-zero master rate does not override NO_GST', async () => {
    const shop = await createTestUser();
    await linkOwnerToShop(shop);
    try {
      const res = await request(app)
        .post('/products')
        .set('Authorization', `Bearer ${shop.accessToken}`)
        .send({
          name: 'Exempt Product 3',
          sku: 'PM-4',
          mrp: 100,
          sellingPrice: 100,
          purchasePrice: 60,
          hsnCode: '1006',
          pricingMode: 'NO_GST',
        });
      expect(res.status).toBe(201);
      expect(res.body.pricingMode).toBe('NO_GST');
      expect(Number(res.body.taxPercent)).toBe(0);
    } finally {
      await cleanupTestUser(shop);
    }
  });

  it('flipping an existing product to NO_GST zeroes its stored taxPercent', async () => {
    const shop = await createTestUser();
    await linkOwnerToShop(shop);
    try {
      const created = await request(app)
        .post('/products')
        .set('Authorization', `Bearer ${shop.accessToken}`)
        .send({ name: 'Taxed Product', sku: 'PM-5', mrp: 100, sellingPrice: 100, purchasePrice: 60, taxPercent: 18 });
      expect(created.status).toBe(201);
      expect(Number(created.body.taxPercent)).toBe(18);

      const patched = await request(app)
        .patch(`/products/${created.body.id}`)
        .set('Authorization', `Bearer ${shop.accessToken}`)
        .send({ pricingMode: 'NO_GST' });
      expect(patched.status).toBe(200);
      expect(patched.body.pricingMode).toBe('NO_GST');
      expect(Number(patched.body.taxPercent)).toBe(0);
    } finally {
      await cleanupTestUser(shop);
    }
  });
});
