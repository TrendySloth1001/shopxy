"use client";

import { useCallback, useEffect, useState, useTransition, startTransition } from "react";
import Link from "next/link";
import { Heart, ShoppingCart } from "@/shared/icons";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { Divider } from "@/shared/ui/divider";
import { formatINR } from "@/shared/format";
import { resolveImageUrl } from "@/features/home/format";
import { fetchWishlist, removeFromWishlist } from "@/features/account-extras/api";
import type { WishlistItem } from "@/features/account-extras/types";
import { BackButton } from "@/shared/ui/back-button";

export default function WishlistPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <WishlistBody />
    </RequireAuth>
  );
}

function WishlistBody() {
  const [items, setItems] = useState<WishlistItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(() => {
    setLoading(true);
    setError(null);
    fetchWishlist()
      .then((data) => {
        setItems(data);
        setLoading(false);
      })
      .catch((e: unknown) => {
        setError(e instanceof Error ? e.message : "Could not load wishlist.");
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    startTransition(load);
  }, [load]);

  function handleRemove(productId: number) {
    setItems((prev) => prev.filter((i) => i.productId !== productId));
    removeFromWishlist(productId).catch(() => {
      // If removal fails silently reload
      load();
    });
  }

  return (
    <main className="mx-auto max-w-shell px-lg py-xxxl">
      <BackButton fallback="/" className="mb-sm" />
      <div>
        <p className="text-label-md uppercase tracking-wide text-brand">Account</p>
        <h1 className="mt-xs text-headline-md text-ink">Saved</h1>
        <p className="mt-xs text-body-md text-muted">Products you&apos;ve saved for later.</p>
      </div>

      <Divider className="my-xl" />

      {loading ? (
        <WishlistSkeleton />
      ) : error ? (
        <ErrorState message={error} onRetry={load} />
      ) : items.length === 0 ? (
        <EmptyState />
      ) : (
        <ul className="flex flex-col gap-sm">
          {items.map((item) => (
            <li key={item.id}>
              <WishlistRow item={item} onRemove={() => handleRemove(item.productId)} />
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}

function WishlistRow({
  item,
  onRemove,
}: {
  item: WishlistItem;
  onRemove: () => void;
}) {
  const [isPending, startTransition] = useTransition();
  const p = item.product;
  const imageUrl = resolveImageUrl(p.images[0]?.url);
  const discountPct =
    p.mrp > p.sellingPrice ? Math.round(((p.mrp - p.sellingPrice) / p.mrp) * 100) : 0;

  return (
    <div className="flex items-start gap-md rounded-md border border-hairline bg-white p-md transition-colors">
      {/* Thumbnail */}
      <Link href={`/p/${p.id}`} className="shrink-0">
        <div className="size-20 overflow-hidden rounded-sm bg-hero-panel sm:size-24">
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
        </div>
      </Link>

      {/* Info */}
      <div className="min-w-0 flex-1">
        <Link href={`/p/${p.id}`}>
          <p className="line-clamp-2 text-body-md font-semibold text-ink hover:text-brand">
            {p.name}
          </p>
        </Link>
        <p className="mt-xs text-body-sm text-muted">{p.unit}</p>
        <div className="mt-xs flex items-baseline gap-sm">
          <span className="text-title-sm text-ink">{formatINR(p.sellingPrice)}</span>
          {discountPct > 0 && (
            <>
              <span className="text-body-sm text-muted line-through">{formatINR(p.mrp)}</span>
              <span className="text-label-md text-success">{discountPct}% off</span>
            </>
          )}
        </div>

        {/* Actions row */}
        <div className="mt-md flex flex-wrap items-center gap-sm">
          <Link
            href={`/p/${p.id}`}
            className="inline-flex h-9 items-center gap-xs rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
          >
            <ShoppingCart size={14} />
            View product
          </Link>
          <button
            type="button"
            onClick={() => startTransition(onRemove)}
            disabled={isPending}
            className="inline-flex h-9 items-center gap-xs rounded-button border border-hairline px-md text-label-md text-muted transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:opacity-50"
          >
            <Heart size={14} className="fill-accent-rose text-accent-rose" />
            {isPending ? "Removing…" : "Remove"}
          </button>
        </div>
      </div>
    </div>
  );
}

function WishlistSkeleton() {
  return (
    <ul className="flex flex-col gap-sm">
      {Array.from({ length: 4 }).map((_, i) => (
        <li key={i} className="flex items-start gap-md rounded-md border border-hairline bg-white p-md">
          <div className="size-20 shrink-0 animate-pulse rounded-sm bg-hairline sm:size-24" />
          <div className="flex-1 space-y-sm py-xs">
            <div className="h-4 w-3/4 animate-pulse rounded bg-hairline" />
            <div className="h-3 w-1/4 animate-pulse rounded bg-hairline" />
            <div className="h-4 w-1/3 animate-pulse rounded bg-hairline" />
          </div>
        </li>
      ))}
    </ul>
  );
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <span className="flex size-16 items-center justify-center rounded-full bg-accent-rose-soft text-accent-rose">
        <Heart size={28} />
      </span>
      <p className="text-title-sm text-ink">Nothing saved yet</p>
      <p className="max-w-content text-body-md text-muted">
        Tap the heart on any product to save it here for later.
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
