/**
 * Zod schemas for account extras — validated at the BFF boundary.
 */

import { z } from "zod";

// ── Wishlist ─────────────────────────────────────────────────────────────────

const wishlistProductSchema = z.object({
  id: z.number(),
  name: z.string(),
  sku: z.string().default(""),
  unit: z.string().default(""),
  mrp: z.coerce.number(),
  sellingPrice: z.coerce.number(),
  taxPercent: z.coerce.number().default(0),
  stockQuantity: z.coerce.number().default(0),
  isActive: z.boolean().default(true),
  isPublished: z.boolean().default(true),
  categoryId: z.number().nullable().optional(),
  images: z
    .array(z.object({ url: z.string(), sortOrder: z.number().default(0) }))
    .default([]),
  shop: z
    .object({
      id: z.number(),
      name: z.string(),
      slug: z.string(),
    })
    .nullable()
    .optional(),
});

export const wishlistItemSchema = z
  .object({
    id: z.number(),
    savedAt: z.string().optional(),
    product: wishlistProductSchema,
  })
  .transform((o) => ({ ...o, productId: o.product.id }));

export const wishlistResponseSchema = z.object({
  data: z.array(wishlistItemSchema).default([]),
});

export type WishlistResponseRaw = z.infer<typeof wishlistResponseSchema>;

// ── Reviews ──────────────────────────────────────────────────────────────────

export const myReviewSchema = z.object({
  id: z.number(),
  productId: z.number(),
  userId: z.number(),
  rating: z.number(),
  title: z.string().nullable().optional(),
  body: z.string().nullable().optional(),
  createdAt: z.string(),
  updatedAt: z.string(),
  product: z.object({
    id: z.number(),
    name: z.string(),
    sellingPrice: z.coerce.number(),
    images: z
      .array(z.object({ url: z.string(), sortOrder: z.number() }))
      .default([]),
  }),
});

export const myReviewsResponseSchema = z.object({
  data: z.array(myReviewSchema).default([]),
  nextCursor: z.number().nullable().optional(),
});

export type MyReviewsResponseRaw = z.infer<typeof myReviewsResponseSchema>;

// ── Coupons ───────────────────────────────────────────────────────────────────

export const couponSchema = z.object({
  id: z.number(),
  code: z.string(),
  title: z.string(),
  description: z.string().nullable().optional(),
  discountType: z.enum(["PERCENT", "FLAT"]),
  discountValue: z.coerce.number(),
  maxDiscount: z.coerce.number().nullable().optional(),
  minOrderAmount: z.coerce.number().nullable().optional(),
  validFrom: z.string(),
  validUntil: z.string(),
  isPublic: z.boolean().default(false),
  firstOrderOnly: z.boolean().default(false),
  perUserLimit: z.number().nullable().optional(),
  alreadyUsed: z.number().default(0),
}).transform((c) => ({
  ...c,
  minOrderValue: c.minOrderAmount ?? null,
  usedCount: c.alreadyUsed,
}));

export const couponsResponseSchema = z.object({
  data: z.array(couponSchema).default([]),
});

export type CouponsResponseRaw = z.infer<typeof couponsResponseSchema>;

// ── Wallet ────────────────────────────────────────────────────────────────────

export const walletEntrySchema = z.object({
  id: z.number(),
  amount: z.coerce.number(),
  balanceAfter: z.coerce.number(),
  source: z.enum(["REFUND", "COUPON", "REFERRAL", "LOYALTY", "CHECKOUT", "TOPUP", "CANCEL", "MANUAL"]),
  sourceId: z.number().nullable().optional(),
  description: z.string(),
  createdAt: z.string(),
});

export const walletSnapshotSchema = z.object({
  balance: z.coerce.number(),
  ledgerBalance: z.number(),
  entries: z.array(walletEntrySchema).default([]),
});

export type WalletSnapshotRaw = z.infer<typeof walletSnapshotSchema>;

// ── Recently viewed ───────────────────────────────────────────────────────────

const recentlyViewedProductSchema = z.object({
  id: z.number(),
  name: z.string(),
  sellingPrice: z.coerce.number(),
  mrp: z.coerce.number(),
  ratingAvg: z.coerce.number().nullable().optional(),
  ratingCount: z.number().default(0),
  images: z
    .array(z.object({ url: z.string(), sortOrder: z.number() }))
    .default([]),
  shop: z.object({
    id: z.number(),
    name: z.string(),
    slug: z.string(),
  }),
});

export const recentlyViewedItemSchema = z
  .object({
    id: z.number().optional(),
    lastViewedAt: z.string().optional(),
    product: recentlyViewedProductSchema,
  })
  .transform((o) => ({
    ...o,
    productId: o.product.id,
    viewedAt: o.lastViewedAt ?? "",
  }));

export const recentlyViewedResponseSchema = z.object({
  data: z.array(recentlyViewedItemSchema).default([]),
});

export type RecentlyViewedResponseRaw = z.infer<typeof recentlyViewedResponseSchema>;
