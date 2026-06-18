"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { ArrowDownLeft, ArrowUpRight, ArrowLeftRight, Mail, Timer, Wallet, X } from "lucide-react";
import { useAuth } from "@/features/auth/auth-context";
import { Divider } from "@/shared/ui/divider";
import { listIncomingInvitations } from "@/features/invitations/api";
import { getPayoutStatus } from "@/features/shop/api";
import {
  fetchDashboardStats,
  type DashboardDraft,
  type DashboardStats,
  type DashboardTransaction,
} from "./stats";

const inr = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
});
const inr2 = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  minimumFractionDigits: 2,
});

function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) return "Good morning";
  if (h < 17) return "Good afternoon";
  return "Good evening";
}

function useDashboardStats() {
  const [data, setData] = useState<DashboardStats | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [nonce, setNonce] = useState(0);

  const reload = useCallback(() => {
    setLoading(true);
    setError(null);
    setNonce((n) => n + 1);
  }, []);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const stats = await fetchDashboardStats();
        if (!active) return;
        setData(stats);
        setError(null);
      } catch (e) {
        if (!active) return;
        setError(e instanceof Error ? e.message : "Could not load the dashboard.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce]);

  return { data, error, loading, reload };
}

export function DashboardHome() {
  const { user } = useAuth();
  const { data, error, loading, reload } = useDashboardStats();

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      {/* Greeting */}
      <div className="flex flex-wrap items-end justify-between gap-md">
        <div>
          <h1 className="text-headline-md text-ink">
            {greeting()}
            {user?.name ? `, ${user.name.split(" ")[0]}` : ""}
          </h1>
          <p className="mt-xs text-body-md text-muted">
            Here’s how {user?.shopName ?? "your shop"} is doing.
          </p>
        </div>
        <p className="text-label-md text-muted">
          {new Date().toLocaleDateString("en-IN", {
            weekday: "short",
            day: "numeric",
            month: "short",
          })}
        </p>
      </div>

      <PendingInviteCallout />
      <PayoutNudge />

      {loading && !data ? (
        <DashboardSkeleton />
      ) : error && !data ? (
        <ErrorView message={error} onRetry={reload} />
      ) : data ? (
        <DashboardBody stats={data} />
      ) : null}
    </div>
  );
}

/**
 * Brand callout at the top of the dashboard for pending incoming invitations
 * (another shop inviting this user as a customer/vendor/team member). Mirrors
 * the Flutter dashboard callout; links to the notifications Invites tab.
 */
function PendingInviteCallout() {
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
      <Mail size={18} className="shrink-0" />
      <span className="min-w-0 flex-1 text-body-md">
        You have {count} pending invitation{count === 1 ? "" : "s"} — review and accept.
      </span>
      <span className="shrink-0 text-label-md underline-offset-2">View</span>
    </Link>
  );
}

const PAYOUT_NUDGE_KEY = "sx_payout_nudge_dismissed";

/**
 * Once-per-session nudge to finish payout (Razorpay Route) onboarding when the
 * settlement account isn't ACTIVE yet. Dismissible; mirrors the Flutter nudge.
 */
function PayoutNudge() {
  const [show, setShow] = useState(false);

  useEffect(() => {
    let active = true;
    if (typeof sessionStorage !== "undefined" && sessionStorage.getItem(PAYOUT_NUDGE_KEY) === "1") {
      return;
    }
    void (async () => {
      try {
        const acct = await getPayoutStatus();
        // Nudge until payouts are actually enabled (the real signal); a linked
        // but still-under-review account still needs attention.
        if (active && !acct?.payoutsEnabled) setShow(true);
      } catch {
        /* no nudge on failure */
      }
    })();
    return () => {
      active = false;
    };
  }, []);

  function dismiss() {
    setShow(false);
    if (typeof sessionStorage !== "undefined") sessionStorage.setItem(PAYOUT_NUDGE_KEY, "1");
  }

  if (!show) return null;
  return (
    <div className="mt-md flex items-center gap-md rounded-lg bg-accent-amber-soft px-md py-sm text-accent-amber">
      <Wallet size={18} className="shrink-0" />
      <Link href="/dashboard/payouts" className="min-w-0 flex-1 text-body-md underline-offset-2 hover:underline">
        Finish setting up payouts to receive settlements for online orders.
      </Link>
      <button type="button" onClick={dismiss} aria-label="Dismiss" className="shrink-0 rounded-md p-xs hover:opacity-70">
        <X size={16} />
      </button>
    </div>
  );
}

