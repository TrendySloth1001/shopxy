import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { invoicesService } from '../../src/modules/invoices/invoices.service.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

/// Smoke tests for invoices.service. The file is 1378 LOC of math,
/// status machine, ledger posting and PDF generation; full coverage is
/// out of scope here, but these tests pin the load-bearing behaviours
/// (happy create, GST split, cross-shop rejection, status flip) so
/// refactors of the giant private methods don't silently break the
/// canonical flows.

async function createTestParty(shopId: number, name = 'Test Customer') {
  return prisma.party.create({
    data: { shopId, name },
  });
}

describe('invoices.service — smoke', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('createInvoice — SALE with one product, intra-state CGST+SGST split', async () => {
    const ctx = await createTestUser();
    try {
      // Only a GST-registered shop may charge output tax. Register this one
      // (Maharashtra GSTIN) so the engine issues a TAX_INVOICE with GST.
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      const product = await createTestProduct(ctx.shopId, {
        sellingPrice: 100,
      });
      const party = await createTestParty(ctx.shopId);
      // 18% GST on ₹100 × 2 = ₹36 tax. Intra-state → split 9% CGST + 9% SGST.
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        items: [
          {
            productId: product.id,
            quantity: 2,
            unitPrice: 100,
            taxPercent: 18,
          },
        ],
      });

      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const inv = result.invoice;
      expect(Number(inv.subtotal)).toBe(200);
      expect(Number(inv.taxableValue)).toBe(200);
      expect(Number(inv.cgstAmount)).toBeCloseTo(18, 2);
      expect(Number(inv.sgstAmount)).toBeCloseTo(18, 2);
      expect(Number(inv.igstAmount)).toBe(0);
      expect(Number(inv.total)).toBeCloseTo(236, 2);
      expect(inv.items).toHaveLength(1);
      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('createInvoice — UNREGISTERED shop issues a zero-tax Bill of Supply', async () => {
    // No shopGstin → the shop is not GST-registered and (CGST Sec 32) may
    // not collect tax. Even when the line carries an 18% rate, the engine
    // must downgrade the document to a BILL_OF_SUPPLY and charge ₹0 GST.
    const ctx = await createTestUser();
    try {
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      const party = await createTestParty(ctx.shopId);
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        documentType: 'TAX_INVOICE',
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2, unitPrice: 100, taxPercent: 18 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const inv = result.invoice;
      expect(inv.documentType).toBe('BILL_OF_SUPPLY');
      expect(Number(inv.taxableValue)).toBe(200);
      expect(Number(inv.cgstAmount)).toBe(0);
      expect(Number(inv.sgstAmount)).toBe(0);
      expect(Number(inv.igstAmount)).toBe(0);
      expect(Number(inv.total)).toBe(200);
      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('createInvoice — COMPOSITION shop (has GSTIN) still issues a zero-tax Bill of Supply', async () => {
    // A composition dealer holds a GSTIN but (CGST Sec 10) cannot collect
    // GST — so even with a GSTIN present, the document must be a Bill of
    // Supply with zero tax. This is the case GSTIN-presence alone can't catch.
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: {
          shopGstin: '27ABCDE1234F1Z5',
          shopStateCode: '27',
          registrationType: 'COMPOSITION',
        },
      });
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      const party = await createTestParty(ctx.shopId);
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        documentType: 'TAX_INVOICE',
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2, unitPrice: 100, taxPercent: 18 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const inv = result.invoice;
      expect(inv.documentType).toBe('BILL_OF_SUPPLY');
      expect(Number(inv.cgstAmount)).toBe(0);
      expect(Number(inv.sgstAmount)).toBe(0);
      expect(Number(inv.total)).toBe(200);
      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('createInvoice — header discount reduces taxable value BEFORE GST (Sec 15(3))', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      const party = await createTestParty(ctx.shopId);
      // ₹1000 taxable, ₹200 invoice discount → GST charged on ₹800, not ₹1000.
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        discount: 200,
        items: [{ productId: product.id, quantity: 10, unitPrice: 100, taxPercent: 18 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const inv = result.invoice;
      expect(Number(inv.taxableValue)).toBe(800);
      expect(Number(inv.cgstAmount)).toBeCloseTo(72, 2); // 9% of 800
      expect(Number(inv.sgstAmount)).toBeCloseTo(72, 2);
      expect(Number(inv.total)).toBeCloseTo(944, 2); // 800 + 144
      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('createInvoice — rejects items where the product belongs to another shop', async () => {
    const shopA = await createTestUser();
    const shopB = await createTestUser();
    try {
      const productB = await createTestProduct(shopB.shopId);
      const partyA = await createTestParty(shopA.shopId);
      const result = await invoicesService.createInvoice({
        shopId: shopA.shopId,
        type: 'SALE',
        partyId: partyA.id,
        items: [
          { productId: productB.id, quantity: 1, unitPrice: 50 },
        ],
      });
      expect('error' in result).toBe(true);
    } finally {
      await cleanupTestUser(shopA);
      await cleanupTestUser(shopB);
    }
  });

  it('updateStatus DRAFT → CONFIRMED stamps the invoice as confirmed', async () => {
    const ctx = await createTestUser();
    try {
      const product = await createTestProduct(ctx.shopId, {
        sellingPrice: 50,
        stockQuantity: 10,
      });
      const party = await createTestParty(ctx.shopId);
      const created = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        items: [{ productId: product.id, quantity: 1, unitPrice: 50 }],
      });
      if ('error' in created) throw new Error(created.error);
      const id = created.invoice.id;

      const result = await invoicesService.updateStatus(
        ctx.shopId,
        id,
        'CONFIRMED',
        ctx.userId,
      );
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      expect(result.invoice.status).toBe('CONFIRMED');
      await prisma.invoice.delete({ where: { id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('listInvoices scopes to the caller shop only', async () => {
    const shopA = await createTestUser();
    const shopB = await createTestUser();
    try {
      const prodA = await createTestProduct(shopA.shopId);
      const prodB = await createTestProduct(shopB.shopId);

      const partyA = await createTestParty(shopA.shopId, 'PartyA-Listing');
      const partyB = await createTestParty(shopB.shopId, 'PartyB-Listing');
      await invoicesService.createInvoice({
        shopId: shopA.shopId,
        type: 'SALE',
        partyId: partyA.id,
        items: [{ productId: prodA.id, quantity: 1, unitPrice: 10 }],
      });
      await invoicesService.createInvoice({
        shopId: shopB.shopId,
        type: 'SALE',
        partyId: partyB.id,
        items: [{ productId: prodB.id, quantity: 1, unitPrice: 10 }],
      });

      const listA = await invoicesService.listInvoices(shopA.shopId, {
        type: 'SALE',
        page: 1,
        limit: 50,
        skip: 0,
      });
      // shopA's list should contain partyA's invoice and not partyB's.
      const partyNames = listA.invoices.map((i) => i.party?.name);
      expect(partyNames).toContain('PartyA-Listing');
      expect(partyNames).not.toContain('PartyB-Listing');
    } finally {
      await cleanupTestUser(shopA);
      await cleanupTestUser(shopB);
    }
  });
});
