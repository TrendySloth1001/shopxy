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
import { rupees } from "./format";
import {
  type CategoryPuck,
  type HeroSlide,
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
    bannerId: asInt(m["id"]) ?? 0,
    imageUrl: asStr(m["imageUrl"]),
    linkUrl: asStrOrNull(m["linkUrl"]),
  };
}

// ── Product cards ───────────────────────────────────────────────────────────

function productCardFromProduct(p: Json): ProductCard | null {
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
    shopSlug: shop ? asStrOrNull(shop["slug"]) : null,
    shopName: shop ? asStrOrNull(shop["name"]) : null,
    brand: asStrOrNull(p["brand"]),
    discountPct,
    freeDelivery: true,
  };
}

/** `{score, product}` wrapper → card. */
function productCardFromTrending(row: unknown): ProductCard | null {
  const m = isObj(row) ? row : {};
  const product = isObj(m["product"]) ? (m["product"] as Json) : null;
  if (!product) return null;
  return productCardFromProduct(product);
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
    curatedRails: asList(j["curatedRailBanners"]).map(heroFromBanner),
    categoryPucks: asList(j["categoryPucks"]).map(categoryPuck),
    trending: mapTrendingList(asList(j["trending"])),
    newInStock: mapMaybeWrapped(newRows),
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