function DashboardBody({ stats }: { stats: DashboardStats }) {
  const hasDrafts = stats.draftInvoices.count > 0;
  return (
    <>
      <Divider className="my-xxl" />
      <ValueHeadline value={stats.totalStockValue} />

      <div className="mt-xxl">
        <QuickStats stats={stats} />
      </div>

      <Divider className="my-xxl" />
      <StockPulse stats={stats} />

      <Divider className="my-xxl" />
      {/* On wide screens, drafts + activity sit side by side; stacked otherwise. */}
      <div className={`grid gap-xxl ${hasDrafts ? "xl:grid-cols-2" : ""}`}>
        {hasDrafts ? <DraftsSection stats={stats} /> : null}
        <ActivitySection transactions={stats.recentTransactions} />
      </div>
    </>
  );
}

function Eyebrow({ children }: { children: React.ReactNode }) {
  return (
    <p className="text-label-md uppercase tracking-wide text-muted">{children}</p>
  );
}

function ValueHeadline({ value }: { value: number }) {
  return (
    <section>
      <div className="flex items-center gap-sm">
        <span className="size-2 rounded-full bg-brand" />
        <Eyebrow>Inventory value</Eyebrow>
      </div>
      <p className="mt-sm text-display-sm tabular-nums text-ink">{inr.format(value)}</p>
      <p className="mt-xs text-body-sm text-muted">
        Cost basis of stock currently on hand.
      </p>
    </section>
  );
}

function QuickStats({ stats }: { stats: DashboardStats }) {
  const items: Array<[string, number]> = [
    ["Products", stats.totalProducts],
    ["Active", stats.activeProducts],
    ["Categories", stats.totalCategories],
  ];
  return (
    <div className="grid grid-cols-3 divide-x divide-hairline">
      {items.map(([label, value], i) => (
        <div key={label} className={i === 0 ? "pr-lg" : "px-lg"}>
          <p className="text-headline-sm tabular-nums text-ink">{value}</p>
          <p className="mt-xs text-label-md text-muted">{label}</p>
        </div>
      ))}
    </div>
  );
}

