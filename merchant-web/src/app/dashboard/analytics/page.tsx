"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  ArrowDown,
  ArrowUp,
  BarChart3,
  Eye,
  Heart,
  Lightbulb,
  MousePointerClick,
  Percent,
  ScanEye,
  Search,
  Sparkles,
  ShoppingBag,
  ShoppingCart,
  Target,
  type LucideIcon,
} from "lucide-react";
import { PageHeader } from "@/shared/ui/page-header";
import { Divider } from "@/shared/ui/divider";
import { LineChart } from "@/shared/ui/charts";
import { LazySection } from "@/shared/ui/lazy-section";
import { CardsSkeleton, ListRowsSkeleton } from "@/shared/ui/skeleton";
import { dateInputToIso, inputDateDaysAgo, startOfMonthInput, todayInputDate } from "@/shared/datetime";
import { getProductAnalytics } from "@/features/analytics/api";
import { HeatmapSection } from "@/features/analytics/heatmap-section";
import { RetentionSection } from "@/features/analytics/retention-section";
import { StockForecast } from "@/features/analytics/stock-forecast";
import type { AnalyticsRow, AnalyticsSortKey, ProductAnalytics } from "@/features/analytics/schema";

const intFmt = new Intl.NumberFormat("en-IN");
const int = (v: number) => intFmt.format(Math.round(v));
const pct = (v: number) => `${(v * 100).toFixed(1)}%`;
const PAGE = 100;

type TrendMetric = "views" | "purchases" | "impressions" | "taps";
const TREND_METRICS: { key: TrendMetric; label: string }[] = [
  { key: "views", label: "Views" },
  { key: "purchases", label: "Purchases" },
  { key: "impressions", label: "Impressions" },
  { key: "taps", label: "Taps" },
];

