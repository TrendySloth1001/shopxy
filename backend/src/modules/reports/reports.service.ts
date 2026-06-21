import prisma from '../../infra/db/prisma.js';

// Bucket "day" by IST ('Asia/Kolkata') so a sale at 11:30pm local doesn't
// land on the next UTC day.
//
// SHOP SCOPING: every query here is scoped to a single `shopId`. The
// reports used to aggregate across ALL shops (no shop_id filter), which
// leaked other tenants' revenue, GST and customer PII into one merchant's
// dashboard. The shopId is threaded from resolveShop via the controller.
//
// DOCUMENT SEMANTICS: every aggregate excludes ESTIMATE / PROFORMA rows
// (offers, not transactions — a confirmed estimate must not count as
// revenue, and its converted TAX_INVOICE would double-count it), and
// counts CREDIT_NOTE rows with a NEGATIVE sign (Sec 34: a credit note
// reduces turnover and output tax; the party ledger already credits it —
// adding it to revenue as a positive was a live miscalculation).
// DEBIT_NOTE stays positive (a supplementary invoice increases both).

/// All numeric aggregates come back from Postgres as strings (because
/// numeric / decimal types can't safely round-trip through JS doubles).
/// Cast to Number once at the edge.
function n(v: string | number | null | undefined): number {
  if (v === null || v === undefined) return 0;
  return typeof v === 'string' ? Number(v) : v;
}

