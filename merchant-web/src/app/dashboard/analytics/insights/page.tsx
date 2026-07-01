"use client";

import { useEffect, useMemo, useState } from "react";
import { useTranslations } from "next-intl";
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
const TREND_METRICS: { key: TrendMetric; labelKey: string }[] = [
  { key: "views", labelKey: "trend.views" },
  { key: "purchases", labelKey: "trend.purchases" },
  { key: "impressions", labelKey: "trend.impressions" },
  { key: "taps", labelKey: "trend.taps" },
];

export default function AnalyticsOverviewPage() {
  const { iso } = useAnalyticsRange();
  const t = useTranslations("analytics");
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
          setError(e instanceof Error ? e.message : t("errors.load"));
          setData(null);
        }
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [iso, t]);

  const insights = useMemo(() => (data ? computeInsights(data.products, data.totals, t) : []), [data, t]);
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
    return <p className="mt-lg rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error ?? t("errors.noData")}</p>;
  }

  const totals = data.totals;

  return (
    <>
      <div className="mt-xl">
        <KpiStrip totals={totals} />
      </div>

      {/* Funnel */}
      <Divider className="my-xxl" />
      <SectionHeading>{t("funnel.title")}</SectionHeading>
      <Funnel totals={totals} t={t} />

      {/* What to act on */}
      <Divider className="my-xxl" />
      <SectionHeading>{t("act.title")}</SectionHeading>
      {insights.length === 0 ? (
        <p className="flex items-center gap-sm py-md text-body-md text-muted">
          <Sparkles size={16} className="text-success" /> {t("act.empty")}
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
            <SectionHeading>{t("trend.title")}</SectionHeading>
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
                  {t(m.labelKey)}
                </button>
              ))}
            </div>
          </div>
          <div className="mt-md">
            <LineChart
              points={data.daily.map((d) => ({ label: labelDay(d.day), value: d[trend] }))}
              heightClass="h-40 sm:h-52"
              ariaLabel={t("trend.ariaLabel", { metric: t(`trend.${trend}`) })}
              formatValue={aInt}
            />
            <p className="mt-xs text-center text-body-sm text-subtle">{t("trend.hoverHint")}</p>
          </div>
        </>
      ) : null}

      {/* Opportunity */}
      {opportunity && (opportunity.gems.length > 0 || opportunity.attention.length > 0) ? (
        <>
          <Divider className="my-xxl" />
          <div className="grid grid-cols-1 gap-xxl lg:grid-cols-2">
            <OpportunityList icon={Sparkles} title={t("opportunity.gemsTitle")} hint={t("opportunity.gemsHint")} rows={opportunity.gems} t={t} />
            <OpportunityList icon={AlertTriangle} title={t("opportunity.attentionTitle")} hint={t("opportunity.attentionHint")} rows={opportunity.attention} t={t} />
          </div>
        </>
      ) : null}

      {/* Leaderboards */}
      <Divider className="my-xxl" />
      <div className="grid grid-cols-1 gap-xxl lg:grid-cols-2">
        <Leaderboard title={t("leaderboard.mostSeen")} rows={topBy(data.products, "impressions")} unit="impressions" unitLabel={t("leaderboard.unitImpressions")} emptyLabel={t("leaderboard.empty")} productFallback={t("common.product")} />
        <Leaderboard title={t("leaderboard.bestSellers")} rows={topBy(data.products, "purchases")} unit="sold" unitLabel={t("leaderboard.unitSold")} emptyLabel={t("leaderboard.empty")} productFallback={t("common.product")} />
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
      <SectionHeading>{t("stock.title")}</SectionHeading>
      <LazySection>
        <StockForecast />
      </LazySection>
    </>
  );
}

/* ---------------- derived ---------------- */

type Insight = { tone: "error" | "amber" | "indigo"; product: string; message: string };

type Translate = (key: string, values?: Record<string, string | number>) => string;

