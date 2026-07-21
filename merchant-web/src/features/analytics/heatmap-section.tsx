"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
import { getPurchaseHeatmap } from "./api";
import type { Heatmap } from "./schema";

const DAY_KEYS = ["heatmap.mon", "heatmap.tue", "heatmap.wed", "heatmap.thu", "heatmap.fri", "heatmap.sat", "heatmap.sun"];
// Postgres DOW: 0=Sun..6=Sat → Mon-first row order.
const DOW_TO_ROW = [6, 0, 1, 2, 3, 4, 5];

/**
 * "When customers buy" — a day-of-week × hour purchase heatmap. Self-fetches
 * for the given range; rendered lazily by the page so it only loads when
 * scrolled into view.
 */
export function HeatmapSection({ from, to }: { from: string; to: string }) {
  const t = useTranslations("analytics");
  const [heat, setHeat] = useState<Heatmap | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const h = await getPurchaseHeatmap({ from, to });
        if (!active) return;
        setHeat(h);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : t("heatmap.error"));
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [from, to, t]);

  return (
    <>
      <h2 className="text-label-md uppercase tracking-wide text-subtle">{t("heatmap.title")}</h2>
      <p className="mb-md text-body-sm text-subtle">{t("heatmap.subtitle")}</p>
      {loading ? (
        <div className="h-40 animate-pulse rounded-xs bg-hairline" />
      ) : error ? (
        <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : !heat || heat.cells.length === 0 ? (
        <p className="py-md text-body-sm text-subtle">{t("heatmap.empty")}</p>
      ) : (
        <HeatGrid heat={heat} t={t} />
      )}
    </>
  );
}

type Translate = (key: string, values?: Record<string, string | number>) => string;

function HeatGrid({ heat, t }: { heat: Heatmap; t: Translate }) {
  const grid = Array.from({ length: 7 }, () => Array(24).fill(0) as number[]);
  let max = 0;
  for (const c of heat.cells) {
    const row = DOW_TO_ROW[c.dow] ?? 0;
    if (c.hour >= 0 && c.hour < 24) {
      grid[row][c.hour] = c.purchases;
      if (c.purchases > max) max = c.purchases;
    }
  }
  const level = (v: number): string => {
    if (v <= 0) return "bg-surface-tint";
    const f = v / (max || 1);
    if (f > 0.66) return "bg-brand";
    if (f > 0.33) return "bg-brand/60";
    return "bg-brand/30";
  };
  return (
    <div className="overflow-x-auto">
      <div className="min-w-[34rem]">
        <div className="flex items-center gap-px pl-10">
          {Array.from({ length: 24 }).map((_, h) => (
            <span key={h} className="flex-1 text-center text-micro leading-none text-subtle">
              {h % 3 === 0 ? h : ""}
            </span>
          ))}
        </div>
        {grid.map((rowVals, r) => (
          <div key={r} className="mt-px flex items-center gap-px">
            <span className="w-10 shrink-0 pr-sm text-right text-body-sm text-subtle">{t(DAY_KEYS[r])}</span>
            {rowVals.map((v, h) => (
              <span
                key={h}
                title={t("heatmap.cellTitle", { day: t(DAY_KEYS[r]), hour: h, count: v })}
                className={`h-4 flex-1 rounded-xs sm:h-5 ${level(v)}`}
              />
            ))}
          </div>
        ))}
        <div className="mt-sm flex items-center justify-end gap-xs text-body-sm text-subtle">
          <span>{t("heatmap.less")}</span>
          <span className="size-3 rounded-xs bg-surface-tint" />
          <span className="size-3 rounded-xs bg-brand/30" />
          <span className="size-3 rounded-xs bg-brand/60" />
          <span className="size-3 rounded-xs bg-brand" />
          <span>{t("heatmap.more")}</span>
        </div>
      </div>
    </div>
  );
}
