import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { invoicesService } from '../../src/modules/invoices/invoices.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

/// GST-6 / Rule 46(e)(f): once an invoice is B2B (recipient GSTIN present) or
/// worth ≥ ₹50,000, the recipient's name AND address are mandatory document
/// elements, and the engine blocks the save without them.
///
/// The block was unescapable from the invoice form: the address came from the
/// linked Party row and ONLY from it, so a party saved without an address made
/// the invoice impossible to save — there was nowhere in the request to put
/// the missing address, and no way to say "issue it anyway". Both now exist.

describe('invoices — recipient detail guard (Rule 46(e)/(f))', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  /// A registered shop, so SALE documents are TAX_INVOICEs the guard applies
  /// to rather than being downgraded to a Bill of Supply.
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

  /// ₹60,000 before tax — comfortably over the ₹50,000 named-recipient
  /// threshold that turns the recipient's address into a hard requirement.
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

  // The fix: the merchant completes the address on the invoice itself. Before
  // this, these fields didn't exist on the request at all — the only way out
  // was to abandon the invoice, go and edit the party, and start again.
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

  // The escape hatch, for a merchant who was shown exactly what's missing and
  // chose to issue the document anyway.
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
      // Issued incomplete, on purpose — the address really is absent.
      expect(result.invoice.customerAddress).toBeNull();
      await prisma.invoice.delete({ where: { id: result.invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // The precedence that makes "complete it here" work at all. A party row's
  // nulls must not overwrite what the request supplied — the party used to win
  // unconditionally, which is what made the address unfixable from the form.
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
      // Supplied wins…
      expect(result.invoice.customerAddress).toBe('9 New Street');
      // …and the untouched party fields still come through.
      expect(result.invoice.customerCity).toBe('Nagpur');
      await prisma.invoice.delete({ where: { id: result.invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // Below the threshold and with no GSTIN there is nothing to enforce — a
  // small B2C counter sale must stay frictionless.
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

  // Documents a real interaction that is easy to misread as a bug: GST-10
  // backfills `customerStateCode` from the recipient's GSTIN prefix, and the
  // address check counts a bare state code as an address. So a B2B invoice
  // never actually trips the address branch, however empty the party row is —
  // only the ≥₹50,000-without-a-GSTIN case does. Any client-side mirror of
  // this rule has to account for it or it will warn about nothing.
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
