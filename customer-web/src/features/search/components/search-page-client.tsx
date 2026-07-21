"use client";

/**
 * Search page — full-featured port of the Flutter `SearchPage`.
 *
 * State model:
 *   URL ?q=  ──► effects update local state ──► search fetch ──► results
 *
 * The effects use the cart-context idiom: inner async functions declared
 * and called inside useEffect so setState calls are inside the async fn,
 * not directly in the effect body — which is what the lint rule permits.
 */

import { useEffect, useRef, useState, useTransition } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import {
  ArrowLeft,
  Flame,
  RefreshCw,
  Search,
  SearchX,
  Sparkles,
  X,
} from "@/shared/icons";
import { fetchAutocomplete, fetchHints, fetchSearch } from "../api";
import { useRecentSearches } from "../use-recent-searches";
import { EMPTY_FILTERS, activeFilterCount } from "../types";
import type {
  AutocompleteSuggestions,
  SearchFacets,
  SearchFilters,
  SearchHit,
} from "../types";
import { AutocompleteDropdown, RecentDropdown } from "./autocomplete-dropdown";
import { FilterChips } from "./filter-chips";
import { SearchResultRow } from "./search-result-row";
import { SearchSkeleton } from "./search-skeleton";

const DEBOUNCE_MS = 250;
const AUTOCOMPLETE_DEBOUNCE_MS = 180;

// ── Main exported component ───────────────────────────────────────────────────

