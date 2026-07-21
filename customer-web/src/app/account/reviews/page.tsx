"use client";

import { useCallback, useEffect, useRef, useState, startTransition } from "react";
import Link from "next/link";
import { Star, StarHalf, Pencil, Trash2, X, Check } from "@/shared/icons";
import { RequireAuth } from "@/features/auth/components/require-auth";
import { AppHeader } from "@/features/auth/components/app-header";
import { Divider } from "@/shared/ui/divider";
import { formatDateTime } from "@/shared/datetime";
import { resolveImageUrl } from "@/features/home/format";
import { fetchMyReviews, deleteReview, upsertReview } from "@/features/account-extras/api";
import type { MyReview } from "@/features/account-extras/types";
import { BackButton } from "@/shared/ui/back-button";

export default function MyReviewsPage() {
  return (
    <RequireAuth>
      <AppHeader />
      <MyReviewsBody />
    </RequireAuth>
  );
}

const LIMIT = 20;

function MyReviewsBody() {
  const [rows, setRows] = useState<MyReview[]>([]);
  const [nextCursor, setNextCursor] = useState<number | null | undefined>(undefined);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const scrollRef = useRef<HTMLDivElement>(null);

  // Editing state
  const [editingId, setEditingId] = useState<number | null>(null);

  const load = useCallback((reset: boolean, cursor?: number) => {
    if (reset) setLoading(true);
    else setLoadingMore(true);
    setError(null);
    fetchMyReviews({ cursor, limit: LIMIT })
      .then((res) => {
        setRows((prev) => (reset ? res.data : [...prev, ...res.data]));
        setNextCursor(res.nextCursor ?? null);
        setLoading(false);
        setLoadingMore(false);
      })
      .catch((e: unknown) => {
        setError(e instanceof Error ? e.message : "Could not load reviews.");
        setLoading(false);
        setLoadingMore(false);
      });
  }, []);

  useEffect(() => {
    startTransition(() => load(true));
  }, [load]);

  // Scroll-to-bottom pagination
  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;
    function onScroll() {
      if (!el) return;
      const distFromBottom =
        document.documentElement.scrollHeight - window.scrollY - window.innerHeight;
      if (distFromBottom < 400 && nextCursor != null && !loadingMore) {
        load(false, nextCursor);
      }
    }
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, [nextCursor, loadingMore, load]);

  function handleDelete(productId: number) {
    setRows((prev) => prev.filter((r) => r.productId !== productId));
    deleteReview(productId).catch(() => load(true));
  }

  function handleUpdated(updated: MyReview) {
    setRows((prev) => prev.map((r) => (r.id === updated.id ? updated : r)));
    setEditingId(null);
  }

  return (
    <main className="mx-auto max-w-content px-lg py-xxxl" ref={scrollRef}>
      <BackButton fallback="/account" className="mb-sm" />
      <div>
        <p className="text-label-md uppercase tracking-wide text-brand">Account</p>
        <h1 className="mt-xs text-headline-md text-ink">My Reviews</h1>
        <p className="mt-xs text-body-md text-muted">
          Reviews you&apos;ve written about products you&apos;ve purchased.
        </p>
      </div>

      <Divider className="my-xl" />

      {loading ? (
        <ReviewsSkeleton />
      ) : error && rows.length === 0 ? (
        <ErrorState message={error} onRetry={() => load(true)} />
      ) : rows.length === 0 ? (
        <EmptyState />
      ) : (
        <>
          <ul className="flex flex-col gap-sm">
            {rows.map((row) => (
              <li key={row.id}>
                {editingId === row.id ? (
                  <ReviewEditCard
                    review={row}
                    onCancel={() => setEditingId(null)}
                    onSaved={handleUpdated}
                  />
                ) : (
                  <ReviewCard
                    review={row}
                    onEdit={() => setEditingId(row.id)}
                    onDelete={() => handleDelete(row.productId)}
                  />
                )}
              </li>
            ))}
          </ul>

          {loadingMore && (
            <div className="mt-lg flex justify-center">
              <span className="text-body-sm text-muted">Loading more…</span>
            </div>
          )}
          {!loadingMore && nextCursor == null && rows.length > 0 && (
            <p className="mt-lg text-center text-body-sm text-subtle">You&apos;re all caught up.</p>
          )}
        </>
      )}
    </main>
  );
}

