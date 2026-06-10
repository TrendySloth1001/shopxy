/**
 * Pure mappers: backend JSON → presentation models. Ported from the Flutter
 * `HomeFeedMapper` (`customer/lib/features/home/data/models/home_feed_mapper.dart`).
 *
 * Reads dynamic wire data as `unknown` and narrows through small typed helpers
 * (`asInt`/`asNum`/`asList` …) so the rest of the app never touches `any`.
 * Prisma `Decimal` fields serialise as strings ("199.00"), so every numeric
 * read accepts both strings and numbers.
 */

import { color } from "@/shared/ui/tokens";
import { parseColor, rupees } from "./format";
import {
  type BrandSpotlight,
  type CategoryPuck,
  type CollectionTile,
  type FlashDeal,
  type HeroImageFit,
  type HeroSlide,
  type HeroTemplate,
  type HomeFeed,
  type ProductCard,
} from "./types";

type Json = Record<string, unknown>;

function isObj(v: unknown): v is Json {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}
function asList(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
}
function asNum(v: unknown): number | null {
  if (typeof v === "number") return Number.isFinite(v) ? v : null;
  if (typeof v === "string") {
    const n = Number.parseFloat(v);
    return Number.isFinite(n) ? n : null;
  }
  return null;
}
function asInt(v: unknown): number | null {
  const n = asNum(v);
  return n === null ? null : Math.trunc(n);
}
function asStr(v: unknown): string {
  return typeof v === "string" ? v : "";
}
function asStrOrNull(v: unknown): string | null {
  return typeof v === "string" ? v : null;
}

const PUCK_TINTS = [
  "#E3E8F4",
  "#F3E4D6",
  "#F9E1EA",
  "#E6F2EC",
  "#EFE9DD",
  "#E0E1E6",
  "#E7DFD4",
  "#E4DECF",
  "#E6F2DA",
  "#DEEAF1",
];

function templateFromWire(v: unknown): HeroTemplate {
  switch (asStr(v)) {
    case "MINIMAL":
      return "minimal";
    case "IMAGE_ONLY":
      return "imageOnly";
    case "SPLIT":
      return "split";
    case "OVERLAY":
      return "overlay";
    case "DEAL":
      return "deal";
    case "POSTER":
      return "poster";
    default:
      return "classic";
  }
}
function fitFromWire(v: unknown): HeroImageFit {
  return asStr(v) === "CONTAIN" ? "contain" : "cover";
}

function firstImage(product: Json): string {
  const imgs = product["images"];
  if (Array.isArray(imgs) && imgs.length > 0 && isObj(imgs[0])) {
    return asStr(imgs[0]["url"]);
  }
  return "";
}

// ── Banner → HeroSlide ──────────────────────────────────────────────────────

function heroFromBanner(raw: unknown): HeroSlide {
  const m = isObj(raw) ? raw : {};
  return {
    brand: asStr(m["brandLabel"]) || asStr(m["eyebrow"]),
    title: asStr(m["title"]),
    subtitle: asStr(m["subtitle"]),
    imageUrl: asStr(m["imageUrl"]),
    bgColor: parseColor(asStrOrNull(m["bgColor"]), color.surface.heroPanel),
    accent: parseColor(asStrOrNull(m["accentColor"]), color.brand.default),
    template: templateFromWire(m["template"]),
    imageFit: fitFromWire(m["imageFit"]),
    brandImageUrl: asStrOrNull(m["brandImageUrl"]),
    brandImageFit: fitFromWire(m["brandImageFit"]),
    ctaText: asStrOrNull(m["ctaText"]),
    ctaTarget: asStrOrNull(m["ctaTarget"]),
    eyebrow: asStrOrNull(m["eyebrow"]),
    bannerId: asInt(m["id"]),
  };
}

// ── BrandSpotlight ──────────────────────────────────────────────────────────

