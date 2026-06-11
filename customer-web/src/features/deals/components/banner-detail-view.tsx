"use client";

import { startTransition, useCallback, useEffect, useState } from "react";
import { CloudOff, RefreshCw, Tag } from "lucide-react";
import Link from "next/link";
import type { BannerSlide } from "../types";
import { fetchBannerSlide } from "../api";
import { BannerSkeleton } from "./banner-skeleton";
import { BannerHero } from "./banner-hero";
import { BannerDealStrip } from "./banner-deal-strip";
import { BannerProductCard } from "./banner-product-card";
import { BackButton } from "@/shared/ui/back-button";

function ErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="flex flex-col items-center gap-md py-huge text-center">
      <CloudOff size={48} className="text-disabled" aria-hidden />
      <p className="text-title-md text-ink">Could not load this slide</p>
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

function NotFoundState() {
  return (
    <div className="flex flex-col items-center gap-md py-huge text-center">
      <Tag size={48} className="text-disabled" aria-hidden />
      <p className="text-title-md text-ink">Slide not available</p>
      <p className="max-w-[280px] text-body-sm text-muted">
        This banner has ended or is no longer active.
      </p>
      <Link
        href="/deals"
        className="mt-sm inline-flex h-10 items-center gap-sm rounded-button bg-ink px-lg text-label-md text-white transition-opacity hover:opacity-80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        Browse deals
      </Link>
    </div>
  );
}

function EmptyProducts() {
  return (
    <div className="flex flex-col items-center gap-md py-xl text-center">
      <Tag size={40} className="text-disabled" aria-hidden />
      <p className="text-title-sm text-ink">No products in this drop yet</p>
      <p className="text-body-sm text-muted">The shop is curating this slide — check back soon.</p>
    </div>
  );
}

type Status = "loading" | "ready" | "notfound" | "error";

/**
 * Banner detail client component. Fetches `/api/banners/:id/slide` and renders
 * the full page: hero, deal strip, product grid. Port of the Flutter
 * `BannerSlideDetailPage` / `_BannerSlideDetailPageState`.
 */
export function BannerDetailView({ bannerId }: { bannerId: number }) {
  const [status, setStatus] = useState<Status>("loading");
  const [error, setError] = useState<string | null>(null);
  const [slide, setSlide] = useState<BannerSlide | null>(null);

  const load = useCallback(async () => {
    setStatus("loading");
    setError(null);
    try {
      const data = await fetchBannerSlide(bannerId);
      setSlide(data);
      setStatus("ready");
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Unknown error";
      // 404 from the BFF indicates the banner is inactive / schedule outside window
      if (msg.includes("404") || msg.includes("not found")) {
        setStatus("notfound");
      } else {
        setError(msg);
        setStatus("error");
      }
    }
  }, [bannerId]);

  useEffect(() => {
    startTransition(() => { void load(); });
  }, [load]);

  if (status === "loading") return <BannerSkeleton />;
  if (status === "notfound") return <NotFoundState />;
  if (status === "error") return <ErrorState message={error ?? "Unknown error"} onRetry={load} />;
  if (!slide) return <NotFoundState />;

  const { banner, products, maxDiscountPct } = slide;

  return (
    <div className="min-h-screen bg-canvas">
      <div className="px-lg pt-md pb-xs">
        <BackButton fallback="/" />
      </div>
      {/* Hero — bleeds to the edges of the shell */}
      <BannerHero banner={banner} productCount={products.length} />

      {/* Deal strip */}
      <BannerDealStrip maxDiscountPct={maxDiscountPct} productCount={products.length} />

      {/* Product grid */}
      {products.length === 0 ? (
        <div className="px-lg py-xl">
          <EmptyProducts />
        </div>
      ) : (
        <div className="grid grid-cols-2 gap-lg px-lg py-lg pb-huge sm:grid-cols-3 lg:grid-cols-4">
          {products.map((p) => (
            <BannerProductCard key={p.id} product={p} />
          ))}
        </div>
      )}
    </div>
  );
}
