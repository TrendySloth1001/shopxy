"use client";

import { Clock, Search, TrendingUp } from "@/shared/icons";
import type { AutocompleteSuggestions } from "../types";

type Props = {
  suggestions: AutocompleteSuggestions;
  activeIndex: number;
  onSelect: (term: string) => void;
};

export function AutocompleteDropdown({ suggestions, activeIndex, onSelect }: Props) {
  const { products, terms } = suggestions;
  if (products.length === 0 && terms.length === 0) return null;

  let flatIndex = -1;

  return (
    <div
      role="listbox"
      aria-label="Search suggestions"
      className="absolute left-0 right-0 top-full z-50 mt-xxs overflow-hidden rounded-md border border-hairline bg-white shadow-menu"
    >
      {products.length > 0 ? (
        <section>
          <p className="border-b border-hairline px-md py-[5px] text-nano font-extrabold uppercase tracking-[0.8px] text-muted">
            Products
          </p>
          <ul>
            {products.map((p) => {
              flatIndex++;
              const fi = flatIndex;
              return (
                <li key={p.id} role="option" aria-selected={fi === activeIndex}>
                  <button
                    type="button"
                    onMouseDown={(e) => {
                      e.preventDefault();
                      onSelect(p.name);
                    }}
                    className={[
                      "flex w-full items-center gap-sm px-md py-[9px] text-left text-[13px] font-semibold text-ink transition-colors",
                      fi === activeIndex ? "bg-brand-soft" : "hover:bg-surface-tint",
                    ].join(" ")}
                  >
                    <Search
                      size={13}
                      className={fi === activeIndex ? "text-brand" : "text-muted"}
                      aria-hidden
                    />
                    <span className="line-clamp-1">{p.name}</span>
                  </button>
                </li>
              );
            })}
          </ul>
        </section>
      ) : null}

      {terms.length > 0 ? (
        <section>
          <p className="border-b border-hairline px-md py-[5px] text-nano font-extrabold uppercase tracking-[0.8px] text-muted">
            Popular
          </p>
          <ul>
            {terms.map((term) => {
              flatIndex++;
              const fi = flatIndex;
              return (
                <li key={term} role="option" aria-selected={fi === activeIndex}>
                  <button
                    type="button"
                    onMouseDown={(e) => {
                      e.preventDefault();
                      onSelect(term);
                    }}
                    className={[
                      "flex w-full items-center gap-sm px-md py-[9px] text-left text-[13px] font-semibold text-ink transition-colors",
                      fi === activeIndex ? "bg-brand-soft" : "hover:bg-surface-tint",
                    ].join(" ")}
                  >
                    <TrendingUp
                      size={13}
                      className={fi === activeIndex ? "text-brand" : "text-muted"}
                      aria-hidden
                    />
                    <span className="line-clamp-1">{term}</span>
                  </button>
                </li>
              );
            })}
          </ul>
        </section>
      ) : null}
    </div>
  );
}

export function RecentDropdown({
  terms,
  activeIndex,
  onSelect,
  onClear,
}: {
  terms: string[];
  activeIndex: number;
  onSelect: (t: string) => void;
  onClear: () => void;
}) {
  if (terms.length === 0) return null;
  return (
    <div
      role="listbox"
      aria-label="Recent searches"
      className="absolute left-0 right-0 top-full z-50 mt-xxs overflow-hidden rounded-md border border-hairline bg-white shadow-menu"
    >
      <div className="flex items-center justify-between border-b border-hairline px-md py-[5px]">
        <p className="text-nano font-extrabold uppercase tracking-[0.8px] text-muted">
          Recent
        </p>
        <button
          type="button"
          onMouseDown={(e) => {
            e.preventDefault();
            onClear();
          }}
          className="text-micro font-bold text-muted hover:text-ink focus-visible:outline-none"
        >
          Clear
        </button>
      </div>
      <ul>
        {terms.map((term, i) => (
          <li key={term} role="option" aria-selected={i === activeIndex}>
            <button
              type="button"
              onMouseDown={(e) => {
                e.preventDefault();
                onSelect(term);
              }}
              className={[
                "flex w-full items-center gap-sm px-md py-[9px] text-left text-[13px] font-semibold text-ink transition-colors",
                i === activeIndex ? "bg-brand-soft" : "hover:bg-surface-tint",
              ].join(" ")}
            >
              <Clock
                size={13}
                className={i === activeIndex ? "text-brand" : "text-muted"}
                aria-hidden
              />
              <span className="line-clamp-1">{term}</span>
            </button>
          </li>
        ))}
      </ul>
    </div>
  );
}
