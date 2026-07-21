"use client";

import { useState, useEffect, useCallback, startTransition } from "react";
import { Pencil, ChevronRight, MessageSquare, Loader2 } from "@/shared/icons";
import { useRouter } from "next/navigation";
import { useAuth } from "@/features/auth/auth-context";
import { fetchReviewSummary, fetchReviews } from "../api";
import type { ReviewSummary, Review } from "../types";
import { ReviewTile } from "./review-tile";
import { WriteReviewModal } from "./write-review-modal";
import { StarRow } from "./star-row";

interface Props {
  productId: number;
  productName: string;
}

// ── Histogram bar ─────────────────────────────────────────────────────────────

function HistogramRow({ star, count, total }: { star: number; count: number; total: number }) {
  const fraction = total > 0 ? Math.min(1, count / total) : 0;
  // Use a star-colour scale matching typical marketplace conventions
  const barColor =
    star <= 2 ? "bg-error" : star === 3 ? "bg-warning" : "bg-success";

  return (
    <div className="flex items-center gap-sm">
      {/* Star label — fixed width so bars align */}
      <span className="flex w-[32px] shrink-0 items-center justify-end gap-[2px]">
        <span className="text-label-md font-semibold text-ink">{star}</span>
        <span className="text-[9px] text-muted">★</span>
      </span>
      {/* Track + filled bar — bg-hairline gives a visible neutral track */}
      <div className="relative h-[8px] flex-1 overflow-hidden rounded-full bg-hairline">
        <div
          className={`absolute inset-y-0 left-0 rounded-full transition-all ${barColor}`}
          style={{ width: `${fraction * 100}%` }}
        />
      </div>
      {/* Count — fixed width so bars don't shift */}
      <span className="w-[28px] shrink-0 text-right text-label-md text-muted">{count}</span>
    </div>
  );
}

// ── Summary block ─────────────────────────────────────────────────────────────

function ReviewSummaryBlock({
  summary,
  onRate,
}: {
  summary: ReviewSummary;
  onRate: () => void;
}) {
  const avg = summary.ratingAvg ?? 0;
  const { histogram, ratingCount } = summary;

  return (
    <div className="flex items-center gap-xl border-b border-hairline px-lg py-md">
      {/* Big number */}
      <div className="flex flex-col items-center gap-xs">
        <span className="text-[40px] font-black leading-none text-ink">{avg.toFixed(1)}</span>
        <StarRow rating={avg} size={14} />
        <span className="text-body-sm text-muted">
          {ratingCount} {ratingCount === 1 ? "rating" : "ratings"}
        </span>
      </div>

      {/* Histogram */}
      <div className="flex flex-1 flex-col gap-xs">
        {([5, 4, 3, 2, 1] as const).map((s) => (
          <HistogramRow
            key={s}
            star={s}
            count={histogram[String(s) as keyof typeof histogram] ?? 0}
            total={ratingCount}
          />
        ))}
      </div>

      {/* Rate button */}
      <button
        onClick={onRate}
        className="flex shrink-0 items-center gap-xs text-label-md font-extrabold text-brand-strong hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
      >
        <Pencil size={13} aria-hidden />
        Rate
      </button>
    </div>
  );
}

// ── Main section ──────────────────────────────────────────────────────────────

