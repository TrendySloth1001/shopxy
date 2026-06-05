"use client";

import { useEffect, useState } from "react";
import { Percent, Repeat, UserPlus, Users, type LucideIcon } from "lucide-react";
import { formatINR } from "@/shared/money";
import { getCustomerRetention } from "./api";
import type { Retention } from "./schema";

const intFmt = new Intl.NumberFormat("en-IN");
const int = (v: number) => intFmt.format(Math.round(v));
const pct = (v: number) => `${(v * 100).toFixed(1)}%`;

/**
 * New-vs-returning split, repeat rate and top customers from confirmed sales.
 * Self-fetches for the range; rendered lazily by the page.
 */
export function RetentionSection({ from, to }: { from: string; to: string }) {
  const [r, setR] = useState<Retention | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const data = await getCustomerRetention({ from, to });
        if (!active) return;
        setR(data);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load customers.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [from, to]);

  return (
    <>
      <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">Customers</h2>
      {loading ? (
        <div className="h-40 animate-pulse rounded-xs bg-hairline" />
      ) : error ? (
        <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : !r || r.totalCustomers === 0 ? (
        <p className="py-md text-body-sm text-subtle">No customers bought in this range.</p>
      ) : (
        <Block r={r} />
      )}
    </>
  );
}

function Block({ r }: { r: Retention }) {
  const newPct = r.totalCustomers > 0 ? Math.round((r.newCustomers / r.totalCustomers) * 100) : 0;
  return (
    <div>
      <div className="grid grid-cols-2 gap-x-lg gap-y-xl sm:grid-cols-4">
        <Stat icon={Users} label="Customers" value={int(r.totalCustomers)} />
        <Stat icon={UserPlus} label="New" value={int(r.newCustomers)} />
        <Stat icon={Repeat} label="Returning" value={int(r.returningCustomers)} />
        <Stat icon={Percent} label="Repeat rate" value={pct(r.repeatRate)} hint="Bought before" />
      </div>

      <div className="mt-lg flex h-3 w-full overflow-hidden rounded-full bg-hairline">
        {r.newCustomers > 0 ? <span className="block h-full bg-accent-indigo" style={{ width: `${newPct}%` }} /> : null}
        {r.returningCustomers > 0 ? <span className="block h-full bg-brand" style={{ width: `${100 - newPct}%` }} /> : null}
      </div>
      <div className="mt-xs flex gap-lg text-body-sm text-subtle">
        <span className="inline-flex items-center gap-xs">
          <span className="size-2 rounded-full bg-accent-indigo" /> New
        </span>
        <span className="inline-flex items-center gap-xs">
          <span className="size-2 rounded-full bg-brand" /> Returning
        </span>
      </div>

      {r.top.length > 0 ? (
        <div className="mt-lg">
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">Top customers</p>
          {r.top.map((c, i) => (
            <div key={i} className="flex items-center justify-between gap-md border-b border-hairline py-sm">
              <span className="min-w-0 flex-1 truncate text-body-md text-ink">{c.name ?? "Walk-in"}</span>
              <span className="shrink-0 text-body-sm text-subtle">
                {c.orders} {c.orders === 1 ? "order" : "orders"}
              </span>
              <span className="shrink-0 text-body-md font-semibold tabular-nums text-ink">{formatINR(c.revenue)}</span>
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}

function Stat({ icon: Icon, label, value, hint }: { icon: LucideIcon; label: string; value: string; hint?: string }) {
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
