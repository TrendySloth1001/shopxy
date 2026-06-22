import prisma from '../../infra/db/prisma.js';
import { reportsService, type DateRange } from '../reports/reports.service.js';
import { getOpenShift, report as cashierReport } from '../cashier/cashier.service.js';
import { cached } from '../../shared/cache/cached.js';
import { DAY_MS, IST_OFFSET_MS, istDayStart, istMonthStart, reportDayKey } from '../../shared/time/ist.js';

/// Shop-level dashboard cache TTL. Short enough that figures feel live, long
/// enough to absorb period toggles + repeated loads under heavy concurrency.
const DASH_TTL_SECONDS = 30;

const round2 = (n: number): number => Math.round(n * 100) / 100;

export type DashboardPeriod = 'today' | 'week' | 'month';
const PERIOD_DAYS: Record<DashboardPeriod, number> = { today: 1, week: 7, month: 30 };
const PERIOD_LABEL: Record<DashboardPeriod, string> = {
  today: 'day',
  week: '7 days',
  month: '30 days',
};

export interface GetStatsOpts {
  /// Caller's user id — used to find their own open till. Omitted ⇒ no till.
  userId?: number;
  /// Whether the caller holds `reports:view`. Money sections (KPIs, trend,
  /// insights, GST, payables) are only computed and returned when true.
  includeFinancials?: boolean;
  /// Rolling window the period-scoped figures cover. Defaults to 'today'.
  period?: DashboardPeriod;
}

/// `prev > 0 ? round((cur-prev)/prev·100) : null` — null when there's no base to
/// compare against (the UI renders that as "new", not a misleading ∞%).
function deltaPct(cur: number, prev: number): number | null {
  if (prev <= 0) return null;
  return Math.round(((cur - prev) / prev) * 100);
}

export class DashboardService {
  async getStats(shopId: number, opts: GetStatsOpts = {}) {
    const { userId, includeFinancials = false, period = 'today' } = opts;

    // The shop-level payload is identical for every user of the shop, so cache
    // it (short TTL + single-flight). At 1000 concurrent loads this collapses to
    // ONE computation per (shop, period, reports-flag) per TTL window instead of
    // ~40 DB queries per request.
    const shop = await cached(
      `dash:v2:${shopId}:${period}:${includeFinancials ? 'f' : 'n'}`,
      DASH_TTL_SECONDS,
      () => this.computeShopStats(shopId, includeFinancials, period),
    );

    // Per-user and uncached: the caller's own open till (one indexed lookup;
    // the heavier shift report only runs if a shift is actually open).
    const till = userId != null ? await this.cashierStats(shopId, userId) : null;

    // Alerts mix cached figures with the live till — pure JS, recomputed per
    // request so till-based alerts stay fresh.
    const alerts = this.buildAlerts({
      period,
      salesDeltaPct: shop.kpis?.sales.deltaPct ?? null,
      gstNetPayable: shop.operations.gstMtd?.netPayable ?? null,
      lowStock: shop.actionQueue.lowStock,
      outOfStock: shop.actionQueue.outOfStock,
      tillOpenedAt: till?.openedAt ?? null,
      now: new Date(),
    });

    return { ...shop, operations: { ...shop.operations, till }, alerts };
  }

