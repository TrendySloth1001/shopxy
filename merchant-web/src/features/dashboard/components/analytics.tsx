import { useTranslations } from "next-intl";
import type { DashboardInsights } from "../stats";
import { inr } from "./ui";
import { InfographicPie, PIE_PALETTE_A, PIE_PALETTE_B, PIE_PALETTE_C } from "./infographic-pie";

/**
 * Ranked analytics as infographic pie charts (variable-radius wedges with
 * leader-line callouts): top categories, top products, and slow movers (share
 * of idle in-stock units — which products lock up the most capital).
 */
export function Analytics({ insights }: { insights: DashboardInsights }) {
  const t = useTranslations("dashboard");
  return (
    <div className="grid gap-md xl:grid-cols-2">
      <Card id="top-categories" title={t("analytics.topCategories")}>
        <InfographicPie
          rows={insights.topCategories.map((c) => ({ label: c.name, value: c.revenue }))}
          palette={PIE_PALETTE_A}
          formatValue={(v) => inr.format(v)}
          ariaLabel={t("analytics.topCategoriesAria")}
          subject={t("analytics.categorySales")}
          itemNoun={t("analytics.nounCategories")}
        />
      </Card>

      <Card id="top-products" title={t("analytics.topProducts")}>
        <InfographicPie
          rows={insights.topProducts.map((p) => ({ label: p.name, value: p.revenue }))}
          palette={PIE_PALETTE_B}
          formatValue={(v) => inr.format(v)}
          ariaLabel={t("analytics.topProductsAria")}
          subject={t("analytics.productSales")}
          itemNoun={t("analytics.nounProducts")}
        />
      </Card>

      <Card id="slow-movers" title={t("analytics.slowMovers")} hint={t("analytics.slowMoversHint")} span>
        <InfographicPie
          rows={insights.slowMovers.map((m) => ({ label: m.name, value: m.stock }))}
          palette={PIE_PALETTE_C}
          formatValue={(v) => t("analytics.unitsValue", { count: v })}
          ariaLabel={t("analytics.slowMoversAria")}
          subject={t("analytics.idleStock")}
          itemNoun={t("analytics.nounProducts")}
        />
      </Card>
    </div>
  );
}

function Card({
  id,
  title,
  hint,
  span,
  children,
}: {
  id: string;
  title: string;
  hint?: string;
  span?: boolean;
  children: React.ReactNode;
}) {
  const headingId = `${id}-h`;
  return (
    <section
      aria-labelledby={headingId}
      className={`rounded-lg border border-hairline bg-canvas p-md ${span ? "xl:col-span-2" : ""}`}
    >
      <h2 id={headingId} className="text-label-md uppercase tracking-wide text-muted">
        {title}
      </h2>
      {hint ? <p className="mt-xs text-body-sm text-muted">{hint}</p> : null}
      <div className="mx-auto mt-md max-w-5xl">{children}</div>
    </section>
  );
}
