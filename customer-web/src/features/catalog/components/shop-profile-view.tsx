"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import Link from "next/link";
import { ArrowLeft, ShoppingBag, Star } from "@/shared/icons";
import { fetchShopProducts } from "@/features/catalog/api";
import type { CatalogProduct, ShopProfile, SortOption } from "@/features/catalog/types";
import { CatalogProductCard } from "./catalog-product-card";
import { ProductGridSkeleton } from "./product-grid-skeleton";
import { SortBar } from "./sort-bar";
import { ImageBox } from "@/features/home/components/image-box";
import { resolveImageUrl } from "@/features/home/format";

const PAGE_SIZE = 24;

/**
 * Client component for /shop/[slug]. Fetches shop + paginated products via
 * BFF, supports infinite scroll and sort.
 *
 * Port of the Flutter ShopProfilePage.
 */
export function ShopProfileView({ slug }: { slug: string }) {
  const [shop, setShop] = useState<ShopProfile | null>(null);
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
        const data = await fetchShopProducts(slug, { page, limit: PAGE_SIZE, sort: currentSort });
        setShop(data.shop);
        setPagination({ page: data.pagination.page, total: data.pagination.total, pages: data.pagination.pages });
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

  // Infinite scroll via IntersectionObserver
  useEffect(() => {
    const el = sentinelRef.current;
    if (!el) return;
    const obs = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting && !loadingMore && !loading && pagination.page < pagination.pages) {
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
  if (loading && !shop) {
    return (
      <div className="mx-auto max-w-shell px-lg">
        <div className="pt-lg">
          <ShopHeaderSkeleton />
        </div>
        <SortBarSkeleton />
        <ProductGridSkeleton count={8} />
      </div>
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────
  if (error && !shop) {
    return (
      <div className="mx-auto max-w-shell px-lg py-xxxl">
        <div className="flex flex-col items-center gap-md py-xxxl text-center">
          <ShoppingBag size={48} className="text-disabled" />
          <p className="text-title-md text-ink">Could not load this shop</p>
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
          href="/"
          className="inline-flex items-center gap-xs text-label-md text-muted hover:text-ink focus-visible:outline-none focus-visible:underline"
        >
          <ArrowLeft size={16} aria-hidden /> Home
        </Link>
      </div>

      {/* Shop header */}
      {shop ? <ShopHeader shop={shop} total={pagination.total} /> : null}

      {/* Sort bar */}
      <div className="px-lg">
        <SortBar value={sort} onChange={handleSort} />
      </div>

      {/* Product grid */}
      <div className="px-lg pb-xxxl pt-sm">
        {loading ? (
          <ProductGridSkeleton count={8} />
        ) : products.length === 0 ? (
          <EmptyState />
        ) : (
          <>
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

// ── Shop header ──────────────────────────────────────────────────────────────

function ShopHeader({ shop, total }: { shop: ShopProfile; total: number }) {
  const logoUrl = resolveImageUrl(shop.logoUrl);
  const bannerUrl = resolveImageUrl(shop.bannerUrl);
  const initials = shop.name.trim()[0]?.toUpperCase() ?? "S";

  return (
    <div className="mb-sm">
      {/* Banner image — only render when a banner exists; no 200px empty gray otherwise */}
      {bannerUrl ? (
        <div className="relative h-[160px] w-full overflow-hidden sm:h-[200px]">
          <ImageBox url={bannerUrl} alt="" fit="cover" />
          <div
            className="absolute inset-0"
            style={{
              background:
                "linear-gradient(to bottom, rgba(0,0,0,0.12), transparent 40%, rgba(0,0,0,0.48))",
            }}
          />
        </div>
      ) : null}

      {/* Logo + info row — logo overlaps banner when banner exists */}
      <div className={["px-lg pb-md", bannerUrl ? "-mt-7" : "pt-lg"].join(" ")}>
        <div className="flex items-end gap-md">
          {/* Shop logo — ring-white + shadow for overlap effect when banner present */}
          <div
            className={[
              "size-14 shrink-0 overflow-hidden rounded-lg bg-white",
              bannerUrl
                ? "border-2 border-white shadow-menu"
                : "border border-hairline shadow-floating",
            ].join(" ")}
          >
            {logoUrl ? (
              <ImageBox url={logoUrl} alt={shop.name} />
            ) : (
              <div className="flex size-full items-center justify-center bg-brand-soft">
                <span className="text-title-lg font-extrabold text-brand">{initials}</span>
              </div>
            )}
          </div>

          {/* Name + stats */}
          <div className="min-w-0 flex-1 pb-xs">
            <h1 className="text-title-lg font-extrabold text-ink">{shop.name}</h1>
            {shop.tagline ? (
              <p className="mt-xs text-body-sm text-muted">{shop.tagline}</p>
            ) : null}
            <div className="mt-sm flex flex-wrap items-center gap-sm">
              {shop.rating != null ? (
                <span className="inline-flex items-center gap-[3px] rounded-sm bg-success px-[6px] py-[2px] text-caption font-bold text-white">
                  {shop.rating.toFixed(1)}
                  <Star size={9} className="fill-white text-white" aria-hidden />
                  <span className="font-normal text-white/80">({shop.ratingCount})</span>
                </span>
              ) : null}
              <span className="flex items-center gap-xs text-body-sm text-muted">
                <ShoppingBag size={13} aria-hidden />
                {total} products
              </span>
            </div>
          </div>
        </div>
      </div>

      <div className="border-t border-hairline" />
    </div>
  );
}

// ── Helpers ──────────────────────────────────────────────────────────────────

function EmptyState() {
  return (
    <div className="flex flex-col items-center gap-md py-xxxl text-center">
      <ShoppingBag size={40} className="text-disabled" />
      <p className="text-title-sm text-muted">No products published yet.</p>
      <Link
        href="/"
        className="inline-flex h-9 items-center rounded-button border border-hairline px-lg text-label-md text-muted hover:border-brand hover:text-brand focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        Continue browsing
      </Link>
    </div>
  );
}

function ShopHeaderSkeleton() {
  return (
    <div className="mb-sm">
      <div className="h-[160px] w-full animate-pulse bg-hero-panel sm:h-[200px]" />
      <div className="px-lg pb-md pt-lg">
        <div className="flex items-start gap-md">
          <div className="size-14 shrink-0 animate-pulse rounded-md bg-hero-panel" />
          <div className="flex flex-1 flex-col gap-sm">
            <div className="h-[18px] w-[55%] animate-pulse rounded-xs bg-hero-panel" />
            <div className="h-3 w-[75%] animate-pulse rounded-xs bg-hero-panel" />
            <div className="flex gap-md">
              <div className="h-3 w-[22%] animate-pulse rounded-xs bg-hero-panel" />
              <div className="h-3 w-[22%] animate-pulse rounded-xs bg-hero-panel" />
            </div>
          </div>
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
