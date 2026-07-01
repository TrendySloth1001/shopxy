"use client";

import { useEffect, useState } from "react";
import { useTranslations } from "next-intl";
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
  const t = useTranslations("analytics");
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
        if (active) setError(e instanceof Error ? e.message : t("customers.error"));
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
      <h2 className="mb-sm text-label-md uppercase tracking-wide text-subtle">{t("customers.title")}</h2>
      {loading ? (
        <div className="h-40 animate-pulse rounded-xs bg-hairline" />
      ) : error ? (
        <p className="rounded-md bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      ) : !r || r.totalCustomers === 0 ? (
        <p className="py-md text-body-sm text-subtle">{t("customers.empty")}</p>
      ) : (
        <Block r={r} t={t} />
      )}
    </>
  );
}

type Translate = (key: string, values?: Record<string, string | number>) => string;

function Block({ r, t }: { r: Retention; t: Translate }) {
  const newPct = r.totalCustomers > 0 ? Math.round((r.newCustomers / r.totalCustomers) * 100) : 0;
  return (
    <div>
      <div className="grid grid-cols-2 gap-x-lg gap-y-xl sm:grid-cols-4">
        <Stat icon={Users} label={t("customers.total")} value={int(r.totalCustomers)} />
        <Stat icon={UserPlus} label={t("customers.new")} value={int(r.newCustomers)} />
        <Stat icon={Repeat} label={t("customers.returning")} value={int(r.returningCustomers)} />
        <Stat icon={Percent} label={t("customers.repeatRate")} value={pct(r.repeatRate)} hint={t("customers.repeatRateHint")} />
      </div>

      <div className="mt-lg flex h-3 w-full overflow-hidden rounded-full bg-hairline">
        {r.newCustomers > 0 ? <span className="block h-full bg-accent-indigo" style={{ width: `${newPct}%` }} /> : null}
        {r.returningCustomers > 0 ? <span className="block h-full bg-brand" style={{ width: `${100 - newPct}%` }} /> : null}
      </div>
      <div className="mt-xs flex gap-lg text-body-sm text-subtle">
        <span className="inline-flex items-center gap-xs">
          <span className="size-2 rounded-full bg-accent-indigo" /> {t("customers.new")}
        </span>
        <span className="inline-flex items-center gap-xs">
          <span className="size-2 rounded-full bg-brand" /> {t("customers.returning")}
        </span>
      </div>

      {r.top.length > 0 ? (
        <div className="mt-lg">
          <p className="mb-sm text-label-md uppercase tracking-wide text-subtle">{t("customers.topTitle")}</p>
          {r.top.map((c, i) => (
            <div key={i} className="flex items-center justify-between gap-md border-b border-hairline py-sm">
              <span className="min-w-0 flex-1 truncate text-body-md text-ink">{c.name ?? t("customers.walkIn")}</span>
              <span className="shrink-0 text-body-sm text-subtle">
                {t("customers.ordersCount", { count: c.orders })}
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
