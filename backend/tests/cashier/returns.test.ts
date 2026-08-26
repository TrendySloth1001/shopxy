import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import * as pos from '../../src/modules/pos/pos.service.js';
import * as cashier from '../../src/modules/cashier/cashier.service.js';
import * as returns from '../../src/modules/cashier/returns.service.js';
import { createTestUser, createTestProduct } from '../helpers/setup.js';

async function registerShop(userId: number) {
  await prisma.user.update({
    where: { id: userId },
    data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
  });
}

const asReport = (r: unknown) => r as cashier.ShiftReport;

describe('POS returns / credit notes', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('returns one unit of a two-unit sale: credit note + restock + drawer refund + over-return cap', async () => {
    const ctx = await createTestUser();
    await registerShop(ctx.userId);
    const product = await createTestProduct(ctx.shopId, { sellingPrice: 100, stockQuantity: 10 });
    await prisma.product.update({ where: { id: product.id }, data: { taxPercent: 18, mrp: 200 } });

    await cashier.openShift(ctx.shopId, ctx.userId, 0);

    const sale = await pos.openSale(ctx.shopId, ctx.userId);
    const saleId = (sale as { sale: { id: number } }).sale.id;
    await pos.addScan(ctx.shopId, saleId, product.sku, ctx.userId);
    await pos.addScan(ctx.shopId, saleId, product.sku, ctx.userId);
    const checkout = await pos.checkout(ctx.shopId, saleId, { tender: { mode: 'CASH' } }, ctx.userId);
    if ('error' in checkout) throw new Error(checkout.error);
    const stockAfterSale = await prisma.product.findUnique({ where: { id: product.id }, select: { stockQuantity: true } });
    expect(Number(stockAfterSale!.stockQuantity)).toBe(8);

    const returnable = await returns.getReturnable(ctx.shopId, checkout.invoiceId);
    if ('error' in returnable) throw new Error(returnable.error);
    expect(returnable.lines[0].soldQty).toBe(2);
    expect(returnable.lines[0].returnableQty).toBe(2);

    const ret = await returns.returnSale(ctx.shopId, ctx.userId, {
      originalInvoiceId: checkout.invoiceId,
      lines: [{ productId: product.id, quantity: 1 }],
      refundMode: 'CASH',
    });
    if ('error' in ret) throw new Error(ret.error);
    expect(ret.refundAmount).toBe(118);
    expect(ret.cashDrawerAdjusted).toBe(true);
    expect(ret.creditNoteNo).toBeTruthy();

    const cn = await prisma.invoice.findUnique({
      where: { id: ret.creditNoteId },
      select: { documentType: true, originalInvoiceId: true, total: true, cgstAmount: true, sgstAmount: true },
    });
    expect(cn!.documentType).toBe('CREDIT_NOTE');
    expect(cn!.originalInvoiceId).toBe(checkout.invoiceId);
    expect(Number(cn!.total)).toBe(118);
    expect(Number(cn!.cgstAmount)).toBe(9);
    expect(Number(cn!.sgstAmount)).toBe(9);
    const stockAfterReturn = await prisma.product.findUnique({ where: { id: product.id }, select: { stockQuantity: true } });
    expect(Number(stockAfterReturn!.stockQuantity)).toBe(9);

    const after = await returns.getReturnable(ctx.shopId, checkout.invoiceId);
    if ('error' in after) throw new Error(after.error);
    expect(after.lines[0].returnedQty).toBe(1);
    expect(after.lines[0].returnableQty).toBe(1);
    const over = await returns.returnSale(ctx.shopId, ctx.userId, {
      originalInvoiceId: checkout.invoiceId,
      lines: [{ productId: product.id, quantity: 2 }],
      refundMode: 'CASH',
    });
    expect('error' in over).toBe(true);

    const x = asReport(await cashier.xReport(ctx.shopId, ctx.userId));
    expect(x.returns.count).toBe(1);
    expect(x.returns.amount).toBe(118);
    expect(x.cash.refunds).toBe(118);
    expect(x.cash.expected).toBe(118);
  });
});
