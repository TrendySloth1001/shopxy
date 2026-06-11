import type { Metadata } from "next";
import { AppHeader } from "@/features/auth/components/app-header";
import { DealsView } from "@/features/deals/components/deals-view";
import { BackButton } from "@/shared/ui/back-button";

export const metadata: Metadata = {
  title: "Deals — ShopXY",
  description:
    "Flash sales, brand spotlights and the best prices on ShopXY — updated every day.",
};

/**
 * Deals page (`/deals`). Public.
 *
 * Reads flash deals + brand spotlights from the home feed and renders them
 * as a full-page experience: live-countdown flash grid + brand-spotlight cards.
 * Port of the Flutter customer app's `DealsPage`.
 */
export default function DealsPage() {
  return (
    <>
      <AppHeader />
      <main className="mx-auto max-w-shell px-lg py-xxxl">
        <BackButton fallback="/" className="mb-sm" />
        <h1 className="mb-xl text-headline-md text-ink">Deals</h1>
        <DealsView />
      </main>
    </>
  );
}
