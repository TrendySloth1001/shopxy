import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { invoicesService } from '../../src/modules/invoices/invoices.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

describe('invoices — recipient detail guard (Rule 46(e)/(f))', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  async function registeredShop() {
    const ctx = await createTestUser();
    await prisma.user.update({
      where: { id: ctx.userId },
      data: {
        shopGstin: '27ABCDE1234F1Z5',
        shopStateCode: '27',
        registrationType: 'REGULAR',
      },
    });
    return ctx;
  }

  const HIGH_VALUE_QTY = 600;

  async function sale(
    ctx: { shopId: number },
    partyId: number,
    { quantity = 1, ...extra }: { quantity?: number } & Record<string, unknown> = {},
  ) {
    const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
    return invoicesService.createInvoice({
      shopId: ctx.shopId,
      type: 'SALE',
      partyId,
      items: [{ productId: product.id, quantity, unitPrice: 100, taxPercent: 18 }],
      ...extra,
    });
  }

  it('blocks a ≥₹50,000 sale to a party with no address', async () => {
    const ctx = await registeredShop();
    try {
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Addressless Traders' },
      });
      const result = await sale(ctx, party.id, { quantity: HIGH_VALUE_QTY });
      expect('error' in result).toBe(true);
      if (!('error' in result)) return;
      expect(result.error).toMatch(/address/i);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('accepts an address supplied on the request when the party has none', async () => {
    const ctx = await registeredShop();
    try {
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Addressless Traders' },
      });
      const result = await sale(ctx, party.id, {
        quantity: HIGH_VALUE_QTY,
        customerAddress: '14 MG Road',
        customerCity: 'Pune',
        customerStateCode: '27',
        customerPinCode: '411001',
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      expect(result.invoice.customerAddress).toBe('14 MG Road');
      expect(result.invoice.customerCity).toBe('Pune');
      expect(result.invoice.customerPinCode).toBe('411001');
      await prisma.invoice.delete({ where: { id: result.invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('lets an explicit acknowledgement past the guard', async () => {
    const ctx = await registeredShop();
    try {
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Addressless Traders' },
      });
      const result = await sale(ctx, party.id, {
        quantity: HIGH_VALUE_QTY,
        acknowledgeMissingRecipientDetails: true,
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      expect(result.invoice.customerAddress).toBeNull();
      await prisma.invoice.delete({ where: { id: result.invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('a supplied address wins over the party, and the party fills the rest', async () => {
    const ctx = await registeredShop();
    try {
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Half Filled Traders', city: 'Nagpur' },
      });
      const result = await sale(ctx, party.id, {
        quantity: HIGH_VALUE_QTY,
        customerAddress: '9 New Street',
      });
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      expect(result.invoice.customerAddress).toBe('9 New Street');
      expect(result.invoice.customerCity).toBe('Nagpur');
      await prisma.invoice.delete({ where: { id: result.invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('does not fire for a small B2C sale with no GSTIN', async () => {
    const ctx = await registeredShop();
    try {
      const party = await prisma.party.create({
        data: { shopId: ctx.shopId, name: 'Walk-in Regular' },
      });
      const result = await sale(ctx, party.id);
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      await prisma.invoice.delete({ where: { id: result.invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('a recipient GSTIN backfills the state code, which satisfies the address check', async () => {
    const ctx = await registeredShop();
    try {
      const party = await prisma.party.create({
        data: {
          shopId: ctx.shopId,
          name: 'B2B Traders',
          gstin: '27AAAAA0000A1Z5',
        },
      });
      const result = await sale(ctx, party.id);
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      expect(result.invoice.customerAddress).toBeNull();
      expect(result.invoice.customerStateCode).toBe('27');
      await prisma.invoice.delete({ where: { id: result.invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});
