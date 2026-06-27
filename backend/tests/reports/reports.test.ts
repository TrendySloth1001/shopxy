import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { reportsService } from '../../src/modules/reports/reports.service.js';
import { invoicesService } from '../../src/modules/invoices/invoices.service.js';
import { stockAdjustmentsService } from '../../src/modules/stock-adjustments/stock-adjustments.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

/// GST-11 — the gstSummary report must report IGST, CGST and SGST as SEPARATE
/// heads (distinct ledgers / head-wise ITC, Sec 49 / Rule 88A), not a single
/// blended figure, so a merchant can actually file GSTR-1 / GSTR-3B from it.
/// This pins that the head split is correct end-to-end with a mix of an
/// inter-state (IGST) and an intra-state (CGST/SGST) confirmed sale.

describe('reports.gstSummary — IGST vs CGST/SGST head split', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('separates IGST from CGST/SGST across interstate + intrastate sales', async () => {
    const ctx = await createTestUser();
    const createdInvoiceIds: number[] = [];
    try {
      // Registered Maharashtra (27) shop so it charges output GST.
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      // Stock for both confirmed sales (2 + 2).
      const seeded = await stockAdjustmentsService.create(ctx.shopId, {
        reasonCode: 'OPENING',
        items: [{ productId: product.id, quantity: 10, unitCost: 70 }],
        createdById: ctx.userId,
      });
      expect('adjustment' in seeded).toBe(true);

      const localParty = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Local', stateCode: '27' },
      });
      const interParty = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Interstate', stateCode: '29' },
      });

      // Intra-state: 2×100 @18% → CGST 18 + SGST 18.
      const intra = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: localParty.id,
        items: [{ productId: product.id, quantity: 2, unitPrice: 100, taxPercent: 18 }],
        confirm: true,
        confirmedById: ctx.userId,
      });
      if ('error' in intra) throw new Error(intra.error);
      createdInvoiceIds.push(intra.invoice.id);

      // Inter-state: 2×100 @18% → IGST 36.
      const inter = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: interParty.id,
        items: [{ productId: product.id, quantity: 2, unitPrice: 100, taxPercent: 18 }],
        confirm: true,
        confirmedById: ctx.userId,
      });
      if ('error' in inter) throw new Error(inter.error);
      createdInvoiceIds.push(inter.invoice.id);

      const summary = await reportsService.gstSummary(ctx.shopId, {
        from: new Date(Date.now() - 24 * 3600 * 1000),
        to: new Date(Date.now() + 24 * 3600 * 1000),
      });

      // Heads are separated, each carrying only its own supplies.
      expect(summary.byHead.output.igst).toBeCloseTo(36, 2);
      expect(summary.byHead.output.cgst).toBeCloseTo(18, 2);
      expect(summary.byHead.output.sgst).toBeCloseTo(18, 2);
      // The blended headline still equals the sum of the heads (back-compat).
      expect(summary.outputTax).toBeCloseTo(72, 2);
      expect(
        summary.byHead.output.igst + summary.byHead.output.cgst + summary.byHead.output.sgst,
      ).toBeCloseTo(summary.outputTax, 2);

      // Rate-wise bucket for 18% carries the per-head split too.
      const row18 = summary.outputByRate.find((r) => r.rate === 18);
      expect(row18).toBeDefined();
      expect(row18!.igst).toBeCloseTo(36, 2);
      expect(row18!.cgst).toBeCloseTo(18, 2);
      expect(row18!.sgst).toBeCloseTo(18, 2);
      expect(row18!.taxable).toBeCloseTo(400, 2);
    } finally {
      // Confirmed invoices RESTRICT the product FK — remove them before cleanup.
      for (const id of createdInvoiceIds) {
        await prisma.stockTransaction
          .deleteMany({ where: { sourceType: 'INVOICE', sourceId: id, shopId: ctx.shopId } })
          .catch(() => undefined);
        await prisma.invoice.delete({ where: { id } }).catch(() => undefined);
      }
      await cleanupTestUser(ctx);
    }
  });
});
