import {
  payoutAccountSchema,
  shopSchema,
  type CancellationPolicy,
  type PayoutAccount,
  type RefundMode,
  type Shop,
} from "./schema";

async function okJson<T>(res: Response, parse: (raw: unknown) => T, fallback: string): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

export type ShopUpdate = {
  name?: string;
  tagline?: string | null;
  logoUrl?: string | null;
  bannerUrl?: string | null;
  locationCity?: string | null;
  locationState?: string | null;
  returnPolicy?: string | null;
  shippingPolicy?: string | null;
  refundPolicy?: string | null;
  vacationMode?: boolean;
  vacationMessage?: string | null;
  returnsEnabled?: boolean;
  returnWindowDays?: number;
  refundMode?: RefundMode;
  returnPolicyNote?: string | null;
  cancellationPolicy?: CancellationPolicy;
  operatingHours?: Record<string, [string, string]> | null;
  pdfTemplateId?: string;
};

export function getShop(): Promise<Shop> {
  return fetch("/api/shop", { cache: "no-store" }).then((r) =>
    okJson(r, (raw) => shopSchema.parse(raw), "Could not load your shop."),
  );
}

export function updateShop(input: ShopUpdate): Promise<Shop> {
  return fetch("/api/shop", {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => okJson(r, (raw) => shopSchema.parse(raw), "Could not save your shop."));
}

export function setShopPublished(isPublished: boolean): Promise<Shop> {
  return fetch("/api/shop/publish", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ isPublished }),
  }).then((r) => okJson(r, (raw) => shopSchema.parse(raw), "Could not update publish state."));
}

export async function uploadShopImage(file: File): Promise<string> {
  const form = new FormData();
  form.append("file", file);
  const res = await fetch("/api/upload", { method: "POST", body: form });
  return okJson(res, (raw) => (raw as { url: string }).url, "Upload failed.");
}

export async function getPayoutStatus(opts?: { refresh?: boolean }): Promise<PayoutAccount | null> {
  const res = await fetch(`/api/payouts${opts?.refresh ? "?refresh=1" : ""}`, { cache: "no-store" });
  if (res.status === 404) return null;
  return okJson(
    res,
    (raw) => (raw == null ? null : payoutAccountSchema.parse(raw)),
    "Could not load payout status.",
  );
}
