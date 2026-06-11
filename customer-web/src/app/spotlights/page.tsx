import type { Metadata } from "next";
import { AppHeader } from "@/features/auth/components/app-header";
import { SpotlightsListView } from "@/features/catalog/components/spotlights-list-view";

export const metadata: Metadata = {
  title: "Brands in Spotlight — ShopXY",
  description: "Discover featured brands and exclusive deals on ShopXY.",
};

/** Spotlights list page — `/spotlights`. Public. */
export default function SpotlightsPage() {
  return (
    <>
      <AppHeader />
      <SpotlightsListView />
    </>
  );
}
