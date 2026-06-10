"use client";

import Link from "next/link";
import { ArrowRight, ChevronRight, Plus, Star, Store, Zap } from "lucide-react";
import type { HomeBlock, ProductCard } from "../types";
import { recordTap } from "../tracking";
import { ImageBox } from "./image-box";
import { ProductTile, productHref } from "./product-tile";
import { ProductCarousel, searchHref } from "./product-carousel";
import { SectionHeader } from "./section-header";
import { HeroSlideCard } from "./hero-slide";
import { FlashDeals } from "./flash-deals";
import { BrandSpotlightCard } from "./brand-spotlight";
import { CollectionBanner } from "./collection-banner";
import { RecentlyViewed } from "./recently-viewed";

/** Renders one composed feed block. Mirrors `HomeFeedBlock` in the Flutter app. */
export function FeedBlock({ block }: { block: HomeBlock }) {
  switch (block.kind) {
    case "mosaic":
      return (
        <section>
          <SectionHeader eyebrow={block.eyebrow} title={block.title} seeAllHref={searchHref(block.title)} />
          <div className="mt-md flex h-[280px] gap-md px-lg">
            <div className="flex-[6]">
              <OverlayCard product={block.hero} big />
            </div>
            <div className="flex flex-[5] flex-col gap-md">
              <OverlayCard product={block.topRight} />
              <OverlayCard product={block.bottomRight} />
            </div>
          </div>
        </section>
      );

    case "grid2":
      return (
        <section>
          <SectionHeader eyebrow={block.eyebrow} title={block.title} seeAllHref={searchHref(block.title)} />
          <div className="mt-md grid grid-cols-2 gap-md px-lg sm:grid-cols-3 lg:grid-cols-4">
            {block.products.map((p) => (
              <ProductTile key={p.productId} product={p} />
            ))}
          </div>
        </section>
      );

    case "grid3":
      return (
        <section>
          <SectionHeader eyebrow={block.eyebrow} title={block.title} seeAllHref={searchHref(block.title)} />
          <div className="mt-md grid grid-cols-3 gap-md px-lg sm:grid-cols-4 lg:grid-cols-6">
            {block.products.map((p) => (
              <ProductTile key={p.productId} product={p} />
            ))}
          </div>
        </section>
      );

    case "vertical":
      return (
        <section>
          <SectionHeader eyebrow={block.eyebrow} title={block.title} seeAllHref={searchHref(block.title)} />
          <div className="mt-md flex flex-col gap-md px-lg">
            {block.products.map((p) => (
              <VerticalCard key={p.productId} product={p} />
            ))}
          </div>
        </section>
      );

    case "reels":
      return (
        <section>
          <SectionHeader eyebrow={block.eyebrow} title={block.title} seeAllHref={searchHref(block.title)} />
          <div className="mt-md flex gap-md overflow-x-auto px-lg pb-xs [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
            {block.products.map((p) => (
              <ReelCard key={p.productId} product={p} />
            ))}
          </div>
        </section>
      );

    case "category":
      return (
        <section className="px-lg">
          <div className="rounded-lg bg-brand-soft p-md">
            <div className="flex items-center justify-between">
              <span className="rounded-full bg-brand-strong px-[8px] py-[3px] text-[11px] font-extrabold tracking-[0.3px] text-white">
                {block.category}
              </span>
              <Link href={searchHref(block.category)} className="text-[12px] font-bold text-brand-strong">
                See all
              </Link>
            </div>
            <div className="mt-md grid grid-cols-4 gap-sm">
              {block.products.map((p) => (
                <CapsuleTile key={p.productId} product={p} />
              ))}
            </div>
          </div>
        </section>
      );

    case "chips":
      return (
        <section>
          <div className="flex items-center gap-sm px-lg">
            <Zap size={18} className="fill-warning text-warning" aria-hidden />
            <h2 className="text-[16px] font-extrabold text-ink">{block.title}</h2>
          </div>
          <div className="mt-md flex gap-sm overflow-x-auto px-lg pb-xs [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
            {block.products.map((p) => (
              <QuickAddChip key={p.productId} product={p} />
            ))}
          </div>
        </section>
      );

    case "compare":
      return (
        <section className="px-lg">
          <h2 className="text-[17px] font-extrabold text-ink">{block.title}</h2>
          <div className="mt-md flex items-stretch gap-sm">
            <div className="flex-1">
              <CompareCard product={block.left} />
            </div>
            <div className="flex items-center">
              <span className="flex size-8 items-center justify-center rounded-full bg-ink text-[11px] font-extrabold text-white">
                vs
              </span>
            </div>
            <div className="flex-1">
              <CompareCard product={block.right} />
            </div>
          </div>
        </section>
      );

    case "carousel":
      return <ProductCarousel eyebrow={block.eyebrow} title={block.title} products={block.products} />;

    case "sponsored":
      return (
        <ProductCarousel
          eyebrow="SPONSORED"
          title="Promoted by merchants"
          products={block.products}
          source="sponsored"
        />
      );

    case "recentlyViewed":
      return <RecentlyViewed items={block.products} />;

    case "curated":
    case "heroOne":
    case "adOne":
    case "promoOne":
      return (
        <div className="px-sm">
          <HeroSlideCard slide={block.slide} />
        </div>
      );

    case "collection":
      return <CollectionBanner title={block.title} tiles={block.tiles} />;

    case "flashOne":
      return <FlashDeals deals={[block.deal]} />;

    case "spotlightOne":
      return <BrandSpotlightCard spotlight={block.spotlight} />;

    case "poster":
      return <PosterBlock eyebrow={block.eyebrow} product={block.product} />;

    case "leaderboard":
      return (
        <section className="px-lg">
          <h2 className="text-[18px] font-extrabold text-ink">{block.title}</h2>
          <div className="mt-md flex flex-col gap-sm">
            {block.products.map((p, i) => (
              <LeaderboardRow key={p.productId} product={p} rank={i + 1} />
            ))}
          </div>
        </section>
      );

    case "brandFocus":
      return (
        <section className="px-lg">
          <div className="rounded-lg bg-hero-panel p-md">
            <div className="flex items-center gap-sm">
              <span className="rounded-full bg-ink px-[8px] py-[3px] text-[10px] font-extrabold tracking-[0.8px] text-white">
                BRAND SPOTLIGHT
              </span>
              <span className="min-w-0 truncate text-[16px] font-extrabold text-ink">{block.brand}</span>
            </div>
            <div className="mt-md grid grid-cols-3 gap-md sm:grid-cols-4 lg:grid-cols-6">
              {block.products.map((p) => (
                <ProductTile key={p.productId} product={p} />
              ))}
            </div>
          </div>
        </section>
      );

    case "priceBand":
      return (
        <section>
          <div className="flex items-center gap-sm px-lg">
            <span className="rounded-full bg-success px-[12px] py-[6px] text-[13px] font-extrabold text-white">
              {block.ceilingLabel}
            </span>
            <h2 className="text-[16px] font-extrabold text-ink">Easy on the wallet</h2>
          </div>
          <div className="mt-md flex gap-md overflow-x-auto px-lg pb-xs [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
            {block.products.map((p) => (
              <div key={p.productId} className="w-[158px] shrink-0">
                <ProductTile product={p} />
              </div>
            ))}
          </div>
        </section>
      );

    case "zigzag":
      return (
        <section className="px-lg">
          <h2 className="text-[18px] font-extrabold text-ink">{block.title}</h2>
          <div className="mt-md flex h-[320px] gap-md">
            <div className="flex-[5]">
              <DuoCard product={block.hero} maxLines={2} />
            </div>
            <div className="flex flex-[4] flex-col gap-sm">
              <span className="w-fit rounded-full bg-brand px-[10px] py-[6px] text-[10px] font-extrabold tracking-[0.6px] text-white">
                BEST PAIR
              </span>
              <div className="min-h-0 flex-1">
                <DuoCard product={block.pair} maxLines={1} />
              </div>
            </div>
          </div>
        </section>
      );

    case "shopShowcase":
      return (
        <section className="px-lg">
          <div className="rounded-lg border border-hairline bg-white p-md">
            <Link
              href={block.shopSlug ? `/shop/${block.shopSlug}` : "/search"}
              className="flex items-center gap-sm focus-visible:outline-none"
            >
              <span className="flex size-10 items-center justify-center rounded-full bg-hero-panel">
                <Store size={22} className="text-ink" aria-hidden />
              </span>
              <span className="flex min-w-0 flex-1 flex-col">
                <span className="text-[10px] font-extrabold tracking-[0.8px] text-muted">VISIT SHOP</span>
                <span className="truncate text-[15px] font-extrabold text-ink">{block.shopName}</span>
              </span>
              <ChevronRight size={18} className="text-ink" aria-hidden />
            </Link>
            <div className="mt-md grid grid-cols-4 gap-sm">
              {block.products.map((p) => (
                <CapsuleTile key={p.productId} product={p} />
              ))}
            </div>
          </div>
        </section>
      );

    default:
      return null;
  }
}

