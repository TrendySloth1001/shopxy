"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useTranslations } from "next-intl";
import { Mail, RefreshCw } from "@/shared/icons";
import { useAuth } from "@/features/auth/auth-context";
import { listIncomingInvitations } from "@/features/invitations/api";
import { getPayoutStatus } from "@/features/shop/api";
import { dateInputToIso } from "@/shared/datetime";
import {
  fetchDashboardStats,
  type DashboardPeriod,
  type DashboardStats,
} from "./stats";
import { PeriodSwitcher } from "./components/period-switcher";
import { Alerts } from "./components/alerts";
import { KpiRow } from "./components/kpi-row";
import { TrendCard } from "./components/trend-card";
import { Analytics } from "./components/analytics";
import { ActionCenter } from "./components/action-center";
import { Operations } from "./components/operations";
import { RecentActivity } from "./components/recent-activity";
import { OnboardingChecklist } from "./components/onboarding-checklist";

const PERIOD_STORE_KEY = "sx_dashboard_period";
const PERIODS_SET = new Set<DashboardPeriod>(["today", "week", "month"]);

function greetingKey(): "morning" | "afternoon" | "evening" {
  const h = new Date().getHours();
  if (h < 12) return "morning";
  if (h < 17) return "afternoon";
  return "evening";
}

function initialPeriod(): DashboardPeriod {
  if (typeof localStorage === "undefined") return "today";
  const v = localStorage.getItem(PERIOD_STORE_KEY) as DashboardPeriod | null;
  return v && PERIODS_SET.has(v) ? v : "today";
}

function useDashboard(period: DashboardPeriod) {
  const t = useTranslations("dashboard");
  const [data, setData] = useState<DashboardStats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true); // first load (no data yet)
  const [refreshing, setRefreshing] = useState(false); // period change / manual refresh
  const [nonce, setNonce] = useState(0);
  const hasData = useRef(false);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    if (hasData.current) setRefreshing(true);
    else setLoading(true);
    void (async () => {
      try {
        const stats = await fetchDashboardStats(period);
        if (!active) return;
        setData(stats);
        hasData.current = true;
        setError(null);
      } catch (e) {
        if (!active) return;
        setError(e instanceof Error ? e.message : t("loadError"));
      } finally {
        if (active) {
          setLoading(false);
          setRefreshing(false);
        }
      }
    })();
    return () => {
      active = false;
    };
  }, [period, nonce, t]);

  return { data, error, loading, refreshing, reload };
}

export function DashboardHome() {
  const { user } = useAuth();
  const router = useRouter();
  const t = useTranslations("dashboard");
  const [period, setPeriod] = useState<DashboardPeriod>(initialPeriod);
  const { data, error, loading, refreshing, reload } = useDashboard(period);

  function changePeriod(p: DashboardPeriod) {
    setPeriod(p);
    if (typeof localStorage !== "undefined") localStorage.setItem(PERIOD_STORE_KEY, p);
  }

  // Cashier kiosk lock: a plain Cashier lands on the till, not the dashboard.
  const isKiosk = user?.shopRole === "CASHIER";
  useEffect(() => {
    if (isKiosk) router.replace("/dashboard/pos");
  }, [isKiosk, router]);
  if (isKiosk) return null;

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      {/* Header */}
      <div className="flex flex-wrap items-end justify-between gap-md">
        <div>
          <h1 className="text-headline-md text-ink">
            {t(`greeting.${greetingKey()}`)}
            {user?.name ? `, ${user.name.split(" ")[0]}` : ""}
          </h1>
          <p className="mt-xs text-body-md text-muted">
            {t("subtitle", { shop: user?.shopName ?? t("yourShop") })}
          </p>
        </div>
        <div className="flex items-center gap-sm">
          <PeriodSwitcher value={period} onChange={changePeriod} />
          <button
            type="button"
            onClick={reload}
            disabled={loading || refreshing}
            aria-label={t("refresh")}
            className="inline-flex size-9 items-center justify-center rounded-button border border-hairline text-muted transition-colors hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:opacity-50"
          >
            <RefreshCw size={16} className={refreshing ? "animate-spin" : ""} aria-hidden="true" />
          </button>
        </div>
      </div>

      <PendingInviteCallout />

      <div className="mt-xxl">
        {loading && !data ? (
          <DashboardSkeleton />
        ) : error && !data ? (
          <ErrorView message={error} onRetry={reload} />
        ) : data ? (
          <DashboardBody stats={data} period={period} refreshing={refreshing} />
        ) : null}
      </div>
    </div>
  );
}