function brandFromSpotlight(raw: unknown): BrandSpotlight {
  const m = isObj(raw) ? raw : {};
  const shop = isObj(m["shop"]) ? (m["shop"] as Json) : null;
  return {
    spotlightId: asInt(m["id"]) ?? 0,
    brand: shop ? asStr(shop["name"]) : "",
    subtitle: asStr(m["subtitle"]),
    dealLabel: asStr(m["dealLabel"]),
    imageUrl: asStr(m["heroImageUrl"]),
    bgColor: parseColor(asStrOrNull(m["bgColor"]), color.surface.heroPanel),
    ctaTarget: asStrOrNull(m["ctaTarget"]),
    shopSlug: shop ? asStrOrNull(shop["slug"]) : null,
  };
}

// ── Flash sale ──────────────────────────────────────────────────────────────

function flashFromSale(raw: unknown): FlashDeal | null {
  const m = isObj(raw) ? raw : {};
  const product = isObj(m["product"]) ? (m["product"] as Json) : null;
  if (!product) return null;
  const flashPrice = asNum(m["flashPrice"]) ?? 0;
  const mrp = asNum(product["mrp"]) ?? asNum(product["sellingPrice"]) ?? flashPrice;
  const sold = asInt(m["soldCount"]) ?? 0;
  const limit = asInt(m["stockLimit"]) ?? 0;
  const discount = mrp > 0 ? Math.trunc(Math.min(99, Math.max(0, (1 - flashPrice / mrp) * 100))) : 0;
  const endRaw = asStr(m["endAt"]);
  const endAt = endRaw && !Number.isNaN(Date.parse(endRaw))
    ? endRaw
    : new Date(Date.now() + 3_600_000).toISOString();
  return {
    productId: asInt(product["id"]) ?? 0,
    saleId: asInt(m["id"]) ?? 0,
    name: asStr(product["name"]),
    price: rupees(flashPrice),
    originalPrice: rupees(mrp),
    discountPct: discount,
    imageUrl: firstImage(product),
    soldPct: limit > 0 ? Math.min(1, Math.max(0, sold / limit)) : 0,
    endAt,
  };
}

// ── Product cards ───────────────────────────────────────────────────────────

function productCardFromProduct(
  p: Json,
  isAd = false,
  promotionId: number | null = null,
): ProductCard | null {
  const mrp = asNum(p["mrp"]);
  const selling = asNum(p["sellingPrice"]) ?? mrp ?? 0;
  if (selling <= 0) return null;
  const ratingCount = asInt(p["ratingCount"]) ?? 0;
  const shop = isObj(p["shop"]) ? (p["shop"] as Json) : null;
  const discountPct =
    mrp !== null && mrp > selling ? Math.round(Math.min(99, Math.max(0, (1 - selling / mrp) * 100))) : 0;
  return {
    productId: asInt(p["id"]) ?? 0,
    name: asStr(p["name"]),
    price: rupees(selling),
    originalPrice: mrp !== null && mrp > selling ? rupees(mrp) : "",
    bankPrice: rupees(selling * 0.95),
    rating: asNum(p["ratingAvg"]) ?? 0,
    ratingCount: ratingCount > 999 ? `${(ratingCount / 1000).toFixed(1)}k` : `${ratingCount}`,
    ratingCountRaw: ratingCount,
    imageUrl: firstImage(p),
    bgColor: color.surface.heroPanel,
    isAd,
    promotionId,
    shopSlug: shop ? asStrOrNull(shop["slug"]) : null,
    brand: asStrOrNull(p["brand"]),
    discountPct,
    freeDelivery: true,
  };
}

/** `{score, product, isAd?, promotionId?}` wrapper → card. */
function productCardFromTrending(row: unknown): ProductCard | null {
  const m = isObj(row) ? row : {};
  const product = isObj(m["product"]) ? (m["product"] as Json) : null;
  if (!product) return null;
  return productCardFromProduct(product, m["isAd"] === true, asInt(m["promotionId"]));
}

function mapTrendingList(rows: unknown[]): ProductCard[] {
  return rows.map(productCardFromTrending).filter((x): x is ProductCard => x !== null);
}

/** Endless page rows are raw products. */
export function mapEndlessProducts(rows: unknown[]): ProductCard[] {
  return rows
    .map((r) => (isObj(r) ? productCardFromProduct(r as Json) : null))
    .filter((x): x is ProductCard => x !== null);
}

