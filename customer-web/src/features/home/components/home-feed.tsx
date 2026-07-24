"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { CloudOff, Loader2, RefreshCw } from "@/shared/icons";
import { fetchEndlessPage, fetchFeed, fetchPersonalized } from "../api";
import { recordImpression } from "../tracking";
import { EMPTY_FEED, type HeroSlide, type HomeFeed, type ProductCard } from "../types";
import { TopBar } from "./top-bar";
import { SearchBar } from "./search-bar";
import { CategoryRail } from "./category-rail";
import { TrustStrip } from "./trust-strip";
import { RecentlyViewed } from "./recently-viewed";
import { ProductCarousel } from "./product-carousel";
import { ProductTile } from "./product-tile";
import { HeroSlideCard } from "./hero-slide";
import { FooterStrip } from "./footer-strip";

type Status = "loading" | "ready" | "error";

// Hysteresis band for the header collapse. Collapsing the search bar removes
// ~88px of page height, which shifts scrollY — a single threshold makes that
// feed back and flicker the header. Two thresholds with a dead band between
// them (collapse past 96, only re-expand below 24) break the loop.
const COLLAPSE_AT = 96;
const EXPAND_AT = 24;

export function HomeFeed({ initialFeed }: { initialFeed?: HomeFeed }) {
  const [status, setStatus] = useState<Status>(initialFeed ? "ready" : "loading");
  const [error, setError] = useState<string | null>(null);
  const [feed, setFeed] = useState<HomeFeed>(initialFeed ?? EMPTY_FEED);
  const [products, setProducts] = useState<ProductCard[]>([]);
  const [collapsed, setCollapsed] = useState(false);

  const [loadingMore, setLoadingMore] = useState(false);
  const [exhausted, setExhausted] = useState(false);

  // Mutable pager state kept in refs (doesn't drive rendering).
  const seed = useRef<number | undefined>(undefined);
  const page = useRef(0);
  const seen = useRef<Set<string>>(new Set());
  const failureStreak = useRef(0);
  const loadingMoreRef = useRef(false);
  const exhaustedRef = useRef(false);
  const statusRef = useRef<Status>(initialFeed ? "ready" : "loading");
  const booted = useRef(false);

  const appendProducts = useCallback((incoming: ProductCard[]) => {
    const fresh = incoming.filter((p) => !seen.current.has(p.productId));
    if (fresh.length === 0) return;
    for (const p of fresh) {
      seen.current.add(p.productId);
      recordImpression(p.productId);
    }
    setProducts((prev) => [...prev, ...fresh]);
  }, []);

  const loadMore = useCallback(async () => {
    if (loadingMoreRef.current || exhaustedRef.current) return;
    if (statusRef.current !== "ready") return;
    loadingMoreRef.current = true;
    setLoadingMore(true);
    try {
      const pg = await fetchEndlessPage(page.current, seed.current);
      seed.current ??= pg.seed;
      page.current = pg.nextPage;
      failureStreak.current = 0;
      appendProducts(pg.products);
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
  }, [appendProducts]);

  useEffect(() => {
    statusRef.current = status;
  }, [status]);

  const boot = useCallback(async () => {
    setStatus("loading");
    statusRef.current = "loading";
    setError(null);
    seed.current = undefined;
    page.current = 0;
    seen.current = new Set();
    failureStreak.current = 0;
    exhaustedRef.current = false;
    setExhausted(false);
    setProducts([]);
    try {
      const next = await fetchFeed();
      setFeed(next);
      setStatus("ready");
      statusRef.current = "ready";
      // personalised overlay (background) — non-fatal
      void fetchPersonalized()
        .then((p) => {
          setFeed((prev) => ({ ...prev, recommended: p.recommended, recentlyViewed: p.recentlyViewed }));
        })
        .catch(() => {});
      // prime the first endless page so the first scroll doesn't hit a loader
      void loadMore();
    } catch (e) {
      setError(e instanceof Error ? e.message : "Could not load home");
      setStatus("error");
      statusRef.current = "error";
    }
  }, [loadMore]);

  // First-mount entry point. When SSR delivered the base feed (see app/page.tsx)
  // status already starts "ready", so skip the initial fetch — just layer
  // personalization on top and prime the first endless page so the first scroll
  // doesn't hit a loader. Otherwise do the full client boot. Manual retry (the
  // error state) always goes through boot().
  const start = useCallback(async () => {
    if (initialFeed) {
      void fetchPersonalized()
        .then((p) => {
          setFeed((prev) => ({ ...prev, recommended: p.recommended, recentlyViewed: p.recentlyViewed }));
        })
        .catch(() => {});
      await loadMore();
    } else {
      await boot();
    }
  }, [initialFeed, loadMore, boot]);

  useEffect(() => {
    if (booted.current) return;
    booted.current = true;
    void start();
  }, [start]);

  // Header collapse + endless prefetch on window scroll. rAF-throttled, with
  // hysteresis (COLLAPSE_AT / EXPAND_AT) so the height change it triggers can't
  // bounce the header across the threshold.
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
          <Feed feed={feed} products={products} loadingMore={loadingMore} exhausted={exhausted} />
        )}
      </div>
    </div>
  );
}