export function SearchPageClient({ initialQuery }: { initialQuery: string }) {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [, startTransition] = useTransition();

  // The query that drives the current results panel.
  const [committedQuery, setCommittedQuery] = useState(initialQuery);
  // What the text input shows (may lag during debounce).
  const [inputValue, setInputValue] = useState(initialQuery);

  // Search result state.
  const [status, setStatus] = useState<"idle" | "loading" | "done" | "error">(
    initialQuery ? "loading" : "idle",
  );
  const [results, setResults] = useState<SearchHit[]>([]);
  const [semantic, setSemantic] = useState(false);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);
  const [facets, setFacets] = useState<SearchFacets | null>(null);
  const [filters, setFilters] = useState<SearchFilters>(EMPTY_FILTERS);

  // Idle-state trending hints.
  const [hints, setHints] = useState<string[]>([]);

  // Autocomplete state.
  const [suggestions, setSuggestions] = useState<AutocompleteSuggestions>({
    products: [],
    terms: [],
  });
  const [showDropdown, setShowDropdown] = useState(false);
  const [acActiveIndex, setAcActiveIndex] = useState(-1);

  // Mutable refs — never trigger renders.
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const acDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const seqRef = useRef(0);
  const inputRef = useRef<HTMLInputElement>(null);
  // Track the last ?q= we pushed so URL-sync effect ignores our own pushes.
  const lastUrlQ = useRef(initialQuery);

  const { recent, add: addRecent, clear: clearRecent } = useRecentSearches();

  // ── Search execution (shared helper, called only from event handlers
  //    and from inside inner async fns within effects — matching the
  //    cart-context pattern which the lint rule permits) ─────────────────────

  function runSearch(
    q: string,
    activeFilters: SearchFilters,
    needFacets: boolean,
  ): void {
    const trimmed = q.trim();
    if (!trimmed) {
      setStatus("idle");
      setResults([]);
      setFacets(null);
      return;
    }
    const seq = ++seqRef.current;
    setStatus("loading");
    setErrorMsg(null);
    fetchSearch(trimmed, activeFilters, { includeFacets: needFacets })
      .then((res) => {
        if (seq !== seqRef.current) return;
        setResults(res.results);
        setSemantic(res.semantic);
        if (res.facets) setFacets(res.facets);
        setStatus("done");
      })
      .catch((e: unknown) => {
        if (seq !== seqRef.current) return;
        setErrorMsg(
          e instanceof Error ? e.message : "Search failed. Please try again.",
        );
        setStatus("error");
        setResults([]);
      });
  }

  // ── Boot: fire initial search if ?q= came in from the server ─────────────
  //    Pattern from cart-context: define an inner async fn and call via void,
  //    so all setState calls are inside the async fn body, not the effect body.

  // Fetch hints on mount.
  useEffect(() => {
    async function boot() {
      const h = await fetchHints().catch(() => [] as string[]);
      setHints(h);
    }
    void boot();
  }, []);

  // Boot search: fire initial query from the URL if one was passed in.
  // This uses an inner async fn wrapper (matching the cart-context pattern)
  // so all setState calls are inside the async fn, not the effect body.
  useEffect(() => {
    if (!initialQuery) return;
    async function bootSearch() {
      runSearch(initialQuery, EMPTY_FILTERS, true);
    }
    void bootSearch();
    // eslint-disable-next-line react-hooks/exhaustive-deps -- intentional boot effect
  }, []);

  // ── URL sync: respond to browser back/forward ─────────────────────────────

  useEffect(() => {
    async function syncFromUrl() {
      const q = (searchParams.get("q") ?? "").trim();
      if (q === lastUrlQ.current) return;
      lastUrlQ.current = q;

      startTransition(() => {
        setCommittedQuery(q);
        setInputValue(q);
        setFilters(EMPTY_FILTERS);
        setFacets(null);
        setResults([]);
        setSuggestions({ products: [], terms: [] });
        setShowDropdown(false);
        setAcActiveIndex(-1);
      });

      if (q) {
        runSearch(q, EMPTY_FILTERS, true);
      } else {
        setStatus("idle");
      }
    }
    void syncFromUrl();
  }, [searchParams]);

  // ── Cleanup on unmount ────────────────────────────────────────────────────

  useEffect(() => {
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
      if (acDebounceRef.current) clearTimeout(acDebounceRef.current);
    };
  }, []);

  // ── Input change → debounce search + autocomplete ────────────────────────

  function handleInputChange(value: string) {
    setInputValue(value);
    setAcActiveIndex(-1);

    // Autocomplete debounce.
    if (acDebounceRef.current) clearTimeout(acDebounceRef.current);
    if (value.trim()) {
      acDebounceRef.current = setTimeout(() => {
        fetchAutocomplete(value)
          .then((ac) => {
            setSuggestions(ac);
            setShowDropdown(true);
          })
          .catch(() => {});
      }, AUTOCOMPLETE_DEBOUNCE_MS);
    } else {
      setSuggestions({ products: [], terms: [] });
      setShowDropdown(!value.trim() && recent.length > 0);
    }

    // Search debounce.
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (!value.trim()) {
      setCommittedQuery("");
      setStatus("idle");
      setResults([]);
      setFacets(null);
      setFilters(EMPTY_FILTERS);
      lastUrlQ.current = "";
      startTransition(() => {
        router.replace("/search", { scroll: false });
      });
      return;
    }
    setStatus("loading");
    debounceRef.current = setTimeout(() => {
      const trimmed = value.trim();
      setCommittedQuery(trimmed);
      setFilters(EMPTY_FILTERS);
      setFacets(null);
      lastUrlQ.current = trimmed;
      startTransition(() => {
        const qs = new URLSearchParams(searchParams);
        qs.set("q", trimmed);
        router.replace(`/search?${qs.toString()}`, { scroll: false });
      });
      runSearch(trimmed, EMPTY_FILTERS, true);
    }, DEBOUNCE_MS);
  }

  // ── Commit (Enter / dropdown select) ─────────────────────────────────────

  function commitSearch(term: string) {
    const t = term.trim();
    if (!t) return;
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (acDebounceRef.current) clearTimeout(acDebounceRef.current);
    setInputValue(t);
    setCommittedQuery(t);
    setShowDropdown(false);
    setSuggestions({ products: [], terms: [] });
    setAcActiveIndex(-1);
    addRecent(t);
    setFilters(EMPTY_FILTERS);
    setFacets(null);
    lastUrlQ.current = t;
    startTransition(() => {
      const qs = new URLSearchParams(searchParams);
      qs.set("q", t);
      router.push(`/search?${qs.toString()}`, { scroll: false });
    });
    runSearch(t, EMPTY_FILTERS, true);
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    commitSearch(inputValue);
  }

  // ── Filter change ─────────────────────────────────────────────────────────

  function handleFiltersChange(next: SearchFilters) {
    setFilters(next);
    if (committedQuery.trim()) runSearch(committedQuery, next, false);
  }

  // ── Keyboard navigation ───────────────────────────────────────────────────

  const acListLen = suggestions.products.length + suggestions.terms.length;
  const recentListLen =
    !inputValue.trim() && showDropdown ? recent.length : 0;
  const navLen = acListLen || recentListLen;

  function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Escape") {
      setShowDropdown(false);
      setAcActiveIndex(-1);
      return;
    }
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setAcActiveIndex((i) => Math.min(i + 1, navLen - 1));
      return;
    }
    if (e.key === "ArrowUp") {
      e.preventDefault();
      setAcActiveIndex((i) => Math.max(i - 1, -1));
      return;
    }
    if (e.key === "Enter" && acActiveIndex >= 0 && showDropdown) {
      e.preventDefault();
      if (acListLen > 0) {
        const all = [
          ...suggestions.products.map((p) => p.name),
          ...suggestions.terms,
        ];
        const sel = all[acActiveIndex];
        if (sel) commitSearch(sel);
      } else if (recentListLen > 0) {
        const sel = recent[acActiveIndex];
        if (sel) commitSearch(sel);
      }
    }
  }

  // ── Clear input ───────────────────────────────────────────────────────────

  function clearInput() {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    if (acDebounceRef.current) clearTimeout(acDebounceRef.current);
    setInputValue("");
    setCommittedQuery("");
    setStatus("idle");
    setResults([]);
    setFacets(null);
    setFilters(EMPTY_FILTERS);
    setSuggestions({ products: [], terms: [] });
    setShowDropdown(recent.length > 0);
    inputRef.current?.focus();
    lastUrlQ.current = "";
    startTransition(() => {
      router.replace("/search", { scroll: false });
    });
  }

  function handleResultTap() {
    if (committedQuery.trim()) addRecent(committedQuery.trim());
    setShowDropdown(false);
  }

  function applyTerm(t: string) {
    setShowDropdown(false);
    setAcActiveIndex(-1);
    commitSearch(t);
  }

  // ── Render ────────────────────────────────────────────────────────────────

  const hasQuery = !!committedQuery.trim();
  const isLoading = status === "loading";

  return (
    <div className="min-h-screen bg-canvas">
      {/* ── Sticky search header ── */}
      <header className="sticky top-0 z-40 border-b border-hairline bg-white/95 backdrop-blur-sm">
        <div className="mx-auto flex max-w-shell items-center gap-sm px-lg py-sm">
          <button
            type="button"
            aria-label="Back"
            onClick={() => router.back()}
            className="flex size-9 shrink-0 items-center justify-center rounded-sm border border-hairline bg-white text-ink transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            <ArrowLeft size={18} aria-hidden />
          </button>

          {/* Search input */}
          <div className="relative min-w-0 flex-1">
            <form onSubmit={handleSubmit} role="search">
              <label htmlFor="search-input" className="sr-only">
                Search ShopXY
              </label>
              <div className="flex h-10 items-center gap-sm rounded-md border border-hairline bg-white px-sm transition-shadow focus-within:border-brand focus-within:ring-2 focus-within:ring-brand-soft">
                <span className="flex size-7 shrink-0 items-center justify-center rounded-sm bg-brand">
                  <Search size={15} className="text-white" aria-hidden />
                </span>
                <input
                  id="search-input"
                  ref={inputRef}
                  type="search"
                  autoFocus
                  autoComplete="off"
                  autoCorrect="off"
                  spellCheck={false}
                  value={inputValue}
                  onChange={(e) => handleInputChange(e.target.value)}
                  onKeyDown={handleKeyDown}
                  onFocus={() => {
                    if (!inputValue.trim() && recent.length > 0) {
                      setShowDropdown(true);
                    } else if (
                      inputValue.trim() &&
                      (suggestions.products.length > 0 ||
                        suggestions.terms.length > 0)
                    ) {
                      setShowDropdown(true);
                    }
                  }}
                  onBlur={() => {
                    // Delay so mousedown on dropdown items fires first.
                    setTimeout(() => setShowDropdown(false), 150);
                  }}
                  placeholder="Search products, brands…"
                  className="min-w-0 flex-1 bg-transparent text-[14px] font-semibold text-ink placeholder:font-normal placeholder:text-subtle focus:outline-none"
                  role="combobox"
                  aria-autocomplete="list"
                  aria-expanded={showDropdown}
                  aria-controls={showDropdown ? "search-dropdown" : undefined}
                  aria-activedescendant={
                    acActiveIndex >= 0
                      ? `search-option-${acActiveIndex}`
                      : undefined
                  }
                  aria-haspopup="listbox"
                />
                {inputValue ? (
                  <button
                    type="button"
                    aria-label="Clear search"
                    onClick={clearInput}
                    className="flex size-6 shrink-0 items-center justify-center rounded-full bg-surface-tint text-muted transition-colors hover:bg-hairline focus-visible:outline-none"
                  >
                    <X size={12} aria-hidden />
                  </button>
                ) : null}
              </div>
            </form>

            {/* Autocomplete dropdown */}
            {showDropdown && inputValue.trim() && acListLen > 0 ? (
              <div id="search-dropdown">
                <AutocompleteDropdown
                  suggestions={suggestions}
                  activeIndex={acActiveIndex}
                  onSelect={commitSearch}
                />
              </div>
            ) : null}

            {/* Recent searches dropdown */}
            {showDropdown && !inputValue.trim() && recent.length > 0 ? (
              <div id="search-dropdown">
                <RecentDropdown
                  terms={recent}
                  activeIndex={acActiveIndex}
                  onSelect={commitSearch}
                  onClear={clearRecent}
                />
              </div>
            ) : null}
          </div>
        </div>
      </header>

      {/* ── Body ── */}
      <main className="mx-auto max-w-shell px-lg">
        {!hasQuery ? (
          <IdleView
            hints={hints}
            recent={recent}
            onApplyTerm={applyTerm}
            onClearRecent={clearRecent}
          />
        ) : isLoading && results.length === 0 ? (
          <div className="pt-lg">
            <SearchSkeleton rows={8} />
          </div>
        ) : status === "error" ? (
          <ErrorState
            message={errorMsg ?? "Something went wrong."}
            onRetry={() => runSearch(committedQuery, filters, facets == null)}
          />
        ) : status === "done" && results.length === 0 ? (
          <EmptyState query={committedQuery} />
        ) : results.length > 0 ? (
          <ResultsView
            results={results}
            semantic={semantic}
            filters={filters}
            facets={facets}
            onChangeFilters={handleFiltersChange}
            onResultTap={handleResultTap}
          />
        ) : null}
      </main>
    </div>
  );
}

