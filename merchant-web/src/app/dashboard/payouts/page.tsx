"use client";

import { useCallback, useEffect, useState } from "react";
import { ArrowLeft, RefreshCw, Wallet } from "lucide-react";
import Link from "next/link";
import { Divider } from "@/shared/ui/divider";
import { getPayoutStatus } from "@/features/shop/api";
import type { PayoutAccount } from "@/features/shop/schema";
import { CardsSkeleton } from "@/shared/ui/skeleton";

const STATUS_TONE: Record<string, string> = {
  ACTIVE: "bg-success-soft text-success",
  ACTIVATED: "bg-success-soft text-success",
  CREATED: "bg-warning-soft text-warning",
  PENDING: "bg-warning-soft text-warning",
  UNDER_REVIEW: "bg-warning-soft text-warning",
  REJECTED: "bg-error-soft text-error",
  SUSPENDED: "bg-error-soft text-error",
};

function tone(status?: string | null): string {
  return (status && STATUS_TONE[status.toUpperCase()]) || "bg-surface-tint text-muted";
}

export default function PayoutsPage() {
  const [account, setAccount] = useState<PayoutAccount | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [nonce, setNonce] = useState(0);

  const reload = useCallback(() => setNonce((n) => n + 1), []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const a = await getPayoutStatus();
        if (!active) return;
        setAccount(a);
        setError(null);
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load payout status.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [nonce]);

  return (
    <div className="w-full px-lg py-xxl md:px-xxl">
      <Link
        href="/dashboard/shop"
        className="inline-flex items-center gap-sm text-body-md text-muted transition-colors hover:text-ink"
      >
        <ArrowLeft size={16} /> My shop
      </Link>

      <div className="mt-md flex flex-wrap items-start justify-between gap-md">
        <div>
          <h1 className="text-headline-md text-ink">Payouts</h1>
          <p className="mt-xs text-body-md text-muted">
            Where ShopXY settles money customers pay you online.
          </p>
        </div>
        <button
          type="button"
          onClick={reload}
          disabled={loading}
          className="inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-md text-label-md text-ink transition-colors hover:bg-surface-tint disabled:text-disabled"
        >
          <RefreshCw size={16} /> Refresh
        </button>
      </div>

      <Divider className="my-xl" />

      {loading ? (
        <CardsSkeleton count={3} />
      ) : error ? (
        <div className="flex flex-col items-start gap-md">
          <p className="text-body-md text-muted">{error}</p>
          <button
            type="button"
            onClick={reload}
            className="inline-flex h-10 items-center rounded-button border border-hairline px-lg text-label-md text-ink transition-colors hover:bg-surface-tint"
          >
            Try again
          </button>
        </div>
      ) : account ? (
        <div className="max-w-content">
          <div className="flex items-center gap-md">
            <span className="flex size-12 shrink-0 items-center justify-center rounded-md bg-hero-panel text-ink">
              <Wallet size={22} />
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-title-md text-ink">Linked account</p>
              <p className="text-body-sm text-muted">
                {account.bankName
                  ? `${account.bankName}${account.last4 ? ` ····${account.last4}` : ""}`
                  : "Razorpay Route settlement account"}
              </p>
            </div>
            <span
              className={`rounded-full px-sm py-px text-body-sm ${tone(account.status)}`}
            >
              {account.status ?? "Unknown"}
            </span>
          </div>

          <dl className="mt-lg grid grid-cols-2 gap-x-xxl gap-y-md">
            {account.accountId ? (
              <Fact label="Account ID" value={account.accountId} />
            ) : null}
            {account.status ? <Fact label="Status" value={account.status} /> : null}
          </dl>

          <p className="mt-xl text-body-sm text-muted">
            To change bank details or re-submit KYC, use the secure onboarding flow
            in the ShopXY mobile app — sensitive details (PAN, bank account) are
            captured there and forwarded straight to the payment provider.
          </p>
        </div>
      ) : (
        <div className="max-w-content">
          <div className="flex items-start gap-md rounded-md bg-surface-tint px-md py-md">
            <Wallet size={20} className="mt-px shrink-0 text-muted" />
            <div>
              <p className="text-body-md font-semibold text-ink">
                Payout onboarding not started
              </p>
              <p className="mt-px text-body-sm text-muted">
                Set up bank settlement and KYC in the ShopXY mobile app. The
                onboarding wizard captures your PAN and bank account securely and
                forwards them to the payment provider — they’re never stored on the
                web. Once submitted, this page shows your live status.
              </p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function Fact({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex flex-col gap-px">
      <dt className="text-label-md text-subtle">{label}</dt>
      <dd className="break-all text-body-md text-ink">{value}</dd>
    </div>
  );
}
