import { describe, it, expect, afterAll } from 'vitest';
import zlib from 'node:zlib';
import { Writable } from 'node:stream';
import request from 'supertest';
import { Prisma } from '@prisma/client';
import prisma from '../../src/infra/db/prisma.js';
import { buildApp } from '../../src/infra/http/app.js';
import { challansService } from '../../src/modules/challans/challans.service.js';
import {
  computeChallanLineTax,
  renderChallanPdf,
} from '../../src/modules/challans/challan-pdf-renderer.js';
import { stockAdjustmentsService } from '../../src/modules/stock-adjustments/stock-adjustments.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

const n = (d: Prisma.Decimal) => d.toNumber();

function pdfText(buf: Buffer): string {
  const s = buf.toString('latin1');
  const re = /stream\r?\n([\s\S]*?)\r?\nendstream/g;
  let m: RegExpExecArray | null;
  let content = '';
  while ((m = re.exec(s))) {
    const bytes = Buffer.from(m[1], 'latin1');
    try {
      content += zlib.inflateSync(bytes).toString('latin1') + '\n';
    } catch {
      content += m[1] + '\n';
    }
  }
  let out = '';
  const hex = content.match(/<([0-9A-Fa-f\s]+)>/g) ?? [];
  for (const h of hex) {
    const clean = h.slice(1, -1).replace(/\s+/g, '');
    if (clean.length >= 2 && clean.length % 2 === 0) {
      out += Buffer.from(clean, 'hex').toString('latin1');
    }
  }
  const lit = content.match(/\(((?:\\.|[^()\\])*)\)/g) ?? [];
  out += ' ' + lit.map((p) => p.slice(1, -1).replace(/\\(.)/g, '$1')).join(' ');
  return out;
}

describe('challan tax math — computeChallanLineTax', () => {
  it('intra-state registered: 18% on 2×100 splits CGST 18 / SGST 18', () => {
    const t = computeChallanLineTax({
      quantity: 2,
      sellingPrice: 100,
      taxPercent: 18,
      cessRate: 0,
      isInterstate: false,
      chargesGst: true,
    });
    expect(n(t.taxable)).toBe(200);
    expect(n(t.cgst)).toBe(18);
    expect(n(t.sgst)).toBe(18);
    expect(n(t.igst)).toBe(0);
    expect(n(t.cess)).toBe(0);
    expect(n(t.total)).toBe(236);
  });

  it('inter-state registered: 18% on 2×100 is IGST 36, no CGST/SGST', () => {
    const t = computeChallanLineTax({
      quantity: 2,
      sellingPrice: 100,
      taxPercent: 18,
      cessRate: 0,
      isInterstate: true,
      chargesGst: true,
    });
    expect(n(t.taxable)).toBe(200);
    expect(n(t.igst)).toBe(36);
    expect(n(t.cgst)).toBe(0);
    expect(n(t.sgst)).toBe(0);
    expect(n(t.total)).toBe(236);
  });

  it('compensation cess is charged on taxable and kept out of the GST heads', () => {
    const t = computeChallanLineTax({
      quantity: 1,
      sellingPrice: 100,
      taxPercent: 18,
      cessRate: 12,
      isInterstate: false,
      chargesGst: true,
    });
    expect(n(t.taxable)).toBe(100);
    expect(n(t.cgst)).toBe(9);
    expect(n(t.sgst)).toBe(9);
    expect(n(t.cess)).toBe(12);
    expect(n(t.total)).toBe(130);
  });

  it('unregistered consignor charges no tax — taxable value only', () => {
    const t = computeChallanLineTax({
      quantity: 2,
      sellingPrice: 100,
      taxPercent: 18,
      cessRate: 5,
      isInterstate: false,
      chargesGst: false,
    });
    expect(n(t.taxable)).toBe(200);
    expect(n(t.igst)).toBe(0);
    expect(n(t.cgst)).toBe(0);
    expect(n(t.sgst)).toBe(0);
    expect(n(t.cess)).toBe(0);
    expect(n(t.total)).toBe(200);
  });

  it('odd-paisa GST split: CGST rounds up, SGST absorbs the remainder (re-sums)', () => {
    const t = computeChallanLineTax({
      quantity: 1,
      sellingPrice: 10.1,
      taxPercent: 5,
      cessRate: 0,
      isInterstate: false,
      chargesGst: true,
    });
    expect(n(t.cgst)).toBe(0.26);
    expect(n(t.sgst)).toBe(0.25);
    expect(n(t.cgst.add(t.sgst))).toBe(0.51);
    expect(n(t.total)).toBe(10.61);
  });
});

