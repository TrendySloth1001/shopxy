"use client";

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
} from "lucide-react";
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
  return (
    <div className="grid grid-cols-2 gap-x-lg gap-y-xl sm:grid-cols-4">
      <Kpi icon={Eye} label="Impressions" value={aInt(totals.impressions)} />
      <Kpi icon={MousePointerClick} label="Taps" value={aInt(totals.taps)} />
      <Kpi icon={ScanEye} label="Views" value={aInt(totals.views)} />
      <Kpi icon={ShoppingCart} label="Add to cart" value={aInt(totals.addToCart)} />
      <Kpi icon={ShoppingBag} label="Purchases" value={aInt(totals.purchases)} />
      <Kpi icon={Heart} label="Wishlist" value={aInt(totals.wishlistAdd)} />
      <Kpi icon={Percent} label="CTR" value={aPct(totals.ctr)} hint="Taps ÷ impressions" />
      <Kpi icon={Target} label="CVR" value={aPct(totals.cvr)} hint="Purchases ÷ views" />
    </div>
  );
}
