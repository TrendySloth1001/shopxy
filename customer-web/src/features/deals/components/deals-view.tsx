"use client";

import { startTransition, useCallback, useEffect, useState } from "react";
import { RefreshCw, Zap } from "lucide-react";
import type { FlashDeal, BrandSpotlight } from "@/features/home/types";
import { fetchDealsFeed } from "../api";
import { DealsSkeleton } from "./deals-skeleton";
import { FlashDealsGrid } from "./flash-deals-grid";
import { SpotlightsList } from "./spotlights-list";

type Status = "loading" | "ready" | "error";

function EmptyState({ onRefresh }: { onRefresh: () => void }) {
  return (
    <div className="flex flex-col items-center gap-md py-huge text-center">
      <Zap size={48} className="text-disabled" aria-hidden />
      <p className="text-title-md text-ink">No deals right now</p>
      <p className="max-w-[280px] text-body-md text-muted">
        Flash sales drop without notice — pull to refresh and be the first to grab a deal.
      </p>
      <button
        onClick={onRefresh}
        className="mt-sm inline-flex h-10 items-center gap-sm rounded-button bg-ink px-lg text-label-md text-white transition-opacity hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        <RefreshCw size={16} aria-hidden />
        Refresh
      </button>
    </div>
  );
}

function ErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center gap-md py-huge text-center">
      <p className="text-title-md text-ink">Could not load deals</p>
      <p className="max-w-[280px] text-body-sm text-muted">{message}</p>
      <button
        onClick={onRetry}
        className="mt-sm inline-flex h-10 items-center gap-sm rounded-button bg-ink px-lg text-label-md text-white transition-opacity hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        <RefreshCw size={16} aria-hidden />
        Try again
      </button>
    </div>
  );
}

/**
 * Full deals-page client component. Fetches the home feed and extracts
 * flash deals + brand spotlights. Port of the Flutter `DealsPage` / `_DealsPageState`.
 *
 * Layout:
 *   1. Flash deals section — peach gradient header with live countdown, 2-4 col grid.
 *   2. Brand spotlights section — 16:9 image cards.
 *   Empty / error states with retry affordances.
 */
export function DealsView() {
  const [status, setStatus] = useState<Status>("loading");
  const [error, setError] = useState<string | null>(null);
  const [flashDeals, setFlashDeals] = useState<FlashDeal[]>([]);
  const [spotlights, setSpotlights] = useState<BrandSpotlight[]>([]);

  const load = useCallback(async () => {
    setStatus("loading");
    setError(null);
    try {
      const { flashDeals: fd, brandSpotlights: bs } = await fetchDealsFeed();
      setFlashDeals(fd);
      setSpotlights(bs);
      setStatus("ready");
    } catch (e) {
      setError(e instanceof Error ? e.message : "Unknown error");
      setStatus("error");
    }
  }, []);

  useEffect(() => {
    startTransition(() => { void load(); });
  }, [load]);

  if (status === "loading") return <DealsSkeleton />;
  if (status === "error") return <ErrorState message={error ?? "Unknown error"} onRetry={load} />;
  if (flashDeals.length === 0 && spotlights.length === 0) return <EmptyState onRefresh={load} />;

  return (
    <div className="flex flex-col gap-xl">
      <FlashDealsGrid deals={flashDeals} />
      <SpotlightsList spotlights={spotlights} />
    </div>
  );
}
