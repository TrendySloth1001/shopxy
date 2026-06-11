/**
 * PDP client-side fetchers — hit /api/* BFF routes only.
 */

import { productDetailSchema, fbtCardSchema, type ProductDetail, type FbtCard } from "./types";

async function getJson(url: string): Promise<unknown> {
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  if (!res.ok) {
    let message = `Request failed (${res.status})`;
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
      // keep default
    }
    throw new Error(message);
  }
  return res.json();
}

/** Fetch a single product for the PDP. */
export async function fetchProduct(id: number): Promise<ProductDetail> {
  const raw = await getJson(`/api/marketplace/products/${id}`);
  return productDetailSchema.parse(raw);
}

/** Fetch frequently-bought-together items. Resolves to [] on any error. */
export async function fetchFbt(productId: number): Promise<FbtCard[]> {
  try {
    const raw = (await getJson(
      `/api/marketplace/products/${productId}/frequently-bought-together`,
    )) as { data?: unknown };
    if (!Array.isArray(raw?.data)) return [];
    return raw.data.flatMap((item): FbtCard[] => {
      const r = fbtCardSchema.safeParse(item);
      return r.success ? [r.data] : [];
    });
  } catch {
    return [];
  }
}

/** Add / remove wishlist item (optimistic — caller supplies direction). */
export async function toggleWishlist(
  productId: number,
  add: boolean,
): Promise<void> {
  const res = await fetch(`/api/me/wishlist/${productId}`, {
    method: add ? "POST" : "DELETE",
  });
  if (!res.ok && res.status !== 204) {
    let msg = add ? "Could not add to wishlist." : "Could not remove from wishlist.";
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) msg = b.error;
    } catch {
      // keep default
    }
    throw new Error(msg);
  }
}

/** Check wishlist membership for a product. Returns null if not authenticated. */
export async function getWishlistIds(): Promise<Set<number> | null> {
  const res = await fetch("/api/me/wishlist", { cache: "no-store" });
  if (res.status === 401) return null;
  if (!res.ok) return null;
  try {
    const body = (await res.json()) as { data?: Array<{ productId?: number }> };
    const ids = new Set<number>();
    if (Array.isArray(body?.data)) {
      for (const item of body.data) {
        if (typeof item.productId === "number") ids.add(item.productId);
      }
    }
    return ids;
  } catch {
    return null;
  }
}

/** Fire-and-forget VIEW event for analytics. */
export function recordView(productId: number): void {
  if (typeof window === "undefined") return;
  const event = {
    clientUuid: crypto.randomUUID?.() ?? `view-${productId}-${Date.now()}`,
    eventType: "VIEW" as const,
    productId,
    source: "pdp",
    occurredAt: new Date().toISOString(),
  };
  void fetch("/api/v1/events", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ events: [event] }),
    keepalive: true,
  }).catch(() => {
    // best-effort
  });
}