function StockPulse({ stats }: { stats: DashboardStats }) {
  const total = stats.totalProducts;
  const low = stats.lowStockCount;
  const out = stats.outOfStockCount;
  const healthy = Math.max(0, total - low - out);
  const pct = total === 0 ? 0 : Math.round((healthy / total) * 100);

  const segments: Array<[number, string]> = [
    [healthy, "bg-brand"],
    [low, "bg-warning"],
    [out, "bg-error"],
  ];
  const legend: Array<[string, string, number]> = [
    ["In good stock", "bg-brand", healthy],
    ["Low", "bg-warning", low],
    ["Out", "bg-error", out],
  ];

  return (
    <section>
      <div className="flex items-center justify-between">
        <Eyebrow>Stock pulse</Eyebrow>
        <span className="text-label-md text-brand-strong">
          {total === 0 ? "—" : `${pct}% healthy`}
        </span>
      </div>
      <div className="mt-md flex h-2 w-full overflow-hidden rounded-full bg-hairline">
        {total > 0 &&
          segments.map(([count, color], i) =>
            count > 0 ? (
              <span key={i} className={color} style={{ flexGrow: count }} />
            ) : null,
          )}
      </div>
      <div className="mt-md grid grid-cols-3 gap-md">
        {legend.map(([label, color, value]) => (
          <div key={label}>
            <div className="flex items-center gap-sm">
              <span className={`size-2 rounded-full ${color}`} />
              <span className="text-title-md tabular-nums text-ink">{value}</span>
            </div>
            <p className="mt-xs text-body-sm text-muted">{label}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

function DraftsSection({ stats }: { stats: DashboardStats }) {
  const count = stats.draftInvoices.count;
  return (
    <section className="min-w-0">
      <Eyebrow>Pending drafts</Eyebrow>
      <p className="mt-xs text-body-md text-ink">
        {count} draft {count === 1 ? "invoice" : "invoices"} waiting to be confirmed.
      </p>
      <p className="text-body-sm text-muted">Stock isn’t deducted until confirmed.</p>
      <ul className="mt-md">
        {stats.draftInvoices.recent.map((d) => (
          <DraftRow key={d.id} draft={d} />
        ))}
      </ul>
    </section>
  );
}

function DraftRow({ draft }: { draft: DashboardDraft }) {
  const isSale = draft.type === "SALE";
  const counterparty = isSale
    ? (draft.customerName ?? "Walk-in customer")
    : (draft.vendorName ?? "Unknown vendor");
  const items = draft._count?.items ?? 0;
  return (
    <li>
      <Link
        href={`/dashboard/invoices/${draft.id}`}
        className="flex items-center gap-md border-t border-hairline py-md transition-colors hover:bg-surface-tint"
      >
        {isSale ? (
          <ArrowUpRight size={16} className="shrink-0 text-success" />
        ) : (
          <ArrowDownLeft size={16} className="shrink-0 text-accent-indigo" />
        )}
        <div className="min-w-0 flex-1">
          <p className="truncate text-body-md text-ink">{counterparty}</p>
          <p className="text-body-sm text-muted">
            {draft.invoiceNo} · {items} {items === 1 ? "item" : "items"}
          </p>
        </div>
        <span className="shrink-0 text-body-md tabular-nums text-ink">
          {inr2.format(draft.total)}
        </span>
      </Link>
    </li>
  );
}

function ActivitySection({
  transactions,
}: {
  transactions: DashboardTransaction[];
}) {
  return (
    <section className="min-w-0">
      <Eyebrow>Recent activity</Eyebrow>
      {transactions.length === 0 ? (
        <div className="mt-md flex items-center gap-md py-lg text-muted">
          <Timer size={20} className="text-subtle" />
          <span className="text-body-md">No recent stock movements.</span>
        </div>
      ) : (
        <ul className="mt-md">
          {transactions.map((t) => (
            <ActivityRow key={t.id} tx={t} />
          ))}
        </ul>
      )}
    </section>
  );
}

function ActivityRow({ tx }: { tx: DashboardTransaction }) {
  const isIn = tx.direction === "IN" || tx.type === "STOCK_IN";
  const isOut = tx.direction === "OUT" || tx.type === "STOCK_OUT";
  const accent = isIn ? "text-success" : isOut ? "text-error" : "text-accent-indigo";
  const accentSoft = isIn
    ? "bg-success-soft"
    : isOut
      ? "bg-error-soft"
      : "bg-accent-indigo-soft";
  const Icon = isIn ? ArrowDownLeft : isOut ? ArrowUpRight : ArrowLeftRight;
  const sign = isIn ? "+" : isOut ? "−" : "";
  const qty = Number.isInteger(tx.quantity)
    ? tx.quantity.toString()
    : tx.quantity.toFixed(2);
  const time = new Date(tx.createdAt).toLocaleString("en-IN", {
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });

  // Link the row to its source document when one exists.
  const sourceHref =
    tx.sourceId != null && tx.sourceType === "INVOICE"
      ? `/dashboard/invoices/${tx.sourceId}`
      : tx.sourceId != null && tx.sourceType === "CHALLAN"
        ? `/dashboard/challans/${tx.sourceId}`
        : null;

  const inner = (
    <>
      <span
        className={`flex size-9 shrink-0 items-center justify-center rounded-md ${accentSoft}`}
      >
        <Icon size={18} className={accent} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="truncate text-body-md text-ink">
          {tx.product?.name ?? `Product #${tx.productId}`}
        </p>
        <p className="text-body-sm text-muted">{time}</p>
      </div>
      <span className={`shrink-0 text-title-md tabular-nums ${accent}`}>
        {sign}
        {qty}
      </span>
    </>
  );

  return (
    <li>
      {sourceHref ? (
        <Link
          href={sourceHref}
          className="flex items-center gap-md border-t border-hairline py-md transition-colors hover:bg-surface-tint"
        >
          {inner}
        </Link>
      ) : (
        <div className="flex items-center gap-md border-t border-hairline py-md">{inner}</div>
      )}
    </li>
  );
}

function ErrorView({
  message,
  onRetry,
}: {
  message: string;
  onRetry: () => void;
}) {
  return (
    <div className="mt-xxxl flex flex-col items-start gap-md">
      <p className="text-body-md text-muted">{message}</p>
      <button
        type="button"
        onClick={onRetry}
        className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        Try again
      </button>
    </div>
  );
}

function DashboardSkeleton() {
  return (
    <div className="mt-xxl animate-pulse">
      <div className="h-3 w-32 rounded-xs bg-hairline" />
      <div className="mt-md h-10 w-64 rounded-sm bg-hairline" />
      <div className="mt-xxl grid grid-cols-3 gap-lg">
        {[0, 1, 2].map((i) => (
          <div key={i}>
            <div className="h-7 w-12 rounded-sm bg-hairline" />
            <div className="mt-sm h-3 w-16 rounded-xs bg-hairline" />
          </div>
        ))}
      </div>
      <div className="mt-xxl h-2 w-full rounded-full bg-hairline" />
      <div className="mt-xxl space-y-md">
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="flex items-center gap-md">
            <div className="size-9 rounded-md bg-hairline" />
            <div className="flex-1">
              <div className="h-3 w-40 rounded-xs bg-hairline" />
              <div className="mt-sm h-3 w-24 rounded-xs bg-hairline" />
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
