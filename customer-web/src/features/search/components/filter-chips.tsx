"use client";

import { SlidersHorizontal, X } from "lucide-react";
import { formatINR } from "@/shared/format";
import type { SearchFacets, SearchFilters } from "../types";
import { activeFilterCount } from "../types";

type Props = {
  filters: SearchFilters;
  facets: SearchFacets | null | undefined;
  onChangeFilters: (f: SearchFilters) => void;
};

/** Inline chip strip for active filters + a filter trigger. */
export function FilterChips({ filters, facets, onChangeFilters }: Props) {
  const count = activeFilterCount(filters);

  function remove(key: keyof SearchFilters) {
    const next = { ...filters };
    delete next[key];
    onChangeFilters(next);
  }

  return (
    <div className="flex flex-wrap items-center gap-sm">
      {/* Filter icon trigger — only show when facets available */}
      {facets ? (
        <FilterButton
          activeCount={count}
          facets={facets}
          filters={filters}
          onChangeFilters={onChangeFilters}
        />
      ) : null}

      {/* Active filter chips */}
      {filters.ratingMin != null ? (
        <Chip
          label={`${filters.ratingMin}★ & up`}
          onRemove={() => remove("ratingMin")}
        />
      ) : null}
      {filters.priceMin != null || filters.priceMax != null ? (
        <Chip
          label={[
            filters.priceMin != null ? `${formatINR(filters.priceMin)}+` : null,
            filters.priceMax != null ? `up to ${formatINR(filters.priceMax)}` : null,
          ]
            .filter(Boolean)
            .join(" – ")}
          onRemove={() => {
            const next = { ...filters };
            delete next.priceMin;
            delete next.priceMax;
            onChangeFilters(next);
          }}
        />
      ) : null}
      {filters.inStock ? (
        <Chip label="In stock" onRemove={() => remove("inStock")} />
      ) : null}

      {/* Clear all */}
      {count > 0 ? (
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

// ── Inline filter panel ───────────────────────────────────────────────────────
// A simple popover-style panel that renders over the results.
// Full facet-driven filter sheet — mirrors the Flutter `FilterSheet`.

function FilterButton({
  activeCount,
  facets,
  filters,
  onChangeFilters,
}: {
  activeCount: number;
  facets: SearchFacets;
  filters: SearchFilters;
  onChangeFilters: (f: SearchFilters) => void;
}) {
  return (
    <FilterPanel facets={facets} filters={filters} onChangeFilters={onChangeFilters}>
      {(open) => (
        <button
          type="button"
          onClick={open}
          className={[
            "inline-flex items-center gap-[5px] rounded-full border px-md py-[5px] text-[11px] font-bold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft",
            activeCount > 0
              ? "border-brand bg-brand-soft text-brand"
              : "border-hairline bg-white text-muted hover:text-ink",
          ].join(" ")}
        >
          <SlidersHorizontal size={12} aria-hidden />
          {activeCount > 0 ? `Filters · ${activeCount}` : "Filters"}
        </button>
      )}
    </FilterPanel>
  );
}

/**
 * Modal-style filter panel. Rendered inline (no portal needed) because the
 * search page has a simple layout with no stacking context conflicts.
 */
function FilterPanel({
  facets,
  filters,
  onChangeFilters,
  children,
}: {
  facets: SearchFacets;
  filters: SearchFilters;
  onChangeFilters: (f: SearchFilters) => void;
  children: (open: () => void) => React.ReactNode;
}) {
  // Local draft state — applied on "Apply"
  const [isOpen, setIsOpen] = useState(false);
  const [draft, setDraft] = useState<SearchFilters>(filters);

  function openPanel() {
    setDraft(filters); // reset draft to current filters
    setIsOpen(true);
  }

  function applyAndClose() {
    onChangeFilters(draft);
    setIsOpen(false);
  }

  const ratings = [4, 3, 2, 1];

  return (
    <>
      {children(openPanel)}

      {isOpen ? (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center bg-ink/40 sm:items-center"
          onClick={(e) => {
            if (e.target === e.currentTarget) setIsOpen(false);
          }}
          role="dialog"
          aria-modal
          aria-label="Filter results"
        >
          <div className="w-full max-w-sm rounded-t-dialog bg-white pb-massive pt-xxl shadow-menu sm:rounded-dialog sm:pb-xxl">
            {/* Header */}
            <div className="flex items-center justify-between border-b border-hairline px-lg pb-md">
              <h3 className="text-title-md text-ink">Filter results</h3>
              <button
                type="button"
                aria-label="Close filters"
                onClick={() => setIsOpen(false)}
                className="flex size-8 items-center justify-center rounded-full text-muted hover:bg-surface-tint focus-visible:outline-none"
              >
                <X size={18} aria-hidden />
              </button>
            </div>

            <div className="max-h-[60vh] overflow-y-auto px-lg pt-lg">
              {/* Rating */}
              <section className="mb-lg">
                <p className="mb-sm text-[11px] font-extrabold uppercase tracking-wide text-muted">
                  Minimum rating
                </p>
                <div className="flex flex-wrap gap-sm">
                  {ratings.map((r) => (
                    <button
                      key={r}
                      type="button"
                      onClick={() =>
                        setDraft((d) => ({
                          ...d,
                          ratingMin: d.ratingMin === r ? undefined : r,
                        }))
                      }
                      className={[
                        "inline-flex items-center gap-[4px] rounded-full border px-md py-[5px] text-[12px] font-bold transition-colors focus-visible:outline-none",
                        draft.ratingMin === r
                          ? "border-brand bg-brand text-white"
                          : "border-hairline bg-white text-ink hover:border-brand hover:text-brand",
                      ].join(" ")}
                    >
                      {r}★ & up
                    </button>
                  ))}
                </div>
              </section>

              {/* Price range */}
              {facets.priceMin < facets.priceMax ? (
                <section className="mb-lg">
                  <p className="mb-sm text-[11px] font-extrabold uppercase tracking-wide text-muted">
                    Price range
                  </p>
                  <div className="flex items-center gap-sm">
                    <div className="flex-1">
                      <label className="mb-[2px] block text-[10px] text-muted">
                        Min (₹)
                      </label>
                      <input
                        type="number"
                        min={facets.priceMin}
                        max={facets.priceMax}
                        value={draft.priceMin ?? ""}
                        onChange={(e) =>
                          setDraft((d) => ({
                            ...d,
                            priceMin: e.target.value ? Number(e.target.value) : undefined,
                          }))
                        }
                        placeholder={String(Math.floor(facets.priceMin))}
                        className="h-9 w-full rounded-input border border-hairline bg-canvas px-md text-body-md text-ink focus:outline-none focus:ring-2 focus:ring-brand-soft"
                      />
                    </div>
                    <span className="mt-lg text-muted">–</span>
                    <div className="flex-1">
                      <label className="mb-[2px] block text-[10px] text-muted">
                        Max (₹)
                      </label>
                      <input
                        type="number"
                        min={facets.priceMin}
                        max={facets.priceMax}
                        value={draft.priceMax ?? ""}
                        onChange={(e) =>
                          setDraft((d) => ({
                            ...d,
                            priceMax: e.target.value ? Number(e.target.value) : undefined,
                          }))
                        }
                        placeholder={String(Math.ceil(facets.priceMax))}
                        className="h-9 w-full rounded-input border border-hairline bg-canvas px-md text-body-md text-ink focus:outline-none focus:ring-2 focus:ring-brand-soft"
                      />
                    </div>
                  </div>
                </section>
              ) : null}

              {/* In stock */}
              {facets.inStockCount > 0 ? (
                <section className="mb-lg">
                  <label className="flex cursor-pointer items-center gap-md">
                    <input
                      type="checkbox"
                      checked={!!draft.inStock}
                      onChange={(e) =>
                        setDraft((d) => ({
                          ...d,
                          inStock: e.target.checked || undefined,
                        }))
                      }
                      className="h-4 w-4 rounded accent-brand"
                    />
                    <span className="text-body-md text-ink">
                      In stock only{" "}
                      <span className="text-muted">({facets.inStockCount})</span>
                    </span>
                  </label>
                </section>
              ) : null}
            </div>

            {/* Footer */}
            <div className="flex gap-sm border-t border-hairline px-lg pt-md">
              <button
                type="button"
                onClick={() => {
                  setDraft({});
                  onChangeFilters({});
                  setIsOpen(false);
                }}
                className="h-10 flex-1 rounded-button border border-hairline text-label-md text-muted transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                Reset
              </button>
              <button
                type="button"
                onClick={applyAndClose}
                className="h-10 flex-1 rounded-button bg-brand text-label-md text-white transition-opacity hover:opacity-90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                Apply
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </>
  );
}

// React import for useState (the component uses hooks, so we need to import).
import { useState } from "react";
