import { BannerDetailSchema, type BannerDetail } from "./types";

/** Fetch a banner + its pinned products via the same-origin BFF route. */
export async function fetchBannerDetail(id: number): Promise<BannerDetail> {
  const res = await fetch(`/api/banners/${id}`, { headers: { Accept: "application/json" } });
  if (!res.ok) throw new Error(`Request failed (${res.status})`);
  return BannerDetailSchema.parse(await res.json());
}
