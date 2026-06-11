import { z } from "zod";

// ── Place Order ───────────────────────────────────────────────────────────────

export const placeOrderRequestSchema = z.object({
  items: z.array(
    z.object({
      productId: z.number(),
      quantity: z.number(),
      expectedUnitPrice: z.number().optional(),
    }),
  ),
  note: z.string().max(500).optional(),
  addressId: z.number().optional(),
  couponCode: z.string().max(40).optional(),
  useWallet: z.boolean().optional(),
});

export type PlaceOrderRequest = z.infer<typeof placeOrderRequestSchema>;

export const placeOrderResponseSchema = z.object({
  id: z.number(),
  shopOrders: z.array(
    z.object({ id: z.number(), shopId: z.number() }),
  ),
  couponDiscount: z.number(),
  walletPaid: z.number(),
});

export type PlaceOrderResponse = z.infer<typeof placeOrderResponseSchema>;

// ── Coupon preview ────────────────────────────────────────────────────────────

export const couponSchema = z.object({
  id: z.number(),
  code: z.string(),
  discountType: z.string(),
  discountValue: z.number(),
  maxDiscountAmount: z.number().nullable().optional(),
  minOrderAmount: z.number().nullable().optional(),
  description: z.string().nullable().optional(),
  expiresAt: z.string().nullable().optional(),
});

export type Coupon = z.infer<typeof couponSchema>;

export const couponValidateResponseSchema = z.union([
  z.object({ ok: z.literal(true), coupon: couponSchema }),
  z.object({ ok: z.literal(false), code: z.string(), message: z.string() }),
]);

export type CouponValidateResponse = z.infer<typeof couponValidateResponseSchema>;

export const autoApplyResponseSchema = z.union([
  z.object({ ok: z.literal(true), coupon: couponSchema }),
  z.object({ ok: z.literal(false) }),
]);

export type AutoApplyResponse = z.infer<typeof autoApplyResponseSchema>;

/** Computed coupon discount given a subtotal. */
export function computeCouponDiscount(coupon: Coupon, subtotal: number): number {
  let discount = 0;
  if (coupon.discountType === "PERCENT") {
    discount = (coupon.discountValue / 100) * subtotal;
    if (coupon.maxDiscountAmount != null) {
      discount = Math.min(discount, coupon.maxDiscountAmount);
    }
  } else {
    // FLAT
    discount = coupon.discountValue;
  }
  return Math.min(discount, subtotal);
}

// ── Wallet snapshot ───────────────────────────────────────────────────────────

export const walletSnapshotSchema = z.object({
  balance: z.number(),
  ledgerBalance: z.number(),
});

export type WalletSnapshot = z.infer<typeof walletSnapshotSchema>;

// ── Pay session ───────────────────────────────────────────────────────────────

export const paySessionSchema = z.object({
  intentId: z.number(),
  provider: z.literal("RAZORPAY"),
  providerOrderRef: z.string(),
  amount: z.number(),
  currency: z.literal("INR"),
  clientParams: z.object({
    key: z.string(),
    order_id: z.string(),
    amount: z.number(),
    currency: z.string().optional(),
  }),
  reused: z.boolean(),
});

export type PaySessionResponse = z.infer<typeof paySessionSchema>;

// ── Payment sync ──────────────────────────────────────────────────────────────

export const paySyncResponseSchema = z.object({
  paymentStatus: z.enum(["COD", "PENDING", "PAID"]),
  settled: z.boolean(),
});

export type PaySyncResponse = z.infer<typeof paySyncResponseSchema>;