/** Route a list whose rows might be raw products or trending wrappers. */
function mapMaybeWrapped(rows: unknown[]): ProductCard[] {
  if (rows.length === 0) return [];
  const first = rows[0];
  if (isObj(first) && isObj(first["product"])) return mapTrendingList(rows);
  return mapEndlessProducts(rows);
}

// ── Collections / curated rails ─────────────────────────────────────────────

function collectionTile(raw: unknown): CollectionTile {
  const m = isObj(raw) ? raw : {};
  return {
    collectionId: asInt(m["id"]) ?? 0,
    slug: asStr(m["slug"]),
    label: asStr(m["title"]),
    imageUrl: asStr(m["coverImageUrl"]),
  };
}

function curatedRails(bannerRows: unknown[], collectionRows: unknown[]): HeroSlide[] {
  const fromBanners = bannerRows.map(heroFromBanner);
  const fromCollections = collectionRows.slice(0, 4).map((raw): HeroSlide => {
    const m = isObj(raw) ? raw : {};
    const slug = asStr(m["slug"]);
    const eyebrow = asStr(m["eyebrow"]) || "EDITORIAL";
    return {
      brand: eyebrow.toUpperCase(),
      title: asStr(m["title"]),
      subtitle: asStr(m["subtitle"]),
      imageUrl: asStr(m["coverImageUrl"]),
      bgColor: parseColor(asStrOrNull(m["bgColor"]), color.surface.heroPanel),
      accent: color.brand.default,
      template: "classic",
      imageFit: "cover",
      brandImageFit: "cover",
      ctaText: asStr(m["ctaText"]) || "Explore",
      ctaTarget: asStr(m["ctaTarget"]) || `collection:${slug}`,
      eyebrow,
    };
  });
  return [...fromBanners, ...fromCollections];
}

// ── Category pucks ──────────────────────────────────────────────────────────

function categoryPuck(raw: unknown, index: number): CategoryPuck {
  const m = isObj(raw) ? raw : {};
  return {
    categoryId: asInt(m["id"]) ?? 0,
    slug: asStr(m["slug"]),
    label: asStr(m["name"]),
    imageUrl: asStrOrNull(m["imageUrl"]),
    tint: PUCK_TINTS[index % PUCK_TINTS.length],
  };
}

// ── Top-level mappers ───────────────────────────────────────────────────────

export function mapFeed(json: unknown): HomeFeed {
  const j = isObj(json) ? json : {};
  const newArrivals = asList(j["newArrivals"]);
  const newRows = newArrivals.length > 0 ? newArrivals : asList(j["newInStock"]);
  return {
    heroSlides: asList(j["heroBanners"]).map(heroFromBanner),
    adStrip: asList(j["adStripBanners"]).map(heroFromBanner),
    promoBanners: asList(j["promoBanners"]).map(heroFromBanner),
    curatedRails: curatedRails(asList(j["curatedRailBanners"]), asList(j["collections"])),
    brandSpotlights: asList(j["brandSpotlights"]).map(brandFromSpotlight),
    flashDeals: asList(j["flashDeals"]).map(flashFromSale).filter((x): x is FlashDeal => x !== null),
    collectionTiles: asList(j["collections"]).map(collectionTile),
    categoryPucks: asList(j["categoryPucks"]).map(categoryPuck),
    trending: mapTrendingList(asList(j["trending"])),
    offers: mapTrendingList(asList(j["offers"])),
    bestValue: mapTrendingList(asList(j["bestValue"])),
    newInStock: mapMaybeWrapped(newRows),
    sponsoredProducts: mapTrendingList(asList(j["sponsoredProducts"])),
    recommended: [],
    recentlyViewed: [],
  };
}

export function mapPersonalized(json: unknown): {
  recommended: ProductCard[];
  recentlyViewed: ProductCard[];
} {
  const j = isObj(json) ? json : {};
  const recommended = asList(j["recommended"])
    .map((p) => (isObj(p) ? productCardFromProduct(p as Json) : null))
    .filter((x): x is ProductCard => x !== null);
  const recentlyViewed = asList(j["recentlyViewed"])
    .map((row) => {
      const product = isObj(row) ? (row as Json)["product"] : null;
      return isObj(product) ? productCardFromProduct(product as Json) : null;
    })
    .filter((x): x is ProductCard => x !== null);
  return { recommended, recentlyViewed };
}