describe('challans.service — create, render, convert', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  async function registerShop(userId: number, stateCode = '27') {
    await prisma.user.update({
      where: { id: userId },
      data: {
        shopGstin: `${stateCode}ABCDE1234F1Z5`,
        shopStateCode: stateCode,
        registrationType: 'REGULAR',
      },
    });
  }

  async function seedStock(ctx: { shopId: number; userId: number }, productId: number, qty: number) {
    const res = await stockAdjustmentsService.create(ctx.shopId, {
      reasonCode: 'OPENING',
      items: [{ productId, quantity: qty, unitCost: 70 }],
      createdById: ctx.userId,
    });
    expect('adjustment' in res).toBe(true);
  }

  it('create posts stock and renders a Rule 55 PDF; convert reconciles (intra-state)', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId, '27');
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18, hsnCode: '1234' },
      });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Local Consignee', stateCode: '27' },
      });
      await seedStock(ctx, product.id, 10);

      const created = await challansService.createChallan(ctx.shopId, {
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2 }],
        createdById: ctx.userId,
      });
      expect('challan' in created).toBe(true);
      if (!('challan' in created)) return;
      const challanId = created.challan.id;

      const moved = await prisma.stockTransaction.count({
        where: { shopId: ctx.shopId, sourceType: 'CHALLAN', sourceId: challanId },
      });
      expect(moved).toBeGreaterThan(0);

      const pdf = await renderChallanPdf(ctx.shopId, challanId, null);
      expect(Buffer.isBuffer(pdf)).toBe(true);
      if (Buffer.isBuffer(pdf)) {
        expect(pdf.length).toBeGreaterThan(500);
        expect(pdf.subarray(0, 5).toString('latin1')).toBe('%PDF-');
      }

      const conv = await challansService.convertToInvoice(ctx.shopId, challanId);
      expect('invoice' in conv).toBe(true);
      if (!('invoice' in conv)) return;
      const inv = await prisma.invoice.findUniqueOrThrow({ where: { id: conv.invoice.id } });
      expect(inv.isInterstate).toBe(false);
      expect(Number(inv.taxableValue)).toBe(200);
      expect(Number(inv.cgstAmount)).toBeCloseTo(18, 2);
      expect(Number(inv.sgstAmount)).toBeCloseTo(18, 2);
      expect(Number(inv.igstAmount)).toBe(0);
      expect(Number(inv.total)).toBeCloseTo(236, 2);

      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('inter-state challan: party in another state bills IGST on convert', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId, '27');
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18, hsnCode: '1234' },
      });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Interstate Consignee', stateCode: '29' },
      });
      await seedStock(ctx, product.id, 10);

      const created = await challansService.createChallan(ctx.shopId, {
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2 }],
        createdById: ctx.userId,
      });
      if (!('challan' in created)) throw new Error('challan not created');

      const pdf = await renderChallanPdf(ctx.shopId, created.challan.id, null);
      expect(Buffer.isBuffer(pdf)).toBe(true);

      const conv = await challansService.convertToInvoice(ctx.shopId, created.challan.id);
      if (!('invoice' in conv)) throw new Error('convert failed');
      const inv = await prisma.invoice.findUniqueOrThrow({ where: { id: conv.invoice.id } });
      expect(inv.isInterstate).toBe(true);
      expect(inv.placeOfSupplyStateCode).toBe('29');
      expect(Number(inv.igstAmount)).toBeCloseTo(36, 2);
      expect(Number(inv.cgstAmount)).toBe(0);
      expect(Number(inv.sgstAmount)).toBe(0);
      expect(Number(inv.total)).toBeCloseTo(236, 2);

      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('challan created before its shop\'s gstEffectiveFrom converts to a zero-tax invoice', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId, '27');
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { gstEffectiveFrom: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000) },
      });
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18, hsnCode: '1234' },
      });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Local Consignee', stateCode: '27' },
      });
      await seedStock(ctx, product.id, 10);

      const created = await challansService.createChallan(ctx.shopId, {
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2 }],
        createdById: ctx.userId,
      });
      if (!('challan' in created)) throw new Error('challan not created');

      const conv = await challansService.convertToInvoice(ctx.shopId, created.challan.id);
      if (!('invoice' in conv)) throw new Error('convert failed');
      const inv = await prisma.invoice.findUniqueOrThrow({ where: { id: conv.invoice.id } });
      expect(inv.documentType).toBe('BILL_OF_SUPPLY');
      expect(Number(inv.cgstAmount)).toBe(0);
      expect(Number(inv.sgstAmount)).toBe(0);

      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('a challan\'s tax gate is keyed to its own createdAt, not wall-clock "now" at render time', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId, '27');
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { gstEffectiveFrom: new Date('2026-06-01') },
      });
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18, hsnCode: '1234' },
      });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Local Consignee', stateCode: '27' },
      });
      await seedStock(ctx, product.id, 10);

      const created = await challansService.createChallan(ctx.shopId, {
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2 }],
        createdById: ctx.userId,
      });
      if (!('challan' in created)) throw new Error('challan not created');

      const asIs = await renderChallanPdf(ctx.shopId, created.challan.id, null);
      if (!Buffer.isBuffer(asIs)) throw new Error('expected a Buffer');
      expect(pdfText(asIs)).toMatch(/18\.00/);

      await prisma.challan.update({
        where: { id: created.challan.id },
        data: { createdAt: new Date('2026-01-01') },
      });
      const backdated = await renderChallanPdf(ctx.shopId, created.challan.id, null);
      if (!Buffer.isBuffer(backdated)) throw new Error('expected a Buffer');
      expect(pdfText(backdated)).not.toMatch(/18\.00/);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('rendered PDF actually contains the Rule 55 fields (intra-state heads)', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId, '27');
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18, hsnCode: '1234' },
      });
      const party = await prisma.party.create({
        data: {
          shopId: ctx.shopId,
          name: 'Local Consignee',
          stateCode: '27',
          gstin: '27ZZZZZ9999Z1Z5',
          address: '1 Market Rd',
          city: 'Pune',
          state: 'Maharashtra',
        },
      });
      await seedStock(ctx, product.id, 10);
      const created = await challansService.createChallan(ctx.shopId, {
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2 }],
        createdById: ctx.userId,
      });
      if (!('challan' in created)) throw new Error('challan not created');

      const pdf = await renderChallanPdf(ctx.shopId, created.challan.id, null);
      if (!Buffer.isBuffer(pdf)) throw new Error('expected a PDF buffer');
      const text = pdfText(pdf);

      expect(text).toContain('DELIVERY CHALLAN');
      expect(text).toContain('Consignor');
      expect(text).toContain('Consignee');
      expect(text).toContain('GSTIN');
      expect(text).toContain('PLACE OF SUPPLY');
      expect(text).toContain('Intra-State');
      expect(text).toContain('1234');
      expect(text).toContain('Authorised Signatory');
      expect(text).toContain('CGST');
      expect(text).toContain('SGST');
      expect(text).not.toContain('IGST');
      expect(text).toContain('200.00');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('rendered PDF shows IGST (and not CGST/SGST) for an inter-state movement', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId, '27');
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18, hsnCode: '1234' },
      });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Interstate Consignee', stateCode: '29' },
      });
      await seedStock(ctx, product.id, 10);
      const created = await challansService.createChallan(ctx.shopId, {
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2 }],
        createdById: ctx.userId,
      });
      if (!('challan' in created)) throw new Error('challan not created');

      const pdf = await renderChallanPdf(ctx.shopId, created.challan.id, null);
      if (!Buffer.isBuffer(pdf)) throw new Error('expected a PDF buffer');
      const text = pdfText(pdf);

      expect(text).toContain('Inter-State');
      expect(text).toContain('IGST');
      expect(text).toContain('Rs. 36.00');
      expect(text).toContain('Karnataka');
      expect(text).not.toContain('SGST');
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('service.streamPdf writes a PDF to the response stream and fires onReady first', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId, '27');
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18, hsnCode: '1234' },
      });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Stream Consignee', stateCode: '27' },
      });
      await seedStock(ctx, product.id, 10);
      const created = await challansService.createChallan(ctx.shopId, {
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2 }],
        createdById: ctx.userId,
      });
      if (!('challan' in created)) throw new Error('challan not created');

      const chunks: Buffer[] = [];
      let readyFiredBeforeBytes = false;
      let onReadyCalled = false;
      const sink = new Writable({
        write(chunk: Buffer, _enc, cb) {
          if (chunks.length === 0) readyFiredBeforeBytes = onReadyCalled;
          chunks.push(Buffer.from(chunk));
          cb();
        },
      });
      const err = await challansService.streamPdf(ctx.shopId, created.challan.id, sink, () => {
        onReadyCalled = true;
      });

      expect(err).toBeNull();
      expect(onReadyCalled).toBe(true);
      expect(readyFiredBeforeBytes).toBe(true);
      const body = Buffer.concat(chunks);
      expect(body.subarray(0, 5).toString('latin1')).toBe('%PDF-');
      expect(body.length).toBeGreaterThan(500);

      const sink2 = new Writable({ write(_c, _e, cb) { cb(); } });
      let onReady2 = false;
      const miss = await challansService.streamPdf(ctx.shopId, 99999999, sink2, () => {
        onReady2 = true;
      });
      expect(miss).toEqual({ error: 'Challan not found' });
      expect(onReady2).toBe(false);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('GET /challans/:id/pdf is registered and wired (not a 404)', async () => {
    const app = buildApp();
    const ctx = await createTestUser();
    try {
      const res = await request(app)
        .get('/challans/1/pdf')
        .set('Authorization', `Bearer ${ctx.accessToken}`);
      expect(res.status).not.toBe(404);
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});