// ── Star display ────────────────────────────────────────────────────────────

function StarDisplay({ rating }: { rating: number }) {
  return (
    <span className="inline-flex items-center gap-xs">
      {Array.from({ length: 5 }).map((_, i) => {
        const filled = i + 1 <= Math.floor(rating);
        const half = !filled && i < rating;
        return half ? (
          <StarHalf key={i} size={14} className="fill-accent-amber text-accent-amber" />
        ) : filled ? (
          <Star key={i} size={14} className="fill-accent-amber text-accent-amber" />
        ) : (
          <Star key={i} size={14} className="text-disabled" />
        );
      })}
      <span className="text-label-md text-muted">{rating}/5</span>
    </span>
  );
}

// ── Star picker (for editing) ───────────────────────────────────────────────

function StarPicker({
  value,
  onChange,
}: {
  value: number;
  onChange: (v: number) => void;
}) {
  return (
    <span className="inline-flex items-center gap-xs" aria-label="Rating">
      {Array.from({ length: 5 }).map((_, i) => (
        <button
          key={i}
          type="button"
          onClick={() => onChange(i + 1)}
          className="focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
          aria-label={`${i + 1} star`}
        >
          <Star
            size={20}
            className={
              i < value
                ? "fill-accent-amber text-accent-amber"
                : "text-disabled hover:text-accent-amber"
            }
          />
        </button>
      ))}
    </span>
  );
}

// ── Review card ─────────────────────────────────────────────────────────────

function ReviewCard({
  review,
  onEdit,
  onDelete,
}: {
  review: MyReview;
  onEdit: () => void;
  onDelete: () => void;
}) {
  const [confirmDelete, setConfirmDelete] = useState(false);
  const imgUrl = resolveImageUrl(review.product.images[0]?.url);

  return (
    <div className="rounded-md border border-hairline bg-white p-md">
      {/* Header: product thumb + name + rating + date */}
      <div className="flex items-start gap-md">
        <Link href={`/p/${review.productId}`} className="shrink-0">
          <div className="size-14 overflow-hidden rounded-sm bg-hero-panel">
            {imgUrl ? (
              // eslint-disable-next-line @next/next/no-img-element -- same-origin media proxy; next/image remote config not wired
              <img src={imgUrl} alt={review.product.name} loading="lazy" className="size-full object-cover" />
            ) : (
              <div className="size-full bg-hero-panel" />
            )}
          </div>
        </Link>
        <div className="min-w-0 flex-1">
          <Link href={`/p/${review.productId}`}>
            <p className="line-clamp-1 text-body-md font-semibold text-ink hover:text-brand">
              {review.product.name}
            </p>
          </Link>
          <div className="mt-xs">
            <StarDisplay rating={review.rating} />
          </div>
        </div>
        <span className="shrink-0 text-label-md text-subtle">
          {formatDateTime(review.createdAt).split(",")[0]}
        </span>
      </div>

      {/* Body */}
      {review.title && (
        <p className="mt-sm text-body-md font-semibold text-ink">{review.title}</p>
      )}
      {review.body && (
        <p className="mt-xs line-clamp-4 text-body-md text-muted">{review.body}</p>
      )}

      {/* Actions */}
      <div className="mt-md flex items-center gap-sm border-t border-hairline pt-md">
        <button
          type="button"
          onClick={onEdit}
          className="inline-flex h-8 items-center gap-xs rounded-button border border-hairline px-sm text-label-md text-muted transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
        >
          <Pencil size={12} /> Edit
        </button>
        {confirmDelete ? (
          <span className="ml-auto flex items-center gap-sm">
            <span className="text-body-sm text-error">Delete this review?</span>
            <button
              type="button"
              onClick={onDelete}
              className="inline-flex h-8 items-center gap-xs rounded-button bg-error px-sm text-label-md text-white transition-colors hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error"
            >
              <Check size={12} /> Yes
            </button>
            <button
              type="button"
              onClick={() => setConfirmDelete(false)}
              className="inline-flex h-8 items-center gap-xs rounded-button border border-hairline px-sm text-label-md text-muted transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
            >
              <X size={12} /> Cancel
            </button>
          </span>
        ) : (
          <button
            type="button"
            onClick={() => setConfirmDelete(true)}
            className="ml-auto inline-flex h-8 items-center gap-xs rounded-button border border-hairline px-sm text-label-md text-error transition-colors hover:bg-error-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-error"
          >
            <Trash2 size={12} /> Delete
          </button>
        )}
      </div>
    </div>
  );
}

