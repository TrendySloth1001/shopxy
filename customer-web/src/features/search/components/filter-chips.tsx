"use client";

import { X } from "@/shared/icons";
import type { SearchFacets, SearchFilters } from "../types";

type Props = {
  filters: SearchFilters;
  /**
   * Facets from the backend — retained in the prop signature so callers
   * don't need updating when filter support lands. Currently unused because
   * the filter panel is hidden (see note below).
   */
  facets: SearchFacets | null | undefined;
  onChangeFilters: (f: SearchFilters) => void;
};

/**
 * Inline chip strip for active filters.
 *
 * BACKEND NOTE: POST /search currently only honours `categoryId` and `shopId`.
 * The rating, price-range, and in-stock filter controls are hidden until the
 * backend supports those fields. Re-enable the FilterButton + FilterPanel
 * (preserved below in commented-out form) and restore the Chip renders for
 * priceMin/priceMax/ratingMin/inStock when that support lands.
 */
// facets is retained in Props for forward-compat; destructured to void to silence unused-var lint
export function FilterChips({ filters, facets: _f, onChangeFilters }: Props) {
  void _f; // facets retained for when backend filter support lands
  function remove(key: keyof SearchFilters) {
    const next = { ...filters };
    delete next[key];
    onChangeFilters(next);
  }

  const hasSupportedFilters =
    filters.categoryId != null || filters.shopId != null;

  return (
    <div className="flex flex-wrap items-center gap-sm">
      {/*
       * [HIDDEN — filter button disabled until backend supports price/rating/stock]
       * When re-enabling: restore FilterButton here and add price/rating/inStock
       * Chip renders below.
       */}

      {/* Active chips — supported filters only */}
      {filters.categoryId != null ? (
        <Chip
          label={`Category #${filters.categoryId}`}
          onRemove={() => remove("categoryId")}
        />
      ) : null}
      {filters.shopId != null ? (
        <Chip
          label={`Shop #${filters.shopId}`}
          onRemove={() => remove("shopId")}
        />
      ) : null}

      {/* Clear all */}
      {hasSupportedFilters ? (
        <button
          type="button"
          onClick={() => onChangeFilters({})}
          className="text-[11px] font-bold text-muted underline-offset-2 hover:text-ink hover:underline focus-visible:outline-none"
        >
          Clear all
        </button>
      ) : null}
    </div>
  );
}

function Chip({ label, onRemove }: { label: string; onRemove: () => void }) {
  return (
    <span className="inline-flex items-center gap-[4px] rounded-full border border-brand bg-brand-soft px-md py-[4px] text-[11px] font-bold text-brand">
      {label}
      <button
        type="button"
        onClick={onRemove}
        aria-label={`Remove filter: ${label}`}
        className="flex size-4 items-center justify-center rounded-full hover:bg-brand hover:text-white focus-visible:outline-none"
      >
        <X size={10} aria-hidden />
      </button>
    </span>
  );
}