  /// Everything identical for every user of the shop (no per-user till, no
  /// alerts) — this is what gets cached.
  private async computeShopStats(shopId: number, includeFinancials: boolean, period: DashboardPeriod) {
    const now = new Date();
    const [
      countRows,
      recentTransactions,
      draftInvoiceCount,
      pendingOrders,
      pendingReturns,
      pendingQuotations,
      invoiceCount,
      partyCount,
      inventoryValue,
    ] = await Promise.all([
      // One scan for every product count (was four separate COUNTs).
      prisma.$queryRaw<{ total: number; active: number; out_of_stock: number; low_stock: number }[]>`
        SELECT
          COUNT(*)::int AS total,
          COUNT(*) FILTER (WHERE is_active)::int AS active,
          COUNT(*) FILTER (WHERE is_active AND stock_quantity <= 0)::int AS out_of_stock,
          COUNT(*) FILTER (WHERE is_active AND stock_quantity > 0 AND stock_quantity <= low_stock_threshold)::int AS low_stock
        FROM products WHERE shop_id = ${shopId}`,
      prisma.stockTransaction.findMany({
        where: { product: { shopId } },
        orderBy: { createdAt: 'desc' },
        take: 8,
        include: { product: { select: { id: true, name: true, sku: true, unit: true } } },
      }),
      prisma.invoice.count({ where: { shopId, status: 'DRAFT' } }),
      // "Needs merchant action" status per module (see commerce-rules memory).
      prisma.purchaseRequest.count({ where: { shopId, status: 'PENDING' } }),
      prisma.returnRequest.count({ where: { shopId, status: 'REQUESTED' } }),
      prisma.quotation.count({ where: { shopId, status: 'REQUESTED' } }),
      prisma.invoice.count({ where: { shopId } }),
      prisma.party.count({ where: { shopId } }),
      this.inventoryValue(shopId),
    ]);
    const c = countRows[0] ?? { total: 0, active: 0, out_of_stock: 0, low_stock: 0 };

    // ── money sections (reports:view only) ─────────────────────────────
    const [money, gstMtd] = includeFinancials
      ? await Promise.all([this.moneyStats(shopId, period), this.gstMtd(shopId, now)])
      : [null, null];

    const todayKey = reportDayKey(now);
    const fromKey = new Date(Date.parse(`${todayKey}T00:00:00.000Z`) - (PERIOD_DAYS[period] - 1) * DAY_MS)
      .toISOString()
      .slice(0, 10);

    return {
      meta: { period, from: fromKey, to: todayKey },
      onboarding: {
        totalProducts: c.total,
        activeProducts: c.active,
        hasInvoices: invoiceCount > 0,
        hasParties: partyCount > 0,
      },
      actionQueue: {
        orders: pendingOrders,
        quotations: pendingQuotations,
        returns: pendingReturns,
        drafts: draftInvoiceCount,
        lowStock: c.low_stock,
        outOfStock: c.out_of_stock,
      },
      operations: {
        inventoryValue,
        gstMtd, // null without reports:view
      },
      recent: recentTransactions,
      // null without reports:view
      kpis: money?.kpis ?? null,
      trend: money?.trend ?? null,
      insights: money?.insights ?? null,
    };
  }

  // ── inventory value (FIFO cost layers + legacy fallback) ─────────────
  private async inventoryValue(shopId: number): Promise<number> {
    const [layerSum, orphans] = await Promise.all([
      prisma.$queryRaw<{ v: string | null }[]>`
        SELECT COALESCE(SUM(cl.qty_remaining * cl.unit_cost), 0)::text AS v
          FROM cost_layers cl JOIN products p ON p.id = cl.product_id
         WHERE p.shop_id = ${shopId} AND p.is_active = true AND cl.qty_remaining > 0`,
      prisma.$queryRaw<{ v: string | null }[]>`
        SELECT COALESCE(SUM(p.stock_quantity * p.purchase_price), 0)::text AS v
          FROM products p
          LEFT JOIN cost_layers cl ON cl.product_id = p.id AND cl.qty_remaining > 0
         WHERE p.shop_id = ${shopId} AND p.is_active = true
           AND p.stock_quantity > 0 AND cl.id IS NULL`,
    ]);
    return toNumber(layerSum[0]?.v ?? 0) + toNumber(orphans[0]?.v ?? 0);
  }

