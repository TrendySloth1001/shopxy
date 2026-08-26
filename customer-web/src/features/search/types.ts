export interface SearchHit {
  id: string;
  name: string;
  sku: string;
  sellingPrice: number;
  ratingAvg: number | null;
  ratingCount: number;
  imageUrl: string | null;
  shopId: string;
  shopName: string;
  shopSlug: string;
  rank: number;
  semanticScore?: number | null;
  ftsScore?: number | null;
}

export interface SearchFacets {
  priceMin: number;
  priceMax: number;
  inStockCount: number;
  ratingBuckets: {
    ge1: number;
    ge2: number;
    ge3: number;
    ge4: number;
    ge5: number;
  };
  brands: Array<{ brand: string; count: number }>;
}

export interface SearchFilters {
  categoryId?: string | null;
  shopId?: string | null;
  priceMin?: number | null;
  priceMax?: number | null;
  ratingMin?: number | null;
  inStock?: boolean | null;
}

export const EMPTY_FILTERS: SearchFilters = {};

export function activeFilterCount(f: SearchFilters): number {
  let count = 0;
  if (f.categoryId != null) count++;
  if (f.shopId != null) count++;
  if (f.priceMin != null) count++;
  if (f.priceMax != null) count++;
  if (f.ratingMin != null) count++;
  if (f.inStock) count++;
  return count;
}

export interface SearchResult {
  query: string;
  semantic: boolean;
  results: SearchHit[];
  facets?: SearchFacets | null;
}

export interface AutocompleteHit {
  id: string;
  name: string;
}

export interface AutocompleteSuggestions {
  products: AutocompleteHit[];
  terms: string[];
}
