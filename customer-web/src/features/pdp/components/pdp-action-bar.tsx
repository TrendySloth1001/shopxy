"use client";

import { useState, useCallback } from "react";
import { ShoppingCart, Zap, Minus, Plus, Trash2, ArrowRight } from "@/shared/icons";
import { useRouter } from "next/navigation";
import { useCart } from "@/features/cart/cart-context";
import type { CartProduct } from "@/features/cart/types";
import type { ProductDetail, Variant } from "../types";

interface Props {
  product: ProductDetail;
  selectedVariant: Variant | null;
  onMessage: (msg: string, type: "success" | "error") => void;
  desktopInline?: boolean;
}

function toCartProduct(product: ProductDetail, variant: Variant | null): CartProduct {
  const imageUrl = variant?.imageUrls[0] ?? product.images[0]?.url ?? "";
  return {
    id: product.id,
    name: product.name,
    sku: variant?.sku ?? product.sku ?? null,
    unit: product.unit ?? null,
    mrp: variant?.mrp ?? product.mrp,
    sellingPrice: variant?.sellingPrice ?? product.sellingPrice,
    taxPercent: product.taxPercent,
    stockQuantity: variant?.stockQuantity ?? product.stockQuantity,
    isActive: true,
    isPublished: true,
    categoryId: product.category?.id ?? null,
    category: product.category
      ? { id: product.category.id, name: product.category.name, iconName: null }
      : null,
    images: imageUrl ? [{ url: imageUrl, sortOrder: 0 }] : [],
    shop: {
      id: product.shop?.id ?? "",
      name: product.shop?.name ?? "",
      slug: product.shop?.slug ?? "",
    },
  };
}

export function PdpActionBar({ product, selectedVariant, onMessage, desktopInline = false }: Props) {
  const router = useRouter();
  const { lines, add, setQty } = useCart();
  const [busy, setBusy] = useState(false);

  const stockQty = selectedVariant?.stockQuantity ?? product.stockQuantity;
  const isOutOfStock = stockQty <= 0;

  const cartLine = lines.find((l) => l.productId === product.id) ?? null;
  const inCart = cartLine != null && cartLine.quantity > 0;

  const handleAddToCart = useCallback(async () => {
    if (busy || isOutOfStock) return;
    setBusy(true);
    try {
      await add(toCartProduct(product, selectedVariant), 1);
      onMessage("Added to cart", "success");
    } catch (err) {
      onMessage(err instanceof Error ? err.message : "Could not add to cart.", "error");
    } finally {
      setBusy(false);
    }
  }, [busy, isOutOfStock, add, product, selectedVariant, onMessage]);

  const handleBuyNow = useCallback(async () => {
    if (busy || isOutOfStock) return;
    setBusy(true);
    try {
      await add(toCartProduct(product, selectedVariant), 1);
      router.push("/cart");
    } catch {
      setBusy(false);
    }
  }, [busy, isOutOfStock, add, product, selectedVariant, router]);

  const handleDecrement = useCallback(async () => {
    if (!cartLine) return;
    try {
      await setQty(product.id, Math.max(0, cartLine.quantity - 1));
    } catch {
    }
  }, [cartLine, product.id, setQty]);

  const handleIncrement = useCallback(async () => {
    if (!cartLine) return;
    try {
      await setQty(product.id, cartLine.quantity + 1);
    } catch {
    }
  }, [cartLine, product.id, setQty]);

  const buttons = isOutOfStock ? (
    <div className="flex h-11 items-center justify-center rounded-button bg-disabled px-lg text-label-md font-extrabold text-white">
      Out of stock
    </div>
  ) : inCart ? (
    <div className="flex items-center gap-sm">
      <div className="flex items-center rounded-button border border-brand bg-brand-soft">
        <button
          onClick={handleDecrement}
          aria-label={cartLine!.quantity === 1 ? "Remove from cart" : "Decrease quantity"}
          className="flex h-11 w-11 items-center justify-center text-brand-strong transition-colors hover:bg-brand-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
        >
          {cartLine!.quantity === 1 ? (
            <Trash2 size={16} aria-hidden />
          ) : (
            <Minus size={16} aria-hidden />
          )}
        </button>
        <span className="min-w-[32px] text-center text-title-md font-extrabold text-brand-strong">
          {cartLine!.quantity}
        </span>
        <button
          onClick={handleIncrement}
          aria-label="Increase quantity"
          className="flex h-11 w-11 items-center justify-center text-brand-strong transition-colors hover:bg-brand-soft focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
        >
          <Plus size={16} aria-hidden />
        </button>
      </div>
      <button
        onClick={() => router.push("/cart")}
        className="flex h-11 items-center justify-center gap-sm rounded-button bg-brand px-xl text-label-md font-extrabold text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand"
      >
        <ArrowRight size={16} aria-hidden />
        Go to cart
      </button>
    </div>
  ) : (
    <div className="flex items-center gap-sm">
      <button
        onClick={handleAddToCart}
        disabled={busy}
        className="flex h-11 items-center justify-center gap-sm rounded-button border border-brand bg-brand-soft px-xl text-label-md font-extrabold text-brand-strong transition-colors hover:bg-brand-soft/80 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:cursor-not-allowed disabled:opacity-50"
      >
        <ShoppingCart size={16} aria-hidden />
        {busy ? "Adding…" : "Add to cart"}
      </button>
      <button
        onClick={handleBuyNow}
        disabled={busy}
        className="flex h-11 items-center justify-center gap-sm rounded-button bg-brand px-xl text-label-md font-extrabold text-white transition-colors hover:bg-brand-strong focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand disabled:cursor-not-allowed disabled:opacity-50"
      >
        <Zap size={16} aria-hidden />
        Buy now
      </button>
    </div>
  );

  if (desktopInline) {
    return <div className="flex flex-wrap items-center gap-sm">{buttons}</div>;
  }

  return (
    <div className="sticky bottom-0 z-20 border-t border-hairline bg-white px-lg py-sm shadow-floating">
      <div className="mx-auto flex max-w-shell items-center gap-sm">
        {buttons}
      </div>
    </div>
  );
}
