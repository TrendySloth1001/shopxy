"use client";

import { useTranslations } from "next-intl";
import {
  Eye,
  Heart,
  MousePointerClick,
  Percent,
  ScanEye,
  ShoppingBag,
  ShoppingCart,
  Target,
  type LucideIcon,
} from "@/shared/icons";
import type { AnalyticsTotals } from "./schema";

const intFmt = new Intl.NumberFormat("en-IN");
export const aInt = (v: number) => intFmt.format(Math.round(v));
export const aPct = (v: number) => `${(v * 100).toFixed(1)}%`;

export function SectionHeading({ children }: { children: React.ReactNode }) {
  return <h2 className="text-label-md uppercase tracking-wide text-subtle">{children}</h2>;
}

export function Kpi({ icon: Icon, label, value, hint }: { icon: LucideIcon; label: string; value: string; hint?: string }) {
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

/** The 8-tile engagement headline, shared by both analytics tabs. */
export function KpiStrip({ totals }: { totals: AnalyticsTotals }) {
  const t = useTranslations("analytics");
  return (
    <div className="grid grid-cols-2 gap-x-lg gap-y-xl sm:grid-cols-4">
      <Kpi icon={Eye} label={t("kpi.impressions")} value={aInt(totals.impressions)} />
      <Kpi icon={MousePointerClick} label={t("kpi.taps")} value={aInt(totals.taps)} />
      <Kpi icon={ScanEye} label={t("kpi.views")} value={aInt(totals.views)} />
      <Kpi icon={ShoppingCart} label={t("kpi.addToCart")} value={aInt(totals.addToCart)} />
      <Kpi icon={ShoppingBag} label={t("kpi.purchases")} value={aInt(totals.purchases)} />
      <Kpi icon={Heart} label={t("kpi.wishlist")} value={aInt(totals.wishlistAdd)} />
      <Kpi icon={Percent} label={t("kpi.ctr")} value={aPct(totals.ctr)} hint={t("kpi.ctrHint")} />
      <Kpi icon={Target} label={t("kpi.cvr")} value={aPct(totals.cvr)} hint={t("kpi.cvrHint")} />
    </div>
  );
}
