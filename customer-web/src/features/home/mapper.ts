import { color } from "@/shared/ui/tokens";
import { CATEGORY_TINTS } from "@/shared/ui/category-tints";
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
function asId(v: unknown): string {
  if (typeof v === "string") return v;
  if (typeof v === "number" && Number.isFinite(v)) return String(v);
  return "";
}

const PUCK_TINTS = CATEGORY_TINTS;

function firstImage(product: Json): string {
  const imgs = product["images"];
  if (Array.isArray(imgs) && imgs.length > 0 && isObj(imgs[0])) {
    return asStr(imgs[0]["url"]);
  }
  return "";
}

function heroFromBanner(raw: unknown): HeroSlide {
  const m = isObj(raw) ? raw : {};
  return {
    bannerId: asId(m["id"]),
    imageUrl: asStr(m["imageUrl"]),
    linkUrl: asStrOrNull(m["linkUrl"]),
    productCount: asInt(m["productCount"]) ?? 0,
  };
}

function productCardFromProduct(p: Json): ProductCard | null {
  const mrp = asNum(p["mrp"]);
  const selling = asNum(p["sellingPrice"]) ?? mrp ?? 0;
  if (selling <= 0) return null;
  const ratingCount = asInt(p["ratingCount"]) ?? 0;
  const shop = isObj(p["shop"]) ? (p["shop"] as Json) : null;
  const discountPct =
    mrp !== null && mrp > selling ? Math.round(Math.min(99, Math.max(0, (1 - selling / mrp) * 100))) : 0;
  return {
    productId: asId(p["id"]),
    name: asStr(p["name"]),
    price: rupees(selling),
    originalPrice: mrp !== null && mrp > selling ? rupees(mrp) : "",
    rating: asNum(p["ratingAvg"]) ?? 0,
    ratingCount: ratingCount > 999 ? `${(ratingCount / 1000).toFixed(1)}k` : `${ratingCount}`,
    ratingCountRaw: ratingCount,
    imageUrl: firstImage(p),
    bgColor: color.surface.heroPanel,
    shopSlug: shop ? asStrOrNull(shop["slug"]) : null,
    shopName: shop ? asStrOrNull(shop["name"]) : null,
    brand: asStrOrNull(p["brand"]),
    discountPct,
    freeDelivery: false,
  };
}

function productCardFromTrending(row: unknown): ProductCard | null {
  const m = isObj(row) ? row : {};
  const product = isObj(m["product"]) ? (m["product"] as Json) : null;
  if (!product) return null;
  return productCardFromProduct(product);
}

function mapTrendingList(rows: unknown[]): ProductCard[] {
  return rows.map(productCardFromTrending).filter((x): x is ProductCard => x !== null);
}

export function mapEndlessProducts(rows: unknown[]): ProductCard[] {
  return rows
    .map((r) => (isObj(r) ? productCardFromProduct(r as Json) : null))
    .filter((x): x is ProductCard => x !== null);
}

function mapMaybeWrapped(rows: unknown[]): ProductCard[] {
  if (rows.length === 0) return [];
  const first = rows[0];
  if (isObj(first) && isObj(first["product"])) return mapTrendingList(rows);
  return mapEndlessProducts(rows);
}

function categoryPuck(raw: unknown, index: number): CategoryPuck {
  const m = isObj(raw) ? raw : {};
  return {
    categoryId: asId(m["id"]),
    slug: asStr(m["slug"]),
    label: asStr(m["name"]),
    imageUrl: asStrOrNull(m["imageUrl"]),
    tint: PUCK_TINTS[index % PUCK_TINTS.length],
  };
}

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
