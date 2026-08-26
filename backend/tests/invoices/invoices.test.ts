import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { invoicesService } from '../../src/modules/invoices/invoices.service.js';
import {
  createTestUser,
  cleanupTestUser,
  createTestProduct,
} from '../helpers/setup.js';

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
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      const product = await createTestProduct(ctx.shopId, {
        sellingPrice: 100,
      });
      const party = await createTestParty(ctx.shopId);
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

  it('createInvoice — B2B recipient with a GSTIN but no stateCode is charged IGST', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Interstate B2B', gstin: '29ABCDE1234F1Z5' },
      });
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        items: [{ productId: product.id, quantity: 2, unitPrice: 100, taxPercent: 18 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const inv = result.invoice;
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

  it('createInvoice — UNREGISTERED shop issues a zero-tax Bill of Supply', async () => {
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

  it('createInvoice — REGULAR shop with a future gstEffectiveFrom is billed as unregistered for a document dated before it', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: {
          shopGstin: '27ABCDE1234F1Z5',
          shopStateCode: '27',
          registrationType: 'REGULAR',
          gstEffectiveFrom: new Date('2026-08-10'),
        },
      });
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      const party = await createTestParty(ctx.shopId);
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        documentType: 'TAX_INVOICE',
        partyId: party.id,
        invoiceDate: '2026-08-09T12:00:00.000Z',
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

  it('createInvoice — REGULAR shop with a past gstEffectiveFrom charges real GST for a document dated on/after it', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: {
          shopGstin: '27ABCDE1234F1Z5',
          shopStateCode: '27',
          registrationType: 'REGULAR',
          gstEffectiveFrom: new Date('2026-08-10'),
        },
      });
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      const party = await createTestParty(ctx.shopId);
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        invoiceDate: '2026-08-10T00:00:00.000Z',
        items: [{ productId: product.id, quantity: 2, unitPrice: 100, taxPercent: 18 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const inv = result.invoice;
      expect(inv.documentType).toBe('TAX_INVOICE');
      expect(Number(inv.cgstAmount)).toBeCloseTo(18, 2);
      expect(Number(inv.sgstAmount)).toBeCloseTo(18, 2);
      expect(Number(inv.total)).toBeCloseTo(236, 2);
      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('createInvoice — REGULAR shop with gstEffectiveFrom null (pre-feature row) charges GST regardless of invoiceDate', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
      const party = await createTestParty(ctx.shopId);
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        invoiceDate: '2020-01-01T00:00:00.000Z',
        items: [{ productId: product.id, quantity: 2, unitPrice: 100, taxPercent: 18 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const inv = result.invoice;
      expect(inv.documentType).toBe('TAX_INVOICE');
      expect(Number(inv.cgstAmount)).toBeCloseTo(18, 2);
      expect(Number(inv.sgstAmount)).toBeCloseTo(18, 2);
      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('createInvoice — TAX_INCLUSIVE product with isPriceInclusive omitted backs GST out of the price', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      const product = await prisma.product.create({
        data: {
          shopId: ctx.shopId,
          name: 'MRP Product',
          sku: `SKU-INC-${Date.now()}`,
          mrp: 118,
          sellingPrice: 118,
          purchasePrice: 70,
          taxPercent: 18,
          pricingMode: 'TAX_INCLUSIVE',
        },
      });
      const party = await createTestParty(ctx.shopId);
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        items: [{ productId: product.id, quantity: 1, unitPrice: 118 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const inv = result.invoice;
      expect(Number(inv.taxableValue)).toBeCloseTo(100, 2);
      expect(Number(inv.cgstAmount)).toBeCloseTo(9, 2);
      expect(Number(inv.sgstAmount)).toBeCloseTo(9, 2);
      expect(Number(inv.total)).toBeCloseTo(118, 2);
      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('createInvoice — NO_GST product with a stale non-zero taxPercent still on the row bills ₹0 tax', async () => {
    const ctx = await createTestUser();
    try {
      await prisma.user.update({
        where: { id: ctx.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      const product = await prisma.product.create({
        data: {
          shopId: ctx.shopId,
          name: 'Stale Exempt Product',
          sku: `SKU-NOGST-${Date.now()}`,
          mrp: 100,
          sellingPrice: 100,
          purchasePrice: 60,
          taxPercent: 28,
          pricingMode: 'NO_GST',
        },
      });
      const party = await createTestParty(ctx.shopId);
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        partyId: party.id,
        items: [{ productId: product.id, quantity: 1, unitPrice: 100 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const inv = result.invoice;
      expect(Number(inv.taxableValue)).toBe(100);
      expect(Number(inv.cgstAmount)).toBe(0);
      expect(Number(inv.sgstAmount)).toBe(0);
      expect(Number(inv.igstAmount)).toBe(0);
      expect(Number(inv.total)).toBe(100);
      await prisma.invoice.delete({ where: { id: inv.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('createInvoice — NO_GST product on a COMPOSITION shop composes to the same zero, not a double negative', async () => {
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
      const product = await prisma.product.create({
        data: {
          shopId: ctx.shopId,
          name: 'Exempt Product',
          sku: `SKU-COMPNOGST-${Date.now()}`,
          mrp: 100,
          sellingPrice: 100,
          purchasePrice: 60,
          taxPercent: 0,
          pricingMode: 'NO_GST',
        },
      });
      const party = await createTestParty(ctx.shopId);
      const result = await invoicesService.createInvoice({
        shopId: ctx.shopId,
        type: 'SALE',
        documentType: 'TAX_INVOICE',
        partyId: party.id,
        items: [{ productId: product.id, quantity: 1, unitPrice: 100 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      const inv = result.invoice;
      expect(inv.documentType).toBe('BILL_OF_SUPPLY');
      expect(Number(inv.cgstAmount)).toBe(0);
      expect(Number(inv.sgstAmount)).toBe(0);
      expect(Number(inv.total)).toBe(100);
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
      expect(Number(inv.cgstAmount)).toBeCloseTo(72, 2);
      expect(Number(inv.sgstAmount)).toBeCloseTo(72, 2);
      expect(Number(inv.total)).toBeCloseTo(944, 2);
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
      const partyNames = listA.invoices.map((i) => i.party?.name);
      expect(partyNames).toContain('PartyA-Listing');
      expect(partyNames).not.toContain('PartyB-Listing');
    } finally {
      await cleanupTestUser(shopA);
      await cleanupTestUser(shopB);
    }
  });
});
