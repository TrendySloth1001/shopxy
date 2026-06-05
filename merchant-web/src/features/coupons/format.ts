import type { Coupon } from "./schema";

const inr = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
});

/** Rupees → "₹120" (no decimals, matching the Flutter list/editor). */
export function rupees(value: number): string {
  return inr.format(value);
}

/** "20% off" / "₹120 off" — the headline discount string. */
export function discountLabel(c: Pick<Coupon, "discountType" | "discountValue">): string {
  return c.discountType === "PERCENT"
    ? `${Math.round(c.discountValue)}% off`
    : `${rupees(c.discountValue)} off`;
}

/**
 * Lifecycle status, mirroring the Flutter `_CouponRow` precedence:
 * inactive → expired → exhausted → live.
 */
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

/** Token-based badge classes for each lifecycle state. */
export const COUPON_STATE_CLASSES: Record<CouponState, string> = {
  live: "bg-success-soft text-success",
  inactive: "bg-error-soft text-error",
  expired: "bg-warning-soft text-warning",
  exhausted: "bg-warning-soft text-warning",
};
