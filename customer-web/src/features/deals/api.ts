/**
 * Client-side fetchers for the deals feature.
 * All routes hit same-origin BFF endpoints (/api/**) — never the backend directly.
 */

import { mapFeed } from "@/features/home/mapper";
import type { FlashDeal, BrandSpotlight, HomeFeed } from "@/features/home/types";
import type { BannerSlide } from "./types";
import { mapBannerSlide } from "./mapper";

async function getJson(url: string): Promise<unknown> {
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  if (!res.ok) {
    let message = `Request failed (${res.status})`;
    try {
      const b = (await res.json()) as { error?: string };
      if (b?.error) message = b.error;
    } catch {
      // ignore
    }
    throw new Error(message);
  }
  return res.json();
}

/** Fetches the home feed; deals page reads flash deals + brand spotlights from it. */
export async function fetchDealsFeed(): Promise<{
  flashDeals: FlashDeal[];
  brandSpotlights: BrandSpotlight[];
}> {
  const raw = await getJson("/api/home/feed");
  const feed: HomeFeed = mapFeed(raw);
  return { flashDeals: feed.flashDeals, brandSpotlights: feed.brandSpotlights };
}

/** Fetches a single banner slide with its curated product list. */
export async function fetchBannerSlide(id: number): Promise<BannerSlide> {
  const raw = await getJson(`/api/banners/${id}/slide`);
  return mapBannerSlide(raw);
}
