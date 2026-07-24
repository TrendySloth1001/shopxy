/**
 * Review client-side fetchers. Hit /api/* BFF routes only.
 */

import { reviewSummarySchema, reviewPageSchema, reviewSchema, type ReviewSummary, type ReviewPage, type Review } from "./types";

async function jsonOrThrow<T>(
  res: Response,
  parse: (raw: unknown) => T,
  fallback: string,
): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
      // keep fallback
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export async function fetchReviewSummary(productId: string): Promise<ReviewSummary> {
  const res = await fetch(`/api/products/${productId}/reviews/summary`);
  return jsonOrThrow(res, (raw) => reviewSummarySchema.parse(raw), "Could not load review summary.");
}

export async function fetchReviews(
  productId: string,
  opts?: { cursor?: number; limit?: number },
): Promise<ReviewPage> {
  const qs = new URLSearchParams({ limit: String(opts?.limit ?? 20) });
  if (opts?.cursor != null) qs.set("cursor", String(opts.cursor));
  const res = await fetch(`/api/products/${productId}/reviews?${qs.toString()}`);
  return jsonOrThrow(res, (raw) => reviewPageSchema.parse(raw), "Could not load reviews.");
}

export async function submitReview(
  productId: string,
  payload: { rating: number; title?: string; body?: string },
): Promise<Review> {
  const res = await fetch(`/api/products/${productId}/reviews`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  return jsonOrThrow(res, (raw) => reviewSchema.parse(raw), "Could not submit review.");
}

export async function deleteReview(productId: string): Promise<void> {
  const res = await fetch(`/api/products/${productId}/reviews/mine`, {
    method: "DELETE",
  });
  if (!res.ok && res.status !== 204) {
    let msg = "Could not delete your review.";
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) msg = b.error;
    } catch {
      // keep
    }
    throw new Error(msg);
  }
}
