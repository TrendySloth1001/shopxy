import { flashSaleListSchema, flashSaleSchema, type FlashSale } from "./schema";

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

export type FlashDealCreate = {
  productId: number;
  flashPrice: number;
  stockLimit: number;
  startAt: string;
  endAt: string;
};

export type FlashDealUpdate = {
  flashPrice?: number;
  stockLimit?: number;
  startAt?: string;
  endAt?: string;
  isActive?: boolean;
};

/** Lists every flash deal for the shop (all statuses); partition client-side. */
export function listFlashDeals(): Promise<FlashSale[]> {
  return fetch("/api/flash-deals", { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => flashSaleListSchema.parse(raw).data, "Could not load flash deals."),
  );
}

export function createFlashDeal(input: FlashDealCreate): Promise<FlashSale> {
  return fetch("/api/flash-deals", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => flashSaleSchema.parse(raw), "Could not create the flash deal."));
}

export function updateFlashDeal(id: number, input: FlashDealUpdate): Promise<FlashSale> {
  return fetch(`/api/flash-deals/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => flashSaleSchema.parse(raw), "Could not save the flash deal."));
}

export async function cancelFlashDeal(id: number): Promise<void> {
  const res = await fetch(`/api/flash-deals/${id}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) {
    await jsonOrThrow(res, () => null, "Could not cancel the flash deal.");
  }
}
