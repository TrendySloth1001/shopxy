"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Mic, QrCode, Search } from "@/shared/icons";

/** Rotating search hints — ported from the Flutter `HomeStaticData.searchHints`. */
export const SEARCH_HINTS = [
  'Search "noise cancelling earbuds"',
  'Search "summer kurta sets"',
  'Search "running shoes for men"',
  'Search "iphone 17 pro"',
  'Search "skincare serums"',
];

/** Cycle the hint index every 3s (paused under reduce-motion via the index hook). */
export function useRotatingHint(): number {
  const [i, setI] = useState(0);
  useEffect(() => {
    const id = setInterval(() => setI((n) => (n + 1) % SEARCH_HINTS.length), 3000);
    return () => clearInterval(id);
  }, []);
  return i;
}

/**
 * Big search pill — port of `HomeSearchBar`. Brand leading icon, a "SEARCH
 * SHOPXY" eyebrow over a rotating hint, and mic / scanner trailing actions.
 * Collapses to zero height as the header shrinks (the compact search then lives
 * in the top bar).
 *
 * The collapse transition is smooth via CSS — DO NOT change the collapsed prop
 * thresholds or the rAF logic in home-feed.tsx (not owned here).
 */
export function SearchBar({ collapsed }: { collapsed: boolean }) {
  const hint = useRotatingHint();
  return (
    <div
      className="overflow-hidden px-lg transition-all duration-200 motion-safe:transition-all"
      style={{ maxHeight: collapsed ? 0 : 80, opacity: collapsed ? 0 : 1, paddingBottom: collapsed ? 0 : 8 }}
      aria-hidden={collapsed}
    >
      <Link
        href="/search"
        className={[
          "flex h-14 items-center gap-[10px] rounded-lg border border-hairline bg-white px-sm",
          "transition-all duration-200",
          "hover:border-ink/20 hover:shadow-floating",
          "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft",
          "motion-safe:transition-all",
        ].join(" ")}
      >
        <span className="flex size-9 shrink-0 items-center justify-center rounded-sm bg-brand">
          <Search size={18} className="text-white" aria-hidden />
        </span>
        <span className="flex min-w-0 flex-1 flex-col">
          <span className="text-nano font-extrabold uppercase leading-none tracking-[0.9px] text-brand">
            Search ShopXY
          </span>
          <span className="mt-xxs line-clamp-1 text-[13px] font-semibold text-ink">{SEARCH_HINTS[hint]}</span>
        </span>
        <span className="mx-xxs h-6 w-px bg-hairline" aria-hidden />
        <span className="flex size-9 items-center justify-center rounded-full transition-colors duration-200 hover:bg-surface-tint motion-safe:transition-colors">
          <Mic size={18} className="text-brand" aria-hidden />
        </span>
        <span className="flex size-9 items-center justify-center rounded-full bg-brand-soft transition-colors duration-200 hover:bg-brand/10 motion-safe:transition-colors">
          <QrCode size={18} className="text-brand" aria-hidden />
        </span>
      </Link>
    </div>
  );
}