function computeInsights(products: AnalyticsRow[], totals: Totals, t: Translate): Insight[] {
  const out: (Insight & { score: number })[] = [];
  for (const p of products) {
    const name = p.productName ?? t("common.product");
    if (p.views >= 4 && p.purchases === 0) {
      out.push({ tone: "error", product: name, message: t("insight.noPurchases", { views: p.views }), score: p.views });
    } else if (p.views >= 4 && p.cvr > 0 && p.cvr < totals.cvr * 0.5) {
      out.push({ tone: "amber", product: name, message: t("insight.lowConversion", { cvr: aPct(p.cvr), avg: aPct(totals.cvr) }), score: p.views });
    }
    if (p.impressions >= 20 && p.ctr < totals.ctr * 0.5) {
      out.push({ tone: "amber", product: name, message: t("insight.weakCtr", { ctr: aPct(p.ctr) }), score: p.impressions });
    }
    if (p.addToCart >= 3 && p.purchases / p.addToCart < 0.5) {
      out.push({ tone: "error", product: name, message: t("insight.cartAbandon", { added: p.addToCart, bought: p.purchases }), score: p.addToCart * 2 });
    }
    if (p.wishlistAdd >= 3 && p.purchases === 0) {
      out.push({ tone: "indigo", product: name, message: t("insight.wishlisted", { count: p.wishlistAdd }), score: p.wishlistAdd });
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

const FUNNEL_STAGES: { key: keyof Totals; labelKey: string }[] = [
  { key: "impressions", labelKey: "funnel.impressions" },
  { key: "taps", labelKey: "funnel.taps" },
  { key: "views", labelKey: "funnel.views" },
  { key: "addToCart", labelKey: "funnel.addToCart" },
  { key: "purchases", labelKey: "funnel.purchases" },
];

function Funnel({ totals, t }: { totals: Totals; t: Translate }) {
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
              <span className="text-ink">{t(s.labelKey)}</span>
              <span className="flex items-center gap-md">
                {stepRate != null ? <span className="tabular-nums text-subtle">{t("funnel.fromPrevious", { rate: aPct(stepRate) })}</span> : null}
                <span className="tabular-nums font-semibold text-ink">{aInt(value)}</span>
              </span>
            </div>
            <div className="mt-xs h-3 w-full overflow-hidden rounded-full bg-hairline">
              <span
                className="block h-full rounded-full bg-brand transition-[filter] group-hover:brightness-110"
                style={{ width: `${width}%` }}
                title={t("funnel.barTitle", { value: aInt(value), pct: aPct(value / top) })}
              />
            </div>
          </div>
        );
      })}
      <LeakKpis totals={totals} t={t} />
    </div>
  );
}

function LeakKpis({ totals, t }: { totals: Totals; t: Translate }) {
  const abandon = totals.addToCart > 0 ? 1 - totals.purchases / totals.addToCart : 0;
  const browseToBuy = totals.views > 0 ? totals.purchases / totals.views : 0;
  const wishlistBuy = totals.wishlistAdd > 0 ? totals.purchases / totals.wishlistAdd : 0;
  return (
    <div className="grid grid-cols-1 gap-x-lg gap-y-md pt-md sm:grid-cols-3">
      <MiniStat label={t("leak.cartAbandonment")} value={aPct(abandon)} hint={t("leak.cartAbandonmentHint")} />
      <MiniStat label={t("leak.browseToBuy")} value={aPct(browseToBuy)} hint={t("leak.browseToBuyHint")} />
      <MiniStat label={t("leak.wishlistToBuy")} value={aPct(wishlistBuy)} hint={t("leak.wishlistToBuyHint")} />
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

function OpportunityList({ icon: Icon, title, hint, rows, t }: { icon: LucideIcon; title: string; hint: string; rows: AnalyticsRow[]; t: Translate }) {
  return (
    <section className="min-w-0">
      <h3 className="flex items-center gap-sm text-title-md text-ink">
        <Icon size={16} className="text-subtle" /> {title}
      </h3>
      <p className="mt-xs text-body-sm text-subtle">{hint}</p>
      <div className="mt-sm">
        {rows.length === 0 ? (
          <p className="py-md text-body-sm text-subtle">{t("opportunity.empty")}</p>
        ) : (
          rows.map((p) => (
            <div key={p.productId} className="flex items-center justify-between gap-md border-b border-hairline py-sm transition-colors hover:bg-surface-tint">
              <span className="min-w-0 flex-1 truncate text-body-md text-ink">{p.productName ?? t("common.product")}</span>
              <span className="shrink-0 text-body-sm text-subtle">{t("opportunity.viewsCount", { count: p.views })}</span>
              <span className="shrink-0 text-body-md font-semibold tabular-nums text-ink">{t("opportunity.cvrValue", { cvr: aPct(p.cvr) })}</span>
            </div>
          ))
        )}
      </div>
    </section>
  );
}

function Leaderboard({ title, rows, unit, unitLabel, emptyLabel, productFallback }: { title: string; rows: AnalyticsRow[]; unit: string; unitLabel: string; emptyLabel: string; productFallback: string }) {
  const key = unit === "sold" ? "purchases" : "impressions";
  const max = Math.max(...rows.map((r) => r[key] as number), 0);
  return (
    <section className="min-w-0">
      <SectionHeading>{title}</SectionHeading>
      <div className="mt-sm">
        {rows.length === 0 ? (
          <p className="py-md text-body-sm text-subtle">{emptyLabel}</p>
        ) : (
          rows.map((r) => {
            const value = r[key] as number;
            const width = max > 0 ? Math.max(2, Math.round((value / max) * 100)) : 0;
            return (
              <div key={r.productId} className="group border-b border-hairline py-sm">
                <div className="flex items-center justify-between gap-md">
                  <span className="min-w-0 flex-1 truncate text-body-md text-ink">{r.productName ?? productFallback}</span>
                  <span className="shrink-0 text-body-sm tabular-nums text-muted">
                    {aInt(value)} {unitLabel}
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
