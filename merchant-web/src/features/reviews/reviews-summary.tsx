"use client";

import { useEffect, useState } from "react";
import { BadgeCheck } from "lucide-react";
import { getReviewSummary } from "./api";
import type { Review, ReviewSummary } from "./schema";
import { Stars } from "./stars";

/**
 * Customer-review block for the product detail page. Fetches the one-shot
 * summary (average, histogram, verified-buyer count, three most recent
 * reviews) and renders it. Shows an empty state when the product has no
 * reviews yet, so the section is always informative.
 */
export function ReviewsSummary({ productId }: { productId: number }) {
  const [summary, setSummary] = useState<ReviewSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    void (async () => {
      try {
        const s = await getReviewSummary(productId);
        if (active) setSummary(s);
      } catch (e) {
        if (active)
          setError(e instanceof Error ? e.message : "Could not load reviews.");
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [productId]);

  if (loading) {
    return <p className="text-body-sm text-muted">Loading reviews…</p>;
  }
  if (error) {
    return <p className="text-body-sm text-muted">{error}</p>;
  }

  const count = summary?.ratingCount ?? 0;
  if (!summary || count === 0) {
    return (
      <p className="text-body-md text-muted">
        No reviews yet. Verified buyers can rate this product after a confirmed
        purchase.
      </p>
    );
  }

  const avg = summary.ratingAvg ?? 0;
  const total = count || 1;

  return (
    <div className="flex flex-col gap-lg">
      <div className="grid gap-xl sm:grid-cols-[auto_1fr] sm:items-center">
        {/* Score */}
        <div className="flex flex-col gap-xs">
          <div className="flex items-baseline gap-sm">
            <span className="text-display-sm tabular-nums text-ink">
              {avg.toFixed(1)}
            </span>
            <span className="text-body-md text-muted">/ 5</span>
          </div>
          <Stars value={avg} size={18} label={`${avg.toFixed(1)} out of 5`} />
          <p className="text-body-sm text-muted">
            {count} {count === 1 ? "rating" : "ratings"}
            {summary.verifiedCount > 0 ? (
              <span className="ml-xs inline-flex items-center gap-px text-success">
                · <BadgeCheck size={13} /> {summary.verifiedCount} verified
              </span>
            ) : null}
          </p>
        </div>

        {/* Histogram */}
        <dl className="flex flex-col gap-xs">
          {[5, 4, 3, 2, 1].map((star) => {
            const n = summary.histogram?.[String(star)] ?? 0;
            const pct = Math.round((n / total) * 100);
            return (
              <div key={star} className="flex items-center gap-sm">
                <dt className="w-8 shrink-0 text-body-sm tabular-nums text-muted">
                  {star}★
                </dt>
                <div className="h-2 flex-1 overflow-hidden rounded-full bg-surface-tint">
                  <div
                    className="h-full rounded-full bg-accent-amber"
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <dd className="w-10 shrink-0 text-right text-body-sm tabular-nums text-subtle">
                  {n}
                </dd>
              </div>
            );
          })}
        </dl>
      </div>

      {/* Most recent */}
      {summary.recent.length > 0 ? (
        <ul className="flex flex-col gap-md">
          {summary.recent.map((r) => (
            <ReviewRow key={r.id} review={r} />
          ))}
        </ul>
      ) : null}
    </div>
  );
}

function ReviewRow({ review }: { review: Review }) {
  const name = review.user?.name?.trim() || "Customer";
  return (
    <li className="border-t border-hairline pt-md">
      <div className="flex flex-wrap items-center gap-sm">
        <Stars value={review.rating} size={14} label={`${review.rating} out of 5`} />
        {review.title ? (
          <span className="text-body-md text-ink">{review.title}</span>
        ) : null}
      </div>
      {review.body ? (
        <p className="mt-xs whitespace-pre-line text-body-sm text-ink">
          {review.body}
        </p>
      ) : null}
      <p className="mt-xs text-body-sm text-subtle">{name}</p>
    </li>
  );
}
