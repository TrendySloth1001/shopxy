import { describe, it, expect, afterAll } from 'vitest';
import crypto from 'crypto';
import prisma from '../../src/infra/db/prisma.js';
import * as cashier from '../../src/modules/cashier/cashier.service.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

/// Z-report visibility: a cashier only ever sees their own shifts; an
/// owner/manager sees every employee's, labelled by name + email. The
/// service enforces this via the optional `openedById` scope the controller
/// passes (caller's id for a cashier, undefined for a manager).

describe('cashier — Z-report scoping', () => {
  const extraUserIds: number[] = [];

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { id: { in: extraUserIds } } });
    await prisma.$disconnect();
  });

  it('scopes the shift list + report by opener', async () => {
    const owner = await createTestUser();
    try {
      // A second cashier in the same shop.
      const id = crypto.randomBytes(6).toString('hex');
      const cashierUser = await prisma.user.create({
        data: { email: `cashier+${id}@shopxy.test`, name: `Cashier ${id}`, passwordHash: 'x', role: 'OWNER', acceptedAt: new Date() },
        select: { id: true, email: true, name: true },
      });
      extraUserIds.push(cashierUser.id);

      // One shift each, same shop. (Close the owner's first so the cashier
      // can hold the single OPEN slot — openShift rejects a second OPEN.)
      const ownerShift = await cashier.openShift(owner.shopId, owner.userId, 100);
      await cashier.closeShift(owner.shopId, owner.userId, { countedCash: 100 });
      const cashierShift = await cashier.openShift(owner.shopId, cashierUser.id, 50);

      // Manager view (no scope) → both shifts, with name + email.
      const all = await cashier.listShifts(owner.shopId, {});
      expect(all.length).toBeGreaterThanOrEqual(2);
      const cashierRow = all.find((s) => s.openedById === cashierUser.id);
      expect(cashierRow?.openedByName).toBe(cashierUser.name);
      expect(cashierRow?.openedByEmail).toBe(cashierUser.email);

      // Cashier view (scoped to self) → only their own shift.
      const mine = await cashier.listShifts(owner.shopId, { openedById: cashierUser.id });
      expect(mine.every((s) => s.openedById === cashierUser.id)).toBe(true);
      expect(mine.some((s) => s.id === ownerShift.id)).toBe(false);
      expect(mine.some((s) => s.id === cashierShift.id)).toBe(true);

      // Cashier can pull their own report…
      const own = await cashier.report(owner.shopId, cashierShift.id, { openedById: cashierUser.id });
      expect('error' in own).toBe(false);
      // …but not the owner's shift report.
      const denied = await cashier.report(owner.shopId, ownerShift.id, { openedById: cashierUser.id });
      expect('error' in denied).toBe(true);

      // Manager can pull anyone's.
      const mgr = await cashier.report(owner.shopId, ownerShift.id, {});
      expect('error' in mgr).toBe(false);
    } finally {
      await cleanupTestUser(owner);
    }
  });
});
