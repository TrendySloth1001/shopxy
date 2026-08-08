import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { challansService } from '../../src/modules/challans/challans.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

/// Archiving for delivery challans, mirroring invoices.
///
/// A challan number is a per-shop serial allocated at CREATE time and Rule 55
/// wants the run serially numbered, so a challan can't be deleted without
/// leaving a hole. Archiving hides it and keeps the number.
///
/// The one rule that differs from invoices: a PENDING challan is refused.
/// Goods are physically out against it and it has been neither invoiced nor
/// cancelled — filing it away would lose track of stock that has left.

describe('challans — archive', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  async function pendingChallan(ctx: { shopId: number; userId: number }) {
    const product = await createTestProduct(ctx.shopId, { sellingPrice: 100, stockQuantity: 50 });
    const result = await challansService.createChallan(ctx.shopId, {
      partyName: 'Archive Test Party',
      items: [{ productId: product.id, quantity: 1 }],
      createdById: ctx.userId,
    });
    if ('error' in result) throw new Error(String(result.error));
    return result.challan;
  }

  /// Cancelling reverses the ledger and lands the challan in a settled state.
  async function settledChallan(ctx: { shopId: number; userId: number }) {
    const challan = await pendingChallan(ctx);
    const cancelled = await challansService.cancelChallan(ctx.shopId, challan.id, ctx.userId);
    if ('error' in cancelled) throw new Error(cancelled.error);
    return challan;
  }

  it('refuses to archive a PENDING challan — goods are out against it', async () => {
    const ctx = await createTestUser();
    try {
      const challan = await pendingChallan(ctx);
      const result = await challansService.setArchived(ctx.shopId, challan.id, true);
      expect('error' in result).toBe(true);
      if ('error' in result) expect(result.error).toMatch(/pending challan/i);

      // Still visible, which is the point of the refusal.
      const list = await challansService.listChallans(ctx.shopId, {
        search: '', page: 1, limit: 50, skip: 0,
      });
      expect(list.challans.map((c) => c.id)).toContain(challan.id);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('archives a settled challan, keeping its number and its row', async () => {
    const ctx = await createTestUser();
    try {
      const challan = await settledChallan(ctx);
      const result = await challansService.setArchived(ctx.shopId, challan.id, true);
      expect('error' in result).toBe(false);
      if ('error' in result) return;

      expect(result.challan?.archivedAt).not.toBeNull();
      // The serial is retained against the row — this is what makes archiving
      // acceptable where deletion wasn't.
      expect(result.challan?.challanNo).toBe(challan.challanNo);
      const stillThere = await prisma.challan.findUnique({ where: { id: challan.id } });
      expect(stillThere).not.toBeNull();
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('drops archived challans out of the default list, and lists them on request', async () => {
    const ctx = await createTestUser();
    try {
      const kept = await settledChallan(ctx);
      const filed = await settledChallan(ctx);
      await challansService.setArchived(ctx.shopId, filed.id, true);

      const live = await challansService.listChallans(ctx.shopId, {
        search: '', page: 1, limit: 50, skip: 0,
      });
      expect(live.challans.map((c) => c.id)).toContain(kept.id);
      expect(live.challans.map((c) => c.id)).not.toContain(filed.id);

      const archived = await challansService.listChallans(ctx.shopId, {
        search: '', archived: true, page: 1, limit: 50, skip: 0,
      });
      expect(archived.challans.map((c) => c.id)).toContain(filed.id);
      expect(archived.challans.map((c) => c.id)).not.toContain(kept.id);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('restoring puts it back in the working list', async () => {
    const ctx = await createTestUser();
    try {
      const challan = await settledChallan(ctx);
      await challansService.setArchived(ctx.shopId, challan.id, true);
      const restored = await challansService.setArchived(ctx.shopId, challan.id, false);
      expect('error' in restored).toBe(false);
      if ('error' in restored) return;
      expect(restored.challan?.archivedAt).toBeNull();

      const live = await challansService.listChallans(ctx.shopId, {
        search: '', page: 1, limit: 50, skip: 0,
      });
      expect(live.challans.map((c) => c.id)).toContain(challan.id);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('is idempotent — a retried tap is a no-op, not an error', async () => {
    const ctx = await createTestUser();
    try {
      const challan = await settledChallan(ctx);
      await challansService.setArchived(ctx.shopId, challan.id, true);
      const again = await challansService.setArchived(ctx.shopId, challan.id, true);
      expect('error' in again).toBe(false);

      const restored = await challansService.setArchived(ctx.shopId, challan.id, false);
      expect('error' in restored).toBe(false);
      const restoredAgain = await challansService.setArchived(ctx.shopId, challan.id, false);
      expect('error' in restoredAgain).toBe(false);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('will not touch another shop\'s challan', async () => {
    const owner = await createTestUser();
    const stranger = await createTestUser();
    try {
      const challan = await settledChallan(owner);
      const result = await challansService.setArchived(stranger.shopId, challan.id, true);
      expect('error' in result).toBe(true);
      if ('error' in result) expect(result.error).toBe('Challan not found');

      const untouched = await prisma.challan.findUnique({ where: { id: challan.id } });
      expect(untouched?.archivedAt).toBeNull();
    } finally {
      await cleanupTestUser(owner);
      await cleanupTestUser(stranger);
    }
  });
});
