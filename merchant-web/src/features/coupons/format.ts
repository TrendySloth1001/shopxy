import type { Coupon } from "./schema";

const inr = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
});

export function rupees(value: number): string {
  return inr.format(value);
}

export function discountLabel(c: Pick<Coupon, "discountType" | "discountValue">): string {
  return c.discountType === "PERCENT"
    ? `${Math.round(c.discountValue)}% off`
    : `${rupees(c.discountValue)} off`;
}

export type CouponState = "live" | "inactive" | "expired" | "exhausted";

export function couponState(c: Coupon, now: Date = new Date()): CouponState {
  if (!c.isActive) return "inactive";
  if (now > new Date(c.validUntil)) return "expired";
  if (c.totalCap > 0 && c.totalRedemptions >= c.totalCap) return "exhausted";
  return "live";
}

export const COUPON_STATE_LABELS: Record<CouponState, string> = {
  live: "Live",
  inactive: "Inactive",
  expired: "Expired",
  exhausted: "Exhausted",
};

export const COUPON_STATE_CLASSES: Record<CouponState, string> = {
  live: "bg-success-soft text-success",
  inactive: "bg-error-soft text-error",
  expired: "bg-warning-soft text-warning",
  exhausted: "bg-warning-soft text-warning",
};
