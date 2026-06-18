"use client";

import { useCallback, useEffect, useState } from "react";
import { ArrowLeft, RefreshCw, Wallet } from "lucide-react";
import Link from "next/link";
import { Divider } from "@/shared/ui/divider";
import { getPayoutStatus } from "@/features/shop/api";
import type { PayoutAccount } from "@/features/shop/schema";
import { CardsSkeleton } from "@/shared/ui/skeleton";
import { ConnectAccountCard } from "@/features/payouts/connect-account-card";
import { OnboardingWizard } from "@/features/payouts/onboarding-wizard";

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

// "UNDER_REVIEW" → "Under review"
function humanStatus(status?: string | null): string {
  if (!status) return "Unknown";
  const s = status.replace(/_/g, " ").toLowerCase();
  return s.charAt(0).toUpperCase() + s.slice(1);
}

export default function PayoutsPage() {
  const [account, setAccount] = useState<PayoutAccount | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // refresh=true re-polls Razorpay live (picks up an activation that happened
  // after we last stored the status).
  const load = useCallback(async (refresh = false) => {
    setLoading(true);
    try {
      setAccount(await getPayoutStatus({ refresh }));
      setError(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load payout status.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    let active = true;
    void (async () => {
      setLoading(true);
      try {
        const a = await getPayoutStatus();
        if (active) {
          setAccount(a);
          setError(null);
        }
      } catch (e) {
        if (active) setError(e instanceof Error ? e.message : "Could not load payout status.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, []);

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
          onClick={() => void load(true)}
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
            onClick={() => void load(true)}
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
              <p className="text-title-md text-ink">{account.contactName ?? "Linked account"}</p>
              <p className="text-body-sm text-muted">Razorpay Route settlement account</p>
            </div>
            <span className={`rounded-full px-sm py-px text-body-sm ${tone(account.kycStatus)}`}>
              {account.payoutsEnabled ? "Payouts enabled" : humanStatus(account.kycStatus)}
            </span>
          </div>

          <dl className="mt-lg grid grid-cols-2 gap-x-xxl gap-y-md">
            {account.providerAccountId ? <Fact label="Account ID" value={account.providerAccountId} /> : null}
            <Fact label="Name" value={account.contactName ?? "—"} />
            {account.email ? <Fact label="Email" value={account.email} /> : null}
            {account.businessType ? <Fact label="Business type" value={account.businessType} /> : null}
            <Fact label="KYC status" value={humanStatus(account.kycStatus)} />
            <Fact label="Payouts" value={account.payoutsEnabled ? "Enabled" : "Not enabled yet"} />
          </dl>

          {!account.payoutsEnabled ? (
            <p className="mt-xl text-body-sm text-muted">
              Razorpay is still reviewing this account — this is the status we last fetched.
              Hit Refresh to re-check live; UPI at the till turns on once payouts are enabled.
            </p>
          ) : null}
        </div>
      ) : (
        <div className="flex max-w-content flex-col gap-lg">
          <div className="flex items-start gap-md rounded-md bg-surface-tint px-md py-md">
            <Wallet size={20} className="mt-px shrink-0 text-muted" />
            <div>
              <p className="text-body-md font-semibold text-ink">Payout onboarding not started</p>
              <p className="mt-px text-body-sm text-muted">
                Set up where ShopXY settles your online + UPI sales. New to Razorpay?
                Complete KYC below. Already have a Razorpay account? Connect it instead.
              </p>
            </div>
          </div>
          <OnboardingWizard onLinked={() => void load(true)} />
          <ConnectAccountCard onLinked={() => void load(true)} />
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
