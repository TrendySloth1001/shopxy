"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import Link from "next/link";
import { use } from "react";
import { AppHeader } from "@/features/auth/components/app-header";
import { RequireAuth } from "@/features/auth/components/require-auth";
import {
  CatalogProductCard,
  CatalogProductCardSkeleton,
} from "@/features/merchants/components/catalog-product-card";
import {
  fetchCatalogCategories,
  fetchCatalogProducts,
} from "@/features/merchants/api";
import {
  parseMerchantRole,
  merchantBase,
  type CatalogCategory,
  type CatalogProduct,
} from "@/features/merchants/types";
import { Search, Package, ReceiptText, FileText, X } from "@/shared/icons";
import { Divider } from "@/shared/ui/divider";

// ─── Nav strip ──────────────────────────────────────────────────────────────

function MerchantNavStrip({
  base,
  isParty,
}: {
  base: string;
  isParty: boolean;
}) {
  const links = [
    { href: `${base}/catalog`, label: "Catalog", icon: <Package size={15} /> },
    { href: `${base}/invoices`, label: "Invoices", icon: <ReceiptText size={15} /> },
    ...(isParty
      ? [
          { href: `${base}/quotations`, label: "Quotations", icon: <FileText size={15} /> },
        ]
      : []),
  ];

  return (
    <div className="flex items-center gap-xs overflow-x-auto py-sm scrollbar-hide">
      {links.map((l) => (
        <Link
          key={l.href}
          href={l.href}
          className="inline-flex flex-shrink-0 items-center gap-xs rounded-full border border-hairline bg-white px-md py-sm text-label-lg font-bold text-muted hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
        >
          {l.icon}
          {l.label}
        </Link>
      ))}
    </div>
  );
}

// ─── Category pills ──────────────────────────────────────────────────────────

function CategoryPills({
  categories,
  active,
  onSelect,
}: {
  categories: CatalogCategory[];
  active: number | null;
  onSelect: (id: number | null) => void;
}) {
  return (
    <div className="flex items-center gap-xs overflow-x-auto py-xs scrollbar-hide">
      <button
        type="button"
        onClick={() => onSelect(null)}
        className={`inline-flex flex-shrink-0 items-center rounded-full px-md py-sm text-label-lg font-extrabold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
          active === null
            ? "bg-ink text-white"
            : "border border-hairline bg-white text-ink hover:bg-surface-tint"
        }`}
      >
        All
      </button>
      {categories.map((cat) => (
        <button
          key={cat.id}
          type="button"
          onClick={() => onSelect(cat.id)}
          className={`inline-flex flex-shrink-0 items-center gap-xs rounded-full px-md py-sm text-label-lg font-extrabold transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand ${
            active === cat.id
              ? "bg-ink text-white"
              : "border border-hairline bg-white text-ink hover:bg-surface-tint"
          }`}
        >
          {cat.name}
          {cat._count && (
            <span
              className={`text-[11px] font-bold ${
                active === cat.id ? "text-white/70" : "text-muted"
              }`}
            >
              {cat._count.products}
            </span>
          )}
        </button>
      ))}
    </div>
  );
}

// ─── Main catalog content ───────────────────────────────────────────────────

const PAGE_LIMIT = 24;

type CatalogContentProps = {
  role: string;
  id: string;
};

