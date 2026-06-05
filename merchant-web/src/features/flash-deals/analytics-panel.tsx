"use client";

import { useEffect, useState } from "react";
import { getFlashDealAnalytics } from "./api";
import type { FlashAnalytics } from "./schema";

/**
 * Self-fetching analytics panel for a flash deal — rendered inline on the deal
 * detail page. Shows headline stats plus an hourly sold/taps/views breakdown.
 */
export function FlashAnalyticsPanel({ id }: { id: number }) {
  const [data, setData] = useState<FlashAnalytics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const a = await getFlashDealAnalytics(id);
        if (active) setData(a);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load analytics.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [id]);

  if (loading) return <p className="py-lg text-body-sm text-subtle">Loading analytics…</p>;
  if (error || !data) {
    return (
      <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">
        {error ?? "No analytics."}
      </p>
    );
  }

  const totals = data.series.reduce(
    (acc, r) => ({ sold: acc.sold + r.sold, taps: acc.taps + r.taps, views: acc.views + r.views }),
    { sold: 0, taps: 0, views: 0 },
  );
  const conversion = totals.taps > 0 ? Math.round((totals.sold / totals.taps) * 100) : 0;
  const maxTaps = Math.max(1, ...data.series.map((r) => r.taps));

  return (
    <div className="flex flex-col gap-lg">
      <div className="grid grid-cols-2 gap-md sm:grid-cols-4">
        <Stat label="Claimed" value={`${data.soldCount}/${data.stockLimit}`} />
        <Stat label="Views" value={totals.views.toLocaleString("en-IN")} />
        <Stat label="Taps" value={totals.taps.toLocaleString("en-IN")} />
        <Stat label="Tap → buy" value={`${conversion}%`} />
      </div>

      <div>
        <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">By hour</p>
        {data.series.length === 0 ? (
          <p className="rounded-md bg-surface-tint px-md py-lg text-center text-body-sm text-muted">
            No activity recorded yet.
          </p>
        ) : (
          <div>
            {data.series.map((r) => (
              <div key={r.hour} className="border-b border-hairline py-sm">
                <div className="flex items-center justify-between gap-md text-body-sm">
                  <span className="text-muted">{fmtHour(r.hour)}</span>
                  <span className="text-ink">
                    {r.sold} sold · {r.taps} taps · {r.views} views
                  </span>
                </div>
                <div className="mt-xs h-1.5 w-full overflow-hidden rounded-full bg-surface-tint">
                  <div
                    className="h-full rounded-full bg-flash-deal"
                    style={{ width: `${(r.taps / maxTaps) * 100}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

const hourFmt = new Intl.DateTimeFormat("en-IN", {
  day: "numeric",
  month: "short",
  hour: "numeric",
});
function fmtHour(iso: string): string {
  const d = new Date(iso);
  return Number.isNaN(d.getTime()) ? iso : hourFmt.format(d);
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-hairline px-md py-sm">
      <p className="text-label-md text-subtle">{label}</p>
      <p className="mt-px text-title-md text-ink">{value}</p>
    </div>
  );
}
