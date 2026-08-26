import { describe, it, expect, afterAll } from 'vitest';
import prisma from '../../src/infra/db/prisma.js';
import * as pos from '../../src/modules/pos/pos.service.js';
import { createTestUser, cleanupTestUser, createTestProduct } from '../helpers/setup.js';

async function registerShop(userId: number) {
  await prisma.user.update({
    where: { id: userId },
    data: { shopGstin: '27ABCDE1234F1Z5', shopStateCode: '27', registrationType: 'REGULAR' },
  });
}

function snap(r: unknown) {
  if (r && typeof r === 'object' && 'error' in (r as Record<string, unknown>)) {
    throw new Error(`expected snapshot, got error: ${(r as { error: string }).error}`);
  }
  return r as Awaited<ReturnType<typeof pos.snapshot>> & { totals: { total: number } };
}

describe('pos.service — money path', () => {
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('open → add → totals (CGST+SGST) → checkout → invoice+payment+stock; idempotent', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId);
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 100, stockQuantity: 10 });
      await prisma.product.update({ where: { id: product.id }, data: { taxPercent: 18 } });

      const opened = snap(await pos.openSale(ctx.shopId, ctx.userId));
      const saleId = opened.sale.id;
      expect(opened.totals.total).toBe(0);

      await pos.addScan(ctx.shopId, saleId, product.sku, ctx.userId);
      const after = snap(await pos.addScan(ctx.shopId, saleId, product.sku, ctx.userId));
      expect(after.lines).toHaveLength(1);
      expect(after.lines[0].quantity).toBe(2);
      expect(after.totals.taxableValue).toBe(200);
      expect(after.totals.cgst).toBe(18);
      expect(after.totals.sgst).toBe(18);
      expect(after.totals.igst).toBe(0);
      expect(after.totals.total).toBe(236);

      const result = await pos.checkout(
        ctx.shopId,
        saleId,
        { tender: { mode: 'CASH' } },
        ctx.userId,
      );
      expect('error' in result).toBe(false);
      if ('error' in result) return;
      expect(result.invoiceNo).toBeTruthy();
      expect(Number(result.total)).toBe(236);
      expect(result.mode).toBe('CASH');
      expect(result.replayed).toBe(false);

      const inv = await prisma.invoice.findUnique({ where: { id: result.invoiceId }, select: { status: true, type: true, total: true } });
      expect(inv!.status).toBe('CONFIRMED');
      expect(inv!.type).toBe('SALE');
      expect(Number(inv!.total)).toBe(236);
      const pay = await prisma.payment.findFirst({ where: { invoiceId: result.invoiceId, type: 'RECEIPT' }, select: { amount: true, mode: true } });
      expect(pay!.mode).toBe('CASH');
      expect(Number(pay!.amount)).toBe(236);

      const stocked = await prisma.product.findUnique({ where: { id: product.id }, select: { stockQuantity: true } });
      expect(Number(stocked!.stockQuantity)).toBe(8);

      const sale = await prisma.sale.findUnique({ where: { id: saleId }, select: { status: true, invoiceId: true } });
      expect(sale!.status).toBe('CHECKED_OUT');
      expect(sale!.invoiceId).toBe(result.invoiceId);

      const replay = await pos.checkout(ctx.shopId, saleId, { tender: { mode: 'CASH' } }, ctx.userId);
      expect('error' in replay).toBe(false);
      if ('error' in replay) return;
      expect(replay.invoiceId).toBe(result.invoiceId);
      expect(replay.replayed).toBe(true);
      const stockedAgain = await prisma.product.findUnique({ where: { id: product.id }, select: { stockQuantity: true } });
      expect(Number(stockedAgain!.stockQuantity)).toBe(8);
      const paymentCount = await prisma.payment.count({ where: { invoiceId: result.invoiceId } });
      expect(paymentCount).toBe(1);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('checkout rejects oversell and leaves the sale OPEN with no invoice', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId);
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 50, stockQuantity: 3 });

      const opened = snap(await pos.openSale(ctx.shopId, ctx.userId));
      await pos.addProduct(ctx.shopId, opened.sale.id, product.id, 5, ctx.userId);

      const result = await pos.checkout(ctx.shopId, opened.sale.id, { tender: { mode: 'CASH' } }, ctx.userId);
      expect('error' in result).toBe(true);
      if (!('error' in result)) return;
      expect(result.error).toMatch(/stock/i);

      const stocked = await prisma.product.findUnique({ where: { id: product.id }, select: { stockQuantity: true } });
      expect(Number(stocked!.stockQuantity)).toBe(3);
      const sale = await prisma.sale.findUnique({ where: { id: opened.sale.id }, select: { status: true, invoiceId: true } });
      expect(sale!.status).toBe('OPEN');
      expect(sale!.invoiceId).toBeNull();
      const invoiceCount = await prisma.invoice.count({ where: { shopId: ctx.shopId } });
      expect(invoiceCount).toBe(0);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('quick-add creates a sellable product (opening stock) and adds it to the cart', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId);
      const opened = snap(await pos.openSale(ctx.shopId, ctx.userId));
      const saleId = opened.sale.id;

      const code = `QA-${Date.now()}`;
      const added = snap(
        await pos.quickAddProduct(
          ctx.shopId,
          saleId,
          { code, name: 'Loose item', sellingPrice: 50, taxPercent: 0, openingStock: 3 },
          ctx.userId,
        ),
      );
      expect(added.lines).toHaveLength(1);
      expect(added.lines[0].sku).toBe(code);

      const result = await pos.checkout(ctx.shopId, saleId, { tender: { mode: 'CASH' } }, ctx.userId);
      expect('error' in result).toBe(false);
      const product = await prisma.product.findFirst({ where: { shopId: ctx.shopId, sku: code }, select: { stockQuantity: true } });
      expect(Number(product!.stockQuantity)).toBe(2);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('op-id dedupe: replaying the same scan does not double-count', async () => {
    const ctx = await createTestUser();
    try {
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 20, stockQuantity: 10 });
      const opened = snap(await pos.openSale(ctx.shopId, ctx.userId));
      const saleId = opened.sale.id;

      await pos.addScan(ctx.shopId, saleId, product.sku, ctx.userId, 'op-abc');
      const after = snap(await pos.addScan(ctx.shopId, saleId, product.sku, ctx.userId, 'op-abc'));
      expect(after.lines).toHaveLength(1);
      expect(after.lines[0].quantity).toBe(1);

      const again = snap(await pos.addScan(ctx.shopId, saleId, product.sku, ctx.userId, 'op-def'));
      expect(again.lines[0].quantity).toBe(2);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('openSale reuses the caller\'s empty OPEN sale instead of leaking a new one (H4)', async () => {
    const ctx = await createTestUser();
    try {
      const a = snap(await pos.openSale(ctx.shopId, ctx.userId));
      const b = snap(await pos.openSale(ctx.shopId, ctx.userId));
      expect(b.sale.id).toBe(a.sale.id);

      const product = await createTestProduct(ctx.shopId, { sellingPrice: 10, stockQuantity: 5 });
      await pos.addScan(ctx.shopId, a.sale.id, product.sku, ctx.userId);
      const c = snap(await pos.openSale(ctx.shopId, ctx.userId));
      expect(c.sale.id).not.toBe(a.sale.id);

      const open = await pos.listOpenSales(ctx.shopId);
      expect(open.map((s) => s.id)).toContain(a.sale.id);
      expect(open.every((s) => s.lineCount > 0)).toBe(true);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('voidSale only voids an OPEN sale (no TOCTOU with checkout)', async () => {
    const ctx = await createTestUser();
    try {
      await registerShop(ctx.userId);
      const product = await createTestProduct(ctx.shopId, { sellingPrice: 30, stockQuantity: 5 });
      const opened = snap(await pos.openSale(ctx.shopId, ctx.userId));
      await pos.addScan(ctx.shopId, opened.sale.id, product.sku, ctx.userId);
      await pos.checkout(ctx.shopId, opened.sale.id, { tender: { mode: 'CASH' } }, ctx.userId);

      const voided = await pos.voidSale(ctx.shopId, opened.sale.id);
      expect('error' in voided).toBe(true);
    } finally {
      await cleanupTestUser(ctx);
    }
  });

  it('unknown scan returns { unknown } so the till can offer Quick add', async () => {
    const ctx = await createTestUser();
    try {
      const opened = snap(await pos.openSale(ctx.shopId, ctx.userId));
      const result = await pos.addScan(ctx.shopId, opened.sale.id, 'NO-SUCH-CODE-xyz', ctx.userId);
      expect(result).toMatchObject({ unknown: true, code: 'NO-SUCH-CODE-xyz' });
    } finally {
      await cleanupTestUser(ctx);
    }
  });
});
