/**
 * Client-side fetchers for the cart BFF routes.
 * All calls go to /api/* — never directly to the backend.
 */

import {
  cartResponseSchema,
  mergeBffResponseSchema,
  setQtyResponseSchema,
  type CartItem,
  type SetQtyResponse,
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
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

/** GET /api/me/cart — fetch the server cart. */
export async function fetchCart(): Promise<CartItem[]> {
  const res = await fetch("/api/me/cart", { cache: "no-store" });
  const { data } = await jsonOrThrow(
    res,
    (raw) => cartResponseSchema.parse(raw),
    "Could not load your cart.",
  );
  return data;
}

/**
 * PUT /api/me/cart/:productId — set qty.
 * Returns null when the server responds 204 (line removed).
 */
export async function setCartQty(
  productId: number,
  quantity: number,
): Promise<SetQtyResponse | null> {
  const res = await fetch(`/api/me/cart/${productId}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ quantity }),
  });
  if (res.status === 204) return null;
  return jsonOrThrow(
    res,
    (raw) => setQtyResponseSchema.parse(raw),
    "Could not update cart.",
  );
}

/** DELETE /api/me/cart/:productId — remove a single line. */
export async function removeCartLine(productId: number): Promise<void> {
  const res = await fetch(`/api/me/cart/${productId}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) throw new Error("Could not remove item.");
}

/** DELETE /api/me/cart — clear the whole cart. */
export async function clearServerCart(): Promise<void> {
  const res = await fetch("/api/me/cart", { method: "DELETE" });
  if (!res.ok && res.status !== 204) throw new Error("Could not clear cart.");
}

/**
 * POST /api/me/cart/merge — merge a guest-cart array into the server cart
 * on first login. Returns the full post-merge cart.
 */
export async function mergeGuestCart(
  items: { productId: number; quantity: number }[],
): Promise<CartItem[]> {
  const res = await fetch("/api/me/cart/merge", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ items }),
  });
  const { data } = await jsonOrThrow(
    res,
    (raw) => mergeBffResponseSchema.parse(raw),
    "Could not merge your cart.",
  );
  return data;
}
