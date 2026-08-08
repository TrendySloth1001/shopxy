import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { quotationsService } from '../../src/modules/quotations/quotations.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

/// Archiving for quotations, mirroring invoices and challans.
///
/// The quotation number is a per-shop serial allocated at CREATE time, so a
/// quotation can't be deleted without leaving a hole in the run. Archiving
/// files it out of the merchant's working list and keeps the number.
///
/// Two rules are specific to quotations and are what these tests pin down:
///   (a) REQUESTED and PENDING are refused — the customer still has a decision
///       to make, and an accept landing against a document the merchant can no
///       longer see is the failure mode worth preventing;
///   (b) the customer-facing list ignores `archivedAt` entirely. Archiving is
///       the merchant's own filing decision; it must not erase the
///       counterparty's record of what they were quoted.

describe('quotations — archive', () => {
  /// Buyer accounts the fixtures mint, torn down together at the end. They
  /// belong to no shop under test, so the per-test `cleanupTestUser(ctx)`
  /// calls can't reach them and would otherwise leave users behind.
  const buyers: Awaited<ReturnType<typeof createTestUser>>[] = [];

  afterAll(async () => {
    for (const buyer of buyers) await cleanupTestUser(buyer);
    await prisma.$disconnect();
  });

  /// A quotation is always sent to a LINKED customer — `create` rejects a
  /// bare party with PARTY_NOT_LINKED — so every fixture needs a buyer user
  /// behind the party.
  async function pendingQuote(ctx: { shopId: number; userId: number }) {
    const buyer = await createTestUser({ role: 'CUSTOMER' as never });
    buyers.push(buyer);
    const party = await prisma.party.create({
      data: { shopId: ctx.shopId, name: 'Archive Test Customer', linkedUserId: buyer.userId },
    });
    const product = await createTestProduct(ctx.shopId, { sellingPrice: 100 });
    const result = await quotationsService.create(ctx.shopId, party.id, ctx.userId, {
      items: [
        {
          productId: product.id,
          name: product.name,
          quantity: 1,
          unitPrice: 100,
          taxPercent: 18,
          discount: 0,
        },
      ],
    });
    if ('error' in result) throw new Error(String(result.error));
    return { quotation: result.quotation, partyId: party.id };
  }

  async function settledQuote(ctx: { shopId: number; userId: number }) {
    const { quotation, partyId } = await pendingQuote(ctx);
    await quotationsService.cancel(ctx.shopId, quotation.id);
    return { quotation, partyId };
  }

  it('refuses to archive a quotation the customer can still act on', async () => {
    const ctx = await createTestUser();
    try {
      const { quotation } = await pendingQuote(ctx);
      const result = await quotationsService.setArchived(ctx.shopId, quotation.id, true);
      expect('error' in result).toBe(true);
      if ('error' in result) expect(result.error).toMatch(/still act on/i);

      const live = await quotationsService.listForShop(ctx.shopId, { skip: 0, take: 50 });
      expect(live.data.map((q) => q.id)).toContain(quotation.id);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('archives a settled quotation, keeping its number and its row', async () => {
    const ctx = await createTestUser();
    try {
      const { quotation } = await settledQuote(ctx);
      const result = await quotationsService.setArchived(ctx.shopId, quotation.id, true);
      expect('error' in result).toBe(false);
      if ('error' in result) return;

      expect(result.quotation?.archivedAt).not.toBeNull();
      expect(result.quotation?.quotationNo).toBe(quotation.quotationNo);
      const stillThere = await prisma.quotation.findUnique({ where: { id: quotation.id } });
      expect(stillThere).not.toBeNull();
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('drops archived quotations out of the default list, and lists them on request', async () => {
    const ctx = await createTestUser();
    try {
      const kept = (await settledQuote(ctx)).quotation;
      const filed = (await settledQuote(ctx)).quotation;
      await quotationsService.setArchived(ctx.shopId, filed.id, true);

      const live = await quotationsService.listForShop(ctx.shopId, { skip: 0, take: 50 });
      expect(live.data.map((q) => q.id)).toContain(kept.id);
      expect(live.data.map((q) => q.id)).not.toContain(filed.id);

      const archived = await quotationsService.listForShop(ctx.shopId, {
        archived: true,
        skip: 0,
        take: 50,
      });
      expect(archived.data.map((q) => q.id)).toContain(filed.id);
      expect(archived.data.map((q) => q.id)).not.toContain(kept.id);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('leaves the customer-facing list alone — the merchant filing it away is not the customer forgetting it', async () => {
    const ctx = await createTestUser();
    try {
      const { quotation, partyId } = await settledQuote(ctx);
      await quotationsService.setArchived(ctx.shopId, quotation.id, true);

      const forCustomer = await quotationsService.listForParty(ctx.shopId, partyId, {
        skip: 0,
        take: 50,
      });
      expect(forCustomer.data.map((q) => q.id)).toContain(quotation.id);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('restoring puts it back in the working list', async () => {
    const ctx = await createTestUser();
    try {
      const { quotation } = await settledQuote(ctx);
      await quotationsService.setArchived(ctx.shopId, quotation.id, true);
      const restored = await quotationsService.setArchived(ctx.shopId, quotation.id, false);
      expect('error' in restored).toBe(false);
      if ('error' in restored) return;
      expect(restored.quotation?.archivedAt).toBeNull();

      const live = await quotationsService.listForShop(ctx.shopId, { skip: 0, take: 50 });
      expect(live.data.map((q) => q.id)).toContain(quotation.id);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('is idempotent — a retried tap is a no-op, not an error', async () => {
    const ctx = await createTestUser();
    try {
      const { quotation } = await settledQuote(ctx);
      await quotationsService.setArchived(ctx.shopId, quotation.id, true);
      expect('error' in (await quotationsService.setArchived(ctx.shopId, quotation.id, true))).toBe(false);
      await quotationsService.setArchived(ctx.shopId, quotation.id, false);
      expect('error' in (await quotationsService.setArchived(ctx.shopId, quotation.id, false))).toBe(false);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('will not touch another shop\'s quotation', async () => {
    const owner = await createTestUser();
    const stranger = await createTestUser();
    try {
      const { quotation } = await settledQuote(owner);
      const result = await quotationsService.setArchived(stranger.shopId, quotation.id, true);
      expect('error' in result).toBe(true);
      if ('error' in result) expect(result.error).toBe('Quotation not found');

      const untouched = await prisma.quotation.findUnique({ where: { id: quotation.id } });
      expect(untouched?.archivedAt).toBeNull();
    } finally {
      await cleanupTestUser(owner);
      await cleanupTestUser(stranger);
    }
  });
});
