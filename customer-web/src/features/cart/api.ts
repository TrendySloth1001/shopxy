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
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export async function fetchCart(): Promise<CartItem[]> {
  const res = await fetch("/api/me/cart", { cache: "no-store" });
  const { data } = await jsonOrThrow(
    res,
    (raw) => cartResponseSchema.parse(raw),
    "Could not load your cart.",
  );
  return data;
}

export async function setCartQty(
  productId: string,
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

export async function removeCartLine(productId: string): Promise<void> {
  const res = await fetch(`/api/me/cart/${productId}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) throw new Error("Could not remove item.");
}

export async function clearServerCart(): Promise<void> {
  const res = await fetch("/api/me/cart", { method: "DELETE" });
  if (!res.ok && res.status !== 204) throw new Error("Could not clear cart.");
}

export async function mergeGuestCart(
  items: { productId: string; quantity: number }[],
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
