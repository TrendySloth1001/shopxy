import { productDetailSchema, fbtCardSchema, type ProductDetail, type FbtCard } from "./types";

async function getJson(url: string): Promise<unknown> {
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  if (!res.ok) {
    let message = `Request failed (${res.status})`;
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
    }
    throw new Error(message);
  }
  return res.json();
}

export async function fetchProduct(id: string): Promise<ProductDetail> {
  const raw = await getJson(`/api/marketplace/products/${id}`);
  return productDetailSchema.parse(raw);
}

export async function fetchFbt(productId: string): Promise<FbtCard[]> {
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

export async function toggleWishlist(
  productId: string,
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
    }
    throw new Error(msg);
  }
}

export async function getWishlistIds(): Promise<Set<string> | null> {
  const res = await fetch("/api/me/wishlist", { cache: "no-store" });
  if (res.status === 401) return null;
  if (!res.ok) return null;
  try {
    const body = (await res.json()) as { data?: Array<{ productId?: number | string }> };
    const ids = new Set<string>();
    if (Array.isArray(body?.data)) {
      for (const item of body.data) {
        if (item.productId != null) ids.add(String(item.productId));
      }
    }
    return ids;
  } catch {
    return null;
  }
}

export function recordView(productId: string): void {
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
  });
}
