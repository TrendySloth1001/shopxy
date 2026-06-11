"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { CloudOff, Loader2, RefreshCw } from "lucide-react";
import { fetchEndlessPage, fetchFeed, fetchPersonalized } from "../api";
import { appendHomeBlocks, newCycleState, type CycleState } from "../composer";
import { recordImpression } from "../tracking";
import { EMPTY_FEED, type HomeBlock, type HomeFeed, type ProductCard } from "../types";
import { TopBar } from "./top-bar";
import { SearchBar } from "./search-bar";
import { CategoryRail } from "./category-rail";
import { TrustStrip } from "./trust-strip";
import { RecentlyViewed } from "./recently-viewed";
import { ProductCarousel } from "./product-carousel";
import { FeedBlock } from "./feed-block";
import { FooterStrip } from "./footer-strip";

type Status = "loading" | "ready" | "error";

/** Products a block surfaces — used to fire impressions for appended blocks. */
function productsInBlock(b: HomeBlock): ProductCard[] {
  switch (b.kind) {
    case "mosaic":
      return [b.hero, b.topRight, b.bottomRight];
    case "compare":
      return [b.left, b.right];
    case "zigzag":
      return [b.hero, b.pair];
    case "poster":
      return [b.product];
    case "grid2":
    case "grid3":
    case "vertical":
    case "reels":
    case "category":
    case "chips":
    case "carousel":
    case "sponsored":
    case "recentlyViewed":
    case "leaderboard":
    case "brandFocus":
    case "priceBand":
    case "shopShowcase":
      return b.products;
    default:
      return [];
  }
}

// Hysteresis band for the header collapse. Collapsing the search bar removes
// ~88px of page height, which shifts scrollY — a single threshold makes that
// feed back and flicker the header. Two thresholds with a dead band between
// them (collapse past 96, only re-expand below 24) break the loop.
const COLLAPSE_AT = 96;
const EXPAND_AT = 24;

