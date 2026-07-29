import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import { buildApp } from '../../src/infra/http/app.js';
import prisma from '../../src/infra/db/prisma.js';
import { seedHsnMaster } from '../../src/modules/hsn/hsn.seed.js';
import { hsnService } from '../../src/modules/hsn/hsn.service.js';
import { classifyService } from '../../src/modules/hsn/classify.service.js';
import { searchCopy, matchAliasesInText } from '../../src/modules/hsn/hsn.copy.js';
import {
  MIN_CONFIDENT_SCORE,
  phoneticKey,
  retrieve,
} from '../../src/modules/hsn/hsn.retrieval.js';
import { productsService } from '../../src/modules/products/products.service.js';
import { invoicesService } from '../../src/modules/invoices/invoices.service.js';
import { HSN_RATE_REVISION } from '../../src/modules/hsn/hsn.master.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

/// HSN/SAC rate master.
///
/// The load-bearing behaviours, in the order a merchant hits them: find the
/// code, see where it sits, get the right rate for what they charge, and have
/// none of it silently go wrong when a rate is missing or overridden.

const app = buildApp();

/// `createTestUser` gives the owner a Shop but no ShopMember row, and
/// `resolveShop` resolves the caller's shop through membership. Without this
/// every shop-scoped route 404s as "No shop linked to this account" — the same
/// gap that makes the products suite fail on a clean baseline. Added here
/// rather than in the shared helper so this change can't move the behaviour of
/// suites it doesn't own.
async function linkOwnerToShop(ctx: { userId: number; shopId: number }): Promise<void> {
  await prisma.shopMember.upsert({
    where: { userId: ctx.userId },
    create: { userId: ctx.userId, shopId: ctx.shopId, role: 'OWNER' },
    update: { shopId: ctx.shopId, role: 'OWNER' },
  });
}

/// Same, but as a non-owner with an explicit grant set — OWNER bypasses every
/// permission check, so it can't demonstrate that a gate exists.
async function linkMemberToShop(
  ctx: { userId: number; shopId: number },
  permissions: string[],
): Promise<void> {
  await prisma.shopMember.upsert({
    where: { userId: ctx.userId },
    create: { userId: ctx.userId, shopId: ctx.shopId, role: 'CASHIER', permissions },
    update: { shopId: ctx.shopId, role: 'CASHIER', permissions },
  });
}

