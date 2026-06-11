/**
 * Maps raw `GET /banners/:id/slide` JSON → `BannerSlide` presentation model.
 * Parallels the Flutter `_parseColor` / product-card field extraction logic in
 * `banner_slide_detail_page.dart`.
 */

import { parseColor } from "@/features/home/format";
import { color } from "@/shared/ui/tokens";
import type { BannerMeta, BannerProduct, BannerSlide } from "./types";

type Json = Record<string, unknown>;

function isObj(v: unknown): v is Json {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}
function asList(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
}
function asNum(v: unknown): number {
  if (typeof v === "number" && Number.isFinite(v)) return v;
  if (typeof v === "string") {
    const n = Number.parseFloat(v);
    return Number.isFinite(n) ? n : 0;
  }
  return 0;
}
function asInt(v: unknown): number {
  return Math.trunc(asNum(v));
}
function asStr(v: unknown): string {
  return typeof v === "string" ? v : "";
}
function asStrOrNull(v: unknown): string | null {
  return typeof v === "string" ? v : null;
}

function mapBannerMeta(raw: unknown): BannerMeta {
  const m = isObj(raw) ? raw : {};
  return {
    id: asInt(m["id"]),
    title: asStr(m["title"]),
    subtitle: asStr(m["subtitle"]),
    eyebrow: asStr(m["eyebrow"]),
    brandLabel: asStr(m["brandLabel"]),
    brandImageUrl: asStrOrNull(m["brandImageUrl"]),
    ctaText: asStr(m["ctaText"]),
    ctaTarget: asStrOrNull(m["ctaTarget"]),
    imageUrl: asStr(m["imageUrl"]),
    bgColor: parseColor(asStrOrNull(m["bgColor"]), color.surface.heroPanel),
    accentColor: parseColor(asStrOrNull(m["accentColor"]), color.brand.default),
    sponsorShopId: m["sponsorShopId"] != null ? asInt(m["sponsorShopId"]) : null,
  };
}

function firstImageUrl(raw: Json): string {
  const imgs = raw["images"];
  if (Array.isArray(imgs) && imgs.length > 0 && isObj(imgs[0])) {
    return asStr(imgs[0]["url"]);
  }
  return "";
}

function mapBannerProduct(raw: unknown): BannerProduct | null {
  if (!isObj(raw)) return null;
  const id = asInt(raw["id"]);
  if (!id) return null;
  const shop = isObj(raw["shop"]) ? (raw["shop"] as Json) : null;

  const sellingPrice = asNum(raw["sellingPrice"]);
  const mrp = asNum(raw["mrp"]);
  const salePriceRaw = asNum(raw["salePrice"]);
  const salePrice = salePriceRaw > 0 ? salePriceRaw : sellingPrice;
  const discountPct = asInt(raw["discountPct"]);
  const discountTypeRaw = asStr(raw["discountType"]);
  const discountType: "PERCENT" | "AMOUNT" =
    discountTypeRaw === "AMOUNT" ? "AMOUNT" : "PERCENT";

  return {
    id,
    name: asStr(raw["name"]),
    sellingPrice,
    mrp,
    salePrice,
    discountPct,
    discountType,
    discountValue: asNum(raw["discountValue"]),
    ratingAvg: asNum(raw["ratingAvg"]),
    ratingCount: asInt(raw["ratingCount"]),
    imageUrl: firstImageUrl(raw),
    shopId: shop ? asInt(shop["id"]) : 0,
    shopName: shop ? asStr(shop["name"]) : "",
    shopSlug: shop ? asStr(shop["slug"]) : "",
  };
}

export function mapBannerSlide(raw: unknown): BannerSlide {
  const j = isObj(raw) ? raw : {};
  const banner = mapBannerMeta(j["banner"]);
  const products = asList(j["products"])
    .map(mapBannerProduct)
    .filter((x): x is BannerProduct => x !== null);

  const maxDiscountPct = products.reduce(
    (max, p) => (p.discountPct > max ? p.discountPct : max),
    0,
  );

  return { banner, products, maxDiscountPct };
}
