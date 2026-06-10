/**
 * Home-feed presentation models — ported 1:1 from the Flutter customer app
 * (`customer/lib/features/home/data/models/home_feed_models.dart` +
 * `home_blocks.dart`). These describe the *shape* the components render; the
 * mapper (`mapper.ts`) populates them from the `/home/feed`,
 * `/me/home/personalized` and `/home/feed/page` payloads.
 *
 * Colours arrive from the backend as `#rrggbb`/`#aarrggbb` strings; the mapper
 * resolves them to CSS colour strings (or a token fallback). Image fields carry
 * server-relative paths or absolute URLs — components pass them through
 * `resolveImageUrl()` (which routes relative paths through the media proxy)
 * before rendering.
 */

/** Visual layout the merchant picked when authoring a banner slide. */
export type HeroTemplate =
  | "classic"
  | "minimal"
  | "imageOnly"
  | "split"
  | "overlay"
  | "deal"
  | "poster";

export type HeroImageFit = "cover" | "contain";

export interface HeroSlide {
  brand: string;
  title: string;
  subtitle: string;
  imageUrl: string;
  /** Resolved CSS colour (panel background). */
  bgColor: string;
  /** Resolved CSS colour (accent — CTA / badges). */
  accent: string;
  template: HeroTemplate;
  imageFit: HeroImageFit;
  brandImageUrl?: string | null;
  brandImageFit: HeroImageFit;
  ctaText?: string | null;
  ctaTarget?: string | null;
  eyebrow?: string | null;
  /** Server-side Banner id; null for locally-seeded fallbacks. */
  bannerId?: number | null;
}

export interface CategoryPuck {
  categoryId: number;
  slug: string;
  label: string;
  imageUrl?: string | null;
  /** Soft tint used as the puck background / image placeholder. */
  tint: string;
}

export interface FlashDeal {
  productId: number;
  saleId: number;
  name: string;
  price: string;
  originalPrice: string;
  discountPct: number;
  imageUrl: string;
  /** 0..1 — fraction of the stock limit sold. */
  soldPct: number;
  /** ISO timestamp the sale ends at. */
  endAt: string;
}

export interface BrandSpotlight {
  spotlightId: number;
  brand: string;
  subtitle: string;
  dealLabel: string;
  imageUrl: string;
  bgColor: string;
  ctaTarget?: string | null;
  shopSlug?: string | null;
}

export interface ProductCard {
  productId: number;
  name: string;
  price: string;
  /** Empty string when there's no MRP above the selling price. */
  originalPrice: string;
  bankPrice: string;
  rating: number;
  /** Pretty-printed count ("1.2k", "37"). */
  ratingCount: string;
  ratingCountRaw: number;
  imageUrl: string;
  /** Resolved CSS colour placeholder behind the image. */
  bgColor: string;
  tag?: string | null;
  isAd: boolean;
  promotionId?: number | null;
  shopSlug?: string | null;
  brand?: string | null;
  /** Integer percent-off (0 → hide the chip). */
  discountPct: number;
  freeDelivery: boolean;
}

/** "Assured" trust-mark eligibility — mirrors the Flutter getter. */
export function isAssured(p: ProductCard): boolean {
  return p.ratingCountRaw >= 50 && p.rating >= 4.0;
}

export interface CollectionTile {
  collectionId: number;
  slug: string;
  label: string;
  imageUrl: string;
}

/** Aggregate the home page consumes — built from `/home/feed` + personalized. */
export interface HomeFeed {
  heroSlides: HeroSlide[];
  categoryPucks: CategoryPuck[];
  flashDeals: FlashDeal[];
  adStrip: HeroSlide[];
  brandSpotlights: BrandSpotlight[];
  promoBanners: HeroSlide[];
  curatedRails: HeroSlide[];
  collectionTiles: CollectionTile[];
  trending: ProductCard[];
  offers: ProductCard[];
  bestValue: ProductCard[];
  newInStock: ProductCard[];
  sponsoredProducts: ProductCard[];
  recommended: ProductCard[];
  recentlyViewed: ProductCard[];
}

export const EMPTY_FEED: HomeFeed = {
  heroSlides: [],
  categoryPucks: [],
  flashDeals: [],
  adStrip: [],
  brandSpotlights: [],
  promoBanners: [],
  curatedRails: [],
  collectionTiles: [],
  trending: [],
  offers: [],
  bestValue: [],
  newInStock: [],
  sponsoredProducts: [],
  recommended: [],
  recentlyViewed: [],
};

export interface EndlessPage {
  products: ProductCard[];
  seed: number;
  nextPage: number;
}

// ── Composed feed blocks ────────────────────────────────────────────────────
// Discriminated union mirroring the Flutter `HomeBlock` sealed class. The
// composer (`composer.ts`) emits these; `feed-block.tsx` renders each `kind`.

export type HomeBlock =
  | { kind: "mosaic"; eyebrow: string; title: string; hero: ProductCard; topRight: ProductCard; bottomRight: ProductCard }
  | { kind: "grid2"; eyebrow: string; title: string; products: ProductCard[] }
  | { kind: "grid3"; eyebrow: string; title: string; products: ProductCard[] }
  | { kind: "vertical"; eyebrow: string; title: string; products: ProductCard[] }
  | { kind: "reels"; eyebrow: string; title: string; products: ProductCard[] }
  | { kind: "category"; category: string; products: ProductCard[] }
  | { kind: "chips"; title: string; products: ProductCard[] }
  | { kind: "compare"; title: string; left: ProductCard; right: ProductCard }
  | { kind: "carousel"; eyebrow: string; title: string; products: ProductCard[] }
  | { kind: "sponsored"; products: ProductCard[] }
  | { kind: "recentlyViewed"; products: ProductCard[] }
  | { kind: "curated"; slide: HeroSlide }
  | { kind: "collection"; title: string; tiles: CollectionTile[] }
  | { kind: "heroOne"; slide: HeroSlide }
  | { kind: "adOne"; slide: HeroSlide }
  | { kind: "promoOne"; slide: HeroSlide }
  | { kind: "flashOne"; deal: FlashDeal }
  | { kind: "spotlightOne"; spotlight: BrandSpotlight }
  | { kind: "poster"; eyebrow: string; product: ProductCard }
  | { kind: "leaderboard"; title: string; products: ProductCard[] }
  | { kind: "brandFocus"; brand: string; products: ProductCard[] }
  | { kind: "priceBand"; ceilingLabel: string; products: ProductCard[] }
  | { kind: "zigzag"; title: string; hero: ProductCard; pair: ProductCard }
  | { kind: "shopShowcase"; shopName: string; shopSlug: string | null; products: ProductCard[] };
