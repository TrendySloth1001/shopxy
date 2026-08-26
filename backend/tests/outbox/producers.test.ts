import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import { stockAdjustmentsService } from '../../src/modules/stock-adjustments/stock-adjustments.service.js';
import { paymentsService } from '../../src/modules/payments/payments.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

describe('outbox producers', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('stockAdjustments.create emits a stock.adjusted event', async () => {
    const ctx = await createTestUser();
    try {
      const product = await createTestProduct(ctx.shopId);
      const res = await stockAdjustmentsService.create(ctx.shopId, {
        reasonCode: 'OPENING',
        items: [{ productId: product.id, quantity: 5, unitCost: 70 }],
        createdById: ctx.userId,
      });
      expect('adjustment' in res).toBe(true);
      const adjustmentId = 'adjustment' in res ? res.adjustment.id : -1;

      const row = await prisma.outboxEvent.findFirst({
        where: { shopId: ctx.shopId, eventType: 'stock.adjusted' },
      });
      expect(row?.status).toBe('PENDING');
      expect(row?.aggregateType).toBe('stock_adjustment');
      expect((row?.payload as { adjustmentId?: number })?.adjustmentId).toBe(adjustmentId);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('payments.createPayment + voidPayment emit payment.recorded then payment.voided', async () => {
    const ctx = await createTestUser();
    const party = await prisma.party.create({ data: { shopId: ctx.shopId, name: 'Outbox Test Party' } });
    try {
      const payment = await paymentsService.createPayment({
        shopId: ctx.shopId,
        type: 'RECEIPT',
        amount: 100,
        mode: 'CASH',
        partyId: party.id,
        createdById: ctx.userId,
      });

      const recorded = await prisma.outboxEvent.findFirst({
        where: { shopId: ctx.shopId, eventType: 'payment.recorded' },
      });
      expect(recorded?.aggregateType).toBe('payment');
      expect((recorded?.payload as { paymentId?: number })?.paymentId).toBe(payment.id);

      const voided = await paymentsService.voidPayment(ctx.shopId, payment.id, ctx.userId);
      expect(voided).toBe(true);

      const voidEvent = await prisma.outboxEvent.findFirst({
        where: { shopId: ctx.shopId, eventType: 'payment.voided' },
      });
      expect(voidEvent?.aggregateType).toBe('payment');
      expect((voidEvent?.payload as { paymentId?: number })?.paymentId).toBe(payment.id);
    } finally {
      await prisma.outboxEvent.deleteMany({ where: { shopId: ctx.shopId } }).catch(() => undefined);
      await prisma.payment.deleteMany({ where: { shopId: ctx.shopId } }).catch(() => undefined);
      await prisma.party.deleteMany({ where: { id: party.id } }).catch(() => undefined);
      await cleanupTestUser(ctx);
    }
  });
});
