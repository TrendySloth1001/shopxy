/**
 * Account extras — types for wishlist, reviews, coupons, recently-viewed.
 * Ported from the Flutter customer app (features/wishlist, features/reviews,
 * features/coupons, features/recently_viewed).
 */

// ── Wishlist ────────────────────────────────────────────────────────────────

export interface WishlistProduct {
  id: number;
  name: string;
  sku: string;
  unit: string;
  mrp: number;
  sellingPrice: number;
  taxPercent: number;
  stockQuantity: number;
  isActive: boolean;
  isPublished: boolean;
  categoryId?: number | null;
  images: { url: string; sortOrder: number }[];
  shop?: { id: number; name: string; slug: string } | null;
}

export interface WishlistItem {
  id: number;
  productId: number;
  product: WishlistProduct;
}

// ── Reviews ─────────────────────────────────────────────────────────────────

export interface MyReview {
  id: number;
  productId: number;
  userId: number;
  rating: number;
  title?: string | null;
  body?: string | null;
  createdAt: string;
  updatedAt: string;
  product: {
    id: number;
    name: string;
    sellingPrice: number;
    images: { url: string; sortOrder: number }[];
  };
}

// ── Coupons ─────────────────────────────────────────────────────────────────

export type DiscountType = "PERCENT" | "FLAT";

export interface Coupon {
  id: number;
  code: string;
  title: string;
  description?: string | null;
  discountType: DiscountType;
  discountValue: number;
  maxDiscount?: number | null;
  minOrderValue?: number | null;
  validFrom: string;
  validUntil: string;
  isPublic: boolean;
  firstOrderOnly: boolean;
  perUserLimit?: number | null;
  /** How many times this caller has already used this coupon. */
  usedCount: number;
}

/** True if this coupon is fully used up for the caller. */
export function isCouponExhausted(c: Coupon): boolean {
  return c.perUserLimit != null && c.usedCount >= c.perUserLimit;
}

/** Short human-readable discount headline, e.g. "20% off up to ₹200". */
export function couponHeadline(c: Coupon, formatINR: (v: number) => string): string {
  if (c.discountType === "PERCENT") {
    const base = `${c.discountValue}% off`;
    return c.maxDiscount ? `${base} up to ${formatINR(c.maxDiscount)}` : base;
  }
  return `${formatINR(c.discountValue)} off`;
}

/** "Min order ₹500" or empty. */
export function couponMinOrderLabel(c: Coupon, formatINR: (v: number) => string): string {
  return c.minOrderValue ? `Min order ${formatINR(c.minOrderValue)}` : "";
}

// ── Recently viewed ──────────────────────────────────────────────────────────

export interface RecentlyViewedProduct {
  id: number;
  name: string;
  sellingPrice: number;
  mrp: number;
  ratingAvg?: number | null;
  ratingCount: number;
  images: { url: string; sortOrder: number }[];
  shop: { id: number; name: string; slug: string };
}

export interface RecentlyViewedItem {
  productId: number;
  viewedAt: string;
  product: RecentlyViewedProduct;
}