/** A horizontal, snap-scrolling strip of banner images for one placement. */
function BannerStrip({ slides, widthClass }: { slides: HeroSlide[]; widthClass: string }) {
  if (slides.length === 0) return null;
  return (
    <div className="flex snap-x snap-mandatory gap-md overflow-x-auto px-lg pb-xs [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
      {slides.map((s) => (
        <div key={s.bannerId} className={`${widthClass} shrink-0 snap-center`}>
          <HeroSlideCard slide={s} />
        </div>
      ))}
    </div>
  );
}

function Feed({
  feed,
  products,
  loadingMore,
  exhausted,
}: {
  feed: HomeFeed;
  products: ProductCard[];
  loadingMore: boolean;
  exhausted: boolean;
}) {
  return (
    <main className="flex flex-col gap-xl pb-massive pt-md">
      <CategoryRail pucks={feed.categoryPucks} />

      {/* Hero banners — full-width snap carousel. */}
      <BannerStrip slides={feed.heroSlides} widthClass="w-[88%] sm:w-[70%] lg:w-[48%]" />

      <TrustStrip />

      {feed.recentlyViewed.length > 0 ? <RecentlyViewed items={feed.recentlyViewed} /> : null}

      {feed.adStrip.length > 0 ? (
        <BannerStrip slides={feed.adStrip} widthClass="w-[70%] sm:w-[46%] lg:w-[31%]" />
      ) : null}

      {feed.newInStock.length > 0 ? (
        <ProductCarousel eyebrow="JUST LANDED" title="Fresh in stock" products={feed.newInStock} layout="rail" />
      ) : null}

      {feed.promoBanners.length > 0 ? (
        <BannerStrip slides={feed.promoBanners} widthClass="w-[70%] sm:w-[46%] lg:w-[31%]" />
      ) : null}

      {feed.trending.length > 0 ? (
        <ProductCarousel eyebrow="TRENDING" title="Trending now" products={feed.trending} layout="rail" />
      ) : null}

      {feed.curatedRails.length > 0 ? (
        <BannerStrip slides={feed.curatedRails} widthClass="w-[88%] sm:w-[70%] lg:w-[48%]" />
      ) : null}

      {/* Endless product grid — the main browse surface. */}
      {products.length > 0 ? (
        <section>
          <div className="mt-md grid grid-cols-2 gap-md px-lg md:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
            {products.map((p, i) => (
              // First row (≤5 cols at xl) loads eagerly as the LCP candidate;
              // the rest stay lazy.
              <ProductTile key={p.productId} product={p} source="home" priority={i < 5} />
            ))}
          </div>
        </section>
      ) : null}

      {/* Tail sentinel */}
      {exhausted ? (
        <div className="flex flex-col items-center gap-lg px-lg pb-massive">
          <FooterStrip />
          <p className="text-center text-label-md text-muted">You&apos;ve reached the end — refresh for more</p>
        </div>
      ) : loadingMore ? (
        <div className="flex justify-center py-xl">
          <Loader2 size={22} className="animate-spin text-muted" aria-hidden />
        </div>
      ) : products.length === 0 ? (
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
      <p className="text-headline-sm font-extrabold text-ink">Couldn&apos;t load your home feed</p>
      <p className="text-body-sm text-muted">{message}</p>
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
