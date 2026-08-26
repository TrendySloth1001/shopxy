import {
  wishlistResponseSchema,
  myReviewsResponseSchema,
  couponsResponseSchema,
  recentlyViewedResponseSchema,
  type MyReviewsResponseRaw,
} from "./schema";
import type { WishlistItem, MyReview, Coupon, RecentlyViewedItem } from "./types";

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
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export async function fetchWishlist(): Promise<WishlistItem[]> {
  const res = await fetch("/api/me/wishlist", { cache: "no-store" });
  const data = await jsonOrThrow(
    res,
    (raw) => wishlistResponseSchema.parse(raw),
    "Could not load wishlist.",
  );
  return data.data;
}

export async function removeFromWishlist(productId: string): Promise<void> {
  const res = await fetch(`/api/me/wishlist/${productId}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) {
    let message = "Could not remove from wishlist.";
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
    }
    throw new Error(message);
  }
}

export async function addToWishlist(productId: string): Promise<void> {
  const res = await fetch(`/api/me/wishlist/${productId}`, { method: "POST" });
  if (!res.ok) {
    let message = "Could not add to wishlist.";
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
    }
    throw new Error(message);
  }
}

export async function fetchMyReviews(opts?: {
  cursor?: number;
  limit?: number;
}): Promise<MyReviewsResponseRaw> {
  const qs = new URLSearchParams();
  if (opts?.cursor != null) qs.set("cursor", String(opts.cursor));
  if (opts?.limit != null) qs.set("limit", String(opts.limit));
  const url = `/api/me/reviews${qs.toString() ? `?${qs.toString()}` : ""}`;
  const res = await fetch(url, { cache: "no-store" });
  return jsonOrThrow(res, (raw) => myReviewsResponseSchema.parse(raw), "Could not load your reviews.");
}

export async function deleteReview(productId: string): Promise<void> {
  const res = await fetch(`/api/products/${productId}/reviews/mine`, {
    method: "DELETE",
  });
  if (!res.ok && res.status !== 204) {
    let message = "Could not delete review.";
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
    }
    throw new Error(message);
  }
}

export async function upsertReview(
  productId: string,
  payload: { rating: number; title?: string; body?: string },
): Promise<MyReview> {
  const res = await fetch(`/api/products/${productId}/reviews`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });
  if (!res.ok) {
    let message = "Could not submit review.";
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
    }
    throw new Error(message);
  }
  return (await res.json()) as MyReview;
}

export async function fetchMyCoupons(): Promise<Coupon[]> {
  const res = await fetch("/api/me/coupons", { cache: "no-store" });
  const data = await jsonOrThrow(
    res,
    (raw) => couponsResponseSchema.parse(raw),
    "Could not load coupons.",
  );
  return data.data;
}

export async function fetchRecentlyViewed(): Promise<RecentlyViewedItem[]> {
  const res = await fetch("/api/me/recently-viewed", { cache: "no-store" });
  const data = await jsonOrThrow(
    res,
    (raw) => recentlyViewedResponseSchema.parse(raw),
    "Could not load recently viewed.",
  );
  return data.data;
}
