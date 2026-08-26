import {
  placeOrderResponseSchema,
  couponValidateResponseSchema,
  autoApplyResponseSchema,
  paySessionSchema,
  paySyncResponseSchema,
  type PlaceOrderRequest,
  type PlaceOrderResponse,
  type CouponValidateResponse,
  type AutoApplyResponse,
  type PaySessionResponse,
  type PaySyncResponse,
} from "./types";

async function jsonOrThrow<T>(
  res: Response,
  parse: (raw: unknown) => T,
  fallback: string,
): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export async function placeOrder(
  body: PlaceOrderRequest,
  idempotencyKey: string,
): Promise<PlaceOrderResponse> {
  const res = await fetch("/api/me/orders", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Idempotency-Key": idempotencyKey,
    },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    let errBody: Record<string, unknown> | null = null;
    let message = "Could not place order.";
    try {
      errBody = await res.json() as Record<string, unknown>;
      if (typeof errBody?.error === "string") message = errBody.error;
    } catch {  }
    const err = Object.assign(new Error(message), { body: errBody });
    throw err;
  }
  return placeOrderResponseSchema.parse(await res.json());
}

export async function validateCoupon(
  code: string,
  subtotal: number,
  shopIds: string[],
): Promise<CouponValidateResponse> {
  const res = await fetch("/api/me/coupons/validate", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ code, subtotal, shopIds }),
  });
  if (!res.ok) {
    try {
      const b = (await res.json()) as { ok?: boolean; code?: string; message?: string };
      if (b?.ok === false) {
        return { ok: false, code: b.code ?? "INVALID", message: b.message ?? "Invalid coupon." };
      }
    } catch {
    }
    throw new Error("Could not validate coupon.");
  }
  return jsonOrThrow(
    res,
    (raw) => couponValidateResponseSchema.parse(raw),
    "Could not validate coupon.",
  );
}

export async function autoApplyCoupon(
  subtotal: number,
  shopIds: string[],
): Promise<AutoApplyResponse> {
  const res = await fetch("/api/me/coupons/auto-apply", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ subtotal, shopIds }),
  });
  return jsonOrThrow(
    res,
    (raw) => autoApplyResponseSchema.parse(raw),
    "Could not check for coupons.",
  );
}

export async function initiatePayment(orderId: string): Promise<PaySessionResponse> {
  const res = await fetch(`/api/me/orders/${orderId}/pay`, { method: "POST" });
  return jsonOrThrow(
    res,
    (raw) => paySessionSchema.parse(raw),
    "Could not initiate payment.",
  );
}

export async function syncPayment(orderId: string): Promise<PaySyncResponse> {
  const res = await fetch(`/api/me/orders/${orderId}/payment/sync`, {
    method: "POST",
  });
  return jsonOrThrow(
    res,
    (raw) => paySyncResponseSchema.parse(raw),
    "Could not confirm payment status.",
  );
}
