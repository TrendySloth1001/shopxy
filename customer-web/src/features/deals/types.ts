/**
 * Presentation models for the Deals page and Banner detail page.
 *
 * Deals reuses `FlashDeal` and `BrandSpotlight` from the home feature (same
 * `/home/feed` payload).  Banner detail introduces `BannerSlide` which is the
 * mapped form of `GET /banners/:id/slide`.
 */

export interface BannerProduct {
  id: number;
  name: string;
  sellingPrice: number;
  mrp: number;
  /** Banner-specific sale price (computed by the backend). */
  salePrice: number;
  discountPct: number;
  discountType: "PERCENT" | "AMOUNT";
  discountValue: number;
  ratingAvg: number;
  ratingCount: number;
  imageUrl: string;
  shopId: number;
  shopName: string;
  shopSlug: string;
}

export interface BannerMeta {
  id: number;
  title: string;
  subtitle: string;
  eyebrow: string;
  brandLabel: string;
  brandImageUrl: string | null;
  ctaText: string;
  ctaTarget: string | null;
  imageUrl: string;
  bgColor: string;
  accentColor: string;
  sponsorShopId: number | null;
}

export interface BannerSlide {
  banner: BannerMeta;
  products: BannerProduct[];
  /** Maximum discount % across all products — 0 when none have a discount. */
  maxDiscountPct: number;
}
