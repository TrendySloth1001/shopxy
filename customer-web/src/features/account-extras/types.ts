export interface WishlistProduct {
  id: string;
  name: string;
  sku: string;
  unit: string;
  mrp: number;
  sellingPrice: number;
  taxPercent: number;
  stockQuantity: number;
  isActive: boolean;
  isPublished: boolean;
  categoryId?: string | null;
  images: { url: string; sortOrder: number }[];
  shop?: { id: string; name: string; slug: string } | null;
}

export interface WishlistItem {
  id: string;
  productId: string;
  product: WishlistProduct;
}

export interface MyReview {
  id: string;
  productId: string;
  userId: string;
  rating: number;
  title?: string | null;
  body?: string | null;
  createdAt: string;
  updatedAt: string;
  product: {
    id: string;
    name: string;
    sellingPrice: number;
    images: { url: string; sortOrder: number }[];
  };
}

export type DiscountType = "PERCENT" | "FLAT";

export interface Coupon {
  id: string;
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
  usedCount: number;
}

export function isCouponExhausted(c: Coupon): boolean {
  return c.perUserLimit != null && c.usedCount >= c.perUserLimit;
}

export function couponHeadline(c: Coupon, formatINR: (v: number) => string): string {
  if (c.discountType === "PERCENT") {
    const base = `${c.discountValue}% off`;
    return c.maxDiscount ? `${base} up to ${formatINR(c.maxDiscount)}` : base;
  }
  return `${formatINR(c.discountValue)} off`;
}

export function couponMinOrderLabel(c: Coupon, formatINR: (v: number) => string): string {
  return c.minOrderValue ? `Min order ${formatINR(c.minOrderValue)}` : "";
}

export interface RecentlyViewedProduct {
  id: string;
  name: string;
  sellingPrice: number;
  mrp: number;
  ratingAvg?: number | null;
  ratingCount: number;
  images: { url: string; sortOrder: number }[];
  shop: { id: string; name: string; slug: string };
}

export interface RecentlyViewedItem {
  productId: string;
  viewedAt: string;
  product: RecentlyViewedProduct;
}
