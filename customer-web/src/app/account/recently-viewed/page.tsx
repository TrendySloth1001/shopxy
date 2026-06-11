"use client";

import { useCallback, useEffect, useState, startTransition } from "react";
import Link from "next/link";
import { Clock, Star } from "lucide-react";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { Divider } from "@/shared/ui/divider";
import { formatINR } from "@/shared/format";
import { resolveImageUrl } from "@/features/home/format";
import { fetchRecentlyViewed } from "@/features/account-extras/api";
import type { RecentlyViewedItem } from "@/features/account-extras/types";
import { BackButton } from "@/shared/ui/back-button";

export default function RecentlyViewedPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <RecentlyViewedBody />
    </RequireAuth>
  );
}

function RecentlyViewedBody() {
  const [items, setItems] = useState<RecentlyViewedItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setLoading(true);
    setError(null);
    fetchRecentlyViewed()
      .then((data) => {
        setItems(data);
        setLoading(false);
      })
      .catch((e: unknown) => {
        setError(e instanceof Error ? e.message : "Could not load recently viewed.");
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    startTransition(load);
  }, [load]);

  return (
    <main className="mx-auto max-w-shell px-lg py-xxxl">
      <BackButton fallback="/account" className="mb-sm" />
      <div>
        <p className="text-label-md uppercase tracking-wide text-brand">Account</p>
        <h1 className="mt-xs text-headline-md text-ink">Recently Viewed</h1>
        <p className="mt-xs text-body-md text-muted">
          Products you&apos;ve opened recently — up to the last 20.
        </p>
      </div>

      <Divider className="my-xl" />

      {loading ? (
        <RecentlyViewedSkeleton />
      ) : error ? (
        <ErrorState message={error} onRetry={load} />
      ) : items.length === 0 ? (
        <EmptyState />
      ) : (
        <div className="grid grid-cols-2 gap-md sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
          {items.map((item) => (
            <ProductTile key={item.productId} item={item} />
          ))}
        </div>
      )}
    </main>
  );
}

// ── Product tile ────────────────────────────────────────────────────────────

function ProductTile({ item }: { item: RecentlyViewedItem }) {
  const p = item.product;
  const imageUrl = resolveImageUrl(p.images[0]?.url);
  const discountPct =
    p.mrp > p.sellingPrice ? Math.round(((p.mrp - p.sellingPrice) / p.mrp) * 100) : 0;

  return (
    <Link
      href={`/p/${p.id}`}
      className="group flex flex-col rounded-md transition-opacity hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
    >
      {/* Image */}
      <div className="relative aspect-square overflow-hidden rounded-md bg-hero-panel">
        {imageUrl ? (
          // eslint-disable-next-line @next/next/no-img-element -- same-origin media proxy; next/image remote config not wired
          <img
            src={imageUrl}
            alt={p.name}
            loading="lazy"
            className="size-full object-cover"
          />
        ) : (
          <div className="size-full bg-hero-panel" />
        )}
        {discountPct > 0 && (
          <span className="absolute left-xs top-xs rounded-xs bg-brand px-xs py-[2px] text-label-md text-white">
            {discountPct}% off
          </span>
        )}
      </div>

      {/* Info */}
      <div className="mt-sm px-xs pb-xs">
        <p className="line-clamp-2 text-body-sm font-semibold text-ink">{p.name}</p>

        {/* Rating badge */}
        {p.ratingCount > 0 && p.ratingAvg != null && (
          <div className="mt-xs flex items-center gap-xs">
            <span className="inline-flex items-center gap-[2px] rounded-xs bg-success px-xs py-[2px] text-label-md text-white">
              {p.ratingAvg.toFixed(1)} <Star size={9} className="fill-white" />
            </span>
            <span className="text-label-md text-muted">({p.ratingCount})</span>
          </div>
        )}

        {/* Pricing */}
        <div className="mt-xs flex flex-wrap items-baseline gap-xs">
          <span className="text-title-sm text-ink">{formatINR(p.sellingPrice)}</span>
          {discountPct > 0 && (
            <span className="text-body-sm text-muted line-through">{formatINR(p.mrp)}</span>
          )}
        </div>
      </div>
    </Link>
  );
}

// ── Skeleton ─────────────────────────────────────────────────────────────────

function RecentlyViewedSkeleton() {
  return (
    <div className="grid grid-cols-2 gap-md sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5">
      {Array.from({ length: 10 }).map((_, i) => (
        <div key={i} className="flex flex-col gap-sm">
          <div className="aspect-square animate-pulse rounded-md bg-hairline" />
          <div className="h-3 w-5/6 animate-pulse rounded bg-hairline" />
          <div className="h-3 w-1/2 animate-pulse rounded bg-hairline" />
        </div>
      ))}
    </div>
  );
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <span className="flex size-14 items-center justify-center rounded-full bg-surface-tint text-muted">
        <Clock size={26} />
      </span>
      <p className="text-title-sm text-ink">Nothing here yet</p>
      <p className="max-w-content text-body-md text-muted">
        Products you open will show up here so you can find your way back to them.
      </p>
      <Link
        href="/"
        className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
      >
        Browse products
      </Link>
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
