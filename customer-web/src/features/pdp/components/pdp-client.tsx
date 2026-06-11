"use client";

import { useState, useEffect, useCallback, useRef, startTransition } from "react";
import Link from "next/link";
import { Share2, Store, CloudOff, RefreshCw, CheckCircle2, XCircle, Package } from "lucide-react";
import { fetchProduct, recordView } from "../api";
import type { ProductDetail, Variant } from "../types";
import { parseSpecGroups, parseOffers } from "../types";
import { PdpGallery } from "./pdp-gallery";
import { PdpVariantPicker } from "./pdp-variant-picker";
import { PdpPriceBlock } from "./pdp-price-block";
import { PdpOffersStrip } from "./pdp-offers-strip";
import { PdpFbtRail } from "./pdp-fbt-rail";
import { PdpActionBar } from "./pdp-action-bar";
import { PdpWishlistButton } from "./pdp-wishlist-button";
import { PdpSpecs } from "./pdp-specs";
import { ReviewsSection } from "@/features/reviews/components/reviews-section";

// ── System tag badge ──────────────────────────────────────────────────────────

const TAG_CONFIG: Record<string, { label: string; className: string }> = {
  BESTSELLER: { label: "Bestseller", className: "bg-ink text-white" },
  EDITORS_PICK: { label: "Editor's pick", className: "bg-info text-white" },
  NEW_ARRIVAL: { label: "New arrival", className: "bg-success text-white" },
  TRENDING: { label: "Trending", className: "bg-warning text-white" },
};

function SystemTagPill({ tag }: { tag: string }) {
  const cfg = TAG_CONFIG[tag] ?? { label: tag, className: "bg-ink text-white" };
  return (
    <span
      className={`rounded-xs px-sm py-[3px] text-[10px] font-extrabold tracking-[0.4px] ${cfg.className}`}
    >
      {cfg.label}
    </span>
  );
}

// ── Toast ─────────────────────────────────────────────────────────────────────

function Toast({
  message,
  type,
  onDismiss,
}: {
  message: string;
  type: "success" | "error";
  onDismiss: () => void;
}) {
  useEffect(() => {
    const t = setTimeout(onDismiss, 3000);
    return () => clearTimeout(t);
  }, [onDismiss]);

  return (
    <div
      role="status"
      className={`fixed bottom-[72px] left-1/2 z-50 flex -translate-x-1/2 items-center gap-sm rounded-full px-lg py-sm shadow-snackbar ${type === "success" ? "bg-ink" : "bg-error"}`}
    >
      {type === "success" ? (
        <CheckCircle2 size={14} className="text-white" aria-hidden />
      ) : (
        <XCircle size={14} className="text-white" aria-hidden />
      )}
      <span className="whitespace-nowrap text-label-md text-white">{message}</span>
    </div>
  );
}

// ── Section divider + header ──────────────────────────────────────────────────

function SectionDivider() {
  return <div className="mt-lg h-[6px] bg-canvas" />;
}

function SectionHeader({ title }: { title: string }) {
  return (
    <h2 className="px-lg pb-sm pt-lg text-title-md font-extrabold tracking-[-0.2px] text-ink">
      {title}
    </h2>
  );
}

// ── Skeleton ──────────────────────────────────────────────────────────────────

function Shimmer({ className }: { className: string }) {
  return (
    <div
      className={`animate-pulse rounded-sm bg-canvas ${className}`}
    />
  );
}

function PdpSkeleton() {
  return (
    <div className="pb-[80px]">
      {/* Gallery */}
      <div className="aspect-square w-full animate-pulse bg-canvas sm:aspect-[4/3] md:aspect-video lg:aspect-[4/3]" />
      <div className="px-lg pb-sm pt-lg">
        <Shimmer className="mb-sm h-[10px] w-1/4" />
        <Shimmer className="mb-xs h-[18px] w-4/5" />
        <Shimmer className="h-[18px] w-3/5" />
        <Shimmer className="mt-sm h-[14px] w-[140px]" />
        <Shimmer className="mt-sm h-[12px] w-full" />
        <Shimmer className="mt-xs h-[12px] w-3/4" />
        <Shimmer className="mt-sm h-[22px] w-[90px]" />
      </div>
      <div className="flex gap-sm px-lg pb-sm">
        {[1, 2, 3, 4].map((i) => (
          <Shimmer key={i} className="h-8 w-14" />
        ))}
      </div>
      <div className="px-lg py-sm">
        <Shimmer className="h-[28px] w-[120px]" />
      </div>
      <SectionDivider />
      <SectionHeader title="Details" />
      <div className="px-lg">
        {[1, 2, 3].map((i) => (
          <Shimmer key={i} className="mb-sm h-[12px] w-4/5" />
        ))}
      </div>
    </div>
  );
}

// ── Error state ───────────────────────────────────────────────────────────────