// ── Bespoke sub-cards ───────────────────────────────────────────────────────

function OverlayCard({ product, big = false }: { product: ProductCard; big?: boolean }) {
  return (
    <Link
      href={productHref(product.productId)}
      onClick={() => recordTap(product.productId)}
      className="relative block size-full overflow-hidden rounded-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <ImageBox url={product.imageUrl} alt={product.name} placeholderColor={product.bgColor} />
      <span className="absolute inset-0 bg-gradient-to-b from-transparent to-black/55" />
      <span className="absolute inset-x-0 bottom-0 flex flex-col gap-[2px] p-md text-white">
        <span className={`font-extrabold ${big ? "line-clamp-2 text-[15px]" : "line-clamp-1 text-[12px]"}`}>
          {product.name}
        </span>
        <span className={`font-extrabold ${big ? "text-[17px]" : "text-[13px]"}`}>{product.price}</span>
      </span>
    </Link>
  );
}

function VerticalCard({ product }: { product: ProductCard }) {
  return (
    <Link
      href={productHref(product.productId)}
      onClick={() => recordTap(product.productId)}
      className="block overflow-hidden rounded-lg bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <span className="relative block aspect-[16/10] w-full">
        <ImageBox url={product.imageUrl} alt={product.name} placeholderColor={product.bgColor} />
      </span>
      <span className="flex flex-col p-md">
        <span className="line-clamp-2 text-[15px] font-bold text-ink">{product.name}</span>
        <span className="mt-xs flex items-center gap-sm">
          <span className="text-[18px] font-extrabold text-ink">{product.price}</span>
          {product.originalPrice ? (
            <span className="text-[12px] text-muted line-through">{product.originalPrice}</span>
          ) : null}
          {product.ratingCountRaw > 0 ? (
            <span className="ml-auto flex items-center gap-[2px] rounded-sm bg-success-soft px-[6px] py-[2px] text-[11px] font-bold text-success">
              <Star size={11} className="fill-success text-success" aria-hidden /> {product.rating.toFixed(1)} (
              {product.ratingCount})
            </span>
          ) : null}
        </span>
      </span>
    </Link>
  );
}