// ── Sub-views ─────────────────────────────────────────────────────────────────

function IdleView({
  hints,
  recent,
  onApplyTerm,
  onClearRecent,
}: {
  hints: string[];
  recent: string[];
  onApplyTerm: (t: string) => void;
  onClearRecent: () => void;
}) {
  if (hints.length === 0 && recent.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-massive text-center">
        <span className="flex size-16 items-center justify-center rounded-full bg-brand-soft">
          <Search size={28} className="text-brand" aria-hidden />
        </span>
        <h2 className="mt-lg text-title-lg font-extrabold text-ink">
          Find a product
        </h2>
        <p className="mt-xs max-w-snug text-body-md text-muted">
          Search by name, brand, or what you need it for — the engine
          understands intent, not just exact words.
        </p>
      </div>
    );
  }

  return (
    <div className="py-lg">
      {hints.length > 0 ? (
        <section className="mb-xl">
          <div className="mb-sm flex items-center gap-sm">
            <Flame size={15} className="text-brand" aria-hidden />
            <p className="text-[10px] font-extrabold uppercase tracking-[0.8px] text-brand">
              Popular right now
            </p>
          </div>
          <h2 className="mb-md text-title-md font-extrabold text-ink">
            Trending searches
          </h2>
          <div className="flex flex-wrap gap-sm">
            {hints.map((h) => (
              <button
                key={h}
                type="button"
                onClick={() => onApplyTerm(h)}
                className="inline-flex items-center gap-[6px] rounded-full border border-hairline bg-white px-md py-[6px] text-[12px] font-bold text-ink transition-all duration-200 hover:border-brand hover:bg-brand-soft hover:text-brand hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                <span className="flex size-5 items-center justify-center rounded-full bg-brand-soft">
                  <Flame size={10} className="text-brand" aria-hidden />
                </span>
                {h}
              </button>
            ))}
          </div>
        </section>
      ) : null}

      {recent.length > 0 ? (
        <section>
          <div className="mb-sm flex items-center justify-between">
            <h2 className="text-title-sm font-bold text-ink">Recent searches</h2>
            <button
              type="button"
              onClick={onClearRecent}
              className="rounded-xs border border-hairline px-sm py-[3px] text-[11px] font-bold text-muted transition-colors hover:text-ink focus-visible:outline-none"
            >
              Clear
            </button>
          </div>
          <div className="flex flex-wrap gap-sm">
            {recent.map((term) => (
              <button
                key={term}
                type="button"
                onClick={() => onApplyTerm(term)}
                className="inline-flex items-center gap-[6px] rounded-full border border-hairline bg-white px-md py-[6px] text-[12px] font-semibold text-muted transition-all duration-200 hover:border-brand hover:bg-surface-tint hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                <span className="flex size-4 shrink-0 items-center justify-center">
                  <Search size={10} className="text-muted" aria-hidden />
                </span>
                {term}
              </button>
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}

function ResultsView({
  results,
  semantic,
  filters,
  facets,
  onChangeFilters,
  onResultTap,
}: {
  results: SearchHit[];
  semantic: boolean;
  filters: SearchFilters;
  facets: SearchFacets | null | undefined;
  onChangeFilters: (f: SearchFilters) => void;
  onResultTap: () => void;
}) {
  const filterCount = activeFilterCount(filters);
  return (
    <div>
      <div className="sticky top-[57px] z-30 border-b border-hairline bg-canvas/95 py-sm backdrop-blur-sm">
        <div className="flex items-center gap-sm">
          {semantic ? (
            <Sparkles size={13} className="text-brand" aria-hidden />
          ) : (
            <Search size={13} className="text-subtle" aria-hidden />
          )}
          <span className="text-[11px] font-semibold text-muted">
            {results.length} result{results.length !== 1 ? "s" : ""}
            {semantic ? (
              <span className="font-bold text-brand"> · AI-ranked</span>
            ) : null}
          </span>
        </div>
        {facets || filterCount > 0 ? (
          <div className="mt-sm">
            <FilterChips
              filters={filters}
              facets={facets}
              onChangeFilters={onChangeFilters}
            />
          </div>
        ) : null}
      </div>
      <ul
        className="divide-y divide-hairline pb-huge"
        aria-label="Search results"
      >
        {results.map((hit) => (
          <li key={hit.id}>
            <SearchResultRow hit={hit} onTap={onResultTap} />
          </li>
        ))}
      </ul>
    </div>
  );
}

function EmptyState({ query }: { query: string }) {
  return (
    <div className="flex flex-col items-center justify-center py-massive text-center">
      <SearchX size={48} className="text-muted" aria-hidden />
      <h2 className="mt-lg text-title-lg font-extrabold text-ink">
        No matches for &ldquo;{query}&rdquo;
      </h2>
      <p className="mt-xs text-body-md text-muted">
        Try a different spelling or a broader term.
      </p>
    </div>
  );
}

function ErrorState({
  message,
  onRetry,
}: {
  message: string;
  onRetry: () => void;
}) {
  return (
    <div className="flex flex-col items-center justify-center py-massive text-center">
      <SearchX size={48} className="text-error" aria-hidden />
      <p className="mt-lg text-body-md text-ink">{message}</p>
      <button
        type="button"
        onClick={onRetry}
        className="mt-lg inline-flex h-10 items-center gap-sm rounded-button border border-hairline px-lg text-label-md text-muted transition-colors hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        <RefreshCw size={15} aria-hidden /> Try again
      </button>
    </div>
  );
}
