"use client";

import { useEffect, useState } from "react";
import { PackageX } from "lucide-react";
import { dateInputToIso, inputDateDaysAgo, todayInputDate } from "@/shared/datetime";
import { getSalesReport } from "@/features/reports/api";
import { listProducts } from "@/features/products/api";

const VELOCITY_DAYS = 30;

type Forecast = {
  id: number;
  name: string;
  sku?: string;
  stock: number;
  perDay: number;
  daysLeft: number;
};

/**
 * Reorder forecast: joins each top-selling product's 30-day sales velocity
 * (Reports) with its current on-hand stock (Products) to estimate how many
 * days of cover remain. Runs on its own fixed 30-day window — velocity needs a
 * stable base — independent of the page's date range. Covers the shop's movers
 * (the Sales report's top products), which are the SKUs most at stock-out risk.
 */
export function StockForecast() {
  const [rows, setRows] = useState<Forecast[] | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const range = {
          from: dateInputToIso(inputDateDaysAgo(VELOCITY_DAYS)),
          to: dateInputToIso(todayInputDate(), true),
        };
        const [sales, products] = await Promise.all([getSalesReport(range), listProducts({ limit: "200" })]);
        if (!active) return;
        const byId = new Map(products.data.map((p) => [p.id, p]));
        const out: Forecast[] = [];
        for (const tp of sales.topProducts) {
          if (tp.productId == null) continue;
          const perDay = tp.quantity / VELOCITY_DAYS;
          if (perDay <= 0) continue;
          const prod = byId.get(tp.productId);
          const stock = prod?.stockQuantity ?? 0;
          out.push({
            id: tp.productId,
            name: tp.productName ?? prod?.name ?? "Product",
            sku: tp.productSku || prod?.sku,
            stock,
            perDay,
            daysLeft: perDay > 0 ? stock / perDay : Infinity,
          });
        }
        out.sort((a, b) => a.daysLeft - b.daysLeft);
        setRows(out);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not build the forecast.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  if (loading) {
    return <div className="mt-md h-24 animate-pulse rounded-xs bg-hairline" />;
  }
  if (error) {
    return <p className="mt-sm rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>;
  }
  if (!rows || rows.length === 0) {
    return <p className="py-md text-body-sm text-subtle">Not enough sales in the last 30 days to forecast stock.</p>;
  }

  return (
    <div className="mt-md">
      <p className="mb-sm text-body-sm text-subtle">
        Estimated days of stock left at the last 30 days&rsquo; sales pace — your fastest movers first.
      </p>
      {rows.map((f) => (
        <ForecastRow key={f.id} f={f} />
      ))}
    </div>
  );
}

function ForecastRow({ f }: { f: Forecast }) {
  const out = f.stock <= 0;
  const days = Math.floor(f.daysLeft);
  const tone = out || days < 7 ? "error" : days < 14 ? "amber" : "ok";
  const toneClass =
    tone === "error" ? "bg-error-soft text-error" : tone === "amber" ? "bg-accent-amber-soft text-accent-amber" : "bg-success-soft text-success";
  const label = out ? "Out of stock" : `≈ ${days} ${days === 1 ? "day" : "days"} left`;
  const perDay = f.perDay >= 1 ? f.perDay.toFixed(1) : f.perDay.toFixed(2);
  return (
    <div className="flex items-center gap-md border-b border-hairline py-md">
      {out ? <PackageX size={16} className="shrink-0 text-error" /> : null}
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">{f.name}</p>
        <p className="text-body-sm text-muted">
          {perDay}/day · {f.stock} in stock{f.sku ? ` · ${f.sku}` : ""}
        </p>
      </div>
      <span className={`shrink-0 rounded-full px-sm py-px text-body-sm font-semibold ${toneClass}`}>{label}</span>
    </div>
  );
}