function DashboardBody({
  stats,
  period,
  refreshing,
}: {
  stats: DashboardStats;
  period: DashboardPeriod;
  refreshing: boolean;
}) {
  const [payoutsEnabled, setPayoutsEnabled] = useState(true); // assume enabled until known

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const acct = await getPayoutStatus();
        if (active) setPayoutsEnabled(Boolean(acct?.payoutsEnabled));
      } catch {
        /* leave default */
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  // meta.from/to are date-only IST keys (YYYY-MM-DD); the reports endpoints the
  // KPI drawers call validate `from`/`to` as full ISO datetimes, so widen them
  // to a day-spanning ISO range. Memoised so the drawers don't refetch on every
  // dashboard re-render (only when the period window changes).
  const kpiRange = useMemo(
    () => ({
      from: dateInputToIso(stats.meta.from),
      to: dateInputToIso(stats.meta.to, true),
    }),
    [stats.meta.from, stats.meta.to],
  );

  const isFresh = !stats.onboarding.hasInvoices && stats.onboarding.totalProducts === 0;

  // A fresh shop gets guidance, not a wall of zeros.
  if (isFresh) {
    return (
      <div className="space-y-xxl">
        {stats.alerts.length > 0 ? <Alerts alerts={stats.alerts} /> : null}
        <OnboardingChecklist onboarding={stats.onboarding} payoutsEnabled={payoutsEnabled} />
      </div>
    );
  }

  return (
    <div className="space-y-xxl">
      {stats.alerts.length > 0 ? <Alerts alerts={stats.alerts} /> : null}

      {/* Period-scoped money sections dim while a new period loads. */}
      <div className={refreshing ? "pointer-events-none opacity-60 transition-opacity" : "transition-opacity"}>
        <div className="space-y-xxl" aria-busy={refreshing}>
          {stats.kpis ? <KpiRow kpis={stats.kpis} period={period} range={kpiRange} /> : null}
          {stats.trend ? <TrendCard trend={stats.trend} /> : null}
          {stats.insights ? <Analytics insights={stats.insights} /> : null}
        </div>
      </div>

      <ActionCenter queue={stats.actionQueue} />

      <Operations
        till={stats.operations.till}
        gstMtd={stats.operations.gstMtd}
        inventoryValue={stats.operations.inventoryValue}
      />

      <RecentActivity transactions={stats.recent} />
    </div>
  );
}

/**
 * Brand callout for pending incoming invitations (another shop inviting this user
 * as a customer/vendor/team member). Links to the notifications Invites tab.
 */
function PendingInviteCallout() {
  const t = useTranslations("dashboard");
  const [count, setCount] = useState(0);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const rows = await listIncomingInvitations();
        if (active) setCount(rows.filter((i) => i.status === "PENDING").length);
      } catch {
        /* no callout on failure */
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  if (count === 0) return null;
  return (
    <Link
      href="/dashboard/notifications"
      className="mt-lg flex items-center gap-md rounded-lg bg-brand-soft px-md py-sm text-brand-strong transition-colors hover:bg-brand-soft/70 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <Mail size={18} className="shrink-0" aria-hidden="true" />
      <span className="min-w-0 flex-1 text-body-md">
        {t("pendingInvites", { count })}
      </span>
      <span className="shrink-0 text-label-md underline-offset-2">{t("view")}</span>
    </Link>
  );
}

function ErrorView({ message, onRetry }: { message: string; onRetry: () => void }) {
  const t = useTranslations("dashboard");
  return (
    <div className="flex flex-col items-start gap-md">
      <p className="text-body-md text-muted">{message}</p>
      <button
        type="button"
        onClick={onRetry}
        className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        {t("tryAgain")}
      </button>
    </div>
  );
}

function DashboardSkeleton() {
  return (
    <div className="animate-pulse space-y-xxl">
      <div className="grid grid-cols-2 gap-md lg:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="h-28 rounded-lg border border-hairline" />
        ))}
      </div>
      <div className="h-52 rounded-lg border border-hairline" />
      <div className="grid grid-cols-2 gap-md lg:grid-cols-6">
        {[0, 1, 2, 3, 4, 5].map((i) => (
          <div key={i} className="h-16 rounded-lg border border-hairline" />
        ))}
      </div>
    </div>
  );
}
