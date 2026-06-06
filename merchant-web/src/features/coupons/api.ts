import {
  couponListSchema,
  couponRedemptionListSchema,
  couponSchema,
  type Coupon,
  type CouponRedemption,
  type DiscountType,
} from "./schema";

async function jsonOrThrow<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

async function okOrThrow(res: Response, fallback: string): Promise<void> {
  if (res.ok || res.status === 204) return;
  await jsonOrThrow(res, () => null, fallback);
}

export type CouponWrite = {
  code: string;
  title: string;
  description?: string | null;
  discountType: DiscountType;
  discountValue: number;
  maxDiscount?: number | null;
  minOrderAmount?: number;
  validFrom: string;
  validUntil: string;
  perUserLimit?: number;
  totalCap?: number;
  isPublic?: boolean;
  firstOrderOnly?: boolean;
  isActive?: boolean;
};

export function listCoupons(): Promise<Coupon[]> {
  return fetch("/api/coupons", { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => couponListSchema.parse(raw).data, "Could not load coupons."),
  );
}

export function getCoupon(id: number): Promise<Coupon> {
  return fetch(`/api/coupons/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => couponSchema.parse(raw), "Could not load the coupon."),
  );
}

/** Recent redemptions for a coupon (admin analytics). */
export function listCouponRedemptions(id: number): Promise<CouponRedemption[]> {
  return fetch(`/api/coupons/${id}/redemptions`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => couponRedemptionListSchema.parse(raw).data, "Could not load redemptions."),
  );
}

export function createCoupon(input: CouponWrite): Promise<{ id: number }> {
  return fetch("/api/coupons", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) =>
    jsonOrThrow(r, (raw) => ({ id: Number((raw as { id?: number }).id) }), "Could not create the coupon."),
  );
}

export async function updateCoupon(id: number, input: Partial<CouponWrite>): Promise<void> {
  const res = await fetch(`/api/coupons/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  });
  await okOrThrow(res, "Could not update the coupon.");
}

export async function deactivateCoupon(id: number): Promise<void> {
  const res = await fetch(`/api/coupons/${id}`, { method: "DELETE" });
  await okOrThrow(res, "Could not deactivate the coupon.");
}
