import prisma from '../../infra/db/prisma.js';
import type { Prisma } from '@prisma/client';

// Bucket "day" by IST ('Asia/Kolkata') so a sale at 11:30pm local doesn't
// land on the next UTC day.
//
// SHOP SCOPING: every query here is scoped to a single `shopId`. The
// reports used to aggregate across ALL shops (no shop_id filter), which
// leaked other tenants' revenue, GST and customer PII into one merchant's
// dashboard. The shopId is threaded from resolveShop via the controller.

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
  async sales(shopId: number, range: DateRange) {
    const where: Prisma.InvoiceWhereInput = {
      shopId,
      type: 'SALE',
      status: 'CONFIRMED',
      invoiceDate: { gte: range.from, lt: range.to },
    };

    const [summary, daily, topProducts, topCustomers, refundRow] = await Promise.all([
      // Aggregate totals. `subtotal` is now gross-of-discount and
      // `taxableValue` is the net taxable (after every discount) — the
      // latter is the real turnover figure.
      prisma.invoice.aggregate({
        where,
        _sum: { subtotal: true, taxableValue: true, taxAmount: true, total: true },
        _count: { _all: true },
      }),
      // Daily series — single GROUP BY ... ORDER BY day
      prisma.$queryRaw<
        { day: Date; invoices: bigint; revenue: string; tax: string }[]
      >`
        SELECT
          date_trunc('day', invoice_date AT TIME ZONE 'Asia/Kolkata') AS day,
          COUNT(*)::bigint                AS invoices,
          COALESCE(SUM(total), 0)::text   AS revenue,
          COALESCE(SUM(tax_amount), 0)::text AS tax
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'SALE' AND status = 'CONFIRMED'
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
        WHERE i.shop_id = ${shopId} AND i.type = 'SALE' AND i.status = 'CONFIRMED'
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
        WHERE shop_id = ${shopId} AND type = 'SALE' AND status = 'CONFIRMED'
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
        GROUP BY party_id, customer_name, vendor_name
        ORDER BY revenue DESC
        LIMIT 10
      `,
      // Returns/refunds netted against the period the original sale was
      // booked in (by the source invoice's date), so a returned sale no
      // longer inflates the headline revenue (C2). NOTE: the GST credit
      // note (Sec 34 output-tax reversal) and COGS restock are tracked as
      // follow-ups — this nets the cash/revenue figure only.
      prisma.$queryRaw<{ refunds: string; count: bigint }[]>`
        SELECT
          COALESCE(SUM(rr.refund_amount), 0)::text AS refunds,
          COUNT(*)::bigint                         AS count
        FROM return_requests rr
        JOIN purchase_requests pr ON pr.id = rr.request_id
        JOIN invoices i ON i.id = pr.invoice_id
        WHERE rr.shop_id = ${shopId} AND rr.status = 'REFUNDED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
      `,
    ]);

    const grossRevenue = n(summary._sum.total?.toString());
    const refunds = n(refundRow[0]?.refunds ?? 0);

    return {
      range,
      summary: {
        invoiceCount: summary._count._all,
        /// Gross of all discounts — sum of (qty × unitPrice).
        subtotal: n(summary._sum.subtotal?.toString()),
        /// Net taxable turnover after every discount (the real "sales" base).
        taxableValue: n(summary._sum.taxableValue?.toString()),
        taxAmount: n(summary._sum.taxAmount?.toString()),
        /// Gross collected (taxable + tax + round-off).
        total: grossRevenue,
        /// Refunds for sales booked in this period (gross, incl. tax).
        refunds,
        /// Headline revenue after returns.
        netRevenue: Math.round((grossRevenue - refunds) * 100) / 100,
        refundCount: Number(refundRow[0]?.count ?? 0),
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
  async purchases(shopId: number, range: DateRange) {
    const where: Prisma.InvoiceWhereInput = {
      shopId,
      type: 'PURCHASE',
      status: 'CONFIRMED',
      invoiceDate: { gte: range.from, lt: range.to },
    };

    const [summary, daily, topProducts, topVendors] = await Promise.all([
      prisma.invoice.aggregate({
        where,
        _sum: { subtotal: true, taxableValue: true, taxAmount: true, total: true },
        _count: { _all: true },
      }),
      prisma.$queryRaw<
        { day: Date; invoices: bigint; spend: string; tax: string }[]
      >`
        SELECT
          date_trunc('day', invoice_date AT TIME ZONE 'Asia/Kolkata') AS day,
          COUNT(*)::bigint                AS invoices,
          COALESCE(SUM(total), 0)::text   AS spend,
          COALESCE(SUM(tax_amount), 0)::text AS tax
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'PURCHASE' AND status = 'CONFIRMED'
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
        WHERE i.shop_id = ${shopId} AND i.type = 'PURCHASE' AND i.status = 'CONFIRMED'
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
        WHERE shop_id = ${shopId} AND type = 'PURCHASE' AND status = 'CONFIRMED'
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
        taxableValue: n(summary._sum.taxableValue?.toString()),
        taxAmount: n(summary._sum.taxAmount?.toString()),
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
  // GST summary — output (sale) tax vs input (purchase) tax, bucketed
  // per tax rate. Uses the STORED per-line GST columns (igst/cgst/sgst/
  // cess) rather than recomputing qty*price*rate — the stored columns
  // already reflect the GST registration gate (zero on a Bill of Supply)
  // and the discount apportionment, so recomputing would disagree.
  // Cess is reported separately because it is not creditable against
  // CGST/SGST/IGST — only against cess.
  // ─────────────────────────────────────────────────────────────────
  async gstSummary(shopId: number, range: DateRange) {
    const byRate = (type: 'SALE' | 'PURCHASE') => prisma.$queryRaw<
      { tax_rate: string; taxable: string; tax: string; cess: string }[]
    >`
        SELECT
          ii.tax_percent::text                                       AS tax_rate,
          COALESCE(SUM(ii.taxable_value), 0)::text                   AS taxable,
          COALESCE(SUM(ii.igst_amount + ii.cgst_amount + ii.sgst_amount), 0)::text AS tax,
          COALESCE(SUM(ii.cess_amount), 0)::text                     AS cess
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.shop_id = ${shopId} AND i.type = ${type} AND i.status = 'CONFIRMED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
        GROUP BY ii.tax_percent
        ORDER BY ii.tax_percent ASC
      `;

    const [output, input, totalsRow] = await Promise.all([
      byRate('SALE'),
      byRate('PURCHASE'),
      prisma.$queryRaw<
        {
          output_gst: string;
          input_gst: string;
          output_cess: string;
          input_cess: string;
        }[]
      >`
        SELECT
          COALESCE(SUM(CASE WHEN type='SALE'     THEN igst_amount + cgst_amount + sgst_amount ELSE 0 END), 0)::text AS output_gst,
          COALESCE(SUM(CASE WHEN type='PURCHASE' THEN igst_amount + cgst_amount + sgst_amount ELSE 0 END), 0)::text AS input_gst,
          COALESCE(SUM(CASE WHEN type='SALE'     THEN cess_amount ELSE 0 END), 0)::text AS output_cess,
          COALESCE(SUM(CASE WHEN type='PURCHASE' THEN cess_amount ELSE 0 END), 0)::text AS input_cess
        FROM invoices
        WHERE shop_id = ${shopId} AND status = 'CONFIRMED'
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
      `,
    ]);

    const outputGst = n(totalsRow[0]?.output_gst ?? 0);
    const inputGst = n(totalsRow[0]?.input_gst ?? 0);
    const outputCess = n(totalsRow[0]?.output_cess ?? 0);
    const inputCess = n(totalsRow[0]?.input_cess ?? 0);
    const r2 = (v: number) => Math.round(v * 100) / 100;

    return {
      range,
      outputTax: outputGst,
      inputTax: inputGst,
      // ITC offsets like-for-like: GST against GST, cess only against cess.
      // Input tax is shown as fully creditable here; blocked credits
      // (Sec 17(5)) and RCM are not yet modelled — a documented gap.
      netPayable: r2(outputGst - inputGst),
      outputCess,
      inputCess,
      netCessPayable: r2(outputCess - inputCess),
      outputByRate: output.map((r) => ({
        rate: n(r.tax_rate),
        taxable: n(r.taxable),
        tax: n(r.tax),
        cess: n(r.cess),
      })),
      inputByRate: input.map((r) => ({
        rate: n(r.tax_rate),
        taxable: n(r.taxable),
        tax: n(r.tax),
        cess: n(r.cess),
      })),
    };
  }

  // ─────────────────────────────────────────────────────────────────
  // P&L — revenue (net taxable from confirmed sales) minus COGS minus
  // operating write-offs. Revenue uses taxable_value (net of every
  // discount); the old `subtotal - discount` broke once the engine moved
  // to gross subtotal + distributed line discounts.
  // ─────────────────────────────────────────────────────────────────
  async pnl(shopId: number, range: DateRange) {
    const [revenueRow, cogsRow, expenseRow, refundRow] = await Promise.all([
      prisma.$queryRaw<{ revenue: string }[]>`
        SELECT COALESCE(SUM(taxable_value), 0)::text AS revenue
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'SALE' AND status = 'CONFIRMED'
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
      `,
      // COGS: consumptions are recorded against the SALE ledger row at
      // confirm time. Join consumption -> ledger -> source invoice, filter
      // to this shop's confirmed sales in range.
      prisma.$queryRaw<{ cogs: string }[]>`
        SELECT COALESCE(SUM(cc.qty_consumed * cc.unit_cost), 0)::text AS cogs
        FROM cost_consumptions cc
        JOIN stock_transactions st ON st.id = cc.ledger_entry_id
        JOIN invoices i
          ON st.source_type = 'INVOICE' AND st.source_id = i.id
        WHERE i.shop_id = ${shopId} AND i.type = 'SALE' AND i.status = 'CONFIRMED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
      `,
      // Adjustment write-offs (damage, expiry, shrinkage) are an
      // operating expense in this lightweight P&L. Scoped to this shop.
      prisma.$queryRaw<{ writeoffs: string }[]>`
        SELECT COALESCE(SUM(sai.quantity * sai.unit_cost), 0)::text AS writeoffs
        FROM stock_adjustment_items sai
        JOIN stock_adjustments sa ON sa.id = sai.adjustment_id
        WHERE sa.shop_id = ${shopId} AND sa.direction = 'OUT'
          AND sa.created_at >= ${range.from} AND sa.created_at < ${range.to}
      `,
      // Returns reduce net revenue. Approximated by the gross refund's
      // ex-tax portion is non-trivial without a credit note, so we net the
      // gross refund and flag it — credit-note-driven exactness is a
      // follow-up.
      prisma.$queryRaw<{ refunds: string }[]>`
        SELECT COALESCE(SUM(rr.refund_amount), 0)::text AS refunds
        FROM return_requests rr
        JOIN purchase_requests pr ON pr.id = rr.request_id
        JOIN invoices i ON i.id = pr.invoice_id
        WHERE rr.shop_id = ${shopId} AND rr.status = 'REFUNDED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
      `,
    ]);

    const grossRevenue = n(revenueRow[0]?.revenue ?? 0);
    const refunds = n(refundRow[0]?.refunds ?? 0);
    const revenue = Math.round((grossRevenue - refunds) * 100) / 100;
    const cogs = n(cogsRow[0]?.cogs ?? 0);
    const writeoffs = n(expenseRow[0]?.writeoffs ?? 0);
    const grossProfit = revenue - cogs;
    const netProfit = grossProfit - writeoffs;
    const grossMargin = revenue > 0 ? grossProfit / revenue : 0;

    return {
      range,
      revenue,
      refunds,
      cogs,
      writeoffs,
      grossProfit,
      netProfit,
      grossMargin,
    };
  }
}

export const reportsService = new ReportsService();