function ReelCard({ product }: { product: ProductCard }) {
  return (
    <Link
      href={productHref(product.productId)}
      onClick={() => recordTap(product.productId)}
      className="relative block aspect-[9/16] w-[180px] shrink-0 overflow-hidden rounded-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <ImageBox url={product.imageUrl} alt={product.name} placeholderColor={product.bgColor} />
      {product.ratingCountRaw > 0 ? (
        <span className="absolute left-sm top-sm flex items-center gap-[2px] rounded-sm bg-white/95 px-[6px] py-[2px] text-[11px] font-extrabold text-ink">
          {product.rating.toFixed(1)} <Star size={11} className="fill-success text-success" aria-hidden />
        </span>
      ) : null}
      <span className="absolute inset-x-0 bottom-0 bg-gradient-to-b from-transparent to-black/75 p-sm text-white">
        <span className="line-clamp-1 text-[13px] font-bold">{product.name}</span>
        <span className="text-[16px] font-extrabold">{product.price}</span>
      </span>
    </Link>
  );
}

function CapsuleTile({ product }: { product: ProductCard }) {
  return (
    <Link
      href={productHref(product.productId)}
      onClick={() => recordTap(product.productId)}
      className="flex flex-col gap-xs focus-visible:outline-none"
    >
      <span className="relative block aspect-square w-full overflow-hidden rounded-md">
        <ImageBox url={product.imageUrl} alt={product.name} placeholderColor={product.bgColor} />
      </span>
      <span className="line-clamp-1 text-[11px] font-semibold text-ink">{product.name}</span>
      <span className="text-[12px] font-extrabold text-ink">{product.price}</span>
    </Link>
  );
}

function QuickAddChip({ product }: { product: ProductCard }) {
  return (
    <Link
      href={productHref(product.productId)}
      onClick={() => recordTap(product.productId)}
      className="flex shrink-0 items-center gap-sm rounded-full border border-hairline bg-white py-[4px] pl-[4px] pr-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <span className="relative block size-12 overflow-hidden rounded-full">
        <ImageBox url={product.imageUrl} alt={product.name} placeholderColor={product.bgColor} />
      </span>
      <span className="flex max-w-[120px] flex-col">
        <span className="line-clamp-1 text-[12px] font-semibold text-ink">{product.name}</span>
        <span className="text-[13px] font-extrabold text-ink">{product.price}</span>
      </span>
      <span className="flex size-7 items-center justify-center rounded-full bg-brand text-white">
        <Plus size={18} aria-hidden />
      </span>
    </Link>
  );
}

