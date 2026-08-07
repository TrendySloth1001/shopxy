import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { invoicesService } from '../../src/modules/invoices/invoices.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

/// Archiving replaces deletion.
///
/// GST Rule 46(b) needs the invoice serial run consecutive, and the serial is
/// allocated at CREATE time — so even an abandoned DRAFT already owns a number
/// and its row can never go away. `deleteInvoice` reflected that by returning
/// an error on every branch: it had no success path at all, while both clients
/// still offered a Delete button that could only ever fail.
///
/// The number staying put is the whole point, so it is what these tests check
/// hardest.

describe('invoices — archive', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  /// A SALE needs exactly one counterparty — the `invoices_vendor_party_xor`
  /// check constraint rejects a row with neither.
  async function draft(ctx: { shopId: number }) {
    const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
    const party = await prisma.party.create({
      data: { shopId: ctx.shopId, name: 'Archive Test Customer' },
    });
    const result = await invoicesService.createInvoice({
      shopId: ctx.shopId,
      type: 'SALE',
      partyId: party.id,
      items: [{ productId: product.id, quantity: 1, unitPrice: 100, taxPercent: 18 }],
    });
    if ('error' in result) throw new Error(result.error);
    return result.invoice;
  }

  it('archives a draft, keeping its number and its row', async () => {
    const ctx = await createTestUser();
    try {
      const invoice = await draft(ctx);
      const result = await invoicesService.setArchived(ctx.shopId, invoice.id, true);
      expect('error' in result).toBe(false);
      if ('error' in result) return;

      expect(result.invoice.archivedAt).not.toBeNull();
      // The serial is retained against the row — this is what makes archiving
      // legal where deletion wasn't.
      expect(result.invoice.invoiceNo).toBe(invoice.invoiceNo);
      const stillThere = await prisma.invoice.findUnique({ where: { id: invoice.id } });
      expect(stillThere).not.toBeNull();

      await prisma.invoice.delete({ where: { id: invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('drops archived documents out of the default list, and lists them on request', async () => {
    const ctx = await createTestUser();
    try {
      const kept = await draft(ctx);
      const filed = await draft(ctx);
      await invoicesService.setArchived(ctx.shopId, filed.id, true);

      const live = await invoicesService.listInvoices(ctx.shopId, {
        search: '', page: 1, limit: 50, skip: 0,
      });
      const liveIds = live.invoices.map((i) => i.id);
      expect(liveIds).toContain(kept.id);
      expect(liveIds).not.toContain(filed.id);

      const archived = await invoicesService.listInvoices(ctx.shopId, {
        search: '', page: 1, limit: 50, skip: 0, archived: true,
      });
      const archivedIds = archived.invoices.map((i) => i.id);
      expect(archivedIds).toContain(filed.id);
      expect(archivedIds).not.toContain(kept.id);

      await prisma.invoice.deleteMany({ where: { id: { in: [kept.id, filed.id] } } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('restores an archived document to the working list', async () => {
    const ctx = await createTestUser();
    try {
      const invoice = await draft(ctx);
      await invoicesService.setArchived(ctx.shopId, invoice.id, true);
      const restored = await invoicesService.setArchived(ctx.shopId, invoice.id, false);
      expect('error' in restored).toBe(false);
      if ('error' in restored) return;
      expect(restored.invoice.archivedAt).toBeNull();

      const live = await invoicesService.listInvoices(ctx.shopId, {
        search: '', page: 1, limit: 50, skip: 0,
      });
      expect(live.invoices.map((i) => i.id)).toContain(invoice.id);

      await prisma.invoice.delete({ where: { id: invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // A confirmed invoice has been issued to someone else. Letting the merchant
  // hide it would put their own books out of step with the customer's copy.
  it('refuses to archive a CONFIRMED invoice', async () => {
    const ctx = await createTestUser();
    try {
      const invoice = await draft(ctx);
      await invoicesService.updateStatus(ctx.shopId, invoice.id, 'CONFIRMED');
      const result = await invoicesService.setArchived(ctx.shopId, invoice.id, true);
      expect('error' in result).toBe(true);
      if (!('error' in result)) return;
      expect(result.error).toMatch(/cancel it first/i);

      await prisma.invoice.delete({ where: { id: invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('allows archiving once cancelled', async () => {
    const ctx = await createTestUser();
    try {
      const invoice = await draft(ctx);
      await invoicesService.updateStatus(ctx.shopId, invoice.id, 'CANCELLED');
      const result = await invoicesService.setArchived(ctx.shopId, invoice.id, true);
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      expect(result.invoice.archivedAt).not.toBeNull();
      expect(result.invoice.invoiceNo).toBe(invoice.invoiceNo);

      await prisma.invoice.delete({ where: { id: invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // A retried tap must not fail.
  it('is idempotent in both directions', async () => {
    const ctx = await createTestUser();
    try {
      const invoice = await draft(ctx);
      await invoicesService.setArchived(ctx.shopId, invoice.id, true);
      const again = await invoicesService.setArchived(ctx.shopId, invoice.id, true);
      expect('error' in again).toBe(false);

      await invoicesService.setArchived(ctx.shopId, invoice.id, false);
      const restoreAgain = await invoicesService.setArchived(ctx.shopId, invoice.id, false);
      expect('error' in restoreAgain).toBe(false);
      if ('error' in restoreAgain) return;
      expect(restoreAgain.invoice.archivedAt).toBeNull();

      await prisma.invoice.delete({ where: { id: invoice.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  // Archiving must not free the number for reuse — that's precisely the hole
  // in the serial run Rule 46(b) forbids.
  it('does not release the number for the next invoice', async () => {
    const ctx = await createTestUser();
    try {
      const first = await draft(ctx);
      await invoicesService.setArchived(ctx.shopId, first.id, true);
      const second = await draft(ctx);

      expect(second.invoiceNo).not.toBe(first.invoiceNo);

      await prisma.invoice.deleteMany({ where: { id: { in: [first.id, second.id] } } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('404s another shop’s invoice', async () => {
    const mine = await createTestUser();
    const theirs = await createTestUser();
    try {
      const invoice = await draft(mine);
      const result = await invoicesService.setArchived(theirs.shopId, invoice.id, true);
      expect('error' in result).toBe(true);
      if (!('error' in result)) return;
      expect(result.error).toMatch(/not found/i);

      await prisma.invoice.delete({ where: { id: invoice.id } });
    } finally {
      await cleanupTestUser(theirs);
      await cleanupTestUser(mine);
    }
  });
});