  // ── money: KPIs (sales/profit/receivables/payables) + trend + insights ─
  /// Reads from the analytics roll-up tables (agg_daily_*) instead of scanning
  /// raw invoices/items, so this is a handful of indexed lookups. Day buckets
  /// use the report convention (reportDayKey) so figures reconcile with Reports.
  private async moneyStats(shopId: number, period: DashboardPeriod) {
    const now = new Date();
    const days = PERIOD_DAYS[period];
    // Trend window is longer than the KPI window for "today" so the chart still
    // shows context; the overlay is the equally-long window before it.
    const trendDays = period === 'today' ? 14 : days;

    const todayKey = reportDayKey(now);
    const base = Date.parse(`${todayKey}T00:00:00.000Z`);
    const keyAt = (off: number) => new Date(base - off * DAY_MS).toISOString().slice(0, 10);
    // Ascending list of `count` keys ending `endOff` days before today.
    const window = (count: number, endOff: number) =>
      Array.from({ length: count }, (_, i) => keyAt(endOff + count - 1 - i));

    const trendKeys = window(trendDays, 0);
    const trendPrevKeys = window(trendDays, trendDays);
    const currentKeys = window(days, 0);
    const prevKeys = window(days, days);
    const minDate = new Date(`${keyAt(2 * trendDays - 1)}T00:00:00.000Z`);
    const maxDate = new Date(`${todayKey}T00:00:00.000Z`);
    const curFromKey = currentKeys[0];

    const [salesAgg, purchaseAgg, paymentAgg, topProducts, topCategories, slowMovers, receivable, payable] =
      await Promise.all([
        prisma.aggDailySales.findMany({ where: { shopId, day: { gte: minDate, lte: maxDate } } }),
        prisma.aggDailyPurchases.findMany({ where: { shopId, day: { gte: minDate, lte: maxDate } } }),
        prisma.aggDailyPayment.findMany({ where: { shopId, type: 'RECEIPT', day: { gte: minDate, lte: maxDate } } }),
        this.topProducts(shopId, curFromKey, todayKey),
        this.topCategories(shopId, curFromKey, todayKey),
        this.slowMovers(shopId, curFromKey, todayKey),
        this.receivables(shopId),
        this.payables(shopId),
      ]);

    const keyOf = (d: Date) => d.toISOString().slice(0, 10);
    const salesByDay = new Map(salesAgg.map((r) => [keyOf(r.day), r]));
    const salesTotal = new Map([...salesByDay].map(([k, r]) => [k, toNumber(r.total)]));
    const refundsByDay = new Map([...salesByDay].map(([k, r]) => [k, toNumber(r.refunds)]));
    const purchaseTotal = new Map(purchaseAgg.map((r) => [keyOf(r.day), toNumber(r.total)]));

    const sumKeys = (m: Map<string, number>, keys: string[]) => keys.reduce((s, k) => s + (m.get(k) ?? 0), 0);
    const fillKeys = (m: Map<string, number>, keys: string[]) => keys.map((k) => m.get(k) ?? 0);

    const pnlFor = (keys: string[]) => {
      let taxable = 0;
      let refunds = 0;
      let cogs = 0;
      let writeoffs = 0;
      for (const k of keys) {
        const r = salesByDay.get(k);
        if (!r) continue;
        taxable += toNumber(r.taxable);
        refunds += toNumber(r.refunds);
        cogs += toNumber(r.cogs);
        writeoffs += toNumber(r.writeoffs);
      }
      const revenue = taxable - refunds;
      const grossProfit = revenue - cogs;
      return { netProfit: round2(grossProfit - writeoffs), margin: revenue > 0 ? Math.round((grossProfit / revenue) * 100) : 0 };
    };

    const salesCur = round2(sumKeys(salesTotal, currentKeys));
    const salesPrev = round2(sumKeys(salesTotal, prevKeys));
    const curPnl = pnlFor(currentKeys);
    const prevPnl = pnlFor(prevKeys);

    // One trend line per payment mode (ordered by total, modes with data only).
    const modeTotals = new Map<string, number>();
    const modeDay = new Map<string, Map<string, number>>();
    for (const r of paymentAgg) {
      const v = toNumber(r.amount);
      modeTotals.set(r.mode, (modeTotals.get(r.mode) ?? 0) + v);
      const m = modeDay.get(r.mode) ?? new Map<string, number>();
      m.set(keyOf(r.day), v);
      modeDay.set(r.mode, m);
    }
    const paymentSeries = [...modeTotals.entries()]
      .filter(([, t]) => t > 0)
      .sort((a, b) => b[1] - a[1])
      .map(([mode]) => ({ mode, values: fillKeys(modeDay.get(mode) ?? new Map(), trendKeys) }));

    return {
      kpis: {
        sales: { value: salesCur, prev: salesPrev, deltaPct: deltaPct(salesCur, salesPrev) },
        profit: {
          value: curPnl.netProfit,
          prev: prevPnl.netProfit,
          deltaPct: deltaPct(curPnl.netProfit, prevPnl.netProfit),
          margin: curPnl.margin,
        },
        receivables: receivable,
        payables: payable,
      },
      trend: {
        labels: trendKeys,
        sales: fillKeys(salesTotal, trendKeys),
        previous: fillKeys(salesTotal, trendPrevKeys),
        purchases: fillKeys(purchaseTotal, trendKeys),
        returns: fillKeys(refundsByDay, trendKeys),
        paymentSeries,
      },
      insights: { topProducts, topCategories, slowMovers },
    };
  }

  /// Top 10 products by net revenue in the window — from the roll-ups.
  private async topProducts(shopId: number, fromKey: string, toKey: string) {
    const rows = await prisma.$queryRaw<{ name: string; revenue: string; qty: string }[]>`
      SELECT p.name AS name,
             COALESCE(SUM(a.revenue), 0)::text AS revenue,
             COALESCE(SUM(a.qty), 0)::text AS qty
        FROM agg_daily_product a JOIN products p ON p.id = a.product_id
       WHERE a.shop_id = ${shopId} AND a.day >= ${fromKey}::date AND a.day <= ${toKey}::date
       GROUP BY p.id, p.name
       ORDER BY SUM(a.revenue) DESC
       LIMIT 10`;
    return rows.map((r) => ({ name: r.name, revenue: toNumber(r.revenue), quantity: toNumber(r.qty) }));
  }

