"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { Sparkles } from "lucide-react";
import { fetchSpotlights } from "@/features/catalog/api";
import type { Spotlight } from "@/features/catalog/types";
import { ImageBox } from "@/features/home/components/image-box";
import { resolveImageUrl, parseColor } from "@/features/home/format";
import { color as tokens } from "@/shared/ui/tokens";

/**
 * Full-page list of all brand spotlights — port of the Flutter SpotlightsListPage.
 * Reachable via the "View all" affordance on the home feed spotlight block.
 */
export function SpotlightsListView() {
  const [spotlights, setSpotlights] = useState<Spotlight[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const booted = useRef(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchSpotlights();
      setSpotlights(data);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Something went wrong.");
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    if (booted.current) return;
    booted.current = true;
    void load();
  }, [load]);

  return (
    <div className="mx-auto max-w-shell px-lg py-lg">
      <h1 className="mb-lg text-headline-sm text-ink">Brands in Spotlight</h1>

      {loading ? (
        <div className="flex flex-col gap-md">
          {Array.from({ length: 4 }).map((_, i) => (
            <SpotlightCardSkeleton key={i} />
          ))}
        </div>
      ) : error ? (
        <div className="flex flex-col items-center gap-md py-xxxl text-center">
          <Sparkles size={48} className="text-disabled" />
          <p className="text-title-sm text-muted">Could not load spotlights</p>
          <p className="text-body-sm text-muted">{error}</p>
          <button
            type="button"
            onClick={() => void load()}
            className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-lg text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            Try again
          </button>
        </div>
      ) : spotlights.length === 0 ? (
        <div className="flex flex-col items-center gap-md py-xxxl text-center">
          <Sparkles size={48} className="text-disabled" />
          <p className="text-title-sm text-muted">No spotlights running right now.</p>
          <p className="text-body-sm text-muted">Check back soon for featured brands.</p>
          <Link
            href="/"
            className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-muted hover:border-brand hover:text-brand focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            Back to home
          </Link>
        </div>
      ) : (
        <div className="flex flex-col gap-md">
          {spotlights.map((s) => (
            <SpotlightCard key={s.id} spotlight={s} />
          ))}
        </div>
      )}
    </div>
  );
}

// ── Spotlight card ────────────────────────────────────────────────────────────

function SpotlightCard({ spotlight }: { spotlight: Spotlight }) {
  const s = spotlight;
  const imageUrl = resolveImageUrl(s.heroImageUrl);
  const bgColor = parseColor(s.bgColor ?? null, tokens.surface.heroPanel);
  const shopSlug = s.shop?.slug;
  const brandName = s.shop?.name ?? "";

  const inner = (
    <div
      className="relative w-full overflow-hidden rounded-lg"
      style={{ backgroundColor: bgColor }}
    >
      {/* 16:9 card */}
      <div className="aspect-video w-full">
        {imageUrl ? (
          <ImageBox url={imageUrl} alt={brandName} fit="cover" />
        ) : (
          <div className="size-full" style={{ backgroundColor: bgColor }} />
        )}
      </div>

      {/* Gradient overlay */}
      <div
        className="absolute inset-0"
        style={{
          background:
            "linear-gradient(to bottom, rgba(0,0,0,0.12), transparent 35%, rgba(0,0,0,0.55))",
        }}
      />

      {/* Content overlay */}
      <div className="absolute inset-x-md bottom-md">
        {s.dealLabel ? (
          <span className="mb-sm inline-block rounded-xs bg-spotlight px-[12px] py-[6px] text-[13px] font-extrabold text-ink">
            {s.dealLabel}
          </span>
        ) : null}
        {brandName ? (
          <p className="text-[18px] font-extrabold leading-tight text-white [text-shadow:0_1px_6px_rgba(0,0,0,0.5)]">
            {brandName}
          </p>
        ) : null}
        {s.subtitle ? (
          <p className="mt-xs line-clamp-2 text-[13px] font-medium leading-snug text-white/90 [text-shadow:0_1px_4px_rgba(0,0,0,0.45)]">
            {s.subtitle}
          </p>
        ) : null}
      </div>
    </div>
  );

  if (shopSlug) {
    return (
      <Link
        href={`/shop/${shopSlug}`}
        className="block rounded-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        {inner}
      </Link>
    );
  }

  return <div>{inner}</div>;
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

function SpotlightCardSkeleton() {
  return (
    <div className="w-full overflow-hidden rounded-lg">
      <div className="aspect-video w-full animate-pulse bg-hero-panel" />
    </div>
  );
}
