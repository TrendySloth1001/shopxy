import prisma from '../../infra/db/prisma.js';
import { reportsService } from '../reports/reports.service.js';
import { reportDayRange } from '../../shared/time/ist.js';

export async function recomputeDay(shopId: number, day: Date): Promise<void> {
  const range = reportDayRange(day);

  const [sales, purchases, gst, pnl, productRows, paymentRows] = await Promise.all([
    reportsService.sales(shopId, range),
    reportsService.purchases(shopId, range),
    reportsService.gstSummary(shopId, range),
    reportsService.pnl(shopId, range),
    prisma.$queryRaw<{ product_id: number; category_id: number | null; qty: string; revenue: string }[]>`
      SELECT ii.product_id, p.category_id,
             COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.quantity), 0)::text AS qty,
             COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.total), 0)::text AS revenue
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        LEFT JOIN products p ON p.id = ii.product_id
       WHERE i.shop_id = ${shopId} AND i.type = 'SALE' AND i.status = 'CONFIRMED'
         AND i.document_type NOT IN ('ESTIMATE', 'PROFORMA')
         AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
         AND ii.product_id IS NOT NULL
       GROUP BY ii.product_id, p.category_id`,
    prisma.$queryRaw<{ type: string; mode: string; amount: string; cnt: bigint }[]>`
      SELECT type, mode, COALESCE(SUM(amount), 0)::text AS amount, COUNT(*)::bigint AS cnt
        FROM payments
       WHERE shop_id = ${shopId} AND voided_at IS NULL
         AND payment_date >= ${range.from} AND payment_date < ${range.to}
       GROUP BY type, mode`,
  ]);

  type GstRow = { taxRate: number; outputTax: number; inputTax: number; outputCess: number; inputCess: number; taxable: number };
  const byRate = new Map<number, GstRow>();
  const ensure = (rate: number): GstRow => {
    let r = byRate.get(rate);
    if (!r) {
      r = { taxRate: rate, outputTax: 0, inputTax: 0, outputCess: 0, inputCess: 0, taxable: 0 };
      byRate.set(rate, r);
    }
    return r;
  };
  for (const o of gst.outputByRate) {
    const r = ensure(o.rate);
    r.outputTax = o.tax;
    r.outputCess = o.cess;
    r.taxable = o.taxable;
  }
  for (const i of gst.inputByRate) {
    const r = ensure(i.rate);
    r.inputTax = i.tax;
    r.inputCess = i.cess;
  }

  const s = sales.summary;
  const p = purchases.summary;
  const salesNonZero =
    s.invoiceCount > 0 ||
    s.total !== 0 ||
    s.refunds !== 0 ||
    pnl.cogs !== 0 ||
    pnl.returnedCogs !== 0 ||
    pnl.writeoffs !== 0;
  const purchasesNonZero = p.invoiceCount > 0 || p.total !== 0;

  await prisma.$transaction(async (tx) => {
    await Promise.all([
      tx.aggDailySales.deleteMany({ where: { shopId, day } }),
      tx.aggDailyPurchases.deleteMany({ where: { shopId, day } }),
      tx.aggDailyGst.deleteMany({ where: { shopId, day } }),
      tx.aggDailyProduct.deleteMany({ where: { shopId, day } }),
      tx.aggDailyPayment.deleteMany({ where: { shopId, day } }),
    ]);

    if (salesNonZero) {
      await tx.aggDailySales.create({
        data: {
          shopId,
          day,
          docCount: s.invoiceCount,
          taxable: s.taxableValue,
          tax: s.taxAmount,
          total: s.total,
          refunds: s.refunds,
          cogs: pnl.cogs,
          returnedCogs: pnl.returnedCogs,
          writeoffs: pnl.writeoffs,
        },
      });
    }
    if (purchasesNonZero) {
      await tx.aggDailyPurchases.create({
        data: { shopId, day, docCount: p.invoiceCount, taxable: p.taxableValue, tax: p.taxAmount, total: p.total },
      });
    }
    if (byRate.size > 0) {
      await tx.aggDailyGst.createMany({
        data: [...byRate.values()].map((r) => ({ shopId, day, ...r })),
      });
    }
    if (productRows.length > 0) {
      await tx.aggDailyProduct.createMany({
        data: productRows.map((r) => ({
          shopId,
          day,
          productId: r.product_id,
          categoryId: r.category_id,
          qty: Number(r.qty),
          revenue: Number(r.revenue),
        })),
      });
    }
    if (paymentRows.length > 0) {
      await tx.aggDailyPayment.createMany({
        data: paymentRows.map((r) => ({
          shopId,
          day,
          type: r.type,
          mode: r.mode,
          amount: Number(r.amount),
          cnt: Number(r.cnt),
        })),
      });
    }
  });
}
