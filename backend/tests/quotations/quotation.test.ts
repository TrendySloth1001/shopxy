import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { quotationsService } from '../../src/modules/quotations/quotations.service.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

/// Smoke tests for the two GST gaps this quotation pass closes:
///   (a) the preview (priceItems) didn't apply the registration gate, so a
///       COMPOSITION/UNREGISTERED shop's quote showed GST the accepted
///       invoice would then zero out;
///   (b) there was no inclusive/no-GST support at all on a quotation line,
///       so a TAX_INCLUSIVE or NO_GST product's quoted total could disagree
///       with what accept() actually billed.
/// Both are asserted end-to-end: quote → accept → compare the preview total
/// against the real invoice total to the paisa.

async function createBuyer() {
  return createTestUser({ role: 'CUSTOMER' as never });
}

async function createLinkedParty(shopId: number, linkedUserId: number) {
  return prisma.party.create({
    data: { shopId, name: 'Linked Customer', linkedUserId },
  });
}

describe('quotations.service — GST gate + pricing mode', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('create — COMPOSITION shop quotation preview shows zero tax', async () => {
    const merchant = await createTestUser();
    const buyer = await createBuyer();
    try {
      await prisma.user.update({
        where: { id: merchant.userId },
        data: {
          shopGstin: '27ABCDE1234F1Z5',
          shopStateCode: '27',
          registrationType: 'COMPOSITION',
        },
      });
      const product = await prisma.product.create({
        data: {
          shopId: merchant.shopId,
          name: 'Composition Product',
          sku: `SKU-COMP-${Date.now()}`,
          mrp: 100,
          sellingPrice: 100,
          purchasePrice: 60,
          taxPercent: 18,
        },
      });
      const party = await createLinkedParty(merchant.shopId, buyer.userId);
      const result = await quotationsService.create(merchant.shopId, party.id, merchant.userId, {
        items: [{ productId: product.id, name: product.name, quantity: 1, unitPrice: 100, taxPercent: 18 }],
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      expect(result.quotation.taxAmount).toBe(0);
      expect(result.quotation.total).toBe(100);
      await prisma.quotation.delete({ where: { id: result.quotation.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('create → accept — NO_GST product quote preview total matches the accepted invoice total', async () => {
    const merchant = await createTestUser();
    const buyer = await createBuyer();
    try {
      await prisma.user.update({
        where: { id: merchant.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      const product = await prisma.product.create({
        data: {
          shopId: merchant.shopId,
          name: 'Exempt Product',
          sku: `SKU-QNOGST-${Date.now()}`,
          mrp: 100,
          sellingPrice: 100,
          purchasePrice: 60,
          taxPercent: 0,
          pricingMode: 'NO_GST',
          stockQuantity: 10,
        },
      });
      const party = await createLinkedParty(merchant.shopId, buyer.userId);
      const created = await quotationsService.create(merchant.shopId, party.id, merchant.userId, {
        items: [{ productId: product.id, name: product.name, quantity: 1, unitPrice: 100 }],
      });
      expect('error' in created).toBe(false);
      if ('error' in created) return;
      expect(created.quotation.taxAmount).toBe(0);
      expect(created.quotation.total).toBe(100);

      const accepted = await quotationsService.accept(merchant.shopId, party.id, created.quotation.id, buyer.userId);
      const invoice = await prisma.invoice.findUniqueOrThrow({ where: { id: accepted.invoice.id } });
      expect(Number(invoice.total)).toBe(created.quotation.total);
      expect(Number(invoice.cgstAmount)).toBe(0);
      expect(Number(invoice.sgstAmount)).toBe(0);
      await prisma.invoice.delete({ where: { id: invoice.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });

  it('create → accept — TAX_INCLUSIVE product quote preview total matches the accepted invoice total', async () => {
    const merchant = await createTestUser();
    const buyer = await createBuyer();
    try {
      await prisma.user.update({
        where: { id: merchant.userId },
        data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
      });
      const product = await prisma.product.create({
        data: {
          shopId: merchant.shopId,
          name: 'Inclusive Product',
          sku: `SKU-QINC-${Date.now()}`,
          mrp: 118,
          sellingPrice: 118,
          purchasePrice: 70,
          taxPercent: 18,
          pricingMode: 'TAX_INCLUSIVE',
          stockQuantity: 10,
        },
      });
      const party = await createLinkedParty(merchant.shopId, buyer.userId);
      const created = await quotationsService.create(merchant.shopId, party.id, merchant.userId, {
        items: [{ productId: product.id, name: product.name, quantity: 1, unitPrice: 118 }],
      });
      expect('error' in created).toBe(false);
      if ('error' in created) return;
      // ₹118 already contains 18% GST → taxable 100, tax 18, total stays 118.
      expect(created.quotation.subtotal).toBeCloseTo(100, 2);
      expect(created.quotation.total).toBeCloseTo(118, 2);

      const accepted = await quotationsService.accept(merchant.shopId, party.id, created.quotation.id, buyer.userId);
      const invoice = await prisma.invoice.findUniqueOrThrow({ where: { id: accepted.invoice.id } });
      expect(Number(invoice.total)).toBeCloseTo(created.quotation.total, 2);
      expect(Number(invoice.taxableValue)).toBeCloseTo(100, 2);
      await prisma.invoice.delete({ where: { id: invoice.id } });
    } finally {
      await cleanupTestUser(merchant);
      await cleanupTestUser(buyer);
    }
  });
});
