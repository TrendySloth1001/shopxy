import {
  bannerListSchema,
  bannerProductListSchema,
  bannerSchema,
  type Banner,
  type BannerProductRow,
  type DiscountType,
  type Placement,
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

export type BannerInput = {
  placement: Placement;
  imageUrl: string;
  linkUrl?: string | null;
  sortOrder?: number;
  isActive?: boolean;
  startAt?: string | null;
  endAt?: string | null;
};

export function listBanners(): Promise<Banner[]> {
  return fetch("/api/banners", { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => bannerListSchema.parse(raw).data, "Could not load banners."),
  );
}

export function getBanner(id: string): Promise<Banner> {
  return fetch(`/api/banners/${id}`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => bannerSchema.parse(raw), "Could not load the banner."),
  );
}

export function createBanner(input: BannerInput): Promise<Banner> {
  return fetch("/api/banners", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => bannerSchema.parse(raw), "Could not create the banner."));
}

export function updateBanner(id: string, input: Partial<BannerInput>): Promise<Banner> {
  return fetch(`/api/banners/${id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(input),
  }).then((r) => jsonOrThrow(r, (raw) => bannerSchema.parse(raw), "Could not update the banner."));
}

export async function deleteBanner(id: string): Promise<void> {
  const res = await fetch(`/api/banners/${id}`, { method: "DELETE" });
  if (!res.ok && res.status !== 204) {
    await jsonOrThrow(res, () => null, "Could not delete the banner.");
  }
}

// ── Pinned products ────────────────────────────────────────────────────────

export type BannerProductInput = {
  productId: string;
  discountType: DiscountType;
  discountValue: number;
  position: number;
};

export function listBannerProducts(bannerId: string): Promise<BannerProductRow[]> {
  return fetch(`/api/banners/${bannerId}/products`, { cache: "no-store" }).then((r) =>
    jsonOrThrow(r, (raw) => bannerProductListSchema.parse(raw).data, "Could not load banner products."),
  );
}

export function replaceBannerProducts(
  bannerId: string,
  items: BannerProductInput[],
): Promise<BannerProductRow[]> {
  return fetch(`/api/banners/${bannerId}/products`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ items }),
  }).then((r) =>
    jsonOrThrow(r, (raw) => bannerProductListSchema.parse(raw).data, "Could not save banner products."),
  );
}
