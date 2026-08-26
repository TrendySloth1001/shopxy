import prisma from '../../infra/db/prisma.js';

function n(v: string | number | null | undefined): number {
  if (v === null || v === undefined) return 0;
  return typeof v === 'string' ? Number(v) : v;
}

const r2 = (v: number) => Math.round(v * 100) / 100;

export interface DateRange {
  from: Date;
  to: Date;
}

export class ReportsService {
  async sales(shopId: number, range: DateRange) {
    const [summaryRow, daily, topProducts, topCustomers, refundRow] = await Promise.all([
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
        creditNoteCount: Number(summary?.credit_notes ?? 0),
        subtotal: n(summary?.subtotal ?? 0),
        taxableValue: n(summary?.taxable_value ?? 0),
        taxAmount: n(summary?.tax_amount ?? 0),
        total: grossRevenue,
        refunds,
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

  async gstSummary(shopId: number, range: DateRange) {
    const byRate = (type: 'SALE' | 'PURCHASE') => prisma.$queryRaw<
      { tax_rate: string; taxable: string; tax: string; igst: string; cgst: string; sgst: string; cess: string }[]
    >`
        SELECT
          ii.tax_percent::text                                       AS tax_rate,
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.taxable_value), 0)::text AS taxable,
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * (ii.igst_amount + ii.cgst_amount + ii.sgst_amount)), 0)::text AS tax,
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.igst_amount), 0)::text AS igst,
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.cgst_amount), 0)::text AS cgst,
          COALESCE(SUM((CASE WHEN i.document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * ii.sgst_amount), 0)::text AS sgst,
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
          output_igst: string;
          output_cgst: string;
          output_sgst: string;
          input_igst: string;
          input_cgst: string;
          input_sgst: string;
          output_cess: string;
          input_cess: string;
        }[]
      >`
        SELECT
          COALESCE(SUM(CASE WHEN type='SALE'     THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * (igst_amount + cgst_amount + sgst_amount) ELSE 0 END), 0)::text AS output_gst,
          COALESCE(SUM(CASE WHEN type='PURCHASE' THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * (igst_amount + cgst_amount + sgst_amount) ELSE 0 END), 0)::text AS input_gst,
          COALESCE(SUM(CASE WHEN type='SALE'     THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * igst_amount ELSE 0 END), 0)::text AS output_igst,
          COALESCE(SUM(CASE WHEN type='SALE'     THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * cgst_amount ELSE 0 END), 0)::text AS output_cgst,
          COALESCE(SUM(CASE WHEN type='SALE'     THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * sgst_amount ELSE 0 END), 0)::text AS output_sgst,
          COALESCE(SUM(CASE WHEN type='PURCHASE' THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * igst_amount ELSE 0 END), 0)::text AS input_igst,
          COALESCE(SUM(CASE WHEN type='PURCHASE' THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * cgst_amount ELSE 0 END), 0)::text AS input_cgst,
          COALESCE(SUM(CASE WHEN type='PURCHASE' THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * sgst_amount ELSE 0 END), 0)::text AS input_sgst,
          COALESCE(SUM(CASE WHEN type='SALE'     THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * cess_amount ELSE 0 END), 0)::text AS output_cess,
          COALESCE(SUM(CASE WHEN type='PURCHASE' THEN (CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * cess_amount ELSE 0 END), 0)::text AS input_cess
        FROM invoices
        WHERE shop_id = ${shopId} AND status = 'CONFIRMED'
          AND document_type NOT IN ('ESTIMATE', 'PROFORMA')
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
      `,
      prisma.$queryRaw<
        { tax_rate: string; taxable: string; tax: string; igst: string; cgst: string; sgst: string; cess: string }[]
      >`
        SELECT
          line.tax_percent::text AS tax_rate,
          COALESCE(SUM(line.taxable_value * rri.quantity / NULLIF(line.quantity, 0)), 0)::text AS taxable,
          COALESCE(SUM((line.igst_amount + line.cgst_amount + line.sgst_amount) * rri.quantity / NULLIF(line.quantity, 0)), 0)::text AS tax,
          COALESCE(SUM(line.igst_amount * rri.quantity / NULLIF(line.quantity, 0)), 0)::text AS igst,
          COALESCE(SUM(line.cgst_amount * rri.quantity / NULLIF(line.quantity, 0)), 0)::text AS cgst,
          COALESCE(SUM(line.sgst_amount * rri.quantity / NULLIF(line.quantity, 0)), 0)::text AS sgst,
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
    const returnedIgst = returnsByRate.reduce((s, r) => s + n(r.igst), 0);
    const returnedCgst = returnsByRate.reduce((s, r) => s + n(r.cgst), 0);
    const returnedSgst = returnsByRate.reduce((s, r) => s + n(r.sgst), 0);
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

    const outputIgst = r2(n(totalsRow[0]?.output_igst ?? 0) - returnedIgst);
    const outputCgst = r2(n(totalsRow[0]?.output_cgst ?? 0) - returnedCgst);
    const outputSgst = r2(n(totalsRow[0]?.output_sgst ?? 0) - returnedSgst);
    const inputIgst = n(totalsRow[0]?.input_igst ?? 0);
    const inputCgst = n(totalsRow[0]?.input_cgst ?? 0);
    const inputSgst = n(totalsRow[0]?.input_sgst ?? 0);

    return {
      range,
      outputTax: outputGst,
      inputTax: inputGst,
      netPayable: r2(outputGst - inputGst),
      outputCess,
      inputCess,
      netCessPayable: r2(outputCess - inputCess),
      byHead: {
        output: { igst: outputIgst, cgst: outputCgst, sgst: outputSgst },
        input: { igst: inputIgst, cgst: inputCgst, sgst: inputSgst },
        netPayable: {
          igst: r2(outputIgst - inputIgst),
          cgst: r2(outputCgst - inputCgst),
          sgst: r2(outputSgst - inputSgst),
        },
      },
      returns: {
        gst: r2(returnedGst),
        igst: r2(returnedIgst),
        cgst: r2(returnedCgst),
        sgst: r2(returnedSgst),
        cess: r2(returnedCess),
      },
      outputByRate: output.map((r) => {
        const ret = returnedByRate.get(n(r.tax_rate));
        return {
          rate: n(r.tax_rate),
          taxable: r2(n(r.taxable) - n(ret?.taxable ?? 0)),
          tax: r2(n(r.tax) - n(ret?.tax ?? 0)),
          igst: r2(n(r.igst) - n(ret?.igst ?? 0)),
          cgst: r2(n(r.cgst) - n(ret?.cgst ?? 0)),
          sgst: r2(n(r.sgst) - n(ret?.sgst ?? 0)),
          cess: r2(n(r.cess) - n(ret?.cess ?? 0)),
        };
      }),
      inputByRate: input.map((r) => ({
        rate: n(r.tax_rate),
        taxable: n(r.taxable),
        tax: n(r.tax),
        igst: n(r.igst),
        cgst: n(r.cgst),
        sgst: n(r.sgst),
        cess: n(r.cess),
      })),
    };
  }

  async pnl(shopId: number, range: DateRange) {
    const [revenueRow, cogsRow, expenseRow, refundRow, returnedCogsRow] = await Promise.all([
      prisma.$queryRaw<{ revenue: string }[]>`
        SELECT COALESCE(SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * taxable_value), 0)::text AS revenue
        FROM invoices
        WHERE shop_id = ${shopId} AND type = 'SALE' AND status = 'CONFIRMED'
          AND document_type NOT IN ('ESTIMATE', 'PROFORMA')
          AND invoice_date >= ${range.from} AND invoice_date < ${range.to}
      `,
      prisma.$queryRaw<{ cogs: string }[]>`
        SELECT COALESCE(SUM(cc.qty_consumed * cc.unit_cost), 0)::text AS cogs
        FROM cost_consumptions cc
        JOIN stock_transactions st ON st.id = cc.ledger_entry_id
        JOIN invoices i
          ON st.source_type = 'INVOICE' AND st.source_id = i.id
        WHERE i.shop_id = ${shopId} AND i.type = 'SALE' AND i.status = 'CONFIRMED'
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
      `,
      prisma.$queryRaw<{ writeoffs: string }[]>`
        SELECT COALESCE(SUM(sai.quantity * sai.unit_cost), 0)::text AS writeoffs
        FROM stock_adjustment_items sai
        JOIN stock_adjustments sa ON sa.id = sai.adjustment_id
        WHERE sa.shop_id = ${shopId} AND sa.direction = 'OUT'
          AND sa.created_at >= ${range.from} AND sa.created_at < ${range.to}
      `,
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

  async soldItems(
    shopId: number,
    range: DateRange,
    opts: { skip: number; limit: number; search?: string; productId?: number },
  ) {
    const q = opts.search?.trim() ? `%${opts.search.trim()}%` : null;
    const pid = opts.productId ?? null;
    const [rows, countRows] = await Promise.all([
      prisma.$queryRaw<{
        productName: string;
        productSku: string;
        unit: string;
        quantity: string;
        total: string;
        invoiceId: number;
        invoiceNo: string;
        soldAt: Date;
      }[]>`
        SELECT ii.product_name AS "productName",
               ii.product_sku  AS "productSku",
               ii.unit         AS "unit",
               ii.quantity::text AS "quantity",
               ii.total::text    AS "total",
               i.id            AS "invoiceId",
               i.invoice_no    AS "invoiceNo",
               i.invoice_date  AS "soldAt"
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.shop_id = ${shopId} AND i.type = 'SALE' AND i.status = 'CONFIRMED'
          AND i.document_type NOT IN ('ESTIMATE', 'PROFORMA', 'CREDIT_NOTE')
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
          AND (${q}::text IS NULL OR ii.product_name ILIKE ${q} OR ii.product_sku ILIKE ${q})
          AND (${pid}::int IS NULL OR ii.product_id = ${pid})
        ORDER BY i.invoice_date DESC, ii.id DESC
        LIMIT ${opts.limit} OFFSET ${opts.skip}
      `,
      prisma.$queryRaw<{ count: string }[]>`
        SELECT COUNT(*)::text AS count
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.shop_id = ${shopId} AND i.type = 'SALE' AND i.status = 'CONFIRMED'
          AND i.document_type NOT IN ('ESTIMATE', 'PROFORMA', 'CREDIT_NOTE')
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
          AND (${q}::text IS NULL OR ii.product_name ILIKE ${q} OR ii.product_sku ILIKE ${q})
          AND (${pid}::int IS NULL OR ii.product_id = ${pid})
      `,
    ]);
    return {
      items: rows.map((s) => ({
        productName: s.productName,
        productSku: s.productSku,
        unit: s.unit,
        quantity: n(s.quantity),
        total: n(s.total),
        invoiceId: s.invoiceId,
        invoiceNo: s.invoiceNo,
        soldAt: s.soldAt,
      })),
      total: Number(countRows[0]?.count ?? 0),
    };
  }

  async soldProducts(
    shopId: number,
    range: DateRange,
    opts: { skip: number; limit: number; search?: string },
  ) {
    const q = opts.search?.trim() ? `%${opts.search.trim()}%` : null;
    const [rows, countRows, totalsRows] = await Promise.all([
      prisma.$queryRaw<{
        productId: number;
        productName: string;
        productSku: string;
        unit: string;
        salesCount: string;
        totalQuantity: string;
        totalAmount: string;
        lastSoldAt: Date;
      }[]>`
        SELECT ii.product_id      AS "productId",
               MAX(ii.product_name) AS "productName",
               MAX(ii.product_sku)  AS "productSku",
               MAX(ii.unit)         AS "unit",
               COUNT(*)::text          AS "salesCount",
               SUM(ii.quantity)::text  AS "totalQuantity",
               SUM(ii.total)::text     AS "totalAmount",
               MAX(i.invoice_date)     AS "lastSoldAt"
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.shop_id = ${shopId} AND i.type = 'SALE' AND i.status = 'CONFIRMED'
          AND i.document_type NOT IN ('ESTIMATE', 'PROFORMA', 'CREDIT_NOTE')
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
          AND (${q}::text IS NULL OR ii.product_name ILIKE ${q} OR ii.product_sku ILIKE ${q})
        GROUP BY ii.product_id
        ORDER BY SUM(ii.total) DESC
        LIMIT ${opts.limit} OFFSET ${opts.skip}
      `,
      prisma.$queryRaw<{ count: string }[]>`
        SELECT COUNT(*)::text AS count FROM (
          SELECT 1
          FROM invoice_items ii
          JOIN invoices i ON i.id = ii.invoice_id
          WHERE i.shop_id = ${shopId} AND i.type = 'SALE' AND i.status = 'CONFIRMED'
            AND i.document_type NOT IN ('ESTIMATE', 'PROFORMA', 'CREDIT_NOTE')
            AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
            AND (${q}::text IS NULL OR ii.product_name ILIKE ${q} OR ii.product_sku ILIKE ${q})
          GROUP BY ii.product_id
        ) t
      `,
      prisma.$queryRaw<{ salesCount: string; totalQuantity: string; totalAmount: string }[]>`
        SELECT COUNT(*)::text             AS "salesCount",
               COALESCE(SUM(ii.quantity), 0)::text AS "totalQuantity",
               COALESCE(SUM(ii.total), 0)::text    AS "totalAmount"
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE i.shop_id = ${shopId} AND i.type = 'SALE' AND i.status = 'CONFIRMED'
          AND i.document_type NOT IN ('ESTIMATE', 'PROFORMA', 'CREDIT_NOTE')
          AND i.invoice_date >= ${range.from} AND i.invoice_date < ${range.to}
          AND (${q}::text IS NULL OR ii.product_name ILIKE ${q} OR ii.product_sku ILIKE ${q})
      `,
    ]);
    return {
      items: rows.map((p) => ({
        productId: p.productId,
        productName: p.productName,
        productSku: p.productSku,
        unit: p.unit,
        salesCount: Number(p.salesCount),
        totalQuantity: n(p.totalQuantity),
        totalAmount: n(p.totalAmount),
        lastSoldAt: p.lastSoldAt,
      })),
      total: Number(countRows[0]?.count ?? 0),
      totals: {
        salesCount: Number(totalsRows[0]?.salesCount ?? 0),
        totalQuantity: n(totalsRows[0]?.totalQuantity ?? 0),
        totalAmount: n(totalsRows[0]?.totalAmount ?? 0),
      },
    };
  }
}

export const reportsService = new ReportsService();
