"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { Maximize2, Minimize2 } from "@/shared/icons";
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
  const t = useTranslations("dashboard");
  const [expanded, setExpanded] = useState(false);
  const headingId = `${id}-h`;
  const fullHeadingId = `${id}-h-full`;

  // While the overlay is open: lock body scroll and let Escape close it.
  useEffect(() => {
    if (!expanded) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setExpanded(false);
    };
    document.addEventListener("keydown", onKey);
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.removeEventListener("keydown", onKey);
      document.body.style.overflow = prevOverflow;
    };
  }, [expanded]);

  const header = (hId: string) => (
    <div className="flex items-start justify-between gap-md">
      <div className="min-w-0">
        <h2 id={hId} className="text-label-md uppercase tracking-wide text-muted">
          {title}
        </h2>
        {hint ? <p className="mt-xs text-body-sm text-muted">{hint}</p> : null}
      </div>
      <button
        type="button"
        onClick={() => setExpanded((v) => !v)}
        aria-expanded={expanded}
        aria-label={expanded ? t("analytics.collapseChart") : t("analytics.expandChart")}
        className="-mr-xs -mt-xs shrink-0 rounded-button p-xs text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        {expanded ? <Minimize2 size={16} aria-hidden="true" /> : <Maximize2 size={16} aria-hidden="true" />}
      </button>
    </div>
  );

  return (
    <section
      aria-labelledby={headingId}
      className={`rounded-lg border border-hairline bg-canvas p-md ${span ? "xl:col-span-2" : ""}`}
    >
      {header(headingId)}
      <div className="mx-auto mt-md max-w-5xl">{children}</div>

      {expanded ? (
        <div
          role="dialog"
          aria-modal="true"
          aria-labelledby={fullHeadingId}
          className="fixed inset-0 z-50 flex flex-col bg-canvas p-lg"
        >
          {header(fullHeadingId)}
          <div className="mt-lg flex-1 overflow-auto">
            <div className="mx-auto flex min-h-full max-w-6xl flex-col justify-center">{children}</div>
          </div>
        </div>
      ) : null}
    </section>
  );
}
