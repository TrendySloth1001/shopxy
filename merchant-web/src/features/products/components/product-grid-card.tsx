"use client";

import Link from "next/link";
import Image from "next/image";
import { Package } from "lucide-react";
import { useTranslations } from "next-intl";
import type { Product } from "../schema";
import { money } from "../format";
import { mediaSrc } from "./product-thumb";
import { StockBadge } from "./stock-badge";

/**
 * Product card for the masonry grid on the products screen — the web
 * counterpart of the Flutter `ProductGridCard`. Carries the same signals as
 * the list row (image, name, SKU · category, sell/MRP, stock, publish state)
 * but stacked, so the card flows into the responsive column layout. The
 * whole card links to the detail page; the publish pill is an overlay button
 * that stops propagation so it doesn't trigger the link.
 */
export function ProductGridCard({
  product,
  categoryName,
  canEdit,
  toggling,
  onTogglePublish,
}: {
  product: Product;
  categoryName: string;
  canEdit: boolean;
  toggling: boolean;
  onTogglePublish: () => void;
}) {
  const t = useTranslations("products");
  const src = mediaSrc(product.images[0]?.url);
  const showStrike = product.mrp > product.sellingPrice;

  return (
    <div className="group relative overflow-hidden rounded-lg border border-hairline bg-canvas transition-colors hover:border-brand-soft">
      <Link
        href={`/dashboard/products/${product.id}`}
        className="block focus-visible:outline-none"
      >
        {/* Square, full-bleed image with a tinted package fallback. */}
        <div className="relative aspect-square w-full bg-surface-tint">
          {src ? (
            <Image
              src={src}
              alt={product.name}
              fill
              unoptimized
              sizes="(max-width: 640px) 50vw, 16rem"
              className="object-cover"
            />
          ) : (
            <span
              aria-hidden
              className="flex h-full w-full items-center justify-center text-subtle"
            >
              <Package size={40} />
            </span>
          )}
        </div>

        <div className="flex flex-col gap-xs p-md">
          <p className="line-clamp-2 text-body-md text-ink">{product.name}</p>
          <p className="truncate text-body-sm text-muted">
            {product.sku} · {categoryName}
          </p>
          <div className="mt-xs flex items-end justify-between gap-sm">
            <div className="min-w-0">
              <p className="text-body-md tabular-nums text-ink">
                {money(product.sellingPrice)}
              </p>
              {showStrike ? (
                <p className="text-body-sm tabular-nums text-subtle line-through">
                  {money(product.mrp)}
                </p>
              ) : null}
            </div>
            <StockBadge product={product} />
          </div>
        </div>
      </Link>

      {/* Publish toggle — overlay so it stays outside the card's link. */}
      <button
        type="button"
        onClick={onTogglePublish}
        disabled={!canEdit || toggling}
        aria-busy={toggling || undefined}
        aria-pressed={product.isPublished}
        title={
          canEdit
            ? product.isPublished
              ? t("list.publishedHint")
              : t("list.unpublishedHint")
            : t("list.noAccessHint")
        }
        className={`absolute right-sm top-sm rounded-full px-sm py-px text-body-sm backdrop-blur transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft disabled:opacity-60 ${
          product.isPublished
            ? "bg-brand-soft/90 text-brand-strong"
            : "bg-surface-tint/90 text-muted hover:text-ink"
        }`}
      >
        {toggling
          ? t("list.saving")
          : product.isPublished
            ? t("list.published")
            : t("list.draft")}
      </button>
    </div>
  );
}