export function ReviewsSection({ productId, productName }: Props) {
  const { status } = useAuth();
  const router = useRouter();

  const [summary, setSummary] = useState<ReviewSummary | null>(null);
  const [summaryLoading, setSummaryLoading] = useState(true);
  const [summaryError, setSummaryError] = useState<string | null>(null);

  const [reviewPage, setReviewPage] = useState<Review[]>([]);
  const [nextCursor, setNextCursor] = useState<number | null>(null);
  const [reviewsLoading, setReviewsLoading] = useState(false);
  const [reviewsError, setReviewsError] = useState<string | null>(null);
  const [loadedFirst, setLoadedFirst] = useState(false);

  const [showModal, setShowModal] = useState(false);
  const [myReview] = useState<Review | null>(null);

  const loadSummary = useCallback(async () => {
    setSummaryLoading(true);
    setSummaryError(null);
    try {
      const s = await fetchReviewSummary(productId);
      setSummary(s);
      // Find my review in the recent list
      // (server only returns up to 3 recent; a full my-reviews check would need a separate endpoint)
    } catch (err) {
      setSummaryError(err instanceof Error ? err.message : "Could not load reviews.");
    } finally {
      setSummaryLoading(false);
    }
  }, [productId]);

  const loadFirstPage = useCallback(async () => {
    setReviewsLoading(true);
    setReviewsError(null);
    try {
      const page = await fetchReviews(productId, { limit: 5 });
      setReviewPage(page.data);
      setNextCursor(page.nextCursor ?? null);
      setLoadedFirst(true);
    } catch (err) {
      setReviewsError(err instanceof Error ? err.message : "Could not load reviews.");
    } finally {
      setReviewsLoading(false);
    }
  }, [productId]);

  const loadMore = useCallback(async () => {
    if (nextCursor == null || reviewsLoading) return;
    setReviewsLoading(true);
    try {
      const page = await fetchReviews(productId, { cursor: nextCursor, limit: 10 });
      setReviewPage((prev) => [...prev, ...page.data]);
      setNextCursor(page.nextCursor ?? null);
    } catch {
      // swallow — user can retry by scrolling again
    } finally {
      setReviewsLoading(false);
    }
  }, [productId, nextCursor, reviewsLoading]);

  useEffect(() => {
    startTransition(() => { void loadSummary(); });
    startTransition(() => { void loadFirstPage(); });
  }, [loadSummary, loadFirstPage]);

  const handleRate = () => {
    if (status !== "authed") {
      router.push(`/login?next=/p/${productId}`);
      return;
    }
    setShowModal(true);
  };

  const handleModalSuccess = () => {
    setShowModal(false);
    void loadSummary();
    void loadFirstPage();
  };

  if (summaryLoading) {
    return (
      <div className="flex items-center gap-sm px-lg py-xxl text-muted">
        <Loader2 size={16} className="animate-spin" aria-hidden />
        <span className="text-body-md">Loading reviews…</span>
      </div>
    );
  }

  if (summaryError || !summary) {
    return null; // hide section silently on error
  }

  return (
    <>
      {/* Summary + histogram */}
      <ReviewSummaryBlock summary={summary} onRate={handleRate} />

      {summary.ratingCount === 0 ? (
        <div className="mx-lg my-md flex items-start gap-md rounded-md bg-canvas p-lg">
          <MessageSquare size={32} className="shrink-0 text-subtle" aria-hidden />
          <div>
            <p className="text-body-md font-bold text-ink">No reviews yet</p>
            <p className="mt-xs text-body-sm text-muted">
              Be the first to rate this product after your purchase is delivered.
            </p>
          </div>
        </div>
      ) : (
        <>
          {/* Recent reviews from summary (dense, always shown) */}
          {!loadedFirst
            ? summary.recent.slice(0, 3).map((r, i) => (
                <div key={r.id}>
                  {i > 0 ? <div className="mx-lg border-t border-hairline" /> : null}
                  <ReviewTile review={r} dense />
                </div>
              ))
            : reviewPage.map((r, i) => (
                <div key={r.id}>
                  {i > 0 ? <div className="mx-lg border-t border-hairline" /> : null}
                  <ReviewTile review={r} dense />
                </div>
              ))}

          {/* Error state */}
          {reviewsError ? (
            <div className="mx-lg my-sm rounded-sm bg-error-soft px-md py-sm text-body-sm text-error">
              {reviewsError}{" "}
              <button
                onClick={loadFirstPage}
                className="ml-xs font-bold underline focus-visible:outline-none"
              >
                Retry
              </button>
            </div>
          ) : null}

          {/* Load more */}
          {loadedFirst && nextCursor != null ? (
            <button
              onClick={loadMore}
              disabled={reviewsLoading}
              className="mx-lg my-sm flex items-center gap-xs text-label-md font-extrabold text-brand-strong hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:opacity-50"
            >
              {reviewsLoading ? (
                <Loader2 size={13} className="animate-spin" aria-hidden />
              ) : (
                <ChevronRight size={13} aria-hidden />
              )}
              {reviewsLoading ? "Loading…" : "Load more reviews"}
            </button>
          ) : null}

          {/* See all CTA when showing summary's 3 */}
          {!loadedFirst && summary.ratingCount > 3 ? (
            <button
              onClick={loadFirstPage}
              className="mx-lg my-sm flex items-center gap-xs text-label-md font-extrabold text-brand-strong hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
            >
              <ChevronRight size={13} aria-hidden />
              See all {summary.ratingCount} reviews
            </button>
          ) : null}
        </>
      )}

      {/* Write review modal */}
      {showModal ? (
        <WriteReviewModal
          productId={productId}
          productName={productName}
          existingReview={myReview}
          onClose={() => setShowModal(false)}
          onSuccess={handleModalSuccess}
        />
      ) : null}
    </>
  );
}