export default function AnalyticsPage() {
  const [from, setFrom] = useState(() => inputDateDaysAgo(7));
  const [to, setTo] = useState(() => todayInputDate());

  const [data, setData] = useState<ProductAnalytics | null>(null);
  const [extra, setExtra] = useState<AnalyticsRow[]>([]);
  const [cursor, setCursor] = useState<string | null>(null);
  const [loadingMore, setLoadingMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const [sortKey, setSortKey] = useState<AnalyticsSortKey>("purchases");
  const [sortAsc, setSortAsc] = useState(false);
  const [trend, setTrend] = useState<TrendMetric>("views");
  const [search, setSearch] = useState("");

  const range = useMemo(() => ({ from: dateInputToIso(from), to: dateInputToIso(to, true) }), [from, to]);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const a = await getProductAnalytics(range, { limit: PAGE });
        if (!active) return;
        setData(a);
        setExtra([]);
        setCursor(a.nextCursor ?? null);
        setError(null);
      } catch (e) {
        if (active) {
          setError(e instanceof Error ? e.message : "Could not load analytics.");
          setData(null);
        }
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [range]);

  const loadMore = useCallback(async () => {
    if (!cursor || loadingMore) return;
    setLoadingMore(true);
    try {
      const a = await getProductAnalytics(range, { limit: PAGE, cursor });
      setExtra((prev) => [...prev, ...a.products]);
      setCursor(a.nextCursor ?? null);
    } catch {
      /* leave the current rows in place */
    } finally {
      setLoadingMore(false);
    }
  }, [cursor, loadingMore, range]);

  function toggleSort(key: AnalyticsSortKey) {
    if (key === sortKey) setSortAsc((a) => !a);
    else {
      setSortKey(key);
      setSortAsc(key === "productName");
    }
  }

  const allProducts = useMemo(() => [...(data?.products ?? []), ...extra], [data, extra]);
  const insights = useMemo(() => (data ? computeInsights(allProducts, data.totals) : []), [allProducts, data]);
  const opportunity = useMemo(() => (data ? computeOpportunity(allProducts, data.totals) : null), [allProducts, data]);

  const rows = useMemo(() => {
    const q = search.trim().toLowerCase();
    const base = q ? allProducts.filter((p) => (p.productName ?? "").toLowerCase().includes(q)) : allProducts;
    const sorted = [...base].sort((a, b) => {
      if (sortKey === "productName") return (a.productName ?? "").localeCompare(b.productName ?? "");
      return (a[sortKey] as number) - (b[sortKey] as number);
    });
    return sortAsc ? sorted : sorted.reverse();
  }, [allProducts, search, sortKey, sortAsc]);

  function preset(p: "7d" | "30d" | "month") {
    setTo(todayInputDate());
    setFrom(p === "month" ? startOfMonthInput() : p === "30d" ? inputDateDaysAgo(30) : inputDateDaysAgo(7));
  }

  const t = data?.totals;

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <PageHeader
        icon={BarChart3}
        tone="indigo"
        title="Analytics"
        subtitle="How customers engage with your products — the funnel from impressions to purchases, where you're leaking, and what to act on."
      />

      {/* Sticky range toolbar */}
      <div className="sticky top-0 z-20 -mx-lg mt-lg border-b border-hairline bg-canvas px-lg py-md md:-mx-xxl md:px-xxl">
        <div className="flex flex-wrap items-end gap-md">
          <DateField label="From" value={from} max={to} onChange={setFrom} />
          <DateField label="To" value={to} min={from} max={todayInputDate()} onChange={setTo} />
          <div className="flex flex-wrap items-center gap-xs">
            <PresetChip label="Last 7 days" onClick={() => preset("7d")} />
            <PresetChip label="Last 30 days" onClick={() => preset("30d")} />
            <PresetChip label="This month" onClick={() => preset("month")} />
          </div>
        </div>
      </div>

      {error ? (
        <p className="mt-lg rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : null}

      {loading ? (
        <div className="mt-xl space-y-xxl">
          <CardsSkeleton count={8} />
          <ListRowsSkeleton rows={6} leading={false} />
        </div>
      ) : t ? (
        <>
          {/* KPI strip */}
          <div className="mt-xl grid grid-cols-2 gap-x-lg gap-y-xl sm:grid-cols-4">
            <Kpi icon={Eye} label="Impressions" value={int(t.impressions)} />
            <Kpi icon={MousePointerClick} label="Taps" value={int(t.taps)} />
            <Kpi icon={ScanEye} label="Views" value={int(t.views)} />
            <Kpi icon={ShoppingCart} label="Add to cart" value={int(t.addToCart)} />
            <Kpi icon={ShoppingBag} label="Purchases" value={int(t.purchases)} />
            <Kpi icon={Heart} label="Wishlist" value={int(t.wishlistAdd)} />
            <Kpi icon={Percent} label="CTR" value={pct(t.ctr)} hint="Taps ÷ impressions" />
            <Kpi icon={Target} label="CVR" value={pct(t.cvr)} hint="Purchases ÷ views" />
          </div>

          {/* Funnel */}
          <Divider className="my-xxl" />
          <SectionHeading>Conversion funnel</SectionHeading>
          <Funnel totals={t} />

          {/* What to act on — surfaced high, it's the actionable bit */}
          <Divider className="my-xxl" />
          <SectionHeading>What to act on</SectionHeading>
          {insights.length === 0 ? (
            <p className="flex items-center gap-sm py-md text-body-md text-muted">
              <Sparkles size={16} className="text-success" /> Nothing flagged — your funnel looks healthy for this range.
            </p>
          ) : (
            <div className="mt-sm">
              {insights.map((ins, i) => (
                <InsightRow key={i} insight={ins} />
              ))}
            </div>
          )}

          {/* Engagement trend */}
          {data && data.daily.length > 0 ? (
            <>
              <Divider className="my-xxl" />
              <div className="flex flex-wrap items-center justify-between gap-sm">
                <SectionHeading>Engagement over time</SectionHeading>
                <div className="flex flex-wrap items-center gap-xs">
                  {TREND_METRICS.map((m) => (
                    <button
                      key={m.key}
                      type="button"
                      onClick={() => setTrend(m.key)}
                      className={`inline-flex h-8 items-center rounded-button px-sm text-label-md transition-colors ${
                        trend === m.key ? "bg-brand text-white" : "border border-hairline text-ink hover:bg-surface-tint"
                      }`}
                    >
                      {m.label}
                    </button>
                  ))}
                </div>
              </div>
              <div className="mt-md">
                <LineChart values={data.daily.map((d) => d[trend])} ariaLabel={`${trend} over time`} heightClass="h-32 sm:h-44" />
                <div className="mt-xs flex justify-between text-body-sm text-subtle">
                  <span>{labelDay(data.daily[0]?.day)}</span>
                  <span>{labelDay(data.daily[data.daily.length - 1]?.day)}</span>
                </div>
              </div>
            </>
          ) : null}

          {/* Opportunity lists */}
          {opportunity && (opportunity.gems.length > 0 || opportunity.attention.length > 0) ? (
            <>
              <Divider className="my-xxl" />
              <div className="grid grid-cols-1 gap-xxl lg:grid-cols-2">
                <OpportunityList icon={Sparkles} title="Hidden gems" hint="High conversion, low traffic — worth promoting." rows={opportunity.gems} />
                <OpportunityList icon={AlertTriangle} title="Needs attention" hint="Lots of views, few buyers — check price & photos." rows={opportunity.attention} />
              </div>
            </>
          ) : null}

          {/* Leaderboards */}
          <Divider className="my-xxl" />
          <div className="grid grid-cols-1 gap-xxl lg:grid-cols-2">
            <Leaderboard title="Most seen" rows={topBy(allProducts, "impressions")} unit="impressions" />
            <Leaderboard title="Best sellers" rows={topBy(allProducts, "purchases")} unit="sold" />
          </div>

          {/* Lazy, self-fetching heavy sections — load when scrolled to */}
          <Divider className="my-xxl" />
          <LazySection>
            <HeatmapSection from={range.from} to={range.to} />
          </LazySection>

          <Divider className="my-xxl" />
          <LazySection>
            <RetentionSection from={range.from} to={range.to} />
          </LazySection>

          <Divider className="my-xxl" />
          <SectionHeading>Stock forecast</SectionHeading>
          <LazySection>
            <StockForecast />
          </LazySection>

          {/* Per-product table */}
          <Divider className="my-xxl" />
          <div className="flex flex-wrap items-center justify-between gap-sm">
            <SectionHeading>By product</SectionHeading>
            <div className="flex w-full items-center gap-sm rounded-input border border-hairline bg-white px-md sm:w-64 focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
              <Search size={15} className="shrink-0 text-subtle" />
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder="Filter products"
                className="h-9 w-full bg-transparent text-body-md text-ink outline-none placeholder:text-subtle"
              />
            </div>
          </div>

          {rows.length === 0 ? (
            <p className="py-xl text-center text-body-sm text-subtle">
              {search ? "No products match your filter." : "No product activity in this range."}
            </p>
          ) : (
            <div className="mt-sm overflow-x-auto">
              <table className="w-full min-w-[44rem] border-collapse">
                <thead>
                  <tr className="border-b border-hairline text-left">
                    <Th label="Product" col="productName" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} align="left" />
                    <Th label="Imp" col="impressions" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="Taps" col="taps" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="Views" col="views" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="ATC" col="addToCart" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="Buys" col="purchases" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="CTR" col="ctr" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                    <Th label="CVR" col="cvr" sortKey={sortKey} sortAsc={sortAsc} onSort={toggleSort} />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((r) => (
                    <Row key={r.productId} row={r} />
                  ))}
                </tbody>
              </table>
            </div>
          )}

          {cursor && !search ? (
            <div className="mt-lg flex justify-center">
              <button
                type="button"
                onClick={loadMore}
                disabled={loadingMore}
                className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
              >
                {loadingMore ? "Loading…" : "Load more products"}
              </button>
            </div>
          ) : null}
        </>
      ) : null}
    </div>
  );
}