describe('hsn rate master', () => {
  beforeAll(async () => {
    // Idempotent — safe whether or not a previous boot already seeded.
    await seedHsnMaster();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  // ── Finding the code ───────────────────────────────────────────────────

  it('matches transliterated and Devanagari trade words, not just English', async () => {
    // The whole reason the alias catalogue exists: merchants type "kameez" and
    // "चप्पल", not "Men's shirts (woven)".
    expect(searchCopy('kameez')).toContain('6205');
    expect(searchCopy('चप्पल')).toContain('6402');
    expect(searchCopy('sariya')).toContain('7213');
    expect(searchCopy('razai')).toContain('9404');
  });

  it('does not match a query mid-word', async () => {
    // A plain substring match put "toilet paper" above cooking oil for "oil".
    expect(searchCopy('oil')).not.toContain('4818');
    expect(searchCopy('oil')).toContain('1512');
  });

  it('prefers the most specific alias contained in a product name', async () => {
    // "sarson ka tel 1L" contains the alias "sarson ka tel". Matching only the
    // bare word "tel" would surface every oil in the catalogue instead.
    expect(matchAliasesInText('sarson ka tel 1L')[0]).toBe('1514');
  });

  it('suggests a code from a full product name, without any model', async () => {
    // Every one of these is answered by the local index: exact alias phrase,
    // BM25 over the definitions, phonetic folding, or typo repair. None costs
    // a network call, which is the point — see hsn.retrieval.ts.
    const cases: Array<[string, string]> = [
      ['blue cotton formal shirt', '6205'],
      // "t" is a single character and drops out of any tokeniser; only the
      // exact alias phrase "t shirt" recovers this.
      ['mens t shirt', '6109'],
      ['sarson ka tel 1L', '1514'],
      ['hawai chappal size 8', '6402'],
      ['tmt sariya 12mm', '7213'],
      ['नारियल तेल 500ml', '1513'],
      // Nothing in this phrase is an alias — it lands on detergent because
      // `dishwash` appears in 3402's definition.
      ['stuff to wash dishes with', '3402'],
      ['device that keeps food cold', '8418'],
      // Spelling variant, folded phonetically — no alias for this exists.
      ['qameez', '6205'],
      // Typo, repaired by trigram similarity.
      ['refrigerater', '8418'],
    ];
    for (const [name, expected] of cases) {
      const result = await classifyService.suggestForName({ name });
      expect(result.suggestions[0]?.code, `"${name}"`).toBe(expected);
      expect(result.usedEmbeddings, `"${name}" should cost nothing`).toBe(false);
    }
  });

  it('scores rare words above common ones', async () => {
    // BM25's whole contribution: `dishwash` occurs once and decides the query,
    // while `cleaning` and `powder` occur all over and must not.
    const hits = retrieve('dishwash', 3);
    expect(hits[0]?.code).toBe('3402');
    expect(hits[0]?.score).toBeGreaterThan(MIN_CONFIDENT_SCORE);
  });

  it('folds transliteration spellings onto one key', () => {
    // kameez / kamiz / qameez are one word typed three ways. Curation can't
    // enumerate every variant; the consonant skeleton doesn't have to.
    const key = phoneticKey('kameez');
    expect(phoneticKey('kamiz')).toBe(key);
    expect(phoneticKey('qameez')).toBe(key);
    // Short words must NOT fold — `dish` and `desi` share a skeleton, and
    // letting them collide put ghee at the top of "wash dishes".
    expect(phoneticKey('dish')).toBe('');
  });

  it('searches by code prefix and by description', async () => {
    const ctx = await createTestUser();
    try {
      const byCode = await request(app)
        .get('/hsn?q=6205')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      const byText = await request(app)
        .get('/hsn?q=shirt')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      expect(byCode.status).toBe(200);
      expect(byCode.body.results.map((r: { code: string }) => r.code)).toContain('6205');
      expect(byText.body.results.map((r: { code: string }) => r.code)).toContain('6205');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // ── Seeing where it sits ───────────────────────────────────────────────

  it('returns the chapter → heading breadcrumb', async () => {
    const nodes = await hsnService.breadcrumb('62052000');
    // Ancestors only, shortest first. Asserted as a prefix rather than an exact
    // list: importing the full tariff added the 6-digit sub-headings, so the
    // ladder legitimately deepens as the catalogue fills in, and pinning the
    // exact array would make every future import look like a regression.
    expect(nodes.map((n) => n.code).slice(0, 2)).toEqual(['62', '6205']);
    expect(nodes.map((n) => n.code)).not.toContain('62052000');
    // The chapter label is what tells a merchant 62 is woven and 61 is knitted.
    expect(nodes[0].name).toMatch(/NOT knitted/i);
  });

  it('never bills at a chapter rate', async () => {
    // Chapter rows exist for navigation and carry no rate of their own.
    // Resolving to one would invent a slab that doesn't legally exist.
    expect(await hsnService.resolveRate({ code: '62' })).toBeNull();
    const ninetyNine = await hsnService.resolveRate({ code: '9983' });
    expect(ninetyNine).toBeNull();
  });

  // ── Getting the right rate ─────────────────────────────────────────────

  it('resolves an exact code to its GST rate', async () => {
    const hit = await hsnService.resolveRate({ code: '8517' });
    expect(hit?.code).toBe('8517');
    expect(hit?.exact).toBe(true);
    expect(hit?.gstRate).toBe(18);
    expect(hit?.source).toBe('HSN');
    expect(hit?.revision).toMatch(/^\d{4}-\d{2}-\d{2}$/);
  });

  it('falls back to the shorter heading and flags the result as inexact', async () => {
    const hit = await hsnService.resolveRate({ code: '62052000' });
    expect(hit?.code).toBe('6205');
    expect(hit?.requestedCode).toBe('62052000');
    expect(hit?.exact).toBe(false);
  });

  it('prefers the longest matching code over its parent heading', async () => {
    // Heading 2202 is the 40% demerit rate; sub-heading 220299 (juice-based
    // drinks) is 5%. Billing juice at the aerated-drinks rate would be a
    // 35-point overcharge.
    expect((await hsnService.resolveRate({ code: '2202' }))?.gstRate).toBe(40);
    const sub = await hsnService.resolveRate({ code: '220299' });
    expect(sub?.code).toBe('220299');
    expect(sub?.gstRate).toBe(5);
  });

  it('decides a price-threshold slab from the line price', async () => {
    const cheap = await hsnService.resolveRate({ code: '6205', price: 2400 });
    const dear = await hsnService.resolveRate({ code: '6205', price: 2600 });
    expect(cheap?.gstRate).toBe(5);
    expect(cheap?.source).toBe('HSN_RULE');
    expect(dear?.gstRate).toBe(18);
    expect(dear?.source).toBe('HSN_RULE');
  });

  it('treats the threshold as inclusive', async () => {
    // The notification reads "not exceeding ₹2,500 per piece", and ₹2,500 is a
    // real SKU price — an off-by-one here is a real mis-billing.
    expect((await hsnService.resolveRate({ code: '6205', price: 2500 }))?.gstRate).toBe(5);
  });

  it('reports a rule without applying it when no price is known', async () => {
    const hit = await hsnService.resolveRate({ code: '6205' });
    expect(hit?.gstRate).toBe(5);
    expect(hit?.source).toBe('HSN');
    expect(hit?.rule?.threshold).toBe(2500);
    expect(hit?.rule?.testedPrice).toBeNull();
  });

  it('normalises punctuation in the requested code', async () => {
    const hit = await hsnService.resolveRate({ code: '6404.11' });
    expect(hit?.code).toBe('6404');
    expect(hit?.requestedCode).toBe('640411');
  });

  it('404s rather than defaulting an unknown code to 0%', async () => {
    const ctx = await createTestUser();
    try {
      const res = await request(app)
        .get('/hsn/resolve?code=1234567')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      expect(res.status).toBe(404);
      expect(res.body.gstRate).toBeUndefined();
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('requires authentication', async () => {
    const res = await request(app).get('/hsn/resolve?code=6205');
    expect(res.status).toBe(401);
  });

  // ── The merchant's own data ────────────────────────────────────────────

  it('saves a shortcut without storing a rate', async () => {
    const ctx = await createTestUser();
    await linkOwnerToShop(ctx);
    try {
      const res = await request(app)
        .post('/hsn/shortcuts')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({ label: 'Formal Shirt', code: '6205' });
      expect(res.status).toBe(201);

      // The absence of a rate column is the whole safety property: a Council
      // revision reaches the merchant automatically because there is nothing
      // of theirs holding a stale number.
      const row = await prisma.shopHsnShortcut.findFirst({
        where: { shopId: ctx.shopId },
      });
      expect(row?.code).toBe('6205');
      expect(Object.keys(row ?? {})).not.toContain('gstRate');

      // The live rate is joined on at read time instead.
      const listed = await hsnService.listShortcuts(ctx.shopId);
      expect(listed[0].gstRate).toBe(5);
      expect(listed[0].needsAttention).toBe(false);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('refuses to bookmark a code with no rate on file', async () => {
    const ctx = await createTestUser();
    await linkOwnerToShop(ctx);
    try {
      const res = await request(app)
        .post('/hsn/shortcuts')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({ label: 'Nonsense', code: '1234567' });
      expect(res.status).toBe(422);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it("lets a shop's override win over the shared master", async () => {
    const ctx = await createTestUser();
    try {
      await hsnService.createOverride({
        shopId: ctx.shopId,
        code: '8517',
        gstRate: 12,
        reason: 'Advance ruling XYZ/2026',
        createdByUserId: ctx.userId,
      });
      const mine = await hsnService.resolveRate({ code: '8517', shopId: ctx.shopId });
      expect(mine?.gstRate).toBe(12);
      expect(mine?.source).toBe('OVERRIDE');

      // And leaks to nobody else.
      const theirs = await hsnService.resolveRate({ code: '8517' });
      expect(theirs?.gstRate).toBe(18);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('does not inherit an override down the prefix ladder', async () => {
    const ctx = await createTestUser();
    try {
      // An override is a stated position about one classification. Extending
      // it to every code under the heading would apply a ruling to goods it
      // was never granted for.
      await hsnService.createOverride({
        shopId: ctx.shopId,
        code: '620599',
        gstRate: 0,
        reason: 'Export consignment',
      });
      const parent = await hsnService.resolveRate({ code: '6205', shopId: ctx.shopId });
      expect(parent?.source).toBe('HSN');
      expect(parent?.gstRate).toBe(5);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // ── The product write path ─────────────────────────────────────────────

  it('fills a product GST rate from its HSN code and records the source', async () => {
    const ctx = await createTestUser();
    try {
      const product = await productsService.createProduct(
        {
          name: 'Mobile phone',
          sku: `HSN-FILL-${Date.now()}`,
          hsnCode: '8517',
          mrp: 10000,
          sellingPrice: 10000,
          purchasePrice: 8000,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      expect(Number(product!.taxPercent)).toBe(18);
      expect(product!.taxSource).toBe('HSN');
      expect(product!.hsnRevision).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('applies the price rule at product save', async () => {
    const ctx = await createTestUser();
    try {
      const premium = await productsService.createProduct(
        {
          name: 'Premium shirt',
          sku: `HSN-RULE-${Date.now()}`,
          hsnCode: '6205',
          mrp: 4000,
          sellingPrice: 4000,
          purchasePrice: 3000,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      // ₹4,000 is over the ₹2,500 threshold, so 18% — not the headline 5%.
      expect(Number(premium!.taxPercent)).toBe(18);
      expect(premium!.taxSource).toBe('HSN_RULE');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('keeps a hand-typed rate but marks it MANUAL when it disagrees', async () => {
    const ctx = await createTestUser();
    try {
      const product = await productsService.createProduct(
        {
          name: 'Oddly rated phone',
          sku: `HSN-MANUAL-${Date.now()}`,
          hsnCode: '8517',
          taxPercent: 12,
          mrp: 500,
          sellingPrice: 500,
          purchasePrice: 400,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      expect(Number(product!.taxPercent)).toBe(12);
      // Divergence stays queryable rather than becoming a discovery later.
      expect(product!.taxSource).toBe('MANUAL');
      expect(product!.hsnRevision).toBeNull();
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('re-derives the rate when a patch moves the product to a new code', async () => {
    const ctx = await createTestUser();
    try {
      const product = await productsService.createProduct(
        {
          name: 'Reclassified item',
          sku: `HSN-PATCH-${Date.now()}`,
          hsnCode: '8517',
          mrp: 500,
          sellingPrice: 500,
          purchasePrice: 400,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      expect(Number(product!.taxPercent)).toBe(18);

      // Moved to 4901, which the notification splits: printed books are Nil
      // (Exempt S.No 132) while brochures and leaflets under the same heading
      // are 5% (Schedule I S.No 324). The code alone cannot say which, so the
      // write is refused rather than resolved — returning 0 here would be
      // inventing the nil half. This assertion used to expect 0 and got 18,
      // because the patch silently kept the previous code's rate.
      await expect(
        productsService.updateProduct(ctx.shopId, product!.id, { hsnCode: '4901' }),
      ).rejects.toMatchObject({ status: 422, code: 'HSN_RATE_UNRESOLVED' });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('uses the persisted price for a patch that changes only the code', async () => {
    const ctx = await createTestUser();
    try {
      const product = await productsService.createProduct(
        {
          name: 'Premium jacket',
          sku: `HSN-PATCH-PRICE-${Date.now()}`,
          hsnCode: '8517',
          mrp: 4000,
          sellingPrice: 4000,
          purchasePrice: 3000,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      // The patch carries no price, so the threshold has to be tested against
      // the stored ₹4,000 — otherwise this lands on the unconditional 5%.
      const updated = await productsService.updateProduct(ctx.shopId, product!.id, {
        hsnCode: '6201',
      });
      expect(Number(updated!.taxPercent)).toBe(18);
      expect(updated!.taxSource).toBe('HSN_RULE');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('carries the cess rate across for cess-bearing goods', async () => {
    const ctx = await createTestUser();
    try {
      const product = await productsService.createProduct(
        {
          name: 'Pan masala pouch',
          sku: `HSN-CESS-${Date.now()}`,
          hsnCode: '21069020',
          mrp: 10,
          sellingPrice: 10,
          purchasePrice: 7,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      // 28%, not 40%: pan masala sits in Schedule VII (14% CGST), S.No 1 of
      // Notification 09/2025 — the demerit 40% slab is the cess-free one, and
      // pan masala keeps a live compensation cess instead. The hand-written
      // master this test was written against had it at 40% and no cess, which
      // overcharged the GST and dropped the larger levy entirely.
      expect(Number(product!.taxPercent)).toBe(28);
      expect(Number(product!.cessRate)).toBe(60);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // ── Who may change what ────────────────────────────────────────────────
  //
  // `/hsn` is mounted outside `mountMerchant`, so it opts out of the boot-time
  // check that every merchant prefix is area-gated. That exemption is right for
  // the reads and wrong for the writes: an override restates the shop's tax
  // position on a code for the whole catalogue and every future invoice. These
  // three tests are the reason the guards in `hsn.routes.ts` can't quietly be
  // dropped again.

  it('lets a cashier read the shared tariff', async () => {
    const ctx = await createTestUser();
    await linkMemberToShop(ctx, ['products:view', 'invoices:manage']);
    try {
      const res = await request(app)
        .get('/hsn/resolve?code=6205')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      // Billing needs the rate. Gating the read would break the till.
      expect(res.status).toBe(200);
      expect(res.body.gstRate).toBe(5);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('refuses a rate override from someone who cannot manage the shop', async () => {
    const ctx = await createTestUser();
    // A cashier at full billing strength — still not a tax position.
    await linkMemberToShop(ctx, ['products:view', 'invoices:manage', 'payments:manage']);
    try {
      const res = await request(app)
        .post('/hsn/overrides')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({ code: '6205', gstRate: 18, reason: 'trying it on' });
      expect(res.status).toBe(403);

      // Denied at the gate, so nothing reached the table.
      const rows = await prisma.shopHsnOverride.count({ where: { shopId: ctx.shopId } });
      expect(rows).toBe(0);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('refuses a saved shortcut from someone with only view rights on products', async () => {
    const ctx = await createTestUser();
    await linkMemberToShop(ctx, ['products:view']);
    try {
      const res = await request(app)
        .post('/hsn/shortcuts')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({ label: 'Formal Shirt', code: '6205' });
      expect(res.status).toBe(403);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // ── It has to reach the bill ───────────────────────────────────────────
  //
  // The whole point of the feature: the code decides the rate, and both appear
  // on the document the department reconciles against. Everything above can be
  // right while the line still bills a stale rate or prints no HSN at all, and
  // the PDF renderer skips its HSN Summary entirely for rows where `hsn` is
  // null — so a regression here is silent on screen and only visible at filing.

  it('carries the HSN and its derived rate onto the invoice line', async () => {
    const ctx = await createTestUser();
    try {
      // Only a registered shop charges output tax.
      await prisma.user.update({
        where: { id: ctx.userId },
        data: {
          shopGstin: '27ABCDE1234F1Z5',
          shopStateCode: '27',
          registrationType: 'REGULAR',
        },
      });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'HSN Test Customer' },
      });
      // 6205 is men's woven shirts: 5% at or below ₹2,500 a piece.
      const product = await productsService.createProduct(
        {
          name: 'Cotton formal shirt',
          sku: `HSN-BILL-${Date.now()}`,
          hsnCode: '6205',
          mrp: 999,
          sellingPrice: 999,
          purchasePrice: 600,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );
      expect(Number(product!.taxPercent)).toBe(5);

      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        // No taxPercent and no hsn sent — both must come off the product.
        items: [{ productId: product!.id, quantity: 1, unitPrice: 999 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;

      const line = await prisma.invoiceItem.findFirst({
        where: { invoiceId: result.invoice.id },
        select: { hsn: true, taxPercent: true, hsnRevision: true },
      });
      expect(line?.hsn).toBe('6205');
      expect(Number(line?.taxPercent)).toBe(5);
      // Stamped because the line billed the product's own derived rate. This
      // is what scopes a recall if a revision turns out to be wrong.
      expect(line?.hsnRevision).toBe(HSN_RATE_REVISION);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('does not stamp a revision on a hand-edited line', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: {
          shopGstin: '27ABCDE1234F1Z5',
          shopStateCode: '27',
          registrationType: 'REGULAR',
        },
      });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'HSN Override Customer' },
      });
      const product = await productsService.createProduct(
        {
          name: 'Cotton formal shirt',
          sku: `HSN-EDIT-${Date.now()}`,
          hsnCode: '6205',
          mrp: 999,
          sellingPrice: 999,
          purchasePrice: 600,
        },
        { shopId: ctx.shopId, createdById: ctx.userId },
      );

      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        // The biller overrode the rate on this line.
        items: [
          { productId: product!.id, quantity: 1, unitPrice: 999, taxPercent: 18 },
        ],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;

      const line = await prisma.invoiceItem.findFirst({
        where: { invoiceId: result.invoice.id },
        select: { hsn: true, taxPercent: true, hsnRevision: true },
      });
      // The code still prints — it describes the goods regardless of who chose
      // the rate — but the revision must not, because this line is no longer
      // evidence of what the master said, and a reconciliation query that
      // trusted it would chase the wrong invoices.
      expect(line?.hsn).toBe('6205');
      expect(Number(line?.taxPercent)).toBe(18);
      expect(line?.hsnRevision).toBeNull();
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // ── Learning what the catalogue is missing ─────────────────────────────

  it('records a name it could not classify, and counts a repeat once', async () => {
    const ctx = await createTestUser();
    try {
      // Deliberately outside the catalogue's vocabulary.
      const q = `zzq widget ${ctx.shopId}`;
      const first = await classifyService.suggestForName({ name: q, shopId: ctx.shopId });
      expect(first.suggestions).toHaveLength(0);

      // The write is fire-and-forget so the typing path never waits on it.
      await new Promise((r) => setTimeout(r, 120));
      const row = await prisma.hsnLookupMiss.findFirst({ where: { shopId: ctx.shopId } });
      expect(row?.occurrences).toBe(1);
      // Verbatim sample kept alongside the normalised term.
      expect(row?.sample).toBe(q);

      // A merchant retyping the same name must increment, not insert — the
      // whole value of the backlog is that its counts mean something.
      await classifyService.suggestForName({ name: q.toUpperCase(), shopId: ctx.shopId });
      await new Promise((r) => setTimeout(r, 120));
      const rows = await prisma.hsnLookupMiss.findMany({ where: { shopId: ctx.shopId } });
      expect(rows).toHaveLength(1);
      expect(rows[0].occurrences).toBe(2);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('records nothing when the name classifies', async () => {
    const ctx = await createTestUser();
    try {
      const hit = await classifyService.suggestForName({
        name: 'blue cotton formal shirt',
        shopId: ctx.shopId,
      });
      expect(hit.suggestions.length).toBeGreaterThan(0);
      await new Promise((r) => setTimeout(r, 120));
      // A successful lookup tells curation nothing it doesn't already have;
      // logging it would cost a write per keystroke for no information.
      const count = await prisma.hsnLookupMiss.count({ where: { shopId: ctx.shopId } });
      expect(count).toBe(0);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('reopens a gap that recurs after being marked resolved', async () => {
    const ctx = await createTestUser();
    try {
      const q = `zzr gadget ${ctx.shopId}`;
      await classifyService.suggestForName({ name: q, shopId: ctx.shopId });
      await new Promise((r) => setTimeout(r, 120));

      expect(await classifyService.resolveGap(q, '8418')).toBe(1);
      const closed = await prisma.hsnLookupMiss.findFirst({ where: { shopId: ctx.shopId } });
      expect(closed?.resolvedCode).toBe('8418');

      // Marking it resolved is a claim, not a fix. If the term still misses,
      // the alias didn't work and the row has to come back — otherwise the
      // backlog quietly fills with gaps someone believed they had closed.
      await classifyService.suggestForName({ name: q, shopId: ctx.shopId });
      await new Promise((r) => setTimeout(r, 120));
      const reopened = await prisma.hsnLookupMiss.findFirst({ where: { shopId: ctx.shopId } });
      expect(reopened?.resolvedCode).toBeNull();
      expect(reopened?.occurrences).toBe(2);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('refuses a match built only from repaired words', async () => {
    // `breed` and `bread` fold to the same consonant skeleton (`brd`) — the
    // mechanism that makes `qameez` → `kameez` work. Left unchecked it scored
    // 7.6 for *biscuits* against "live horses for breeding", which is worse
    // than no answer: the merchant trusts it and bills the wrong rate.
    //
    // This used to assert an empty result, which was only ever true because
    // nothing in the 101-entry catalogue was about horses. The tariff is, so
    // the honest assertion is the one that was always meant: the answer is
    // *horses*, and bakery is nowhere in it.
    const horses = retrieve('live horses for breeding', 5);
    expect(horses[0]?.code).toBe('010121');
    expect(horses.map((h) => h.code)).not.toContain('1905');
    // Every surviving hit rests on a word that was really typed. Nothing here
    // is held up by a repair alone.
    for (const hit of horses) {
      expect(hit.matched.some((m) => m === 'exact' || m === 'prefix')).toBe(true);
    }

    // The cure must not disarm the repair itself. Both of these rest entirely
    // on a repaired word too — the difference is they account for the whole
    // query rather than one rescued word out of three.
    expect(retrieve('qameez', 1)[0]?.code).toBe('6205');
    expect(retrieve('refrigerater', 1)[0]?.code).toBe('8418');

    // And a hit anchored by words the merchant really typed stays, even though
    // it never explains the whole query — "device" and "that" are in no
    // definition anywhere. The bound is deliberately loose: this used to sit
    // under 0.5, and rose when 8418's definition gained "keeps food and drinks
    // cold" to settle a near-tie against restaurant services, where `food` and
    // `cold` were pulling one term each. Pinning the exact figure would make
    // every future copy edit look like a regression.
    const cold = retrieve('device that keeps food cold', 1)[0];
    expect(cold?.code).toBe('8418');
    expect(cold!.coverage).toBeLessThan(1);
    expect(cold!.matched.some((m) => m === 'exact' || m === 'prefix')).toBe(true);
  });

  it('inherits a rate from the nearest rated ancestor', async () => {
    // Importing the tariff added ~6,700 codes that carry no rate of their own.
    // They are only an improvement if they still bill: resolution walks up the
    // ladder to the heading the notification actually rated. Without this the
    // import would have made thousands of codes findable and unbillable.
    const deep = await hsnService.resolveRate({ code: '620520' });
    expect(deep?.code).toBe('6205');
    expect(deep?.gstRate).toBe(5);
    expect(deep?.exact).toBe(false);
  });

  it('seeds idempotently — a second run writes nothing', async () => {
    const again = await seedHsnMaster();
    expect(again.created).toBe(0);
    expect(again.updated).toBe(0);
    expect(again.superseded).toBe(0);
    expect(again.deactivated).toBe(0);
  });
});
