"use client";

import { useState, useEffect, useCallback, useRef, startTransition } from "react";
import Link from "next/link";
import { Share2, Store, CloudOff, RefreshCw, CheckCircle2, XCircle, Package } from "@/shared/icons";
import { fetchProduct, recordView } from "../api";
import type { ProductDetail, Variant } from "../types";
import { parseSpecGroups, parseOffers } from "../types";
import { PdpGallery } from "./pdp-gallery";
import { PdpVariantPicker } from "./pdp-variant-picker";
import { PdpPriceBlock } from "./pdp-price-block";
import { PdpSellerInfo } from "./pdp-seller-info";
import { PdpOffersStrip } from "./pdp-offers-strip";
import { PdpFbtRail } from "./pdp-fbt-rail";
import { PdpActionBar } from "./pdp-action-bar";
import { PdpWishlistButton } from "./pdp-wishlist-button";
import { PdpSpecs } from "./pdp-specs";
import { ReviewsSection } from "@/features/reviews/components/reviews-section";
import { BackButton } from "@/shared/ui/back-button";

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
      className={`rounded-xs px-sm py-[3px] text-micro font-extrabold tracking-[0.4px] ${cfg.className}`}
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
    <div className="pb-[80px] lg:pb-0">
      {/* Two-column skeleton on desktop, single column on mobile */}
      <div className="lg:grid lg:grid-cols-[minmax(0,45fr)_minmax(0,55fr)] lg:items-start lg:gap-xl lg:px-lg lg:pt-lg">
        {/* Gallery shimmer */}
        <div className="aspect-square w-full animate-pulse bg-canvas sm:aspect-[4/3] md:aspect-video lg:aspect-square lg:max-h-[420px]" />
        {/* Buy-box shimmer */}
        <div className="px-lg pb-sm pt-lg lg:px-0 lg:pt-0">
          <Shimmer className="mb-sm h-[10px] w-1/4" />
          <Shimmer className="mb-xs h-[18px] w-4/5" />
          <Shimmer className="h-[18px] w-3/5" />
          <Shimmer className="mt-sm h-[14px] w-[140px]" />
          <Shimmer className="mt-sm h-[12px] w-full" />
          <Shimmer className="mt-xs h-[12px] w-3/4" />
          <Shimmer className="mt-sm h-[22px] w-[90px]" />
          <div className="mt-md flex gap-sm">
            {[1, 2, 3, 4].map((i) => (
              <Shimmer key={i} className="h-8 w-14" />
            ))}
          </div>
          <div className="mt-md">
            <Shimmer className="h-[28px] w-[120px]" />
          </div>
        </div>
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
      <p className="max-w-snug text-body-md text-muted">{message}</p>
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

  // ── Buy-box content (shared between mobile inline and desktop right column) ──
  const buyBoxContent = (
    <>
      {/* Title block */}
      <div className="px-lg pb-sm pt-lg lg:px-0 lg:pt-0">
        {product.systemTags.length > 0 ? (
          <div className="mb-sm flex flex-wrap gap-xs">
            {product.systemTags.map((t) => (
              <SystemTagPill key={t} tag={t} />
            ))}
          </div>
        ) : null}
        {product.brand ? (
          <p className="mb-xs text-micro font-extrabold uppercase tracking-[1px] text-muted">
            {product.brand}
          </p>
        ) : null}
        <h1 className="text-[18px] font-extrabold leading-snug tracking-[-0.2px] text-ink lg:text-[22px]">
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
              <span className="text-micro text-white">★</span>
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
      <div className="lg:[&>div]:px-0">
        <PdpVariantPicker product={product} onSelect={setSelectedVariant} />
      </div>

      {/* Price block */}
      <div className="lg:[&>div]:px-0">
        <PdpPriceBlock product={product} selectedVariant={selectedVariant} />
      </div>

      {/* Stock chip */}
      <div className="lg:[&>div]:mx-0">
        <StockChip qty={displayQty} />
      </div>

      {/* Offers */}
      <div className="lg:[&>div]:px-0">
        <PdpOffersStrip offers={offers} bankOffers={product.bankOffers} />
      </div>

      {/* Desktop-only buy actions (inline in right column, hidden on mobile) */}
      <div className="hidden lg:block lg:px-0 lg:pb-md lg:pt-sm">
        <PdpActionBar product={product} selectedVariant={selectedVariant} onMessage={showToast} desktopInline />
      </div>

      {/* Seller card */}
      {product.shop ? (
        <Link
          href={`/shop/${product.shop.slug}`}
          className="mx-lg mb-md flex items-center gap-md rounded-md border border-hairline bg-white p-md transition-shadow hover:shadow-floating focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand lg:mx-0"
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

      {/* Seller identity disclosure (CP E-Commerce Rules r.5/r.6) */}
      {product.shop ? <PdpSellerInfo shop={product.shop} /> : null}
    </>
  );

  return (
    <>
      {/*
       * Mobile layout: single column, sticky bottom bar.
       * Desktop (lg+): two-column grid — left sticky gallery (~45%), right buy-box.
       * Below the grid: Details, FBT rail, Specs, Reviews (full-width).
       */}
      <div className="pb-[80px] lg:pb-0">
        <div className="px-sm pt-sm">
          <BackButton fallback="/" />
        </div>

        {/* ── Two-column grid on lg+ ── */}
        <div className="lg:grid lg:grid-cols-[minmax(0,45fr)_minmax(0,55fr)] lg:items-start lg:gap-xl lg:px-lg lg:pt-lg">

          {/* Left: gallery (sticky within column on desktop) */}
          <div className="relative lg:sticky lg:top-[72px]">
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

          {/* Right: buy-box — shown inline on desktop, hidden on mobile (rendered below) */}
          <div className="hidden lg:block">
            {buyBoxContent}
          </div>
        </div>

        {/* Mobile buy-box (below gallery, single column) */}
        <div className="lg:hidden">
          {buyBoxContent}
        </div>

        {/* ── Below-the-fold sections (full width on both breakpoints) ── */}

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

        {/* Specs section */}
        <SectionDivider />
        <SectionHeader title="Specifications" />
        <PdpSpecs groups={specGroups} />

        {/* Reviews section */}
        <SectionDivider />
        <SectionHeader title="Ratings & Reviews" />
        <ReviewsSection productId={product.id} productName={product.name} />
      </div>

      {/* Sticky bottom bar — mobile only (hidden on lg+) */}
      <div className="lg:hidden">
        <PdpActionBar product={product} selectedVariant={selectedVariant} onMessage={showToast} />
      </div>

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
