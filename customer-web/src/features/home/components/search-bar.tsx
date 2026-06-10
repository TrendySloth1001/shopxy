"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { Mic, QrCode, Search } from "lucide-react";

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
 */
export function SearchBar({ collapsed }: { collapsed: boolean }) {
  const hint = useRotatingHint();
  return (
    <div
      className="overflow-hidden px-lg transition-all duration-200"
      style={{ maxHeight: collapsed ? 0 : 80, opacity: collapsed ? 0 : 1, paddingBottom: collapsed ? 0 : 8 }}
      aria-hidden={collapsed}
    >
      <Link
        href="/search"
        className="flex h-14 items-center gap-[10px] rounded-lg border border-hairline bg-white px-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        <span className="flex size-9 shrink-0 items-center justify-center rounded-sm bg-brand">
          <Search size={18} className="text-white" aria-hidden />
        </span>
        <span className="flex min-w-0 flex-1 flex-col">
          <span className="text-[9.5px] font-extrabold uppercase leading-none tracking-[0.9px] text-brand">
            Search ShopXY
          </span>
          <span className="mt-[2px] line-clamp-1 text-[13px] font-semibold text-ink">{SEARCH_HINTS[hint]}</span>
        </span>
        <span className="mx-[2px] h-6 w-px bg-hairline" aria-hidden />
        <span className="flex size-9 items-center justify-center rounded-full">
          <Mic size={18} className="text-brand" aria-hidden />
        </span>
        <span className="flex size-9 items-center justify-center rounded-full bg-brand-soft">
          <QrCode size={18} className="text-brand" aria-hidden />
        </span>
      </Link>
    </div>
  );
}