// ── Inline edit card ────────────────────────────────────────────────────────

function ReviewEditCard({
  review,
  onCancel,
  onSaved,
}: {
  review: MyReview;
  onCancel: () => void;
  onSaved: (updated: MyReview) => void;
}) {
  const [rating, setRating] = useState(review.rating);
  const [title, setTitle] = useState(review.title ?? "");
  const [body, setBody] = useState(review.body ?? "");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (rating < 1 || rating > 5) {
      setError("Please pick a rating.");
      return;
    }
    setSaving(true);
    setError(null);
    try {
      const updated = await upsertReview(review.productId, { rating, title, body });
      onSaved({ ...review, ...updated });
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : "Could not save review.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form
      onSubmit={(e) => void handleSubmit(e)}
      className="rounded-md border border-brand bg-white p-md"
    >
      <p className="mb-sm text-title-sm text-ink">Edit review</p>

      <div className="mb-sm">
        <label className="mb-xs block text-label-md text-muted">Rating</label>
        <StarPicker value={rating} onChange={setRating} />
      </div>

      <div className="mb-sm">
        <label className="mb-xs block text-label-md text-muted" htmlFor={`title-${review.id}`}>
          Title (optional)
        </label>
        <input
          id={`title-${review.id}`}
          type="text"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          maxLength={120}
          placeholder="Sum it up in a few words"
          className="w-full rounded-input border border-hairline bg-canvas px-md py-sm text-body-md text-ink placeholder:text-subtle focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand-soft"
        />
      </div>

      <div className="mb-md">
        <label className="mb-xs block text-label-md text-muted" htmlFor={`body-${review.id}`}>
          Review (optional)
        </label>
        <textarea
          id={`body-${review.id}`}
          value={body}
          onChange={(e) => setBody(e.target.value)}
          maxLength={2000}
          rows={4}
          placeholder="Share your experience with this product"
          className="w-full rounded-input border border-hairline bg-canvas px-md py-sm text-body-md text-ink placeholder:text-subtle focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand-soft"
        />
      </div>

      {error && (
        <p className="mb-sm rounded-sm bg-error-soft px-md py-sm text-body-sm text-error">{error}</p>
      )}

      <div className="flex items-center gap-sm">
        <button
          type="submit"
          disabled={saving}
          className="inline-flex h-9 items-center rounded-button bg-brand px-md text-label-md text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:opacity-50"
        >
          {saving ? "Saving…" : "Save changes"}
        </button>
        <button
          type="button"
          onClick={onCancel}
          disabled={saving}
          className="inline-flex h-9 items-center rounded-button border border-hairline px-md text-label-md text-muted transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:opacity-50"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}

// ── Skeleton / Empty / Error ─────────────────────────────────────────────────

function ReviewsSkeleton() {
  return (
    <ul className="flex flex-col gap-sm">
      {Array.from({ length: 4 }).map((_, i) => (
        <li key={i} className="rounded-md border border-hairline bg-white p-md">
          <div className="flex items-start gap-md">
            <div className="size-14 shrink-0 animate-pulse rounded-sm bg-hairline" />
            <div className="flex-1 space-y-sm">
              <div className="h-4 w-2/3 animate-pulse rounded bg-hairline" />
              <div className="h-3 w-1/3 animate-pulse rounded bg-hairline" />
            </div>
          </div>
          <div className="mt-sm space-y-xs">
            <div className="h-3 w-full animate-pulse rounded bg-hairline" />
            <div className="h-3 w-5/6 animate-pulse rounded bg-hairline" />
          </div>
        </li>
      ))}
    </ul>
  );
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <span className="flex size-14 items-center justify-center rounded-full bg-warning-soft text-warning">
        <Star size={26} />
      </span>
      <p className="text-title-sm text-ink">No reviews yet</p>
      <p className="max-w-content text-body-md text-muted">
        Once you receive an order, you can rate and review the products you bought.
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