function ErrorState({ message, onRetry }: { message: string; onRetry: () => void }) {
  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center gap-md p-xl text-center">
      <CloudOff size={48} className="text-muted" aria-hidden />
      <p className="text-title-md font-bold text-ink">Couldn&apos;t load this product</p>
      <p className="max-w-xs text-body-md text-muted">{message}</p>
      <button
        onClick={onRetry}
        className="flex h-10 items-center gap-sm rounded-button border border-hairline px-lg text-label-md font-bold text-ink transition-colors hover:bg-canvas focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
      >
        <RefreshCw size={14} aria-hidden />
        Try again
      </button>
    </div>
  );
}

// ── Stock chip ────────────────────────────────────────────────────────────────

function StockChip({ qty }: { qty: number }) {
  if (qty <= 0) {
    return (
      <div className="mx-lg mb-sm inline-flex items-center gap-xs rounded-full bg-error-soft px-md py-xs">
        <span className="text-label-md font-extrabold text-error">Out of stock</span>
      </div>
    );
  }
  if (qty <= 5) {
    return (
      <div className="mx-lg mb-sm inline-flex items-center gap-xs rounded-full bg-warning-soft px-md py-xs">
        <span className="text-label-md font-extrabold text-warning">
          Only {qty} left
        </span>
      </div>
    );
  }
  return (
    <div className="mx-lg mb-sm inline-flex items-center gap-xs rounded-full bg-success-soft px-md py-xs">
      <Package size={12} className="text-success" aria-hidden />
      <span className="text-label-md font-extrabold text-success">In stock</span>
    </div>
  );
}

// ── Sold-by chip ──────────────────────────────────────────────────────────────

function SoldByChip({ product }: { product: ProductDetail }) {
  const shop = product.shop;
  if (!shop) return null;
  return (
    <Link
      href={`/shop/${shop.slug}`}
      className="inline-flex items-center gap-xs text-body-sm hover:underline focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
    >
      <Store size={13} className="text-muted" aria-hidden />
      <span className="text-muted">Sold by</span>
      <span className="font-bold text-brand-strong">{shop.name}</span>
    </Link>
  );
}

// ── Share button ──────────────────────────────────────────────────────────────

function ShareButton({ productName }: { productName: string }) {
  const handleShare = async () => {
    const url = window.location.href;
    if (navigator.share) {
      try {
        await navigator.share({ title: productName, url });
      } catch {
        // cancelled — ignore
      }
    } else {
      await navigator.clipboard.writeText(url).catch(() => {});
    }
  };

  return (
    <button
      onClick={handleShare}
      aria-label="Share product"
      className="flex size-8 items-center justify-center rounded-full bg-white/90 shadow-floating transition-colors hover:bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
    >
      <Share2 size={16} className="text-ink" aria-hidden />
    </button>
  );
}

// ── PDP body ──────────────────────────────────────────────────────────────────

interface BodyProps {
  product: ProductDetail;
  initialData?: ProductDetail;
}

