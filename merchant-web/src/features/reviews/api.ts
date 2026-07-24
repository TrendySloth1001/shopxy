import { reviewSummarySchema, type ReviewSummary } from "./schema";

/** Fetch the rating summary (average, histogram, recent reviews) for a product. */
export async function getReviewSummary(productId: string): Promise<ReviewSummary> {
  const res = await fetch(`/api/products/${productId}/reviews/summary`, {
    cache: "no-store",
  });
  if (!res.ok) {
    let message = "Could not load reviews.";
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      // keep fallback
    }
    throw new Error(message);
  }
  return reviewSummarySchema.parse(await res.json());
}
