"use client";

import { useCallback, useEffect, useState, startTransition } from "react";
import {
  Wallet,
  RefreshCcw,
  Tag,
  Users,
  Award,
  ShoppingBag,
  Undo2,
  PlusCircle,
  History,
} from "lucide-react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { Divider } from "@/shared/ui/divider";
import { formatINR } from "@/shared/format";
import { formatDateTime } from "@/shared/datetime";
import { fetchWallet } from "@/features/account-extras/api";
import { isWalletCredit } from "@/features/account-extras/types";
import type { WalletSnapshot, WalletEntry, WalletSource } from "@/features/account-extras/types";

export default function WalletPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <WalletBody />
    </RequireAuth>
  );
}

function WalletBody() {
  const [snapshot, setSnapshot] = useState<WalletSnapshot | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setLoading(true);
    setError(null);
    fetchWallet()
      .then((data) => {
        setSnapshot(data);
        setLoading(false);
      })
      .catch((e: unknown) => {
        setError(e instanceof Error ? e.message : "Could not load wallet.");
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    startTransition(load);
  }, [load]);

  return (
    <main className="mx-auto max-w-content px-lg py-xxxl">
      <div>
        <p className="text-label-md uppercase tracking-wide text-brand">Account</p>
        <h1 className="mt-xs text-headline-md text-ink">Wallet</h1>
        <p className="mt-xs text-body-md text-muted">
          Your wallet balance and recent transaction history.
        </p>
      </div>

      <Divider className="my-xl" />

      {loading ? (
        <WalletSkeleton />
      ) : error ? (
        <ErrorState message={error} onRetry={load} />
      ) : snapshot ? (
        <WalletContent snapshot={snapshot} onRefresh={load} />
      ) : null}
    </main>
  );
}

function WalletContent({
  snapshot,
  onRefresh,
}: {
  snapshot: WalletSnapshot;
  onRefresh: () => void;
}) {
  return (
    <>
      {/* Balance hero card */}
      <BalanceCard balance={snapshot.balance} onRefresh={onRefresh} />

      {/* Recent activity */}
      <div className="mt-xxl">
        <p className="mb-sm text-label-md uppercase tracking-wide text-muted">Recent activity</p>
        {snapshot.entries.length === 0 ? (
          <EmptyLedger />
        ) : (
          <div className="overflow-hidden rounded-md border border-hairline bg-white">
            {snapshot.entries.map((entry, i) => (
              <div key={entry.id}>
                {i > 0 && <Divider inset />}
                <LedgerRow entry={entry} />
              </div>
            ))}
          </div>
        )}
      </div>
    </>
  );
}

// ── Balance card ────────────────────────────────────────────────────────────

function BalanceCard({
  balance,
  onRefresh,
}: {
  balance: number;
  onRefresh: () => void;
}) {
  return (
    <div className="rounded-lg bg-ink p-lg">
      <div className="flex items-center gap-sm">
        <Wallet size={18} className="text-white opacity-70" />
        <span className="text-label-md uppercase tracking-wide text-white opacity-70">
          Wallet balance
        </span>
      </div>
      <p className="mt-sm text-headline-lg font-bold text-white">{formatINR(balance)}</p>
      <p className="mt-xs text-body-sm text-white opacity-70">
        Use at checkout — refunds, coupons and rewards land here.
      </p>
      <div className="mt-md flex items-center gap-sm">
        <button
          type="button"
          onClick={onRefresh}
          className="inline-flex h-8 items-center gap-xs rounded-button border border-white/20 px-sm text-label-md text-white transition-opacity hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/40"
        >
          <RefreshCcw size={12} /> Refresh
        </button>
      </div>
    </div>
  );
}

// ── Ledger row ──────────────────────────────────────────────────────────────

const SOURCE_META: Record<
  WalletSource,
  { Icon: React.ComponentType<{ size: number; className?: string }>; cls: string }
> = {
  REFUND: { Icon: Undo2, cls: "bg-success-soft text-success" },
  COUPON: { Icon: Tag, cls: "bg-accent-amber-soft text-accent-amber" },
  REFERRAL: { Icon: Users, cls: "bg-accent-indigo-soft text-accent-indigo" },
  LOYALTY: { Icon: Award, cls: "bg-accent-indigo-soft text-accent-indigo" },
  CHECKOUT: { Icon: ShoppingBag, cls: "bg-error-soft text-error" },
  TOPUP: { Icon: PlusCircle, cls: "bg-success-soft text-success" },
  CANCEL: { Icon: Undo2, cls: "bg-success-soft text-success" },
  MANUAL: { Icon: Wallet, cls: "bg-surface-tint text-muted" },
};

function LedgerRow({ entry }: { entry: WalletEntry }) {
  const credit = isWalletCredit(entry);
  const meta = SOURCE_META[entry.source] ?? SOURCE_META.MANUAL;
  const { Icon, cls } = meta;
  const sign = credit ? "+" : "-";
  const amountClass = credit ? "text-success" : "text-error";

  return (
    <div className="flex items-center gap-md px-md py-md">
      <span
        className={`flex size-10 shrink-0 items-center justify-center rounded-full ${cls}`}
      >
        <Icon size={18} />
      </span>
      <div className="min-w-0 flex-1">
        <p className="line-clamp-2 text-body-md font-semibold text-ink">
          {entry.description}
        </p>
        <p className="mt-xs text-label-md text-muted">{formatDateTime(entry.createdAt)}</p>
      </div>
      <span className={`shrink-0 text-label-lg font-bold ${amountClass}`}>
        {sign}
        {formatINR(Math.abs(entry.amount))}
      </span>
    </div>
  );
}

// ── Empty ledger ─────────────────────────────────────────────────────────────

function EmptyLedger() {
  return (
    <div className="flex flex-col items-center gap-sm rounded-md border border-hairline bg-white px-lg py-xl text-center">
      <History size={28} className="text-muted" />
      <p className="text-body-md font-semibold text-muted">No activity yet</p>
    </div>
  );
}

// ── Skeleton ─────────────────────────────────────────────────────────────────

function WalletSkeleton() {
  return (
    <>
      {/* Balance card skeleton */}
      <div className="rounded-lg bg-ink p-lg">
        <div className="flex items-center gap-sm">
          <div className="size-5 animate-pulse rounded-sm bg-white/20" />
          <div className="h-3 w-32 animate-pulse rounded bg-white/20" />
        </div>
        <div className="mt-sm h-10 w-40 animate-pulse rounded bg-white/20" />
        <div className="mt-xs h-3 w-64 animate-pulse rounded bg-white/20" />
      </div>

      {/* Ledger skeleton */}
      <div className="mt-xxl">
        <div className="mb-sm h-3 w-32 animate-pulse rounded bg-hairline" />
        <div className="overflow-hidden rounded-md border border-hairline bg-white">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i}>
              {i > 0 && <Divider inset />}
              <div className="flex items-center gap-md px-md py-md">
                <div className="size-10 shrink-0 animate-pulse rounded-full bg-hairline" />
                <div className="flex-1 space-y-xs">
                  <div className="h-4 w-3/4 animate-pulse rounded bg-hairline" />
                  <div className="h-3 w-1/3 animate-pulse rounded bg-hairline" />
                </div>
                <div className="h-4 w-16 animate-pulse rounded bg-hairline" />
              </div>
            </div>
          ))}
        </div>
      </div>
    </>
  );
}

function ErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <p className="text-body-md text-error">{message}</p>
      <button
        type="button"
        onClick={onRetry}
        className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
      >
        Try again
      </button>
    </div>
  );
}
