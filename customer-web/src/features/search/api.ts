/**
 * Client-side search fetchers. Hit /api/search/* (never the backend directly).
 * All payloads are validated with Zod at the boundary.
 */

import {
  autocompleteSchema,
  hintsSchema,
  searchResultSchema,
} from "./schema";
import type {
  AutocompleteSuggestions,
  SearchFilters,
  SearchResult,
} from "./types";

// ── Helpers ──────────────────────────────────────────────────────────────────

async function jsonOrThrow<T>(
  res: Response,
  parse: (raw: unknown) => T,
  fallback: string,
): Promise<T> {
  if (!res.ok) {
    let message = fallback;
    try {
      const body = (await res.json()) as { error?: string };
      if (body?.error) message = body.error;
    } catch {
      /* keep fallback */
    }
    throw new Error(message);
  }
  return parse(await res.json());
}

// ── Search ───────────────────────────────────────────────────────────────────

export async function fetchSearch(
  query: string,
  filters: SearchFilters = {},
  opts: { includeFacets?: boolean; sessionId?: string } = {},
): Promise<SearchResult> {
  const hasFilters =
    filters.categoryId != null ||
    filters.shopId != null ||
    filters.priceMin != null ||
    filters.priceMax != null ||
    filters.ratingMin != null ||
    filters.inStock === true;

  const body: Record<string, unknown> = { q: query };
  if (hasFilters) {
    const f: Record<string, unknown> = {};
    if (filters.categoryId != null) f.categoryId = filters.categoryId;
    if (filters.shopId != null) f.shopId = filters.shopId;
    if (filters.priceMin != null) f.priceMin = filters.priceMin;
    if (filters.priceMax != null) f.priceMax = filters.priceMax;
    if (filters.ratingMin != null) f.ratingMin = filters.ratingMin;
    if (filters.inStock === true) f.inStock = true;
    body.filters = f;
  }
  if (opts.includeFacets) body.includeFacets = true;
  if (opts.sessionId) body.sessionId = opts.sessionId;

  const res = await fetch("/api/search", {
    method: "POST",
    headers: { "Content-Type": "application/json", Accept: "application/json" },
    body: JSON.stringify(body),
    cache: "no-store",
  });

  const raw = await jsonOrThrow(res, (r) => r, "Search failed. Please try again.");
  const parsed = searchResultSchema.parse(raw);

  return {
    query: parsed.query,
    semantic: parsed.semantic,
    results: parsed.results.map((h) => ({
      id: h.id,
      name: h.name,
      sku: h.sku,
      sellingPrice: h.sellingPrice,
      ratingAvg: h.ratingAvg ?? null,
      ratingCount: h.ratingCount,
      imageUrl: h.imageUrl ?? null,
      shopId: h.shop?.id ?? 0,
      shopName: h.shop?.name ?? "",
      shopSlug: h.shop?.slug ?? "",
      rank: h.rank,
      semanticScore: h.semanticScore,
      ftsScore: h.ftsScore,
    })),
    facets: parsed.facets ?? null,
  };
}

// ── Autocomplete ─────────────────────────────────────────────────────────────

export async function fetchAutocomplete(
  q: string,
): Promise<AutocompleteSuggestions> {
  if (!q.trim()) return { products: [], terms: [] };
  const qs = new URLSearchParams({ q: q.trim() });
  const res = await fetch(`/api/search/autocomplete?${qs.toString()}`, {
    headers: { Accept: "application/json" },
    cache: "no-store",
  });
  if (!res.ok) return { products: [], terms: [] };
  const parsed = autocompleteSchema.parse(await res.json().catch(() => null) ?? {});
  return {
    products: parsed.products,
    terms: parsed.terms,
  };
}

// ── Trending hints ────────────────────────────────────────────────────────────

export async function fetchHints(): Promise<string[]> {
  const res = await fetch("/api/search/hints", {
    headers: { Accept: "application/json" },
    // Hints are Redis-cached 5 min server-side; allow client to cache briefly.
    next: { revalidate: 120 },
  });
  if (!res.ok) return [];
  const parsed = hintsSchema.parse(await res.json().catch(() => null) ?? { data: [] });
  return parsed.data;
}
