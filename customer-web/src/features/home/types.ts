/**
 * Home-feed presentation models. The mapper (`mapper.ts`) populates these from
 * the `/home/feed`, `/home/personalized` and `/home/feed/page` payloads.
 *
 * A banner is now just an uploaded image + an optional click-through link +
 * the placement slot it shows in — no templates, colours, or product pinning.
 */

/** A home banner — a merchant/admin-uploaded image and where it links to. */
export interface HeroSlide {
  /** Server-side Banner id. */
  bannerId: string;
  imageUrl: string;
  /** Optional click-through: a relative app path or absolute URL. */
  linkUrl: string | null;
  /** Number of products pinned to this banner; >0 → tap opens its detail page. */
  productCount: number;
}

export interface CategoryPuck {
  categoryId: string;
  slug: string;
  label: string;
  imageUrl?: string | null;
  /** Soft tint used as the puck background / image placeholder. */
  tint: string;
}

export interface ProductCard {
  productId: string;
  name: string;
  price: string;
  /** Empty string when there's no MRP above the selling price. */
  originalPrice: string;
  rating: number;
  /** Pretty-printed count ("1.2k", "37"). */
  ratingCount: string;
  ratingCountRaw: number;
  imageUrl: string;
  /** Resolved CSS colour placeholder behind the image. */
  bgColor: string;
  tag?: string | null;
  shopSlug?: string | null;
  /** Selling shop's display name — shown as a "by <shop>" line. */
  shopName?: string | null;
  brand?: string | null;
  /** Integer percent-off (0 → hide the chip). */
  discountPct: number;
  freeDelivery: boolean;
}

/** "Assured" trust-mark eligibility — mirrors the Flutter getter. */
export function isAssured(p: ProductCard): boolean {
  return p.ratingCountRaw >= 50 && p.rating >= 4.0;
}

/** Aggregate the home page consumes — built from `/home/feed` + personalized. */
export interface HomeFeed {
  heroSlides: HeroSlide[];
  adStrip: HeroSlide[];
  promoBanners: HeroSlide[];
  curatedRails: HeroSlide[];
  categoryPucks: CategoryPuck[];
  trending: ProductCard[];
  newInStock: ProductCard[];
  recommended: ProductCard[];
  recentlyViewed: ProductCard[];
}

export const EMPTY_FEED: HomeFeed = {
  heroSlides: [],
  adStrip: [],
  promoBanners: [],
  curatedRails: [],
  categoryPucks: [],
  trending: [],
  newInStock: [],
  recommended: [],
  recentlyViewed: [],
};

export interface EndlessPage {
  products: ProductCard[];
  seed: number;
  nextPage: number;
}
