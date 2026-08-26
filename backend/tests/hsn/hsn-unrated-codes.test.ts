import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { seedHsnMaster } from '../../src/modules/hsn/hsn.seed.js';
import { hsnService } from '../../src/modules/hsn/hsn.service.js';
import { productsService } from '../../src/modules/products/products.service.js';
import { HttpError } from '../../src/shared/http/errorHandler.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

describe('hsn — codes the tariff does not rate', () => {
  beforeAll(async () => {
    await seedHsnMaster();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('still inherits a rate from the nearest rated ancestor', async () => {
    const deep = await hsnService.resolveRate({ code: '620520' });
    expect(deep?.code).toBe('6205');
    expect(deep?.gstRate).toBe(5);
    expect(deep?.exact).toBe(false);
    expect(deep?.source).toBe('HSN');
  });

  it('walks through a navigation row rather than stopping at it', async () => {
    const outcome = await hsnService.resolveOutcome({ code: '620520' });
    expect(outcome.status).toBe('RESOLVED');
    const deeper = await hsnService.resolveRate({ code: '62052000' });
    expect(deeper?.code).toBe('6205');
    expect(deeper?.gstRate).toBe(5);
  });

  it('keeps the price rule on an inherited rate', async () => {
    const cheap = await hsnService.resolveRate({ code: '620520', price: 2400 });
    const dear = await hsnService.resolveRate({ code: '620520', price: 2600 });
    expect(cheap?.gstRate).toBe(5);
    expect(dear?.gstRate).toBe(18);
    expect(dear?.source).toBe('HSN_RULE');
  });

  it('still prefers the longest rated code over its parent heading', async () => {
    expect((await hsnService.resolveRate({ code: '2202' }))?.gstRate).toBe(40);
    expect((await hsnService.resolveRate({ code: '220299' }))?.gstRate).toBe(5);
  });

  it('returns no rate for a code whose rate depends on the goods', async () => {
    expect(await hsnService.resolveRate({ code: '1006' })).toBeNull();

    const outcome = await hsnService.resolveOutcome({ code: '1006' });
    expect(outcome.status).toBe('UNRATED');
    if (outcome.status !== 'UNRATED') throw new Error('unreachable');
    expect(outcome.code).toBe('1006');
    expect(outcome.reason).toBe('CONDITIONAL');
    expect(outcome.note).toMatch(/pre-packaged/i);
  });

  it('does not let a sub-heading escape its parent condition', async () => {
    const outcome = await hsnService.resolveOutcome({ code: '100630' });
    expect(outcome.status).toBe('UNRATED');
    if (outcome.status !== 'UNRATED') throw new Error('unreachable');
    expect(outcome.code).toBe('1006');
    expect(outcome.reason).toBe('CONDITIONAL');
  });

  it('returns no rate for a code nothing on its ladder rates', async () => {
    expect(await hsnService.resolveRate({ code: '4901' })).toBeNull();

    const outcome = await hsnService.resolveOutcome({ code: '4901' });
    expect(outcome.status).toBe('UNRATED');
    if (outcome.status !== 'UNRATED') throw new Error('unreachable');
    expect(outcome.code).toBe('4901');
    expect(outcome.reason).toBe('NO_RATE_ON_FILE');
  });

  it('tells a code it has never seen apart from a code it cannot rate', async () => {
    const unknown = await hsnService.resolveOutcome({ code: '1234567' });
    expect(unknown.status).toBe('UNKNOWN');
    expect((await hsnService.resolveOutcome({ code: '4901' })).status).toBe('UNRATED');
    expect((await hsnService.resolveOutcome({ code: '8517' })).status).toBe('RESOLVED');
  });

  it('never invents either half of a conditional split', async () => {
    for (const code of ['1006', '1001', '1101', '0713', '4901']) {
      expect(await hsnService.resolveRate({ code })).toBeNull();
    }
  });

  it('refuses to move a product onto an unrated code without a rate', async () => {
    const ctx = await createTestUser();
    try {
      const product = await productsService.createProduct(
        {
          name: 'Reclassified to books',
          sku: `HSN-UNRATED-${Date.now()}`,
          hsnCode: '8517',
          mrp: 500,
          sellingPrice: 500,
          purchasePrice: 400,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      expect(Number(product!.taxPercent)).toBe(18);

      await expect(
        productsService.updateProduct(ctx.shopId, product!.id, { hsnCode: '4901' }),
      ).rejects.toMatchObject({ status: 422, code: 'HSN_RATE_UNRESOLVED' });

      const after = await prisma.product.findUnique({
        where: { id: product!.id },
        select: { hsnCode: true, taxPercent: true, taxSource: true },
      });
      expect(after?.hsnCode).toBe('8517');
      expect(Number(after?.taxPercent)).toBe(18);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('hands back the condition so the merchant can answer it', async () => {
    const ctx = await createTestUser();
    try {
      const err = await productsService
        .createProduct(
          {
            name: 'Basmati rice 5kg',
            sku: `HSN-RICE-${Date.now()}`,
            hsnCode: '1006',
            mrp: 500,
            sellingPrice: 500,
            purchasePrice: 400,
          },
          { shopId: ctx.shopId, createdById: ctx.userId },
        )
        .then(
          () => null,
          (e: unknown) => e,
        );
      expect(err).toBeInstanceOf(HttpError);
      const http = err as HttpError;
      expect(http.status).toBe(422);
      expect(http.code).toBe('HSN_RATE_UNRESOLVED');
      expect(http.message).toMatch(/pre-packaged/i);
      expect((http.details as { reason: string }).reason).toBe('CONDITIONAL');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('takes the merchant rate for an unrated code and records it as theirs', async () => {
    const ctx = await createTestUser();
    try {
      const product = await productsService.createProduct(
        {
          name: 'Basmati rice 5kg, pre-packaged',
          sku: `HSN-RICE-OK-${Date.now()}`,
          hsnCode: '1006',
          taxPercent: 5,
          mrp: 500,
          sellingPrice: 500,
          purchasePrice: 400,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      expect(Number(product!.taxPercent)).toBe(5);
      expect(product!.taxSource).toBe('MANUAL');
      expect(product!.hsnRevision).toBeNull();
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('still auto-fills from a rated code, and from an inherited one', async () => {
    const ctx = await createTestUser();
    try {
      const phone = await productsService.createProduct(
        {
          name: 'Phone',
          sku: `HSN-OK-PHONE-${Date.now()}`,
          hsnCode: '8517',
          mrp: 500,
          sellingPrice: 500,
          purchasePrice: 400,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      expect(Number(phone!.taxPercent)).toBe(18);
      expect(phone!.taxSource).toBe('HSN');

      const shirt = await productsService.createProduct(
        {
          name: 'Cotton shirt',
          sku: `HSN-OK-SHIRT-${Date.now()}`,
          hsnCode: '620520',
          mrp: 999,
          sellingPrice: 999,
          purchasePrice: 400,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      expect(Number(shirt!.taxPercent)).toBe(5);
      expect(shirt!.taxSource).toBe('HSN_RULE');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('leaves a code the master has never heard of exactly as it was', async () => {
    const ctx = await createTestUser();
    try {
      const product = await productsService.createProduct(
        {
          name: 'Something exotic',
          sku: `HSN-UNKNOWN-${Date.now()}`,
          hsnCode: '9999999',
          taxPercent: 12,
          mrp: 500,
          sellingPrice: 500,
          purchasePrice: 400,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      expect(Number(product!.taxPercent)).toBe(12);
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});
