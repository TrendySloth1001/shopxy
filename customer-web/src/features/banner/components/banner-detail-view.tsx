"use client";

import { useEffect, useState } from "react";
import { CloudOff, Loader2 } from "@/shared/icons";
import { ImageBox } from "@/features/home/components/image-box";
import { CatalogProductCard } from "@/features/catalog/components/catalog-product-card";
import type { CatalogProduct } from "@/features/catalog/types";
import { fetchBannerDetail } from "../api";
import type { BannerDetail, BannerProduct } from "../types";

/** Map a banner product (with its banner sale price) onto the shared
 *  CatalogProduct card shape: the banner sale price becomes the price,
 *  with the higher of (MRP, list price) struck through. */
function toCard(p: BannerProduct): CatalogProduct {
  const struck = Math.max(p.mrp, p.sellingPrice);
  return {
    id: p.id,
    name: p.name,
    mrp: struck > p.salePrice ? struck : p.salePrice,
    sellingPrice: p.salePrice,
    ratingAvg: p.ratingAvg ?? null,
    ratingCount: p.ratingCount,
    images: p.images,
    shop: p.shop && p.shop.slug ? { id: p.shop.id, name: p.shop.name, slug: p.shop.slug } : undefined,
  };
}

export function BannerDetailView({ id }: { id: string }) {
  const [status, setStatus] = useState<"loading" | "ready" | "error">("loading");
  const [data, setData] = useState<BannerDetail | null>(null);

  useEffect(() => {
    let active = true;
    fetchBannerDetail(id)
      .then((d) => {
        if (!active) return;
        setData(d);
        setStatus("ready");
      })
      .catch(() => active && setStatus("error"));
    return () => {
      active = false;
    };
  }, [id]);

  if (status === "loading") {
    return (
      <div className="flex justify-center py-massive">
        <Loader2 size={24} className="animate-spin text-muted" aria-hidden />
      </div>
    );
  }
  if (status === "error" || !data) {
    return (
      <div className="flex flex-col items-center gap-md px-xl py-massive text-center">
        <CloudOff size={48} className="text-muted" aria-hidden />
        <p className="text-headline-sm font-extrabold text-ink">Banner not found</p>
        <p className="text-body-sm text-muted">This promotion may have ended.</p>
      </div>
    );
  }

  return (
    <div className="mx-auto w-full max-w-shell px-lg py-lg">
      <div className="overflow-hidden rounded-lg">
        <span className="relative block aspect-[16/9] w-full bg-hero-panel sm:aspect-[1024/300]">
          <ImageBox url={data.banner.imageUrl} alt="" fit="cover" />
        </span>
      </div>

      {data.products.length > 0 ? (
        <>
          <h1 className="mt-xl text-headline-sm font-extrabold text-ink">Featured products</h1>
          <div className="mt-md grid grid-cols-2 gap-md sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-5">
            {data.products.map((p) => (
              <CatalogProductCard key={p.id} product={toCard(p)} />
            ))}
          </div>
        </>
      ) : (
        <p className="mt-xl text-center text-body-md text-muted">No products in this promotion.</p>
      )}
    </div>
  );
}