function CompareCard({ product }: { product: ProductCard }) {
  return (
    <Link
      href={productHref(product.productId)}
      onClick={() => recordTap(product.productId)}
      className="flex size-full flex-col overflow-hidden rounded-lg border border-hairline bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <span className="relative block aspect-square w-full">
        <ImageBox url={product.imageUrl} alt={product.name} placeholderColor={product.bgColor} />
      </span>
      <span className="flex flex-col p-sm">
        <span className="line-clamp-1 text-[12px] font-semibold text-ink">{product.name}</span>
        <span className="text-[14px] font-extrabold text-ink">{product.price}</span>
        {product.ratingCountRaw > 0 ? (
          <span className="flex items-center gap-[2px] text-[10px] font-semibold text-muted">
            <Star size={12} className="fill-success text-success" aria-hidden /> {product.rating.toFixed(1)} (
            {product.ratingCount})
          </span>
        ) : null}
      </span>
    </Link>
  );
}

function PosterBlock({ eyebrow, product }: { eyebrow: string; product: ProductCard }) {
  return (
    <section className="px-lg">
      <Link
        href={productHref(product.productId)}
        onClick={() => recordTap(product.productId)}
        className="relative block aspect-[16/11] w-full overflow-hidden rounded-lg focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
      >
        <ImageBox url={product.imageUrl} alt={product.name} placeholderColor={product.bgColor} />
        <span className="absolute inset-0 bg-gradient-to-b from-black/5 to-black/65" />
        <span className="absolute inset-x-lg bottom-lg flex flex-col items-start gap-sm text-white">
          {eyebrow ? (
            <span className="text-[11px] font-extrabold uppercase tracking-[1.2px]">{eyebrow}</span>
          ) : null}
          <span className="line-clamp-2 text-[22px] font-extrabold leading-tight">{product.name}</span>
          <span className="flex items-center gap-sm">
            <span className="rounded-full bg-white px-[10px] py-[5px] text-[14px] font-extrabold text-ink">
              {product.price}
            </span>
            <span className="flex items-center gap-[4px] rounded-full bg-brand px-md py-[6px] text-[12px] font-extrabold text-white">
              Shop now <ArrowRight size={16} aria-hidden />
            </span>
          </span>
        </span>
      </Link>
    </section>
  );
}

function LeaderboardRow({ product, rank }: { product: ProductCard; rank: number }) {
  const rankClass =
    rank === 1
      ? "bg-warning text-white"
      : rank <= 3
        ? "bg-brand text-white"
        : "bg-hero-panel text-ink";
  return (
    <Link
      href={productHref(product.productId)}
      onClick={() => recordTap(product.productId)}
      className="flex items-center gap-sm rounded-md border border-hairline bg-white p-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <span className={`flex size-10 items-center justify-center rounded-full text-[15px] font-extrabold ${rankClass}`}>
        {rank}
      </span>
      <span className="relative block size-10 shrink-0 overflow-hidden rounded-sm">
        <ImageBox url={product.imageUrl} alt={product.name} placeholderColor={product.bgColor} />
      </span>
      <span className="flex min-w-0 flex-1 flex-col">
        <span className="line-clamp-1 text-[13px] font-bold text-ink">{product.name}</span>
        <span className="flex items-baseline gap-[4px]">
          <span className="text-[14px] font-extrabold text-ink">{product.price}</span>
          {product.originalPrice ? (
            <span className="text-[11px] text-muted line-through">{product.originalPrice}</span>
          ) : null}
        </span>
      </span>
      <ChevronRight size={14} className="text-muted" aria-hidden />
    </Link>
  );
}

function DuoCard({ product, maxLines }: { product: ProductCard; maxLines: 1 | 2 }) {
  const clamp = maxLines === 2 ? "line-clamp-2" : "line-clamp-1";
  return (
    <Link
      href={productHref(product.productId)}
      onClick={() => recordTap(product.productId)}
      className="flex size-full flex-col overflow-hidden rounded-md border border-hairline bg-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-soft"
    >
      <span className="relative block min-h-0 flex-1">
        <ImageBox url={product.imageUrl} alt={product.name} placeholderColor={product.bgColor} />
      </span>
      <span className="flex flex-col p-sm">
        <span className={`${clamp} text-[12.5px] font-bold leading-snug text-ink`}>{product.name}</span>
        <span className="text-[14px] font-extrabold text-ink">{product.price}</span>
      </span>
    </Link>
  );
}