function CatalogContent({ role: roleRaw, id }: CatalogContentProps) {
  const role = parseMerchantRole(roleRaw);
  const isParty = role === "party";
  const base = merchantBase(role ?? "party", id);

  const [categories, setCategories] = useState<CatalogCategory[]>([]);
  const [products, setProducts] = useState<CatalogProduct[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [loading, setLoading] = useState(true);
  const [catLoading, setCatLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [debouncedSearch, setDebouncedSearch] = useState("");
  const [activeCategory, setActiveCategory] = useState<number | null>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Debounce search
  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      setDebouncedSearch(search);
      setPage(1);
    }, 220);
    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [search]);

  // Load categories once
  useEffect(() => {
    let cancelled = false;
    async function run() {
      setCatLoading(true);
      try {
        const cats = await fetchCatalogCategories();
        if (!cancelled) setCategories(cats);
      } catch {
        /* silently ignore — show all products */
      } finally {
        if (!cancelled) setCatLoading(false);
      }
    }
    if (!cancelled) void run();
    return () => { cancelled = true; };
  }, []);

  const loadProducts = useCallback(
    async (p = 1) => {
      setLoading(true);
      setError(null);
      try {
        const result = await fetchCatalogProducts({
          search: debouncedSearch || undefined,
          categoryId: activeCategory ?? undefined,
          page: p,
          limit: PAGE_LIMIT,
        });
        setProducts(result.data);
        setTotal(result.total);
        setPage(p);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Could not load products.");
      } finally {
        setLoading(false);
      }
    },
    [debouncedSearch, activeCategory],
  );

  useEffect(() => {
    let cancelled = false;
    async function run() { await loadProducts(1); }
    if (!cancelled) void run();
    return () => { cancelled = true; };
  }, [loadProducts]);

  const handleCategorySelect = (id: number | null) => {
    setActiveCategory(id);
    setPage(1);
  };

  const clearSearch = () => {
    setSearch("");
    setDebouncedSearch("");
    setPage(1);
  };

  if (role === null) {
    return (
      <div className="mx-auto max-w-content px-lg py-massive text-center">
        <p className="text-title-sm font-bold text-ink">Invalid merchant URL</p>
        <div className="mt-xl">
          <Link
            href="/merchants"
            className="inline-flex h-10 items-center rounded-button bg-brand px-xl text-label-lg font-extrabold text-white hover:bg-brand-strong transition-colors"
          >
            Back to merchants
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="mx-auto max-w-shell">
      {/* Merchant nav strip */}
      <div className="border-b border-hairline bg-canvas">
        <div className="px-lg">
          <MerchantNavStrip base={base} isParty={isParty} />
        </div>
      </div>

      <div className="px-lg py-md">
        {/* Search bar */}
        <div className="relative mb-md">
          <Search
            size={16}
            className="absolute left-md top-1/2 -translate-y-1/2 text-muted"
          />
          <input
            type="search"
            placeholder="Search products…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full rounded-input border border-hairline bg-white py-sm pl-xxxl pr-md text-body-md text-ink placeholder:text-subtle focus:border-brand focus:outline-none focus:ring-2 focus:ring-brand/20 transition-colors"
          />
          {search && (
            <button
              type="button"
              onClick={clearSearch}
              className="absolute right-md top-1/2 -translate-y-1/2 text-muted hover:text-ink focus-visible:outline-none"
              aria-label="Clear search"
            >
              <X size={15} />
            </button>
          )}
        </div>

        {/* Category pills */}
        {!catLoading && categories.length > 0 && (
          <>
            <CategoryPills
              categories={categories}
              active={activeCategory}
              onSelect={handleCategorySelect}
            />
            <Divider className="my-md" />
          </>
        )}

        {/* Results */}
        {loading ? (
          <div className="grid grid-cols-2 gap-sm sm:grid-cols-3 md:grid-cols-4">
            {Array.from({ length: PAGE_LIMIT }, (_, i) => (
              <CatalogProductCardSkeleton key={i} />
            ))}
          </div>
        ) : error ? (
          <div className="py-massive text-center">
            <p className="text-title-sm font-bold text-ink mb-xs">
              Could not load products
            </p>
            <p className="text-body-sm text-muted mb-xl">{error}</p>
            <button
              onClick={() => void loadProducts(page)}
              className="inline-flex h-10 items-center rounded-button border border-hairline px-xl text-label-lg font-bold text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
            >
              Try again
            </button>
          </div>
        ) : products.length === 0 ? (
          <div className="flex flex-col items-center py-massive text-center">
            <div className="mb-lg flex h-24 w-24 items-center justify-center rounded-xl bg-hero-panel">
              <Package size={40} className="text-muted" />
            </div>
            <p className="text-title-sm font-extrabold text-ink">
              {debouncedSearch || activeCategory ? "No matching products" : "No products yet"}
            </p>
            <p className="mt-xs max-w-snug text-body-md text-muted">
              {debouncedSearch
                ? `No products match "${debouncedSearch}".`
                : activeCategory
                  ? "Try a different category."
                  : "This shop hasn't listed any products in their catalog yet."}
            </p>
            {(debouncedSearch || activeCategory) && (
              <button
                type="button"
                onClick={() => {
                  clearSearch();
                  setActiveCategory(null);
                }}
                className="mt-xl inline-flex h-10 items-center rounded-button border border-hairline px-xl text-label-lg font-bold text-ink hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
              >
                Clear filters
              </button>
            )}
          </div>
        ) : (
          <>
            {/* Result count */}
            <p className="mb-sm text-body-sm text-muted">
              {total} product{total === 1 ? "" : "s"}
              {debouncedSearch ? ` for "${debouncedSearch}"` : ""}
            </p>

            {/* Product grid */}
            <div className="grid grid-cols-2 gap-sm sm:grid-cols-3 md:grid-cols-4 pb-lg">
              {products.map((p) => (
                <CatalogProductCard key={p.id} product={p} />
              ))}
            </div>

            {/* Pagination */}
            {total > PAGE_LIMIT && (
              <div className="flex items-center justify-center gap-md py-md">
                <button
                  onClick={() => void loadProducts(page - 1)}
                  disabled={page <= 1 || loading}
                  className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-ink disabled:opacity-40 hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
                >
                  Previous
                </button>
                <span className="text-body-sm text-muted">
                  Page {page} of {Math.ceil(total / PAGE_LIMIT)}
                </span>
                <button
                  onClick={() => void loadProducts(page + 1)}
                  disabled={page >= Math.ceil(total / PAGE_LIMIT) || loading}
                  className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-ink disabled:opacity-40 hover:bg-surface-tint focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand transition-colors"
                >
                  Next
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}

// ─── Page ───────────────────────────────────────────────────────────────────

type PageProps = {
  params: Promise<{ role: string; id: string }>;
};

export default function CatalogPage({ params }: PageProps) {
  const { role, id } = use(params);
  const base = merchantBase((role === "vendor" ? "vendor" : "party"), id);

  return (
    <RequireAuth>
      <AppHeader />
      <main className="min-h-screen bg-canvas">
        {/* Breadcrumb */}
        <div className="mx-auto max-w-shell border-b border-hairline px-lg py-md">
          <div className="flex items-center gap-xs text-body-sm text-muted">
            <Link href="/merchants" className="hover:text-ink transition-colors">
              Merchants
            </Link>
            <span>/</span>
            <Link href={`${base}/catalog`} className="font-semibold text-ink truncate max-w-[200px]">
              Catalog
            </Link>
          </div>
          <h1 className="mt-xs text-headline-sm font-extrabold text-ink">
            Shop Catalog
          </h1>
          <p className="mt-xs text-body-md text-muted">
            Browse products from this merchant.
          </p>
        </div>

        <CatalogContent role={role} id={id} />
      </main>
    </RequireAuth>
  );
}
