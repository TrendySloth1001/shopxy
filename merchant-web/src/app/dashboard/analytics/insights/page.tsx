"use client";

import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, Lightbulb, Sparkles, type LucideIcon } from "lucide-react";
import { Divider } from "@/shared/ui/divider";
import { LineChart } from "@/shared/ui/charts";
import { LazySection } from "@/shared/ui/lazy-section";
import { CardsSkeleton, ListRowsSkeleton } from "@/shared/ui/skeleton";
import { getProductAnalytics } from "@/features/analytics/api";
import { useAnalyticsRange } from "@/features/analytics/range-context";
import { KpiStrip, SectionHeading, aInt, aPct } from "@/features/analytics/ui";
import { HeatmapSection } from "@/features/analytics/heatmap-section";
import { RetentionSection } from "@/features/analytics/retention-section";
import { StockForecast } from "@/features/analytics/stock-forecast";
import type { AnalyticsRow, ProductAnalytics } from "@/features/analytics/schema";

type Totals = ProductAnalytics["totals"];
type TrendMetric = "views" | "purchases" | "impressions" | "taps";
const TREND_METRICS: { key: TrendMetric; label: string }[] = [
  { key: "views", label: "Views" },
  { key: "purchases", label: "Purchases" },
  { key: "impressions", label: "Impressions" },
  { key: "taps", label: "Taps" },
];

export default function AnalyticsOverviewPage() {
  const { iso } = useAnalyticsRange();
  const [data, setData] = useState<ProductAnalytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [trend, setTrend] = useState<TrendMetric>("views");

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const a = await getProductAnalytics(iso, { limit: 100 });
        if (!active) return;
        setData(a);
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
  }, [iso]);

  const insights = useMemo(() => (data ? computeInsights(data.products, data.totals) : []), [data]);
  const opportunity = useMemo(() => (data ? computeOpportunity(data.products, data.totals) : null), [data]);

  if (loading) {
    return (
      <div className="mt-xl space-y-xxl">
        <CardsSkeleton count={8} />
        <ListRowsSkeleton rows={6} leading={false} />
      </div>
    );
  }
  if (error || !data) {
    return <p className="mt-lg rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error ?? "No data."}</p>;
  }

  const t = data.totals;

  return (
    <>
      <div className="mt-xl">
        <KpiStrip totals={t} />
      </div>

      {/* Funnel */}
      <Divider className="my-xxl" />
      <SectionHeading>Conversion funnel</SectionHeading>
      <Funnel totals={t} />

      {/* What to act on */}
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
      {data.daily.length > 0 ? (
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
            <LineChart
              points={data.daily.map((d) => ({ label: labelDay(d.day), value: d[trend] }))}
              heightClass="h-40 sm:h-52"
              ariaLabel={`${trend} over time`}
              formatValue={aInt}
            />
            <p className="mt-xs text-center text-body-sm text-subtle">Hover the line for any day&rsquo;s numbers.</p>
          </div>
        </>
      ) : null}

      {/* Opportunity */}
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
        <Leaderboard title="Most seen" rows={topBy(data.products, "impressions")} unit="impressions" />
        <Leaderboard title="Best sellers" rows={topBy(data.products, "purchases")} unit="sold" />
      </div>

      {/* Lazy heavy sections */}
      <Divider className="my-xxl" />
      <LazySection>
        <HeatmapSection from={iso.from} to={iso.to} />
      </LazySection>

      <Divider className="my-xxl" />
      <LazySection>
        <RetentionSection from={iso.from} to={iso.to} />
      </LazySection>

      <Divider className="my-xxl" />
      <SectionHeading>Stock forecast</SectionHeading>
      <LazySection>
        <StockForecast />
      </LazySection>
    </>
  );
}

/* ---------------- derived ---------------- */

type Insight = { tone: "error" | "amber" | "indigo"; product: string; message: string };

function computeInsights(products: AnalyticsRow[], totals: Totals): Insight[] {
  const out: (Insight & { score: number })[] = [];
  for (const p of products) {
    const name = p.productName ?? "Product";
    if (p.views >= 4 && p.purchases === 0) {
      out.push({ tone: "error", product: name, message: `${p.views} views, no purchases — review price or photos.`, score: p.views });
    } else if (p.views >= 4 && p.cvr > 0 && p.cvr < totals.cvr * 0.5) {
      out.push({ tone: "amber", product: name, message: `Low conversion (${aPct(p.cvr)} vs ${aPct(totals.cvr)} shop avg).`, score: p.views });
    }
    if (p.impressions >= 20 && p.ctr < totals.ctr * 0.5) {
      out.push({ tone: "amber", product: name, message: `Weak click-through (${aPct(p.ctr)}) — try a better thumbnail or title.`, score: p.impressions });
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
          <div key={s.key} className="group">
            <div className="flex items-center justify-between text-body-sm">
              <span className="text-ink">{s.label}</span>
              <span className="flex items-center gap-md">
                {stepRate != null ? <span className="tabular-nums text-subtle">{aPct(stepRate)} from previous</span> : null}
                <span className="tabular-nums font-semibold text-ink">{aInt(value)}</span>
              </span>
            </div>
            <div className="mt-xs h-3 w-full overflow-hidden rounded-full bg-hairline">
              <span
                className="block h-full rounded-full bg-brand transition-[filter] group-hover:brightness-110"
                style={{ width: `${width}%` }}
                title={`${aInt(value)} (${aPct(value / top)} of impressions)`}
              />
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
      <MiniStat label="Cart abandonment" value={aPct(abandon)} hint="Added but not bought" />
      <MiniStat label="Browse → buy" value={aPct(browseToBuy)} hint="Views that purchase" />
      <MiniStat label="Wishlist → buy" value={aPct(wishlistBuy)} hint="Wishlists that purchase" />
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
    <div className="flex items-start gap-md border-b border-hairline py-md transition-colors hover:bg-surface-tint">
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
            <div key={p.productId} className="flex items-center justify-between gap-md border-b border-hairline py-sm transition-colors hover:bg-surface-tint">
              <span className="min-w-0 flex-1 truncate text-body-md text-ink">{p.productName ?? "Product"}</span>
              <span className="shrink-0 text-body-sm text-subtle">{p.views} views</span>
              <span className="shrink-0 text-body-md font-semibold tabular-nums text-ink">CVR {aPct(p.cvr)}</span>
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
              <div key={r.productId} className="group border-b border-hairline py-sm">
                <div className="flex items-center justify-between gap-md">
                  <span className="min-w-0 flex-1 truncate text-body-md text-ink">{r.productName ?? "Product"}</span>
                  <span className="shrink-0 text-body-sm tabular-nums text-muted">
                    {aInt(value)} {unit}
                  </span>
                </div>
                <div className="mt-xs h-1.5 w-full overflow-hidden rounded-full bg-hairline">
                  <span
                    className="block h-full rounded-full bg-brand transition-[filter] group-hover:brightness-110"
                    style={{ width: `${width}%` }}
                  />
                </div>
              </div>
            );
          })
        )}
      </div>
    </section>
  );
}
