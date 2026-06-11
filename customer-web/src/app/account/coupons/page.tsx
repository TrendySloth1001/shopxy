"use client";

import { useCallback, useEffect, useState, startTransition } from "react";
import { Copy, Check, Tag } from "lucide-react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { Divider } from "@/shared/ui/divider";
import { formatINR } from "@/shared/format";
import { formatDate } from "@/shared/datetime";
import { fetchMyCoupons } from "@/features/account-extras/api";
import { isCouponExhausted, couponHeadline, couponMinOrderLabel } from "@/features/account-extras/types";
import type { Coupon } from "@/features/account-extras/types";
import { BackButton } from "@/shared/ui/back-button";

export default function MyCouponsPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <CouponsBody />
    </RequireAuth>
  );
}

function CouponsBody() {
  const [coupons, setCoupons] = useState<Coupon[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setLoading(true);
    setError(null);
    fetchMyCoupons()
      .then((data) => {
        setCoupons(data);
        setLoading(false);
      })
      .catch((e: unknown) => {
        setError(e instanceof Error ? e.message : "Could not load coupons.");
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    startTransition(load);
  }, [load]);

  return (
    <main className="mx-auto max-w-content px-lg py-xxxl">
      <BackButton fallback="/account" className="mb-sm" />
      <div>
        <p className="text-label-md uppercase tracking-wide text-brand">Account</p>
        <h1 className="mt-xs text-headline-md text-ink">My Coupons</h1>
        <p className="mt-xs text-body-md text-muted">
          Promo codes you can use at checkout.
        </p>
      </div>

      <Divider className="my-xl" />

      {loading ? (
        <CouponsSkeleton />
      ) : error ? (
        <ErrorState message={error} onRetry={load} />
      ) : coupons.length === 0 ? (
        <EmptyState />
      ) : (
        <ul className="flex flex-col gap-sm">
          {coupons.map((coupon) => (
            <li key={coupon.id}>
              <CouponCard coupon={coupon} />
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}

function CouponCard({ coupon }: { coupon: Coupon }) {
  const [copied, setCopied] = useState(false);
  const exhausted = isCouponExhausted(coupon);
  const headline = couponHeadline(coupon, formatINR);
  const minOrderLabel = couponMinOrderLabel(coupon, formatINR);

  async function handleCopy() {
    try {
      await navigator.clipboard.writeText(coupon.code);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard API might not be available; show a silent fallback
    }
  }

  return (
    <div
      className={`rounded-md border border-hairline bg-white p-md transition-opacity ${
        exhausted ? "opacity-50" : ""
      }`}
    >
      {/* Title row */}
      <div className="flex flex-wrap items-start gap-sm">
        <p className="flex-1 text-title-sm text-ink">{coupon.title}</p>
        <div className="flex flex-wrap gap-xs">
          {coupon.firstOrderOnly && (
            <span className="inline-flex items-center rounded-full bg-accent-amber-soft px-sm py-xs text-label-md text-accent-amber">
              First order only
            </span>
          )}
          {coupon.isPublic && (
            <span className="inline-flex items-center rounded-full bg-brand-soft px-sm py-xs text-label-md text-brand-strong">
              Auto-applies
            </span>
          )}
          {exhausted && (
            <span className="inline-flex items-center rounded-full bg-surface-tint px-sm py-xs text-label-md text-muted">
              Used
            </span>
          )}
        </div>
      </div>

      {/* Benefit line */}
      <p className="mt-xs text-title-sm font-bold text-brand">{headline}</p>

      {/* Min order */}
      {minOrderLabel && (
        <p className="mt-xs text-body-sm text-muted">{minOrderLabel}</p>
      )}

      {/* Description */}
      {coupon.description && (
        <p className="mt-sm text-body-sm leading-relaxed text-muted">{coupon.description}</p>
      )}

      {/* Code + expiry row */}
      <div className="mt-md flex flex-wrap items-center gap-sm">
        <span className="inline-flex items-center rounded-sm bg-brand-soft px-sm py-xs text-label-md font-bold tracking-wide text-brand-strong">
          {coupon.code}
        </span>
        <button
          type="button"
          onClick={() => void handleCopy()}
          disabled={exhausted}
          className="inline-flex h-8 items-center gap-xs rounded-button border border-hairline px-sm text-label-md text-brand transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:cursor-not-allowed disabled:text-disabled"
        >
          {copied ? (
            <>
              <Check size={12} className="text-success" /> Copied!
            </>
          ) : (
            <>
              <Copy size={12} /> Copy
            </>
          )}
        </button>
        <span className="ml-auto text-label-md text-subtle">
          Expires {formatDate(coupon.validUntil)}
        </span>
      </div>
    </div>
  );
}

function CouponsSkeleton() {
  return (
    <ul className="flex flex-col gap-sm">
      {Array.from({ length: 3 }).map((_, i) => (
        <li key={i} className="rounded-md border border-hairline bg-white p-md">
          <div className="flex items-start gap-sm">
            <div className="h-4 flex-1 animate-pulse rounded bg-hairline" />
            <div className="h-5 w-20 animate-pulse rounded-full bg-hairline" />
          </div>
          <div className="mt-sm h-4 w-1/3 animate-pulse rounded bg-hairline" />
          <div className="mt-sm h-3 w-1/4 animate-pulse rounded bg-hairline" />
          <div className="mt-md flex items-center gap-sm">
            <div className="h-7 w-24 animate-pulse rounded-sm bg-hairline" />
            <div className="h-7 w-16 animate-pulse rounded-button bg-hairline" />
          </div>
        </li>
      ))}
    </ul>
  );
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <span className="flex size-14 items-center justify-center rounded-full bg-surface-tint text-muted">
        <Tag size={26} />
      </span>
      <p className="text-title-sm text-ink">No coupons yet</p>
      <p className="max-w-content text-body-md text-muted">
        Promo codes you earn will appear here.
      </p>
    </div>
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