/* ---------------- derived analytics ---------------- */

type Insight = { tone: "error" | "amber" | "indigo"; product: string; message: string };
type Totals = ProductAnalytics["totals"];

function computeInsights(products: AnalyticsRow[], totals: Totals): Insight[] {
  const out: (Insight & { score: number })[] = [];
  for (const p of products) {
    const name = p.productName ?? "Product";
    if (p.views >= 4 && p.purchases === 0) {
      out.push({ tone: "error", product: name, message: `${p.views} views, no purchases — review price or photos.`, score: p.views });
    } else if (p.views >= 4 && p.cvr > 0 && p.cvr < totals.cvr * 0.5) {
      out.push({ tone: "amber", product: name, message: `Low conversion (${pct(p.cvr)} vs ${pct(totals.cvr)} shop avg).`, score: p.views });
    }
    if (p.impressions >= 20 && p.ctr < totals.ctr * 0.5) {
      out.push({ tone: "amber", product: name, message: `Weak click-through (${pct(p.ctr)}) — try a better thumbnail or title.`, score: p.impressions });
    }
    if (p.addToCart >= 3 && p.purchases / p.addToCart < 0.5) {
      out.push({ tone: "error", product: name, message: `Cart abandonment — ${p.addToCart} added, ${p.purchases} bought.`, score: p.addToCart * 2 });
    }
    if (p.wishlistAdd >= 3 && p.purchases === 0) {
      out.push({ tone: "indigo", product: name, message: `Wishlisted ${p.wishlistAdd}× but never bought — a flash deal could convert it.`, score: p.wishlistAdd });
    }
  }
  return out
    .sort((a, b) => b.score - a.score)
    .slice(0, 6)
    .map((x) => ({ tone: x.tone, product: x.product, message: x.message }));
}

