import type { Metadata } from "next";
import { HomeFeed } from "@/features/home/components/home-feed";

export const metadata: Metadata = {
  title: "ShopXY — Shop everything",
  description: "Discover trending products, flash deals and curated collections on ShopXY.",
};

/**
 * Customer home — the marketplace feed. Public (works signed-out); the feed
 * client component fetches `/home/feed` + the endless pager via the BFF and
 * layers personalised data on top once a session is present. Port of the
 * Flutter customer app's `HomePage`.
 */
export default function HomePage() {
  return <HomeFeed />;
}
