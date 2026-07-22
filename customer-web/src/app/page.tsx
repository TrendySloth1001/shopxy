import type { Metadata } from "next";
import { HomeFeed } from "@/features/home/components/home-feed";
import { backendFetch } from "@/server/auth/session";
import { mapFeed } from "@/features/home/mapper";
import type { HomeFeed as HomeFeedModel } from "@/features/home/types";

export const metadata: Metadata = {
  title: "ShopXY — Shop everything",
  description: "Discover trending products, flash deals and curated collections on ShopXY.",
};

/**
 * Server-side fetch of the public home feed for SSR / LCP / SEO — the same
 * `/home/feed` aggregator the BFF route proxies, called directly here so the
 * storefront's front door paints real content on first byte instead of a client
 * spinner. Returns undefined on any error → the client falls back to its own
 * fetch + loading/error states. Mirrors the PDP server-fetch pattern.
 */
async function fetchFeedServer(): Promise<HomeFeedModel | undefined> {
  try {
    const res = await backendFetch("/home/feed");
    if (!res.ok) return undefined;
    return mapFeed(await res.json());
  } catch {
    return undefined;
  }
}

/**
 * Customer home — the marketplace feed. Public (works signed-out). The base
 * feed is server-rendered here; the client component layers the endless pager
 * and personalised data on top once mounted. Port of the Flutter customer app's
 * `HomePage`.
 */
export default async function HomePage() {
  const initialFeed = await fetchFeedServer();
  return <HomeFeed initialFeed={initialFeed} />;
}