  /// Top 10 product categories by net revenue in the window — from the roll-ups.
  private async topCategories(shopId: number, fromKey: string, toKey: string) {
    const rows = await prisma.$queryRaw<{ name: string; revenue: string }[]>`
      SELECT c.name AS name, COALESCE(SUM(a.revenue), 0)::text AS revenue
        FROM agg_daily_product a JOIN categories c ON c.id = a.category_id
       WHERE a.shop_id = ${shopId} AND a.category_id IS NOT NULL
         AND a.day >= ${fromKey}::date AND a.day <= ${toKey}::date
       GROUP BY c.name
       ORDER BY SUM(a.revenue) DESC
       LIMIT 10`;
    return rows.map((r) => ({ name: r.name, revenue: toNumber(r.revenue) }));
  }

  /// Slow movers — active, in-stock products with the fewest units sold in the
  /// window (zero-sellers first, most stock tied up). Sales come from the
  /// roll-ups; stock from the live products table.
  private async slowMovers(shopId: number, fromKey: string, toKey: string) {
    const rows = await prisma.$queryRaw<{ name: string; stock: string; sold: string }[]>`
      SELECT p.name AS name, p.stock_quantity::text AS stock, COALESCE(s.qty, 0)::text AS sold
        FROM products p
        LEFT JOIN (
          SELECT product_id, SUM(qty) AS qty
            FROM agg_daily_product
           WHERE shop_id = ${shopId} AND day >= ${fromKey}::date AND day <= ${toKey}::date
           GROUP BY product_id
        ) s ON s.product_id = p.id
       WHERE p.shop_id = ${shopId} AND p.is_active = true AND p.stock_quantity > 0
       ORDER BY COALESCE(s.qty, 0) ASC, p.stock_quantity DESC
       LIMIT 10`;
    return rows.map((r) => ({ name: r.name, stock: toNumber(r.stock), sold: toNumber(r.sold) }));
  }

  /// Receivables: per-party billed (confirmed sales, credit-note-signed) minus
  /// non-voided receipts; only debtors (positive balance) count. Mirrors
  /// parties.service getPartyOverview's billed − received basis.
  private async receivables(shopId: number) {
    const row = await prisma.$queryRaw<{ outstanding: string; debtors: bigint }[]>`
      WITH billed AS (
        SELECT party_id, SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * total) AS amt
          FROM invoices
         WHERE shop_id = ${shopId} AND type = 'SALE' AND status = 'CONFIRMED'
           AND document_type NOT IN ('ESTIMATE', 'PROFORMA') AND party_id IS NOT NULL
         GROUP BY party_id),
      paid AS (
        SELECT party_id, SUM(amount) AS amt FROM payments
         WHERE shop_id = ${shopId} AND type = 'RECEIPT' AND voided_at IS NULL AND party_id IS NOT NULL
         GROUP BY party_id)
      SELECT COALESCE(SUM(GREATEST(b.amt - COALESCE(p.amt, 0), 0)), 0)::text AS outstanding,
             COUNT(*) FILTER (WHERE b.amt - COALESCE(p.amt, 0) > 0.005)::bigint AS debtors
        FROM billed b LEFT JOIN paid p ON p.party_id = b.party_id`;
    return { outstanding: toNumber(row[0]?.outstanding ?? 0), debtors: Number(row[0]?.debtors ?? 0) };
  }

  /// Payables: the vendor-side mirror of receivables — confirmed purchase bills
  /// minus non-voided vendor payments, summed across creditor vendors.
  private async payables(shopId: number) {
    const row = await prisma.$queryRaw<{ outstanding: string; creditors: bigint }[]>`
      WITH billed AS (
        SELECT vendor_id, SUM((CASE WHEN document_type = 'CREDIT_NOTE' THEN -1 ELSE 1 END) * total) AS amt
          FROM invoices
         WHERE shop_id = ${shopId} AND type = 'PURCHASE' AND status = 'CONFIRMED'
           AND document_type NOT IN ('ESTIMATE', 'PROFORMA') AND vendor_id IS NOT NULL
         GROUP BY vendor_id),
      paid AS (
        SELECT vendor_id, SUM(amount) AS amt FROM payments
         WHERE shop_id = ${shopId} AND type = 'PAYMENT' AND voided_at IS NULL AND vendor_id IS NOT NULL
         GROUP BY vendor_id)
      SELECT COALESCE(SUM(GREATEST(b.amt - COALESCE(p.amt, 0), 0)), 0)::text AS outstanding,
             COUNT(*) FILTER (WHERE b.amt - COALESCE(p.amt, 0) > 0.005)::bigint AS creditors
        FROM billed b LEFT JOIN paid p ON p.vendor_id = b.vendor_id`;
    return { outstanding: toNumber(row[0]?.outstanding ?? 0), creditors: Number(row[0]?.creditors ?? 0) };
  }

