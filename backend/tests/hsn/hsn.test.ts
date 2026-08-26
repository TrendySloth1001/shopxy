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

const app = buildApp();

async function linkOwnerToShop(ctx: { userId: number; shopId: number }): Promise<void> {
  await prisma.shopMember.upsert({
    where: { userId: ctx.userId },
    create: { userId: ctx.userId, shopId: ctx.shopId, role: 'OWNER' },
    update: { shopId: ctx.shopId, role: 'OWNER' },
  });
}

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
    await seedHsnMaster();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('matches transliterated and Devanagari trade words, not just English', async () => {
    expect(searchCopy('kameez')).toContain('6205');
    expect(searchCopy('चप्पल')).toContain('6402');
    expect(searchCopy('sariya')).toContain('7213');
    expect(searchCopy('razai')).toContain('9404');
  });

  it('does not match a query mid-word', async () => {
    expect(searchCopy('oil')).not.toContain('4818');
    expect(searchCopy('oil')).toContain('1512');
  });

  it('prefers the most specific alias contained in a product name', async () => {
    expect(matchAliasesInText('sarson ka tel 1L')[0]).toBe('1514');
  });

  it('suggests a code from a full product name, without any model', async () => {
    const cases: Array<[string, string]> = [
      ['blue cotton formal shirt', '6205'],
      ['mens t shirt', '6109'],
      ['sarson ka tel 1L', '1514'],
      ['hawai chappal size 8', '6402'],
      ['tmt sariya 12mm', '7213'],
      ['नारियल तेल 500ml', '1513'],
      ['stuff to wash dishes with', '3402'],
      ['device that keeps food cold', '8418'],
      ['qameez', '6205'],
      ['refrigerater', '8418'],
    ];
    for (const [name, expected] of cases) {
      const result = await classifyService.suggestForName({ name });
      expect(result.suggestions[0]?.code, `"${name}"`).toBe(expected);
      expect(result.usedEmbeddings, `"${name}" should cost nothing`).toBe(false);
    }
  });

  it('scores rare words above common ones', async () => {
    const hits = retrieve('dishwash', 3);
    expect(hits[0]?.code).toBe('3402');
    expect(hits[0]?.score).toBeGreaterThan(MIN_CONFIDENT_SCORE);
  });

  it('folds transliteration spellings onto one key', () => {
    const key = phoneticKey('kameez');
    expect(phoneticKey('kamiz')).toBe(key);
    expect(phoneticKey('qameez')).toBe(key);
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

  it('returns the chapter → heading breadcrumb', async () => {
    const nodes = await hsnService.breadcrumb('62052000');
    expect(nodes.map((n) => n.code).slice(0, 2)).toEqual(['62', '6205']);
    expect(nodes.map((n) => n.code)).not.toContain('62052000');
    expect(nodes[0].name).toMatch(/NOT knitted/i);
  });

  it('never bills at a chapter rate', async () => {
    expect(await hsnService.resolveRate({ code: '62' })).toBeNull();
    const ninetyNine = await hsnService.resolveRate({ code: '9983' });
    expect(ninetyNine).toBeNull();
  });

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

  it('saves a shortcut without storing a rate', async () => {
    const ctx = await createTestUser();
    await linkOwnerToShop(ctx);
    try {
      const res = await request(app)
        .post('/hsn/shortcuts')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({ label: 'Formal Shirt', code: '6205' });
      expect(res.status).toBe(201);

      const row = await prisma.shopHsnShortcut.findFirst({
        where: { shopId: ctx.shopId },
      });
      expect(row?.code).toBe('6205');
      expect(Object.keys(row ?? {})).not.toContain('gstRate');

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

      const theirs = await hsnService.resolveRate({ code: '8517' });
      expect(theirs?.gstRate).toBe(18);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('does not inherit an override down the prefix ladder', async () => {
    const ctx = await createTestUser();
    try {
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
      expect(Number(product!.taxPercent)).toBe(28);
      expect(Number(product!.cessRate)).toBe(60);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('lets a cashier read the shared tariff', async () => {
    const ctx = await createTestUser();
    await linkMemberToShop(ctx, ['products:view', 'invoices:manage']);
    try {
      const res = await request(app)
        .get('/hsn/resolve?code=6205')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      expect(res.status).toBe(200);
      expect(res.body.gstRate).toBe(5);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('refuses a rate override from someone who cannot manage the shop', async () => {
    const ctx = await createTestUser();
    await linkMemberToShop(ctx, ['products:view', 'invoices:manage', 'payments:manage']);
    try {
      const res = await request(app)
        .post('/hsn/overrides')
        .set('Authorization', `Bearer ${ctx.accessToken}`)
        .send({ code: '6205', gstRate: 18, reason: 'trying it on' });
      expect(res.status).toBe(403);

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

  it('carries the HSN and its derived rate onto the invoice line', async () => {
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
        data: { shopId: ctx.shopId, name: 'HSN Test Customer' },
      });
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
      expect(line?.hsn).toBe('6205');
      expect(Number(line?.taxPercent)).toBe(18);
      expect(line?.hsnRevision).toBeNull();
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('records a name it could not classify, and counts a repeat once', async () => {
    const ctx = await createTestUser();
    try {
      const q = `zzq widget ${ctx.shopId}`;
      const first = await classifyService.suggestForName({ name: q, shopId: ctx.shopId });
      expect(first.suggestions).toHaveLength(0);

      await new Promise((r) => setTimeout(r, 120));
      const row = await prisma.hsnLookupMiss.findFirst({ where: { shopId: ctx.shopId } });
      expect(row?.occurrences).toBe(1);
      expect(row?.sample).toBe(q);

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
    const horses = retrieve('live horses for breeding', 5);
    expect(horses[0]?.code).toBe('010121');
    expect(horses.map((h) => h.code)).not.toContain('1905');
    for (const hit of horses) {
      expect(hit.matched.some((m) => m === 'exact' || m === 'prefix')).toBe(true);
    }

    expect(retrieve('qameez', 1)[0]?.code).toBe('6205');
    expect(retrieve('refrigerater', 1)[0]?.code).toBe('8418');

    const cold = retrieve('device that keeps food cold', 1)[0];
    expect(cold?.code).toBe('8418');
    expect(cold!.coverage).toBeLessThan(1);
    expect(cold!.matched.some((m) => m === 'exact' || m === 'prefix')).toBe(true);
  });

  it('inherits a rate from the nearest rated ancestor', async () => {
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
