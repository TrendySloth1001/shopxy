import type { Metadata } from "next";
import { HomeFeed } from "@/features/home/components/home-feed";
import { backendFetch } from "@/server/auth/session";
import { mapFeed } from "@/features/home/mapper";
import type { HomeFeed as HomeFeedModel } from "@/features/home/types";

export const metadata: Metadata = {
  title: "ShopXY — Shop everything",
  description: "Discover trending products, flash deals and curated collections on ShopXY.",
};

async function fetchFeedServer(): Promise<HomeFeedModel | undefined> {
  try {
    const res = await backendFetch("/home/feed");
    if (!res.ok) return undefined;
    return mapFeed(await res.json());
  } catch {
    return undefined;
  }
}

export default async function HomePage() {
  const initialFeed = await fetchFeedServer();
  return <HomeFeed initialFeed={initialFeed} />;
}
