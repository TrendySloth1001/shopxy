import { promotionListSchema, promotionSchema, type Promotion } from "./schema";

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

export type PromotionCreate = {
  productId: number;
  budgetPaise: number;
  dailyCapPaise: number;
  cpmPaise: number;
  startAt: string;
  endAt: string;
};

export function listPromotions(): Promise<Promotion[]> {
  return fetch("/api/promotions", { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => promotionListSchema.parse(raw).data, "Could not load promotions."),
  );
}

export function createPromotion(input: PromotionCreate): Promise<Promotion> {
  return fetch("/api/promotions", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => promotionSchema.parse(raw), "Could not create the promotion."));
}

export async function cancelPromotion(id: number): Promise<void> {
  const res = await fetch(`/api/promotions/${id}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) {
    await jsonOrThrow(res, () => null, "Could not cancel the promotion.");
  }
}