const r2 = (v: number) => Math.round(v * 100) / 100;

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
    const [summaryRow, daily, topProducts, topCustomers, refundRow] = await Promise.all([
      // Aggregate totals. `subtotal` is gross-of-discount and
      // `taxable_value` is the net taxable (after every discount) — the
      // latter is the real turnover figure. Credit notes subtract.
      prisma.$queryRaw<
        {
          invoices: bigint;
          credit_notes: bigint;
          subtotal: string;
          taxable_value: string;
          tax_amount: string;
          total: string;
        }[]
      >`
        SELECT
          COUNT(*) FILTER (WHERE document_type <> 'CREDIT_NOTE')::bigint AS invoices,
          COUNT(*) FILTER (WHERE document_type = 'CREDIT_NOTE')::bigint  AS credit_notes,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * subtotal), 0)::text       AS subtotal,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * taxable_value), 0)::text  AS taxable_value,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * tax_amount), 0)::text     AS tax_amount,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * total), 0)::text          AS total
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'SALE' AND status = 'CONFIRMED'
          AND document_type NOT IN ('ESTIMATE', 'PROFORMA')
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
      `,
      // Daily series — single GROUP BY ... ORDER BY day
      prisma.$queryRaw<
        { day: Date; invoices: bigint; revenue: string; tax: string }[]
      >`
        SELECT
          date_trunc('day', invoice_date AT TIME ZONE 'Asia/Kolkata') AS day,
          COUNT(*)::bigint                AS invoices,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * total), 0)::text      AS revenue,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * tax_amount), 0)::text AS tax
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'SALE' AND status = 'CONFIRMED'
          AND document_type NOT IN ('ESTIMATE', 'PROFORMA')
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
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.quantity), 0)::text AS qty,
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.total), 0)::text    AS revenue
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.shop_id = ${shopId} AND i.type = 'SALE' AND i.status = 'CONFIRMED'
          AND i.document_type NOT IN ('ESTIMATE', 'PROFORMA')
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
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * total), 0)::text AS revenue,
          COUNT(*)::bigint              AS invoices
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'SALE' AND status = 'CONFIRMED'
          AND document_type NOT IN ('ESTIMATE', 'PROFORMA')
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
        GROUP BY party_id, customer_name, vendor_name
        ORDER BY revenue DESC
        LIMIT 10
      `,
      // Returns/refunds netted against the period the original sale was
      // booked in (by the source invoice's date), so a returned sale no
      // longer inflates the headline revenue (C2). The GST leg of the
      // reversal is netted in gstSummary() from the refunded lines'
      // stored tax columns.
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

    const summary = summaryRow[0];
    const grossRevenue = n(summary?.total ?? 0);
    const refunds = n(refundRow[0]?.refunds ?? 0);

    return {
      range,
      summary: {
        invoiceCount: Number(summary?.invoices ?? 0),
        /// Confirmed sale credit notes in range (already netted out of
        /// every money figure above).
        creditNoteCount: Number(summary?.credit_notes ?? 0),
        /// Gross of all discounts — sum of (qty × unitPrice).
        subtotal: n(summary?.subtotal ?? 0),
        /// Net taxable turnover after every discount (the real "sales" base).
        taxableValue: n(summary?.taxable_value ?? 0),
        taxAmount: n(summary?.tax_amount ?? 0),
        /// Gross collected (taxable + tax + round-off), net of credit notes.
        total: grossRevenue,
        /// Refunds for sales booked in this period (gross, incl. tax).
        refunds,
        /// Headline revenue after returns.
        netRevenue: r2(grossRevenue - refunds),
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
  // Purchase report — same shape as sales but vendor-side. A purchase
  // CREDIT_NOTE (vendor reduced our bill) subtracts from spend/tax.
  // ─────────────────────────────────────────────────────────────────
  async purchases(shopId: number, range: DateRange) {
    const [summaryRow, daily, topProducts, topVendors] = await Promise.all([
      prisma.$queryRaw<
        {
          invoices: bigint;
          subtotal: string;
          taxable_value: string;
          tax_amount: string;
          total: string;
        }[]
      >`
        SELECT
          COUNT(*) FILTER (WHERE document_type <> 'CREDIT_NOTE')::bigint AS invoices,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * subtotal), 0)::text       AS subtotal,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * taxable_value), 0)::text  AS taxable_value,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * tax_amount), 0)::text     AS tax_amount,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * total), 0)::text          AS total
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'PURCHASE' AND status = 'CONFIRMED'
          AND document_type NOT IN ('ESTIMATE', 'PROFORMA')
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
      `,
      prisma.$queryRaw<
        { day: Date; invoices: bigint; spend: string; tax: string }[]
      >`
        SELECT
          date_trunc('day', invoice_date AT TIME ZONE 'Asia/Kolkata') AS day,
          COUNT(*)::bigint                AS invoices,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * total), 0)::text      AS spend,
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * tax_amount), 0)::text AS tax
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'PURCHASE' AND status = 'CONFIRMED'
          AND document_type NOT IN ('ESTIMATE', 'PROFORMA')
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
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.quantity), 0)::text AS qty,
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.total), 0)::text    AS spend
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.shop_id = ${shopId} AND i.type = 'PURCHASE' AND i.status = 'CONFIRMED'
          AND i.document_type NOT IN ('ESTIMATE', 'PROFORMA')
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
          COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * total), 0)::text AS spend,
          COUNT(*)::bigint              AS invoices
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'PURCHASE' AND status = 'CONFIRMED'
          AND document_type NOT IN ('ESTIMATE', 'PROFORMA')
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
        GROUP BY vendor_id, vendor_name
        ORDER BY spend DESC
        LIMIT 10
      `,
    ]);

    const summary = summaryRow[0];
    return {
      range,
      summary: {
        invoiceCount: Number(summary?.invoices ?? 0),
        subtotal: n(summary?.subtotal ?? 0),
        taxableValue: n(summary?.taxable_value ?? 0),
        taxAmount: n(summary?.tax_amount ?? 0),
        total: n(summary?.total ?? 0),
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
  //
  // Returns: a REFUNDED return reverses the output tax on the refunded
  // quantity (CGST Sec 34 — the credit-note adjustment). The reversal is
  // computed from the source invoice line's stored tax, pro-rated by the
  // returned quantity, and netted out of both the headline figures and
  // the matching by-rate bucket.
  // ─────────────────────────────────────────────────────────────────
  async gstSummary(shopId: number, range: DateRange) {
    const byRate = (type: 'SALE' | 'PURCHASE') => prisma.$queryRaw<
      { tax_rate: string; taxable: string; tax: string; cess: string }[]
    >`
        SELECT
          ii.tax_percent::text                                       AS tax_rate,
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.taxable_value), 0)::text AS taxable,
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * (ii.igst_amount + ii.cgst_amount + ii.sgst_amount)), 0)::text AS tax,
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.cess_amount), 0)::text   AS cess
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.shop_id = ${shopId} AND i.type = ${type} AND i.status = 'CONFIRMED'
          AND i.document_type NOT IN ('ESTIMATE', 'PROFORMA')
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
        GROUP BY ii.tax_percent
        ORDER BY ii.tax_percent ASC
      `;

    const [output, input, totalsRow, returnsByRate] = await Promise.all([
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
          COALESCE(SUM(CASE WHEN type='SALE'     THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * (igst_amount + cgst_amount + sgst_amount) ELSE 0 END), 0)::text AS output_gst,
          COALESCE(SUM(CASE WHEN type='PURCHASE' THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * (igst_amount + cgst_amount + sgst_amount) ELSE 0 END), 0)::text AS input_gst,
          COALESCE(SUM(CASE WHEN type='SALE'     THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * cess_amount ELSE 0 END), 0)::text AS output_cess,
          COALESCE(SUM(CASE WHEN type='PURCHASE' THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * cess_amount ELSE 0 END), 0)::text AS input_cess
        FROM invoices
        WHERE shop_id = ${shopId} AND status = 'CONFIRMED'
          AND document_type NOT IN ('ESTIMATE', 'PROFORMA')
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
      `,
      // Output-tax reversal for refunded returns, pro-rated from the
      // source invoice line by returned quantity and grouped by rate so
      // the headline and by-rate figures stay consistent.
      //
      // AUTH-TR-C1: resolve the reversed invoice line via a LATERAL that
      // returns EXACTLY ONE invoice_items row per return item, so a product
      // billed on several lines of the same invoice can't fan the reversal
      // out N×. Preference order inside the LATERAL:
      //   1. the exact billed line (rri.invoice_item_id) when set;
      //   2. legacy null rows fall back to the matching (invoice, product)
      //      line, deterministically pinned to the lowest ii.id so multiple
      //      same-product lines pick one — never multiply.
      // This keys off the same per-line resolution the P&L refund leg uses,
      // so the GST and sales/P&L reports reconcile on identical returns.
      prisma.$queryRaw<
        { tax_rate: string; taxable: string; tax: string; cess: string }[]
      >`
        SELECT
          line.tax_percent::text AS tax_rate,
          COALESCE(SUM(line.taxable_value * rri.quantity / NULLIF(line.quantity, 0)), 0)::text AS taxable,
          COALESCE(SUM((line.igst_amount + line.cgst_amount + line.sgst_amount) * rri.quantity / NULLIF(line.quantity, 0)), 0)::text AS tax,
          COALESCE(SUM(line.cess_amount * rri.quantity / NULLIF(line.quantity, 0)), 0)::text AS cess
        FROM return_request_items rri
        JOIN return_requests rr ON rr.id = rri.return_id
        JOIN purchase_requests pr ON pr.id = rr.request_id
        JOIN purchase_request_items pri ON pri.id = rri.purchase_request_item_id
        JOIN invoices i ON i.id = pr.invoice_id
        JOIN LATERAL (
          SELECT ii.tax_percent, ii.taxable_value, ii.quantity,
                 ii.igst_amount, ii.cgst_amount, ii.sgst_amount, ii.cess_amount
          FROM invoice_items ii
          WHERE ii.invoice_id = i.id
            AND (
              ii.id = rri.invoice_item_id
              OR (rri.invoice_item_id IS NULL AND ii.product_id = pri.product_id)
            )
          ORDER BY (ii.id = rri.invoice_item_id) DESC, ii.id ASC
          LIMIT 1
        ) line ON TRUE
        WHERE rr.shop_id = ${shopId} AND rr.status = 'REFUNDED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
        GROUP BY line.tax_percent
      `,
    ]);

    const returnedGst = returnsByRate.reduce((s, r) => s + n(r.tax), 0);
    const returnedCess = returnsByRate.reduce((s, r) => s + n(r.cess), 0);
    const returnedByRate = new Map(
      returnsByRate.map((r) => [n(r.tax_rate), r]),
    );

    const outputGst = r2(
      n(totalsRow[0]?.output_gst ?? 0) - returnedGst,
    );
    const inputGst = n(totalsRow[0]?.input_gst ?? 0);
    const outputCess = r2(n(totalsRow[0]?.output_cess ?? 0) - returnedCess);
    const inputCess = n(totalsRow[0]?.input_cess ?? 0);

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
      /// Output tax reversed on refunded returns in this period (already
      /// netted out of outputTax / outputCess / the by-rate buckets).
      returns: {
        gst: r2(returnedGst),
        cess: r2(returnedCess),
      },
      outputByRate: output.map((r) => {
        const ret = returnedByRate.get(n(r.tax_rate));
        return {
          rate: n(r.tax_rate),
          taxable: r2(n(r.taxable) - n(ret?.taxable ?? 0)),
          tax: r2(n(r.tax) - n(ret?.tax ?? 0)),
          cess: r2(n(r.cess) - n(ret?.cess ?? 0)),
        };
      }),
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
    const [revenueRow, cogsRow, expenseRow, refundRow, returnedCogsRow] = await Promise.all([
      prisma.$queryRaw<{ revenue: string }[]>`
        SELECT COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * taxable_value), 0)::text AS revenue
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'SALE' AND status = 'CONFIRMED'
          AND document_type NOT IN ('ESTIMATE', 'PROFORMA')
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
      // Bucketed by created_at deliberately: a stock adjustment has no
      // user-settable business date (it can't be backdated), so its
      // created_at IS the event date — the same basis invoice_date gives
      // revenue/COGS for invoices.
      prisma.$queryRaw<{ writeoffs: string }[]>`
        SELECT COALESCE(SUM(sai.quantity * sai.unit_cost), 0)::text AS writeoffs
        FROM stock_adjustment_items sai
        JOIN stock_adjustments sa ON sa.id = sai.adjustment_id
        WHERE sa.shop_id = ${shopId} AND sa.direction = 'OUT'
          AND sa.created_at >= ${range.from} AND sa.created_at < ${range.to}
      `,
      // Returns reduce revenue by the refunded lines' EX-TAX value (the
      // taxable slice of the original invoice line, pro-rated by returned
      // quantity). Subtracting the gross refund here over-stated the hit:
      // revenue is ex-tax, and the GST slice of the refund is reversed in
      // gstSummary, not in the P&L.
      //
      // AUTH-TR-C1: same single-line LATERAL resolution as gstSummary's
      // reversal leg — exactly one invoice_items row per return item
      // (exact rri.invoice_item_id when set, else the lowest-id matching
      // (invoice, product) line for legacy nulls). Prevents the old
      // product_id join from fanning the ex-tax reversal out N× when a
      // product was billed on several lines of the same invoice, and keeps
      // the P&L reconciling with the GST report on identical returns.
      prisma.$queryRaw<{ refunds: string }[]>`
        SELECT COALESCE(SUM(line.taxable_value * rri.quantity / NULLIF(line.quantity, 0)), 0)::text AS refunds
        FROM return_request_items rri
        JOIN return_requests rr ON rr.id = rri.return_id
        JOIN purchase_requests pr ON pr.id = rr.request_id
        JOIN purchase_request_items pri ON pri.id = rri.purchase_request_item_id
        JOIN invoices i ON i.id = pr.invoice_id
        JOIN LATERAL (
          SELECT ii.taxable_value, ii.quantity
          FROM invoice_items ii
          WHERE ii.invoice_id = i.id
            AND (
              ii.id = rri.invoice_item_id
              OR (rri.invoice_item_id IS NULL AND ii.product_id = pri.product_id)
            )
          ORDER BY (ii.id = rri.invoice_item_id) DESC, ii.id ASC
          LIMIT 1
        ) line ON TRUE
        WHERE rr.shop_id = ${shopId} AND rr.status = 'REFUNDED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
      `,
      // Returned goods come back into stock via the RETURN_IN restock at
      // the cost they were consumed at — that value offsets the period's
      // COGS (the goods were not, in the end, sold).
      prisma.$queryRaw<{ returned_cogs: string }[]>`
        SELECT COALESCE(SUM(st.total_value), 0)::text AS returned_cogs
        FROM stock_transactions st
        JOIN return_requests rr ON st.source_type = 'RETURN' AND st.source_id = rr.id
        JOIN purchase_requests pr ON pr.id = rr.request_id
        JOIN invoices i ON i.id = pr.invoice_id
        WHERE st.shop_id = ${shopId} AND st.direction = 'IN' AND st.reason_code = 'RETURN_IN'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
      `,
    ]);

    const grossRevenue = n(revenueRow[0]?.revenue ?? 0);
    const refunds = n(refundRow[0]?.refunds ?? 0);
    const revenue = r2(grossRevenue - refunds);
    const returnedCogs = n(returnedCogsRow[0]?.returned_cogs ?? 0);
    const cogs = r2(n(cogsRow[0]?.cogs ?? 0) - returnedCogs);
    const writeoffs = n(expenseRow[0]?.writeoffs ?? 0);
    const grossProfit = r2(revenue - cogs);
    const netProfit = r2(grossProfit - writeoffs);
    const grossMargin = revenue > 0 ? grossProfit / revenue : 0;

    return {
      range,
      revenue,
      refunds,
      cogs,
      returnedCogs,
      writeoffs,
      grossProfit,
      netProfit,
      grossMargin,
    };
  }
}

export const reportsService = new ReportsService();
