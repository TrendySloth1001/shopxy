import type { DashboardInsights } from "../stats";
import { inr } from "./ui";
import { InfographicPie, PIE_PALETTE_A, PIE_PALETTE_B, PIE_PALETTE_C } from "./infographic-pie";

/**
 * Ranked analytics as infographic pie charts (variable-radius wedges with
 * leader-line callouts): top categories, top products, and slow movers (share
 * of idle in-stock units — which products lock up the most capital).
 */
export function Analytics({ insights }: { insights: DashboardInsights }) {
  return (
    <div className="grid gap-md xl:grid-cols-2">
      <Card title="Top categories">
        <InfographicPie
          rows={insights.topCategories.map((c) => ({ label: c.name, value: c.revenue }))}
          palette={PIE_PALETTE_A}
          formatValue={(v) => inr.format(v)}
          ariaLabel="Top categories by sales"
          subject="category sales"
          itemNoun="categories"
        />
      </Card>

      <Card title="Top products">
        <InfographicPie
          rows={insights.topProducts.map((p) => ({ label: p.name, value: p.revenue }))}
          palette={PIE_PALETTE_B}
          formatValue={(v) => inr.format(v)}
          ariaLabel="Top products by sales"
          subject="product sales"
          itemNoun="products"
        />
      </Card>

      <Card title="Slow movers" hint="Share of idle in-stock units — capital that isn’t moving." span>
        <InfographicPie
          rows={insights.slowMovers.map((m) => ({ label: m.name, value: m.stock }))}
          palette={PIE_PALETTE_C}
          formatValue={(v) => `${v} units`}
          ariaLabel="Slow movers by idle stock"
          subject="idle stock"
          itemNoun="products"
        />
      </Card>
    </div>
  );
}

function Card({
  title,
  hint,
  span,
  children,
}: {
  title: string;
  hint?: string;
  span?: boolean;
  children: React.ReactNode;
}) {
  const headingId = `${title.replace(/\s+/g, "-").toLowerCase()}-h`;
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
