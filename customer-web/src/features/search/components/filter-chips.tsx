"use client";

import { X } from "@/shared/icons";
import type { SearchFacets, SearchFilters } from "../types";

type Props = {
  filters: SearchFilters;
  facets: SearchFacets | null | undefined;
  onChangeFilters: (f: SearchFilters) => void;
};

export function FilterChips({ filters, facets: _f, onChangeFilters }: Props) {
  void _f;
  function remove(key: keyof SearchFilters) {
    const next = { ...filters };
    delete next[key];
    onChangeFilters(next);
  }

  const hasSupportedFilters =
    filters.categoryId != null || filters.shopId != null;

  return (
    <div className="flex flex-wrap items-center gap-sm">

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

      {hasSupportedFilters ? (
        <button
          type="button"
          onClick={() => onChangeFilters({})}
          className="text-caption font-bold text-muted underline-offset-2 hover:text-ink hover:underline focus-visible:outline-none"
        >
          Clear all
        </button>
      ) : null}
    </div>
  );
}

function Chip({ label, onRemove }: { label: string; onRemove: () => void }) {
  return (
    <span className="inline-flex items-center gap-[4px] rounded-full border border-brand bg-brand-soft px-md py-[4px] text-caption font-bold text-brand">
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