  /// GST liability for the current IST month-to-date (a compliance period,
  /// independent of the dashboard's rolling window). Reuses the audited report.
  private async gstMtd(shopId: number, now: Date) {
    const monthStart = istMonthStart(now);
    const to = new Date(istDayStart(now).getTime() + DAY_MS);
    const range: DateRange = { from: monthStart, to };
    const gst = await reportsService.gstSummary(shopId, range);
    return {
      monthStart: monthStart.toISOString(),
      outputTax: gst.outputTax,
      inputTax: gst.inputTax,
      netPayable: gst.netPayable,
    };
  }

  // ── till (caller's own open shift) ─────────────────────────────────
  private async cashierStats(shopId: number, userId: number) {
    const shift = await getOpenShift(shopId, userId);
    if (!shift) return null;
    const rep = await cashierReport(shopId, shift.id, { openedById: userId });
    if ('error' in rep) return null;
    return {
      shiftId: rep.shift.id,
      openedAt: rep.shift.openedAt,
      salesCount: rep.sales.count,
      salesGross: rep.sales.gross,
      expectedCash: rep.cash.expected,
      tenders: rep.tenders.map((t) => ({ mode: t.mode, amount: t.amount, count: t.count })),
    };
  }

  // ── smart alerts (simple, documented heuristics) ───────────────────
  private buildAlerts(c: {
    period: DashboardPeriod;
    salesDeltaPct: number | null;
    gstNetPayable: number | null;
    lowStock: number;
    outOfStock: number;
    tillOpenedAt: string | Date | null;
    now: Date;
  }) {
    const alerts: Array<{ id: string; severity: 'critical' | 'warning' | 'info'; message: string; href: string }> = [];

    // Sales anomaly — a meaningful drop vs the previous equal window.
    const sd = c.salesDeltaPct;
    if (sd != null && sd <= -25) {
      alerts.push({
        id: 'sales-drop',
        severity: 'warning',
        message: `Sales are down ${Math.abs(sd)}% versus the previous ${PERIOD_LABEL[c.period]}.`,
        href: '/dashboard/reports',
      });
    }

    // GST filing reminder — GSTR-3B is due ~20th of the following month. Surface
    // it from the 14th onward while there's a net liability for the period.
    const ist = new Date(c.now.getTime() + IST_OFFSET_MS);
    const dom = ist.getUTCDate();
    const daysToDue = 20 - dom;
    if (c.gstNetPayable != null && c.gstNetPayable > 0 && dom >= 14 && daysToDue >= 0) {
      alerts.push({
        id: 'gst-due',
        severity: daysToDue <= 2 ? 'critical' : 'info',
        message:
          daysToDue === 0
            ? 'GST (GSTR-3B) is due today.'
            : `GST (GSTR-3B) is due in ${daysToDue} day${daysToDue === 1 ? '' : 's'}.`,
        href: '/dashboard/reports',
      });
    }

    // Reorder nudge.
    const stockNeedy = c.lowStock + c.outOfStock;
    if (stockNeedy > 0) {
      alerts.push({
        id: 'low-stock',
        severity: c.outOfStock > 0 ? 'warning' : 'info',
        message: `${stockNeedy} product${stockNeedy === 1 ? '' : 's'} ${stockNeedy === 1 ? 'is' : 'are'} low or out of stock — reorder soon.`,
        href: '/dashboard/products',
      });
    }

    // Till left open a long time.
    if (c.tillOpenedAt) {
      const hours = (c.now.getTime() - new Date(c.tillOpenedAt).getTime()) / (60 * 60 * 1000);
      if (hours >= 10) {
        alerts.push({
          id: 'till-open',
          severity: 'info',
          message: 'A till has been open for over 10 hours — remember to close it.',
          href: '/dashboard/cashier',
        });
      }
    }

    return alerts;
  }
}

function toNumber(value: unknown): number {
  if (value == null) return 0;
  if (typeof value === 'number') return value;
  if (typeof value === 'bigint') return Number(value);
  if (typeof (value as { toNumber?: () => number }).toNumber === 'function') {
    return (value as { toNumber: () => number }).toNumber();
  }
  return Number(value);
}

export const dashboardService = new DashboardService();
