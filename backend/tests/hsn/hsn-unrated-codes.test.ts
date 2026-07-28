import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { seedHsnMaster } from '../../src/modules/hsn/hsn.seed.js';
import { hsnService } from '../../src/modules/hsn/hsn.service.js';
import { productsService } from '../../src/modules/products/products.service.js';
import { HttpError } from '../../src/shared/http/errorHandler.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

/// Codes the tariff carries but does not rate.
///
/// The import marks two very different things `isRatable: false`:
///
///   - ~6,000 **navigation** rows — chapters, and headings whose rate lives in
///     their sub-headings. 620520 is one: it must still bill, by inheriting
///     6205's 5%, or the import made thousands of codes findable and unusable.
///   - a couple of hundred **condition-split** codes, where the schedule
///     declares the rate per (code + condition) and the code alone can't
///     decide. 1006 rice is nil loose and 5% pre-packaged; 4901 is nil for
///     printed books and 5% for brochures.
///
/// The second kind must never inherit a rate and must never leave a product on
/// the rate of the code it used to have. That is the whole of this file.

describe('hsn — codes the tariff does not rate', () => {
  beforeAll(async () => {
    // Idempotent — safe whether or not a previous boot already seeded.
    await seedHsnMaster();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  // ── The ladder still works (the regression this fix must not cause) ──────

  it('still inherits a rate from the nearest rated ancestor', async () => {
    // 620520 carries no rate of its own; 6205 does. Breaking this would make
    // thousands of imported sub-headings unbillable.
    const deep = await hsnService.resolveRate({ code: '620520' });
    expect(deep?.code).toBe('6205');
    expect(deep?.gstRate).toBe(5);
    expect(deep?.exact).toBe(false);
    expect(deep?.source).toBe('HSN');
  });

  it('walks through a navigation row rather than stopping at it', async () => {
    const outcome = await hsnService.resolveOutcome({ code: '620520' });
    expect(outcome.status).toBe('RESOLVED');
    // The 8-digit tariff item isn't in the master at all, so the walk passes
    // the navigation row AND the missing level to reach the rated heading.
    const deeper = await hsnService.resolveRate({ code: '62052000' });
    expect(deeper?.code).toBe('6205');
    expect(deeper?.gstRate).toBe(5);
  });

  it('keeps the price rule on an inherited rate', async () => {
    // Inheriting must carry the *condition* too, not just the number: 6205's
    // ₹2,500 threshold has to reach 620520 or a premium shirt bills at 5%.
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

  // ── Condition-split codes return no rate at all ──────────────────────────

  it('returns no rate for a code whose rate depends on the goods', async () => {
    // Rice. The master records the condition in the schedule's own words and
    // marks the row unrated — and chapter 10 happens to carry 0%, so an
    // inherited answer here would bill pre-packaged rice at nil forever.
    expect(await hsnService.resolveRate({ code: '1006' })).toBeNull();

    const outcome = await hsnService.resolveOutcome({ code: '1006' });
    expect(outcome.status).toBe('UNRATED');
    if (outcome.status !== 'UNRATED') throw new Error('unreachable');
    expect(outcome.code).toBe('1006');
    expect(outcome.reason).toBe('CONDITIONAL');
    expect(outcome.note).toMatch(/pre-packaged/i);
  });

  it('does not let a sub-heading escape its parent condition', async () => {
    // A sub-heading of rice is still rice: the walk has to stop at 1006
    // rather than carry on to the chapter.
    const outcome = await hsnService.resolveOutcome({ code: '100630' });
    expect(outcome.status).toBe('UNRATED');
    if (outcome.status !== 'UNRATED') throw new Error('unreachable');
    expect(outcome.code).toBe('1006');
    expect(outcome.reason).toBe('CONDITIONAL');
  });

  it('returns no rate for a code nothing on its ladder rates', async () => {
    // Printed books. 4901 and chapter 49 are both unrated, so there is
    // nothing to inherit and nothing to guess.
    expect(await hsnService.resolveRate({ code: '4901' })).toBeNull();

    const outcome = await hsnService.resolveOutcome({ code: '4901' });
    expect(outcome.status).toBe('UNRATED');
    if (outcome.status !== 'UNRATED') throw new Error('unreachable');
    expect(outcome.code).toBe('4901');
    expect(outcome.reason).toBe('NO_RATE_ON_FILE');
  });

  it('tells a code it has never seen apart from a code it cannot rate', async () => {
    // "Unknown" and "known but unrated" are different facts and lead to
    // different handling on a write. Collapsing them is what let a stale rate
    // survive a re-classification.
    // Nothing at heading level or deeper — chapter 12 existing is not evidence
    // that 1234567 does, so this is unknown, not "known and unrated".
    const unknown = await hsnService.resolveOutcome({ code: '1234567' });
    expect(unknown.status).toBe('UNKNOWN');
    expect((await hsnService.resolveOutcome({ code: '4901' })).status).toBe('UNRATED');
    expect((await hsnService.resolveOutcome({ code: '8517' })).status).toBe('RESOLVED');
  });

  it('never invents either half of a conditional split', async () => {
    // The two candidate rates for rice are 0 and 5. Neither may be returned,
    // and no rate may be returned at all.
    for (const code of ['1006', '1001', '1101', '0713', '4901']) {
      expect(await hsnService.resolveRate({ code })).toBeNull();
    }
  });

  // ── The write path: no product ever keeps a rate for a different code ────

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

      // The bug: this used to succeed and leave 18% on an exempt good.
      await expect(
        productsService.updateProduct(ctx.shopId, product!.id, { hsnCode: '4901' }),
      ).rejects.toMatchObject({ status: 422, code: 'HSN_RATE_UNRESOLVED' });

      // And the rejected write changed nothing — the product still bills the
      // rate of the code it still has.
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
      // The schedule's own words, not a shrug.
      expect(http.message).toMatch(/pre-packaged/i);
      expect((http.details as { reason: string }).reason).toBe('CONDITIONAL');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('takes the merchant rate for an unrated code and records it as theirs', async () => {
    const ctx = await createTestUser();
    try {
      // Pre-packaged and labelled rice: the merchant answers the question the
      // code can't. 5 is the schedule's number, but *they* chose it.
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
      // Never stamped with a revision — nothing in the master derived this.
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

      // Inherited through a navigation row, with the price rule applied.
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
      // Not in the tariff we carry. We have nothing to say about it, so the
      // merchant's own number stands and the write goes through.
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
