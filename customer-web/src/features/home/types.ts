export interface HeroSlide {
  bannerId: string;
  imageUrl: string;
  linkUrl: string | null;
  productCount: number;
}

export interface CategoryPuck {
  categoryId: string;
  slug: string;
  label: string;
  imageUrl?: string | null;
  tint: string;
}

export interface ProductCard {
  productId: string;
  name: string;
  price: string;
  originalPrice: string;
  rating: number;
  ratingCount: string;
  ratingCountRaw: number;
  imageUrl: string;
  bgColor: string;
  tag?: string | null;
  shopSlug?: string | null;
  shopName?: string | null;
  brand?: string | null;
  discountPct: number;
  freeDelivery: boolean;
}

export function isAssured(p: ProductCard): boolean {
  return p.ratingCountRaw >= 50 && p.rating >= 4.0;
}

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