export function HomeFeed() {
  const [status, setStatus] = useState<Status>("loading");
  const [error, setError] = useState<string | null>(null);
  const [feed, setFeed] = useState<HomeFeed>(EMPTY_FEED);
  const [blocks, setBlocks] = useState<HomeBlock[]>([]);
  const [collapsed, setCollapsed] = useState(false);

  const [loadingMore, setLoadingMore] = useState(false);
  const [exhausted, setExhausted] = useState(false);

  // Mutable pager/composer state kept in refs (doesn't drive rendering).
  const cycle = useRef<CycleState>(newCycleState());
  const seed = useRef<number | undefined>(undefined);
  const page = useRef(0);
  const failureStreak = useRef(0);
  const loadingMoreRef = useRef(false);
  const exhaustedRef = useRef(false);
  const statusRef = useRef<Status>("loading");
  const booted = useRef(false);

  const fireImpressions = useCallback((appended: HomeBlock[]) => {
    for (const b of appended) for (const p of productsInBlock(b)) recordImpression(p.productId);
  }, []);

  const loadMore = useCallback(
    async (feedOverride?: HomeFeed) => {
      if (loadingMoreRef.current || exhaustedRef.current) return;
      if (statusRef.current !== "ready") return;
      loadingMoreRef.current = true;
      setLoadingMore(true);
      try {
        const pg = await fetchEndlessPage(page.current, seed.current);
        seed.current ??= pg.seed;
        page.current = pg.nextPage;
        failureStreak.current = 0;
        const appended = appendHomeBlocks(cycle.current, feedOverride ?? feed, pg.products);
        if (appended.length > 0) {
          setBlocks((prev) => [...prev, ...appended]);
          fireImpressions(appended);
        }
      } catch {
        failureStreak.current += 1;
        if (failureStreak.current >= 3) {
          exhaustedRef.current = true;
          setExhausted(true);
        }
      } finally {
        loadingMoreRef.current = false;
        setLoadingMore(false);
      }
    },
    [fireImpressions, feed],
  );

  useEffect(() => {
    statusRef.current = status;
  }, [status]);

  const boot = useCallback(async () => {
    setStatus("loading");
    statusRef.current = "loading";
    setError(null);
    // reset pager/composer
    cycle.current = newCycleState();
    seed.current = undefined;
    page.current = 0;
    failureStreak.current = 0;
    exhaustedRef.current = false;
    setExhausted(false);
    try {
      const next = await fetchFeed();
      setFeed(next);
      const initial = appendHomeBlocks(cycle.current, next, []);
      setBlocks(initial);
      fireImpressions(initial);
      setStatus("ready");
      statusRef.current = "ready";
      // personalised overlay (background) — non-fatal
      void fetchPersonalized()
        .then((p) => {
          setFeed((prev) => ({ ...prev, recommended: p.recommended, recentlyViewed: p.recentlyViewed }));
        })
        .catch(() => {});
      // prime one endless page so the first scroll doesn't hit a loader
      void loadMore(next);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load home");
      setStatus("error");
      statusRef.current = "error";
    }
  }, [fireImpressions, loadMore]);

  useEffect(() => {
    if (booted.current) return;
    booted.current = true;
    void boot();
  }, [boot]);

  // Header collapse + endless prefetch on window scroll. rAF-throttled so a
  // burst of scroll events collapses to one measurement per frame, and the
  // collapse uses hysteresis (COLLAPSE_AT / EXPAND_AT) so the height change it
  // triggers can't bounce the header across the threshold.
  useEffect(() => {
    let ticking = false;
    const measure = () => {
      ticking = false;
      const y = window.scrollY;
      setCollapsed((prev) => (prev ? y > EXPAND_AT : y > COLLAPSE_AT));
      const nearBottom =
        window.innerHeight + y >= document.documentElement.scrollHeight - window.innerHeight * 1.5;
      if (nearBottom) void loadMore();
    };
    const onScroll = () => {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(measure);
    };
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, [loadMore]);

  return (
    <div className="min-h-dvh bg-canvas">
      {/* Marketplace shell — centered at max-w-shell on wide screens, never full
          bleed (Amazon/Flipkart-style). The sticky header bg spans the viewport
          while its content stays aligned with the feed. */}
      <header className="sticky top-0 z-20 bg-canvas">
        <div className="mx-auto w-full max-w-shell">
          <TopBar collapsed={collapsed} />
          <SearchBar collapsed={collapsed} />
          <div className="mx-lg h-px bg-hairline" />
        </div>
      </header>

      <div className="mx-auto w-full max-w-shell">
        {status === "error" ? (
          <ErrorRetry message={error ?? "Could not load home"} onRetry={boot} />
        ) : status === "loading" ? (
          <HomeSkeleton />
        ) : (
          <Feed feed={feed} blocks={blocks} loadingMore={loadingMore} exhausted={exhausted} />
        )}
      </div>
    </div>
  );
}

function Feed({
  feed,
  blocks,
  loadingMore,
  exhausted,
}: {
  feed: HomeFeed;
  blocks: HomeBlock[];
  loadingMore: boolean;
  exhausted: boolean;
}) {
  return (
    <main className="flex flex-col gap-xl pb-massive pt-md">
      {/* Prelude — browse intent → continuity → freshness, then the endless cycle. */}
      <CategoryRail pucks={feed.categoryPucks} />
      <TrustStrip />
      {feed.recentlyViewed.length > 0 ? <RecentlyViewed items={feed.recentlyViewed} /> : null}
      {feed.newInStock.length > 0 ? (
        <ProductCarousel eyebrow="JUST LANDED" title="Fresh in stock" products={feed.newInStock} />
      ) : null}

      {blocks.map((b, i) => (
        <FeedBlock key={`${b.kind}-${i}`} block={b} />
      ))}

      {/* Tail sentinel */}
      {exhausted ? (
        <div className="flex flex-col items-center gap-lg px-lg pb-massive">
          <FooterStrip />
          <p className="text-center text-[12.5px] text-muted">You&apos;ve reached the end — refresh for more</p>
        </div>
      ) : loadingMore ? (
        <div className="flex justify-center py-xl">
          <Loader2 size={22} className="animate-spin text-muted" aria-hidden />
        </div>
      ) : blocks.length === 0 ? (
        <FooterStrip />
      ) : null}
    </main>
  );
}

function HomeSkeleton() {
  return (
    <div className="flex flex-col gap-xl px-lg pt-lg">
      <div className="flex gap-lg overflow-hidden">
        {Array.from({ length: 8 }).map((_, i) => (
          <div key={i} className="flex flex-col items-center gap-[6px]">
            <div className="size-16 rounded-full bg-hero-panel" />
            <div className="h-2 w-10 rounded-xs bg-hero-panel" />
          </div>
        ))}
      </div>
      <div className="h-[188px] rounded-lg bg-hero-panel" />
      <div className="h-[232px] rounded-lg bg-hero-panel" />
      <div className="h-[130px] rounded-lg bg-hero-panel" />
      <div className="h-[280px] rounded-lg bg-hero-panel" />
    </div>
  );
}

function ErrorRetry({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center gap-md px-xl py-massive text-center">
      <CloudOff size={56} className="text-muted" aria-hidden />
      <p className="text-[17px] font-extrabold text-ink">Couldn&apos;t load your home feed</p>
      <p className="text-[13px] text-muted">{message}</p>
      <button
        type="button"
        onClick={onRetry}
        className="mt-sm inline-flex items-center gap-sm rounded-button bg-brand px-lg py-sm text-label-lg font-semibold text-white transition-opacity hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        <RefreshCw size={16} aria-hidden /> Try again
      </button>
    </div>
  );
}
