import { describe, it, expect, afterAll } from 'vitest';
import crypto from 'crypto';
import prisma from '../../src/infra/db/prisma.js';
import { paymentsService } from '../../src/modules/payments/payments.service.js';
import { createTestUser, cleanupTestUser } from '../helpers/setup.js';

async function createParty(shopId: number) {
  return prisma.party.create({
    data: { shopId, name: `TestParty-${crypto.randomBytes(3).toString('hex')}` },
  });
}

describe('payments.service — smoke', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('createPayment — RECEIPT against a party persists with the right amount', async () => {
    const ctx = await createTestUser();
    try {
      const party = await createParty(ctx.shopId);
      const row = await paymentsService.createPayment({
        shopId: ctx.shopId,
        type: 'RECEIPT',
        amount: 250,
        mode: 'CASH',
        partyId: party.id,
        createdById: ctx.userId,
      });
      expect(Number(row.amount)).toBe(250);
      expect(row.partyId).toBe(party.id);
      expect(row.type).toBe('RECEIPT');
      await prisma.payment.delete({ where: { id: row.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('createPayment — second call with same idempotencyKey returns the original row', async () => {
    const ctx = await createTestUser();
    try {
      const party = await createParty(ctx.shopId);
      const idempotencyKey = `key-${crypto.randomBytes(4).toString('hex')}`;
      const first = await paymentsService.createPayment({
        shopId: ctx.shopId,
        type: 'RECEIPT',
        amount: 100,
        mode: 'UPI',
        partyId: party.id,
        idempotencyKey,
        createdById: ctx.userId,
      });
      const second = await paymentsService.createPayment({
        shopId: ctx.shopId,
        type: 'RECEIPT',
        amount: 100,
        mode: 'UPI',
        partyId: party.id,
        idempotencyKey,
        createdById: ctx.userId,
      });
      expect(second.id).toBe(first.id);
      await prisma.payment.delete({ where: { id: first.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('createPayment — same idempotencyKey with different amount throws conflict', async () => {
    const ctx = await createTestUser();
    try {
      const party = await createParty(ctx.shopId);
      const idempotencyKey = `key-${crypto.randomBytes(4).toString('hex')}`;
      const first = await paymentsService.createPayment({
        shopId: ctx.shopId,
        type: 'RECEIPT',
        amount: 100,
        mode: 'CASH',
        partyId: party.id,
        idempotencyKey,
        createdById: ctx.userId,
      });
      await expect(
        paymentsService.createPayment({
          shopId: ctx.shopId,
          type: 'RECEIPT',
          amount: 999,
          mode: 'CASH',
          partyId: party.id,
          idempotencyKey,
          createdById: ctx.userId,
        }),
      ).rejects.toThrow(/IDEMPOTENCY_CONFLICT/);
      await prisma.payment.delete({ where: { id: first.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('createPayment — rejects when the party belongs to a different shop', async () => {
    const shopA = await createTestUser();
    const shopB = await createTestUser();
    try {
      const partyB = await createParty(shopB.shopId);
      await expect(
        paymentsService.createPayment({
          shopId: shopA.shopId,
          type: 'RECEIPT',
          amount: 100,
          mode: 'CASH',
          partyId: partyB.id,
          createdById: shopA.userId,
        }),
      ).rejects.toThrow(/Party not found/);
    } finally {
      await cleanupTestUser(shopA);
      await cleanupTestUser(shopB);
    }
  });

  it('voidPayment — retains the row but drops it from the party ledger balance', async () => {
    const ctx = await createTestUser();
    try {
      const party = await createParty(ctx.shopId);
      const pay = await paymentsService.createPayment({
        shopId: ctx.shopId,
        type: 'RECEIPT',
        amount: 500,
        mode: 'CASH',
        partyId: party.id,
        createdById: ctx.userId,
      });

      const before = await paymentsService.partyLedger(ctx.shopId, party.id);
      expect(before?.balance).toBe(-500);

      const ok = await paymentsService.voidPayment(ctx.shopId, pay.id, ctx.userId, 'entered twice');
      expect(ok).toBe(true);

      const row = await prisma.payment.findUnique({ where: { id: pay.id } });
      expect(row).not.toBeNull();
      expect(row?.voidedAt).not.toBeNull();
      expect(row?.voidReason).toBe('entered twice');

      const after = await paymentsService.partyLedger(ctx.shopId, party.id);
      expect(after?.balance).toBe(0);

      expect(await paymentsService.voidPayment(ctx.shopId, pay.id, ctx.userId)).toBe(true);

      await prisma.payment.delete({ where: { id: pay.id } });
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});
