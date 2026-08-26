import { z } from "zod";

export const reviewSchema = z
  .object({
    id: z.coerce.string(),
    productId: z.coerce.string(),
    userId: z.coerce.string(),
    rating: z.coerce.number(),
    title: z.string().nullish(),
    body: z.string().nullish(),
    createdAt: z.string(),
    updatedAt: z.string().nullish(),
    user: z
      .object({ id: z.coerce.string(), name: z.string().nullish() })
      .nullish(),
  })
  .passthrough();
export type Review = z.infer<typeof reviewSchema>;

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
