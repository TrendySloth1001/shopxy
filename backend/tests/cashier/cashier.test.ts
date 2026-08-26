import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import * as pos from '../../src/modules/pos/pos.service.js';
import * as cashier from '../../src/modules/cashier/cashier.service.js';
import { createTestUser, createTestProduct } from '../helpers/setup.js';

async function registerShop(userId: number) {
  await prisma.user.update({
    where: { id: userId },
    data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
  });
}

const asReport = (r: unknown) => {
  if (r && typeof r === 'object' && 'error' in (r as Record<string, unknown>)) {
    throw new Error(`expected report, got error: ${(r as { error: string }).error}`);
  }
  return r as cashier.ShiftReport;
};

describe('cashier control center', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('shift: open float → cash sale + drawer movements → close reconciles expected vs counted', async () => {
    const ctx = await createTestUser();
    await registerShop(ctx.userId);
    const product = await createTestProduct(ctx.shopId, { sellingPrice: 100, stockQuantity: 10 });
    await prisma.product.update({ where: { id: product.id }, data: { taxPercent: 18, mrp: 200 } });

    const opened = await cashier.openShift(ctx.shopId, ctx.userId, 2000);
    expect('error' in opened).toBe(false);

    const sale = await pos.openSale(ctx.shopId, ctx.userId);
    const saleId = (sale as { sale: { id: number } }).sale.id;
    await pos.addScan(ctx.shopId, saleId, product.sku, ctx.userId);
    await pos.addScan(ctx.shopId, saleId, product.sku, ctx.userId);
    const checkout = await pos.checkout(ctx.shopId, saleId, { tender: { mode: 'CASH' } }, ctx.userId);
    expect('error' in checkout).toBe(false);

    const saleRow = await prisma.sale.findUnique({ where: { id: saleId }, select: { shiftId: true } });
    expect(saleRow!.shiftId).toBe((opened as cashier.ShiftView).id);

    await cashier.addCashMovement(ctx.shopId, ctx.userId, { type: 'PAY_IN', amount: 500, reason: 'float top-up' });
    await cashier.addCashMovement(ctx.shopId, ctx.userId, { type: 'PAY_OUT', amount: 200, reason: 'tea' });
    await cashier.addCashMovement(ctx.shopId, ctx.userId, { type: 'DROP', amount: 1000 });

    const x = asReport(await cashier.xReport(ctx.shopId, ctx.userId));
    expect(x.cash.openingFloat).toBe(2000);
    expect(x.cash.cashSales).toBe(236);
    expect(x.cash.payIns).toBe(500);
    expect(x.cash.payOuts).toBe(200);
    expect(x.cash.drops).toBe(1000);
    expect(x.cash.expected).toBe(1536);
    expect(x.tenders.find((t) => t.mode === 'CASH')?.amount).toBe(236);
    expect(x.gst.cgst).toBe(18);
    expect(x.gst.sgst).toBe(18);
    expect(x.sales.count).toBe(1);

    const z = asReport(await cashier.closeShift(ctx.shopId, ctx.userId, { countedCash: 1500, note: 'eod' }));
    expect(z.shift.status).toBe('CLOSED');
    expect(z.cash.expected).toBe(1536);
    expect(z.cash.counted).toBe(1500);
    expect(z.cash.variance).toBe(-36);

    expect(await cashier.getOpenShift(ctx.shopId, ctx.userId)).toBeNull();
  });

  it('openShift is idempotent — a second open returns the same shift', async () => {
    const ctx = await createTestUser();
    const a = (await cashier.openShift(ctx.shopId, ctx.userId, 1000)) as cashier.ShiftView;
    const b = (await cashier.openShift(ctx.shopId, ctx.userId, 9999)) as cashier.ShiftView;
    expect(b.id).toBe(a.id);
    expect(b.openingFloat).toBe(1000);
  });

  it('lists shift history (Z-receipts) with the closed figures + a fetchable report', async () => {
    const ctx = await createTestUser();
    await registerShop(ctx.userId);
    await cashier.openShift(ctx.shopId, ctx.userId, 500);
    await cashier.closeShift(ctx.shopId, ctx.userId, { countedCash: 500 });

    const shifts = await cashier.listShifts(ctx.shopId);
    expect(shifts.length).toBeGreaterThanOrEqual(1);
    expect(shifts[0].status).toBe('CLOSED');
    expect(shifts[0].closingCounted).toBe(500);
    expect(shifts[0].variance).toBe(0);

    const rep = await cashier.report(ctx.shopId, shifts[0].id);
    expect('error' in rep).toBe(false);
  });

  it('§269ST: a cash tender ≥ ₹2,00,000 is blocked; non-cash is allowed', async () => {
    const ctx = await createTestUser();
    await registerShop(ctx.userId);
    const product = await createTestProduct(ctx.shopId, { sellingPrice: 250000, stockQuantity: 5 });
    await prisma.product.update({ where: { id: product.id }, data: { taxPercent: 0, mrp: 250000 } });

    const sale = await pos.openSale(ctx.shopId, ctx.userId);
    const saleId = (sale as { sale: { id: number } }).sale.id;
    await pos.addScan(ctx.shopId, saleId, product.sku, ctx.userId);

    const cashResult = await pos.checkout(ctx.shopId, saleId, { tender: { mode: 'CASH' } }, ctx.userId);
    expect('error' in cashResult).toBe(true);
    expect((cashResult as { error: string }).error).toContain('269ST');

    const upiResult = await pos.checkout(ctx.shopId, saleId, { tender: { mode: 'UPI' } }, ctx.userId);
    expect('error' in upiResult).toBe(false);
  });

  it('Legal Metrology: a price override above MRP is rejected', async () => {
    const ctx = await createTestUser();
    await registerShop(ctx.userId);
    const product = await createTestProduct(ctx.shopId, { sellingPrice: 100, stockQuantity: 5 });
    await prisma.product.update({ where: { id: product.id }, data: { mrp: 120 } });

    const sale = await pos.openSale(ctx.shopId, ctx.userId);
    const saleId = (sale as { sale: { id: number } }).sale.id;
    await pos.addScan(ctx.shopId, saleId, product.sku, ctx.userId);

    const above = await pos.setUnitPrice(ctx.shopId, saleId, product.id, 150);
    expect('error' in above).toBe(true);
    expect((above as { error: string }).error).toContain('MRP');

    const atOrBelow = await pos.setUnitPrice(ctx.shopId, saleId, product.id, 90);
    expect('error' in atOrBelow).toBe(false);
  });
});
