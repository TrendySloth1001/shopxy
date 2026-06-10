/**
 * Client-side home-feed fetchers. Hit the same-origin BFF routes (never the
 * backend directly) and return mapped presentation models.
 */

import { mapEndlessProducts, mapFeed, mapPersonalized } from "./mapper";
import type { EndlessPage, HomeFeed, ProductCard } from "./types";

async function getJson(url: string): Promise<unknown> {
  const res = await fetch(url, { headers: { Accept: "application/json" } });
  if (!res.ok) throw new Error(`Request failed (${res.status})`);
  return res.json();
}

export async function fetchFeed(): Promise<HomeFeed> {
  return mapFeed(await getJson("/api/home/feed"));
}

export async function fetchPersonalized(): Promise<{
  recommended: ProductCard[];
  recentlyViewed: ProductCard[];
}> {
  return mapPersonalized(await getJson("/api/home/personalized"));
}

export async function fetchEndlessPage(page: number, seed?: number): Promise<EndlessPage> {
  const qp = new URLSearchParams({ page: String(page), limit: "16" });
  if (seed != null) qp.set("seed", String(seed));
  const raw = (await getJson(`/api/home/feed/page?${qp.toString()}`)) as {
    products?: unknown;
    seed?: unknown;
    nextPage?: unknown;
  };
  return {
    products: mapEndlessProducts(Array.isArray(raw?.products) ? raw.products : []),
    seed: typeof raw?.seed === "number" ? raw.seed : (seed ?? 0),
    nextPage: typeof raw?.nextPage === "number" ? raw.nextPage : page + 1,
  };
}
