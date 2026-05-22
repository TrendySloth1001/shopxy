import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';

/// All numeric aggregates come back from Postgres as strings (because
/// numeric / decimal types can't safely round-trip through JS doubles).
/// Cast to Number once at the edge.
function n(v: string | number | null | undefined): number {
  if (v === null || v === undefined) return 0;
  return typeof v === 'string' ? Number(v) : v;
}

export interface DateRange {
  /// Lower bound (inclusive). UTC.
  from: Date;
  /// Upper bound (exclusive). UTC. Pass a value 1 ms after the day end
  /// to include the entire end-day.
  to: Date;
}

export class ReportsService {
  // ─────────────────────────────────────────────────────────────────
  // Sales report — single aggregate query + per-day series + top
  // products, each one round-trip. No N+1.
  // ─────────────────────────────────────────────────────────────────
  async sales(range: DateRange) {
    const where: Prisma.InvoiceWhereInput = {
      type: 'SALE',
      status: 'CONFIRMED',
      invoiceDate: { gte: range.from, lt: range.to },
    };

    const [summary, daily, topProducts, topCustomers] = await Promise.all([
      // Aggregate totals
      prisma.invoice.aggregate({
        where,
        _sum: { subtotal: true, taxAmount: true, discount: true, total: true },
        _count: { _all: true },
      }),
      // Daily series — single GROUP BY ... ORDER BY day
      prisma.$queryRaw<
        { day: Date; invoices: bigint; revenue: string; tax: string }[]
      >`
        SELECT
          date_trunc('day', invoice_date) AS day,
          COUNT(*)::bigint                AS invoices,
          COALESCE(SUM(total), 0)::text   AS revenue,
          COALESCE(SUM(tax_amount), 0)::text AS tax
        FROM invoices
        WHERE type = 'SALE' AND status = 'CONFIRMED'
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
        GROUP BY day
        ORDER BY day ASC
      `,
      // Top 10 products by quantity + revenue (single query w/ join +
      // group-by, no per-product round-trip).
      prisma.$queryRaw<
        {
          product_id: number;
          product_name: string;
          product_sku: string;
          qty: string;
          revenue: string;
        }[]
      >`
        SELECT
          ii.product_id,
          ii.product_name,
          ii.product_sku,
          COALESCE(SUM(ii.quantity), 0)::text AS qty,
          COALESCE(SUM(ii.total), 0)::text    AS revenue
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.type = 'SALE' AND i.status = 'CONFIRMED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
        GROUP BY ii.product_id, ii.product_name, ii.product_sku
        ORDER BY revenue DESC
        LIMIT 10
      `,
      prisma.$queryRaw<
        {
          party_id: number | null;
          customer_name: string | null;
          revenue: string;
          invoices: bigint;
        }[]
      >`
        SELECT
          party_id,
          COALESCE(customer_name, vendor_name, '(unnamed)') AS customer_name,
          COALESCE(SUM(total), 0)::text AS revenue,
          COUNT(*)::bigint              AS invoices
        FROM invoices
        WHERE type = 'SALE' AND status = 'CONFIRMED'
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
        GROUP BY party_id, customer_name, vendor_name
        ORDER BY revenue DESC
        LIMIT 10
      `,
    ]);

    return {
      range,
      summary: {
        invoiceCount: summary._count._all,
        subtotal: n(summary._sum.subtotal?.toString()),
        taxAmount: n(summary._sum.taxAmount?.toString()),
        discount: n(summary._sum.discount?.toString()),
        total: n(summary._sum.total?.toString()),
      },
      daily: daily.map((d) => ({
        day: d.day.toISOString(),
        invoices: Number(d.invoices),
        revenue: n(d.revenue),
        tax: n(d.tax),
      })),
      topProducts: topProducts.map((p) => ({
        productId: p.product_id,
        productName: p.product_name,
        productSku: p.product_sku,
        quantity: n(p.qty),
        revenue: n(p.revenue),
      })),
      topCustomers: topCustomers.map((c) => ({
        partyId: c.party_id,
        name: c.customer_name ?? '(unnamed)',
        revenue: n(c.revenue),
        invoices: Number(c.invoices),
      })),
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // Purchase report — same shape as sales but vendor-side.
  // ─────────────────────────────────────────────────────────────────
  async purchases(range: DateRange) {
    const where: Prisma.InvoiceWhereInput = {
      type: 'PURCHASE',
      status: 'CONFIRMED',
      invoiceDate: { gte: range.from, lt: range.to },
    };

    const [summary, daily, topProducts, topVendors] = await Promise.all([
      prisma.invoice.aggregate({
        where,
        _sum: { subtotal: true, taxAmount: true, discount: true, total: true },
        _count: { _all: true },
      }),
      prisma.$queryRaw<
        { day: Date; invoices: bigint; spend: string; tax: string }[]
      >`
        SELECT
          date_trunc('day', invoice_date) AS day,
          COUNT(*)::bigint                AS invoices,
          COALESCE(SUM(total), 0)::text   AS spend,
          COALESCE(SUM(tax_amount), 0)::text AS tax
        FROM invoices
        WHERE type = 'PURCHASE' AND status = 'CONFIRMED'
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
        GROUP BY day
        ORDER BY day ASC
      `,
      prisma.$queryRaw<
        {
          product_id: number;
          product_name: string;
          product_sku: string;
          qty: string;
          spend: string;
        }[]
      >`
        SELECT
          ii.product_id,
          ii.product_name,
          ii.product_sku,
          COALESCE(SUM(ii.quantity), 0)::text AS qty,
          COALESCE(SUM(ii.total), 0)::text    AS spend
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.type = 'PURCHASE' AND i.status = 'CONFIRMED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
        GROUP BY ii.product_id, ii.product_name, ii.product_sku
        ORDER BY spend DESC
        LIMIT 10
      `,
      prisma.$queryRaw<
        {
          vendor_id: number | null;
          vendor_name: string | null;
          spend: string;
          invoices: bigint;
        }[]
      >`
        SELECT
          vendor_id,
          COALESCE(vendor_name, '(unnamed)') AS vendor_name,
          COALESCE(SUM(total), 0)::text AS spend,
          COUNT(*)::bigint              AS invoices
        FROM invoices
        WHERE type = 'PURCHASE' AND status = 'CONFIRMED'
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
        GROUP BY vendor_id, vendor_name
        ORDER BY spend DESC
        LIMIT 10
      `,
    ]);

    return {
      range,
      summary: {
        invoiceCount: summary._count._all,
        subtotal: n(summary._sum.subtotal?.toString()),
        taxAmount: n(summary._sum.taxAmount?.toString()),
        discount: n(summary._sum.discount?.toString()),
        total: n(summary._sum.total?.toString()),
      },
      daily: daily.map((d) => ({
        day: d.day.toISOString(),
        invoices: Number(d.invoices),
        spend: n(d.spend),
        tax: n(d.tax),
      })),
      topProducts: topProducts.map((p) => ({
        productId: p.product_id,
        productName: p.product_name,
        productSku: p.product_sku,
        quantity: n(p.qty),
        spend: n(p.spend),
      })),
      topVendors: topVendors.map((v) => ({
        vendorId: v.vendor_id,
        name: v.vendor_name ?? '(unnamed)',
        spend: n(v.spend),
        invoices: Number(v.invoices),
      })),
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // GST summary — output (sale) tax vs input (purchase) tax,
  // bucketed per tax rate. Two GROUP BYs by tax_percent in raw SQL.
  // ─────────────────────────────────────────────────────────────────
  async gstSummary(range: DateRange) {
    const [output, input, totalsRow] = await Promise.all([
      prisma.$queryRaw<
        { tax_rate: string; taxable: string; tax: string }[]
      >`
        SELECT
          ii.tax_percent::text                                   AS tax_rate,
          COALESCE(SUM(ii.quantity * ii.unit_price - ii.discount), 0)::text AS taxable,
          COALESCE(SUM(
            (ii.quantity * ii.unit_price - ii.discount) * ii.tax_percent / 100
          ), 0)::text                                            AS tax
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.type = 'SALE' AND i.status = 'CONFIRMED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
        GROUP BY ii.tax_percent
        ORDER BY ii.tax_percent ASC
      `,
      prisma.$queryRaw<
        { tax_rate: string; taxable: string; tax: string }[]
      >`
        SELECT
          ii.tax_percent::text                                   AS tax_rate,
          COALESCE(SUM(ii.quantity * ii.unit_price - ii.discount), 0)::text AS taxable,
          COALESCE(SUM(
            (ii.quantity * ii.unit_price - ii.discount) * ii.tax_percent / 100
          ), 0)::text                                            AS tax
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.type = 'PURCHASE' AND i.status = 'CONFIRMED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
        GROUP BY ii.tax_percent
        ORDER BY ii.tax_percent ASC
      `,
      prisma.$queryRaw<
        { output_tax: string; input_tax: string }[]
      >`
        SELECT
          COALESCE(SUM(CASE WHEN type='SALE' THEN tax_amount ELSE 0 END), 0)::text AS output_tax,
          COALESCE(SUM(CASE WHEN type='PURCHASE' THEN tax_amount ELSE 0 END), 0)::text AS input_tax
        FROM invoices
        WHERE status = 'CONFIRMED'
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
      `,
    ]);

    const outputTax = n(totalsRow[0]?.output_tax ?? 0);
    const inputTax = n(totalsRow[0]?.input_tax ?? 0);

    return {
      range,
      outputTax,
      inputTax,
      netPayable: outputTax - inputTax,
      outputByRate: output.map((r) => ({
        rate: n(r.tax_rate),
        taxable: n(r.taxable),
        tax: n(r.tax),
      })),
      inputByRate: input.map((r) => ({
        rate: n(r.tax_rate),
        taxable: n(r.taxable),
        tax: n(r.tax),
      })),
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // P&L — revenue (from confirmed sales) minus COGS (from cost
  // consumptions tied to those sales). Single raw query each.
  // ─────────────────────────────────────────────────────────────────
  async pnl(range: DateRange) {
    const [revenueRow, cogsRow, expenseRow] = await Promise.all([
      prisma.$queryRaw<{ revenue: string; discount: string }[]>`
        SELECT
          COALESCE(SUM(subtotal - discount), 0)::text AS revenue,
          COALESCE(SUM(discount), 0)::text             AS discount
        FROM invoices
        WHERE type = 'SALE' AND status = 'CONFIRMED'
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
      `,
      // COGS: consumptions are recorded against the SALE ledger row at
      // confirm time. Join consumption -> ledger -> source invoice, filter
      // to confirmed sales in range.
      prisma.$queryRaw<{ cogs: string }[]>`
        SELECT COALESCE(SUM(cc.qty_consumed * cc.unit_cost), 0)::text AS cogs
        FROM cost_consumptions cc
        JOIN stock_transactions st ON st.id = cc.ledger_entry_id
        JOIN invoices i
          ON st.source_type = 'INVOICE' AND st.source_id = i.id
        WHERE i.type = 'SALE' AND i.status = 'CONFIRMED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
      `,
      // Adjustment write-offs (damage, expiry, shrinkage) are an
      // operating expense in this lightweight P&L.
      prisma.$queryRaw<{ writeoffs: string }[]>`
        SELECT COALESCE(SUM(sai.quantity * sai.unit_cost), 0)::text AS writeoffs
        FROM stock_adjustment_items sai
        JOIN stock_adjustments sa ON sa.id = sai.adjustment_id
        WHERE sa.direction = 'OUT'
          AND sa.created_at >= ${range.from} AND sa.created_at < ${range.to}
      `,
    ]);

    const revenue = n(revenueRow[0]?.revenue ?? 0);
    const cogs = n(cogsRow[0]?.cogs ?? 0);
    const writeoffs = n(expenseRow[0]?.writeoffs ?? 0);
    const grossProfit = revenue - cogs;
    const netProfit = grossProfit - writeoffs;
    const grossMargin = revenue > 0 ? grossProfit / revenue : 0;

    return {
      range,
      revenue,
      cogs,
      writeoffs,
      grossProfit,
      netProfit,
      grossMargin,
    };
  }
}

export const reportsService = new ReportsService();
