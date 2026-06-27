import { describe, it, expect, afterAll } from 'vitest';
import { Prisma } from '@prisma/client';
import prisma from '../../src/infra/db/prisma.js';
import { challansService } from '../../src/modules/challans/challans.service.js';
import {
  computeChallanLineTax,
  renderChallanPdf,
} from '../../src/modules/challans/challan-pdf-renderer.js';
import { stockAdjustmentsService } from '../../src/modules/stock-adjustments/stock-adjustments.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

/// Challan coverage: the Rule 55 per-line tax math (pure unit tests) plus the
/// load-bearing flows — create posts stock, the PDF renders to a valid document,
/// and convert-to-invoice reconciles with the same figures the challan printed.

const n = (d: Prisma.Decimal) => d.toNumber();

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
    // 5% on 10.10 = 0.505 → GST 0.51; CGST round2(0.255)=0.26, SGST 0.25.
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
    // The whole point: the two halves re-sum to the GST total exactly.
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
      reasonCode: 'OPENING', // IN reason — gives the challan stock to draw down.
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
      // Same-state party → intra-state movement (CGST + SGST).
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

      // Stock actually moved: a CHALLAN OUT row exists for the line.
      const moved = await prisma.stockTransaction.count({
        where: { shopId: ctx.shopId, sourceType: 'CHALLAN', sourceId: challanId },
      });
      expect(moved).toBeGreaterThan(0);

      // The PDF renders to a real document (out=null → Buffer).
      const pdf = await renderChallanPdf(ctx.shopId, challanId, null);
      expect(Buffer.isBuffer(pdf)).toBe(true);
      if (Buffer.isBuffer(pdf)) {
        expect(pdf.length).toBeGreaterThan(500);
        expect(pdf.subarray(0, 5).toString('latin1')).toBe('%PDF-');
      }

      // Convert → invoice: the GST split must match what the challan printed.
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

      // Delete the convert-created invoice so cleanup can drop the product
      // (InvoiceItem RESTRICTs the product FK).
      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('inter-state challan: party in another state bills IGST on convert', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId, '27'); // shop in Maharashtra (27)
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      await prisma.product.update({
        where: { id: product.id },
        data: { taxPercent: 18, hsnCode: '1234' },
      });
      // Consignee in Karnataka (29) → inter-state → IGST.
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
});
