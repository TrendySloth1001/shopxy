"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { ArrowLeft, LayoutGrid } from "lucide-react";
import { fetchCategoryProducts, type CategoryDetail } from "@/features/catalog/api";
import type { CatalogProduct, SortOption } from "@/features/catalog/types";
import { CatalogProductCard } from "./catalog-product-card";
import { ProductGridSkeleton } from "./product-grid-skeleton";
import { SortBar } from "./sort-bar";
import { ImageBox } from "@/features/home/components/image-box";
import { resolveImageUrl } from "@/features/home/format";

const PAGE_SIZE = 24;

/**
 * Client component for /c/[slug].
 * - Shows child-category chips for drilling down
 * - Sort chip bar
 * - Paginated product grid with infinite scroll
 *
 * Port of the Flutter CategoryProductsPage.
 */
export function CategoryProductsView({ slug }: { slug: string }) {
  const [category, setCategory] = useState<CategoryDetail | null>(null);
  const [products, setProducts] = useState<CatalogProduct[]>([]);
  const [pagination, setPagination] = useState({ page: 1, total: 0, pages: 1 });
  const [sort, setSort] = useState<SortOption>("popular");
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const sentinelRef = useRef<HTMLDivElement | null>(null);
  const booted = useRef(false);

  const load = useCallback(
    async (page: number, currentSort: SortOption, reset: boolean) => {
      if (reset) setLoading(true);
      else setLoadingMore(true);
      setError(null);
      try {
        const data = await fetchCategoryProducts(slug, {
          page,
          limit: PAGE_SIZE,
          sort: currentSort,
        });
        setCategory(data.category);
        setPagination({
          page: data.pagination.page,
          total: data.pagination.total,
          pages: data.pagination.pages,
        });
        setProducts((prev) => (reset ? data.products : [...prev, ...data.products]));
      } catch (e) {
        setError(e instanceof Error ? e.message : "Something went wrong.");
      } finally {
        setLoading(false);
        setLoadingMore(false);
      }
    },
    [slug],
  );

  useEffect(() => {
    if (booted.current) return;
    booted.current = true;
    void load(1, sort, true);
  }, [load, sort]);

  // Infinite scroll
  useEffect(() => {
    const el = sentinelRef.current;
    if (!el) return;
    const obs = new IntersectionObserver(
      (entries) => {
        if (
          entries[0]?.isIntersecting &&
          !loadingMore &&
          !loading &&
          pagination.page < pagination.pages
        ) {
          void load(pagination.page + 1, sort, false);
        }
      },
      { rootMargin: "400px" },
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, [load, loadingMore, loading, pagination, sort]);

  const handleSort = (s: SortOption) => {
    setSort(s);
    void load(1, s, true);
  };

  // ── Skeleton ────────────────────────────────────────────────────────────
  if (loading && !category) {
    return (
      <div className="mx-auto max-w-shell px-lg">
        <CategoryHeaderSkeleton />
        <SortBarSkeleton />
        <ProductGridSkeleton count={8} />
      </div>
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────
  if (error && !category) {
    return (
      <div className="mx-auto max-w-shell px-lg py-xxxl">
        <div className="flex flex-col items-center gap-md py-xxxl text-center">
          <LayoutGrid size={48} className="text-disabled" />
          <p className="text-title-md text-ink">Could not load this category</p>
          <p className="text-body-md text-muted">{error}</p>
          <button
            type="button"
            onClick={() => void load(1, sort, true)}
            className="inline-flex h-10 items-center rounded-button bg-brand px-lg text-label-lg text-white hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
          >
            Try again
          </button>
        </div>
      </div>
    );
  }

  const hasMore = pagination.page < pagination.pages;

  return (
    <div className="mx-auto max-w-shell">
      {/* Back nav */}
      <div className="px-lg pt-lg">
        <Link
          href="/categories"
          className="inline-flex items-center gap-xs text-label-md text-muted hover:text-ink focus-visible:outline-none focus-visible:underline"
        >
          <ArrowLeft size={16} aria-hidden /> All categories
        </Link>
      </div>

      {/* Category header */}
      {category ? <CategoryHeader category={category} total={pagination.total} /> : null}

      {/* Sub-category chips */}
      {category?.children && category.children.length > 0 ? (
        <div className="overflow-x-auto px-lg pb-sm [-ms-overflow-style:none] [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          <div className="flex gap-sm">
            {category.children.map((child) => (
              <Link
                key={child.id}
                href={`/c/${child.slug}`}
                className="group inline-flex shrink-0 items-center gap-xs rounded-full border border-hairline bg-white px-md py-xs text-label-md text-muted transition-all duration-200 hover:border-brand hover:bg-brand-soft hover:text-brand hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
              >
                {child.imageUrl ? (
                  <span className="size-5 shrink-0 overflow-hidden rounded-full border border-hairline bg-hero-panel">
                    <ImageBox url={resolveImageUrl(child.imageUrl)} alt="" fit="cover" />
                  </span>
                ) : null}
                {child.name}
              </Link>
            ))}
          </div>
        </div>
      ) : null}

      {/* Sort bar */}
      <div className="px-lg">
        <SortBar value={sort} onChange={handleSort} />
      </div>

      {/* Product grid */}
      <div className="px-lg pb-xxxl pt-sm">
        {loading ? (
          <ProductGridSkeleton count={8} />
        ) : products.length === 0 ? (
          <EmptyState categoryName={category?.name ?? "this category"} />
        ) : (
          <>
            {pagination.total > 0 ? (
              <p className="mb-md text-body-sm text-muted">{pagination.total} products</p>
            ) : null}
            <div className="grid grid-cols-2 gap-md sm:grid-cols-3 lg:grid-cols-4">
              {products.map((p) => (
                <CatalogProductCard key={p.id} product={p} />
              ))}
            </div>
            <div ref={sentinelRef} className="h-px" />
            {loadingMore ? (
              <div className="flex justify-center py-lg">
                <span className="size-6 animate-spin rounded-full border-2 border-hairline border-t-brand" />
              </div>
            ) : !hasMore && products.length > 0 ? (
              <p className="py-lg text-center text-body-sm text-muted">
                You&apos;ve reached the end.
              </p>
            ) : null}
          </>
        )}
      </div>
    </div>
  );
}

// ── Category header ──────────────────────────────────────────────────────────

// Rotating tints — matches home puck palette
const HEADER_TINTS = [
  "#E3E8F4", "#F3E4D6", "#F9E1EA", "#E6F2EC",
  "#EFE9DD", "#E0E1E6", "#E7DFD4", "#E4DECF",
  "#E6F2DA", "#DEEAF1",
];

function catTint(name: string): string {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) & 0xffff;
  return HEADER_TINTS[h % HEADER_TINTS.length] ?? HEADER_TINTS[0]!;
}

function CategoryHeader({ category, total }: { category: CategoryDetail; total: number }) {
  const imageUrl = resolveImageUrl(category.imageUrl);
  const initials = category.name.trim()[0]?.toUpperCase() ?? "C";
  const tint = catTint(category.name);

  return (
    <div className="mb-sm">
      {/* Tinted hero band */}
      <div
        className="w-full px-lg py-xl"
        style={{ backgroundColor: tint }}
      >
        <div className="flex items-center gap-md">
          {/* White circular chip for icon/image */}
          <div className="size-14 shrink-0 overflow-hidden rounded-full border-2 border-white bg-white shadow-floating">
            {imageUrl ? (
              <ImageBox url={imageUrl} alt={category.name} fit="cover" />
            ) : (
              <div
                className="flex size-full items-center justify-center"
                style={{ backgroundColor: tint }}
              >
                <span className="text-title-lg font-extrabold text-brand">{initials}</span>
              </div>
            )}
          </div>
          <div className="min-w-0 flex-1">
            <h1 className="text-title-lg font-extrabold text-ink">{category.name}</h1>
            {total > 0 ? (
              <p className="text-body-sm text-muted">{total} products</p>
            ) : null}
          </div>
        </div>
      </div>
      <div className="border-t border-hairline" />
    </div>
  );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function EmptyState({ categoryName }: { categoryName: string }) {
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <LayoutGrid size={40} className="text-disabled" />
      <p className="text-title-sm text-muted">No products in {categoryName} yet.</p>
      <Link
        href="/categories"
        className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-muted hover:border-brand hover:text-brand focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        Browse categories
      </Link>
    </div>
  );
}

function CategoryHeaderSkeleton() {
  return (
    <div className="mb-sm px-lg pb-md pt-lg">
      <div className="flex items-center gap-md">
        <div className="size-12 shrink-0 animate-pulse rounded-button bg-hero-panel" />
        <div className="flex flex-1 flex-col gap-sm">
          <div className="h-[18px] w-[55%] animate-pulse rounded-xs bg-hero-panel" />
          <div className="h-3 w-[30%] animate-pulse rounded-xs bg-hero-panel" />
        </div>
      </div>
    </div>
  );
}

function SortBarSkeleton() {
  return (
    <div className="flex gap-sm px-lg py-sm">
      {[72, 64, 120, 80].map((w) => (
        <div
          key={w}
          className="h-8 animate-pulse rounded-full bg-hero-panel"
          style={{ width: w }}
        />
      ))}
    </div>
  );
}
