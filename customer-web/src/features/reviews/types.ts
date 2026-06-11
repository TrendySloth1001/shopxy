import { z } from "zod";

export const reviewUserSchema = z.object({
  id: z.number(),
  name: z.string(),
});

export const reviewSchema = z.object({
  id: z.number(),
  productId: z.number(),
  userId: z.number(),
  rating: z.number(),
  title: z.string().nullable().optional(),
  body: z.string().nullable().optional(),
  createdAt: z.string(),
  updatedAt: z.string(),
  user: reviewUserSchema,
});
export type Review = z.infer<typeof reviewSchema>;

export const reviewSummarySchema = z.object({
  ratingAvg: z.coerce.number().nullable().optional(),
  ratingCount: z.number().default(0),
  verifiedCount: z.number().default(0),
  histogram: z
    .object({
      "1": z.number().default(0),
      "2": z.number().default(0),
      "3": z.number().default(0),
      "4": z.number().default(0),
      "5": z.number().default(0),
    })
    .default({ "1": 0, "2": 0, "3": 0, "4": 0, "5": 0 }),
  recent: z.array(reviewSchema).default([]),
});
export type ReviewSummary = z.infer<typeof reviewSummarySchema>;

export const reviewPageSchema = z.object({
  data: z.array(reviewSchema),
  nextCursor: z.number().nullable().optional(),
});
export type ReviewPage = z.infer<typeof reviewPageSchema>;