function median(nums: number[]): number {
  if (nums.length === 0) return 0;
  const s = [...nums].sort((a, b) => a - b);
  const mid = Math.floor(s.length / 2);
  return s.length % 2 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

function computeOpportunity(products: AnalyticsRow[], totals: Totals) {
  const withViews = products.filter((p) => p.views > 0);
  const medViews = median(withViews.map((p) => p.views));
  const avgCvr = totals.cvr;
  const gems = withViews
    .filter((p) => p.cvr >= avgCvr && p.views <= medViews && p.purchases > 0)
    .sort((a, b) => b.cvr - a.cvr)
    .slice(0, 5);
  const attention = withViews
    .filter((p) => p.views >= medViews && p.cvr < avgCvr)
    .sort((a, b) => b.views - a.views)
    .slice(0, 5);
  return { gems, attention };
}

function topBy(products: AnalyticsRow[], key: "impressions" | "purchases"): AnalyticsRow[] {
  return [...products].filter((p) => p[key] > 0).sort((a, b) => b[key] - a[key]).slice(0, 6);
}

function labelDay(iso?: string): string {
  if (!iso) return "";
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? "" : d.toLocaleDateString("en-IN", { day: "numeric", month: "short" });
}

/* ---------------- presentation ---------------- */

function SectionHeading({ children }: { children: React.ReactNode }) {
  return <h2 className="text-label-md uppercase tracking-wide text-subtle">{children}</h2>;
}

function Kpi({ icon: Icon, label, value, hint }: { icon: LucideIcon; label: string; value: string; hint?: string }) {
  return (
    <div>
      <p className="flex items-center gap-xs text-label-md uppercase tracking-wide text-subtle">
        <Icon size={13} className="shrink-0" />
        {label}
      </p>
      <p className="mt-xs text-headline-md font-bold tabular-nums text-ink">{value}</p>
      {hint ? <p className="text-body-sm text-subtle">{hint}</p> : null}
    </div>
  );
}

const FUNNEL_STAGES: { key: keyof Totals; label: string }[] = [
  { key: "impressions", label: "Impressions" },
  { key: "taps", label: "Taps" },
  { key: "views", label: "Views" },
  { key: "addToCart", label: "Add to cart" },
  { key: "purchases", label: "Purchases" },
];

function Funnel({ totals }: { totals: Totals }) {
  const top = totals.impressions || 1;
  return (
    <div className="mt-md space-y-sm">
      {FUNNEL_STAGES.map((s, i) => {
        const value = totals[s.key] as number;
        const prev = i === 0 ? value : (totals[FUNNEL_STAGES[i - 1].key] as number);
        const stepRate = i === 0 || prev === 0 ? null : value / prev;
        const width = Math.max(2, Math.round((value / top) * 100));
        return (
          <div key={s.key}>
            <div className="flex items-center justify-between text-body-sm">
              <span className="text-ink">{s.label}</span>
              <span className="flex items-center gap-md">
                {stepRate != null ? <span className="tabular-nums text-subtle">{pct(stepRate)} from previous</span> : null}
                <span className="tabular-nums font-semibold text-ink">{int(value)}</span>
              </span>
            </div>
            <div className="mt-xs h-3 w-full overflow-hidden rounded-full bg-hairline">
              <span className="block h-full rounded-full bg-brand" style={{ width: `${width}%` }} />
            </div>
          </div>
        );
      })}
      <LeakKpis totals={totals} />
    </div>
  );
}

function LeakKpis({ totals }: { totals: Totals }) {
  const abandon = totals.addToCart > 0 ? 1 - totals.purchases / totals.addToCart : 0;
  const browseToBuy = totals.views > 0 ? totals.purchases / totals.views : 0;
  const wishlistBuy = totals.wishlistAdd > 0 ? totals.purchases / totals.wishlistAdd : 0;
  return (
    <div className="grid grid-cols-1 gap-x-lg gap-y-md pt-md sm:grid-cols-3">
      <MiniStat label="Cart abandonment" value={pct(abandon)} hint="Added but not bought" />
      <MiniStat label="Browse → buy" value={pct(browseToBuy)} hint="Views that purchase" />
      <MiniStat label="Wishlist → buy" value={pct(wishlistBuy)} hint="Wishlists that purchase" />
    </div>
  );
}

function MiniStat({ label, value, hint }: { label: string; value: string; hint: string }) {
  return (
    <div>
      <p className="text-label-md uppercase tracking-wide text-subtle">{label}</p>
      <p className="mt-xs text-title-lg font-bold tabular-nums text-ink">{value}</p>
      <p className="text-body-sm text-subtle">{hint}</p>
    </div>
  );
}

const INSIGHT_TONE: Record<Insight["tone"], string> = {
  error: "bg-error-soft text-error",
  amber: "bg-accent-amber-soft text-accent-amber",
  indigo: "bg-accent-indigo-soft text-accent-indigo",
};

function InsightRow({ insight }: { insight: Insight }) {
  return (
    <div className="flex items-start gap-md border-b border-hairline py-md">
      <span className={`flex size-8 shrink-0 items-center justify-center rounded-full ${INSIGHT_TONE[insight.tone]}`}>
        <Lightbulb size={15} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{insight.product}</p>
        <p className="text-body-sm text-muted">{insight.message}</p>
      </div>
    </div>
  );
}

function OpportunityList({ icon: Icon, title, hint, rows }: { icon: LucideIcon; title: string; hint: string; rows: AnalyticsRow[] }) {
  return (
    <section className="min-w-0">
      <h3 className="flex items-center gap-sm text-title-md text-ink">
        <Icon size={16} className="text-subtle" /> {title}
      </h3>
      <p className="mt-xs text-body-sm text-subtle">{hint}</p>
      <div className="mt-sm">
        {rows.length === 0 ? (
          <p className="py-md text-body-sm text-subtle">Nothing here for this range.</p>
        ) : (
          rows.map((p) => (
            <div key={p.productId} className="flex items-center justify-between gap-md border-b border-hairline py-sm">
              <span className="min-w-0 flex-1 truncate text-body-md text-ink">{p.productName ?? "Product"}</span>
              <span className="shrink-0 text-body-sm text-subtle">{p.views} views</span>
              <span className="shrink-0 text-body-md font-semibold tabular-nums text-ink">CVR {pct(p.cvr)}</span>
            </div>
          ))
        )}
      </div>
    </section>
  );
}

function Leaderboard({ title, rows, unit }: { title: string; rows: AnalyticsRow[]; unit: string }) {
  const key = unit === "sold" ? "purchases" : "impressions";
  const max = Math.max(...rows.map((r) => r[key] as number), 0);
  return (
    <section className="min-w-0">
      <SectionHeading>{title}</SectionHeading>
      <div className="mt-sm">
        {rows.length === 0 ? (
          <p className="py-md text-body-sm text-subtle">No data for this range.</p>
        ) : (
          rows.map((r) => {
            const value = r[key] as number;
            const width = max > 0 ? Math.max(2, Math.round((value / max) * 100)) : 0;
            return (
              <div key={r.productId} className="border-b border-hairline py-sm">
                <div className="flex items-center justify-between gap-md">
                  <span className="min-w-0 flex-1 truncate text-body-md text-ink">{r.productName ?? "Product"}</span>
                  <span className="shrink-0 text-body-sm tabular-nums text-muted">
                    {int(value)} {unit}
                  </span>
                </div>
                <div className="mt-xs h-1.5 w-full overflow-hidden rounded-full bg-hairline">
                  <span className="block h-full rounded-full bg-brand" style={{ width: `${width}%` }} />
                </div>
              </div>
            );
          })
        )}
      </div>
    </section>
  );
}

function Th({
  label,
  col,
  sortKey,
  sortAsc,
  onSort,
  align = "right",
}: {
  label: string;
  col: AnalyticsSortKey;
  sortKey: AnalyticsSortKey;
  sortAsc: boolean;
  onSort: (k: AnalyticsSortKey) => void;
  align?: "left" | "right";
}) {
  const active = sortKey === col;
  return (
    <th className={`py-sm ${align === "right" ? "text-right" : "text-left"}`}>
      <button
        type="button"
        onClick={() => onSort(col)}
        className={`inline-flex items-center gap-xs text-label-md uppercase tracking-wide transition-colors hover:text-ink ${
          active ? "text-ink" : "text-subtle"
        } ${align === "right" ? "flex-row-reverse" : ""}`}
      >
        {label}
        {active ? sortAsc ? <ArrowUp size={12} /> : <ArrowDown size={12} /> : null}
      </button>
    </th>
  );
}

function Row({ row }: { row: AnalyticsRow }) {
  return (
    <tr className="border-b border-hairline">
      <td className="max-w-xs truncate py-sm pr-md text-body-md text-ink">{row.productName ?? "Product"}</td>
      <Td value={int(row.impressions)} />
      <Td value={int(row.taps)} />
      <Td value={int(row.views)} />
      <Td value={int(row.addToCart)} />
      <Td value={int(row.purchases)} />
      <Td value={pct(row.ctr)} />
      <Td value={pct(row.cvr)} />
    </tr>
  );
}

function Td({ value }: { value: string }) {
  return <td className="py-sm pl-md text-right text-body-md tabular-nums text-muted">{value}</td>;
}

/* Range controls. */
const dateInput =
  "h-10 rounded-input border border-hairline bg-white px-md text-body-md text-ink outline-none focus-visible:border-brand focus-visible:ring-2 focus-visible:ring-brand-soft";

function DateField({
  label,
  value,
  min,
  max,
  onChange,
}: {
  label: string;
  value: string;
  min?: string;
  max?: string;
  onChange: (v: string) => void;
}) {
  return (
    <label className="flex flex-col gap-xs">
      <span className="text-label-md text-muted">{label}</span>
      <input type="date" value={value} min={min} max={max} onChange={(e) => onChange(e.target.value)} className={dateInput} />
    </label>
  );
}

function PresetChip({ label, onClick }: { label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint"
    >
      {label}
    </button>
  );
}
