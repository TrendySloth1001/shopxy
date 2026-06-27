import { z } from "zod";

/** A single customer review, as returned by the public reviews endpoints. */
export const reviewSchema = z
  .object({
    id: z.number(),
    productId: z.number(),
    userId: z.number(),
    rating: z.coerce.number(),
    title: z.string().nullish(),
    body: z.string().nullish(),
    createdAt: z.string(),
    updatedAt: z.string().nullish(),
    user: z
      .object({ id: z.number(), name: z.string().nullish() })
      .nullish(),
  })
  .passthrough();
export type Review = z.infer<typeof reviewSchema>;

/**
 * One-shot PDP summary: average, count, how many came from verified buyers,
 * a zero-filled 1..5 histogram, and the three most recent reviews so the
 * section renders without a follow-up list call.
 */
export const reviewSummarySchema = z
  .object({
    ratingAvg: z.coerce.number().nullish(),
    ratingCount: z.coerce.number().default(0),
    verifiedCount: z.coerce.number().default(0),
    histogram: z.record(z.string(), z.coerce.number()).default({}),
    recent: z.array(reviewSchema).default([]),
  })
  .passthrough();
export type ReviewSummary = z.infer<typeof reviewSummarySchema>;