function PdpBody({ product }: BodyProps) {
  const [selectedVariant, setSelectedVariant] = useState<Variant | null>(() => {
    return product.variants.find((v) => v.isDefault) ?? product.variants[0] ?? null;
  });
  const [toast, setToast] = useState<{ message: string; type: "success" | "error" } | null>(null);

  const specGroups = parseSpecGroups(product.specs);
  const offers = parseOffers(product.offers);
  const displayQty = selectedVariant?.stockQuantity ?? product.stockQuantity;

  const showToast = useCallback((message: string, type: "success" | "error") => {
    setToast({ message, type });
  }, []);

  const compact = (n: number) => {
    if (n >= 1000) return `${Math.floor(n / 500) * 500}`;
    if (n >= 100) return `${Math.floor(n / 50) * 50}`;
    return `${Math.floor(n / 10) * 10}`;
  };

  return (
    <>
      <div className="pb-[80px]">
        {/* Gallery */}
        <div className="relative">
          <PdpGallery
            images={selectedVariant?.imageUrls.map((url, i) => ({ url, sortOrder: i })) ?? product.images}
            offers={offers}
            productName={product.name}
          />
          {/* Overlay buttons (wishlist + share) */}
          <div className="absolute right-md top-md flex flex-col gap-sm">
            <PdpWishlistButton productId={product.id} />
            <ShareButton productName={product.name} />
          </div>
        </div>

        {/* Title block */}
        <div className="px-lg pb-sm pt-lg">
          {product.systemTags.length > 0 ? (
            <div className="mb-sm flex flex-wrap gap-xs">
              {product.systemTags.map((t) => (
                <SystemTagPill key={t} tag={t} />
              ))}
            </div>
          ) : null}
          {product.brand ? (
            <p className="mb-xs text-[10px] font-extrabold uppercase tracking-[1px] text-muted">
              {product.brand}
            </p>
          ) : null}
          <h1 className="text-[18px] font-extrabold leading-snug tracking-[-0.2px] text-ink">
            {product.name}
          </h1>
          <div className="mt-sm">
            <SoldByChip product={product} />
          </div>
          {product.soldLast30d >= 50 ? (
            <p className="mt-xs text-body-sm font-bold text-muted">
              {compact(product.soldLast30d)}+ bought in the past month
            </p>
          ) : null}
          {product.description ? (
            <p className="mt-sm line-clamp-2 text-body-sm leading-snug text-muted">
              {product.description}
            </p>
          ) : null}
          {/* Rating chip */}
          {product.ratingAvg != null ? (
            <div className="mt-sm flex items-center gap-sm">
              <span className="flex items-center gap-xs rounded-[3px] bg-success px-sm py-xs">
                <span className="text-label-md font-extrabold text-white">
                  {product.ratingAvg.toFixed(1)}
                </span>
                <span className="text-[10px] text-white">★</span>
              </span>
              <span className="text-label-md text-muted">
                {product.ratingCount} ratings · {product.totalSold} sold
              </span>
            </div>
          ) : (
            <div className="mt-sm inline-flex rounded-[3px] bg-canvas px-sm py-xs">
              <span className="text-label-md text-muted">No reviews yet</span>
            </div>
          )}
        </div>

        {/* Variant picker */}
        <PdpVariantPicker product={product} onSelect={setSelectedVariant} />

        {/* Price block */}
        <PdpPriceBlock product={product} selectedVariant={selectedVariant} />

        {/* Stock chip */}
        <StockChip qty={displayQty} />

        {/* Offers */}
        <PdpOffersStrip offers={offers} bankOffers={product.bankOffers} />

        {/* FBT */}
        <PdpFbtRail productId={product.id} />

        {/* Details section */}
        <SectionDivider />
        <SectionHeader title="Details" />
        {product.highlights.length > 0 ? (
          <ul className="flex flex-col gap-sm px-lg pb-md">
            {product.highlights.map((h, i) => (
              <li key={i} className="flex items-start gap-sm">
                <span className="mt-[3px] size-[6px] shrink-0 rounded-full bg-brand" />
                <span className="text-body-sm text-ink">{h}</span>
              </li>
            ))}
          </ul>
        ) : null}
        {product.description && product.description.length > 80 ? (
          <div className="px-lg pb-md">
            <p className="mb-sm text-title-sm font-bold text-ink">Description</p>
            <p className="text-body-sm leading-relaxed text-muted">{product.description}</p>
          </div>
        ) : null}
        {/* Shop card */}
        {product.shop ? (
          <Link
            href={`/shop/${product.shop.slug}`}
            className="mx-lg mb-md flex items-center gap-md rounded-md border border-hairline bg-white p-md transition-shadow hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
          >
            <div className="flex size-11 shrink-0 items-center justify-center rounded-sm bg-brand-soft text-[18px] font-extrabold text-brand-strong">
              {(product.shop.name[0] ?? "?").toUpperCase()}
            </div>
            <div className="flex flex-1 flex-col">
              <span className="text-body-md font-bold text-ink">
                Sold by {product.shop.name}
              </span>
              {product.shop.rating != null ? (
                <span className="text-body-sm text-muted">
                  {product.shop.rating.toFixed(1)} ★ · {product.shop.ratingCount} ratings
                </span>
              ) : null}
            </div>
            <span className="text-muted">›</span>
          </Link>
        ) : null}

        {/* Specs section */}
        <SectionDivider />
        <SectionHeader title="Specifications" />
        <PdpSpecs groups={specGroups} />

        {/* Reviews section */}
        <SectionDivider />
        <SectionHeader title="Ratings & Reviews" />
        <ReviewsSection productId={product.id} productName={product.name} />
      </div>

      {/* Sticky bottom bar */}
      <PdpActionBar product={product} selectedVariant={selectedVariant} onMessage={showToast} />

      {/* Toast */}
      {toast ? (
        <Toast
          message={toast.message}
          type={toast.type}
          onDismiss={() => setToast(null)}
        />
      ) : null}
    </>
  );
}

// ── Main export — handles hydration (SSR data → client state) ─────────────────

interface PdpClientProps {
  productId: number;
  /** Server-rendered initial product data (for hydration) */
  initialData?: ProductDetail;
}

export function PdpClient({ productId, initialData }: PdpClientProps) {
  const [product, setProduct] = useState<ProductDetail | null>(initialData ?? null);
  const [loading, setLoading] = useState(!initialData);
  const [error, setError] = useState<string | null>(null);
  const viewFired = useRef(false);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const p = await fetchProduct(productId);
      setProduct(p);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong.");
    } finally {
      setLoading(false);
    }
  }, [productId]);

  // Only fetch client-side if we don't have initialData
  useEffect(() => {
    if (!initialData) startTransition(() => { void load(); });
  }, [initialData, load]);

  // Fire-and-forget view event
  useEffect(() => {
    if (viewFired.current) return;
    viewFired.current = true;
    recordView(productId);
  }, [productId]);

  if (loading && !product) return <PdpSkeleton />;
  if (error && !product)
    return <ErrorState message={error} onRetry={load} />;
  if (!product) return null;

  return <PdpBody product={product} />;
}
