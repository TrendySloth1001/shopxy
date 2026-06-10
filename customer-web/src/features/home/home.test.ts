import { describe, expect, it } from "vitest";
import { rupees, resolveImageUrl, parseColor } from "./format";
import { mapFeed, mapPersonalized } from "./mapper";
import { appendHomeBlocks, newCycleState } from "./composer";
import type { ProductCard } from "./types";

describe("format", () => {
  it("formats whole rupees with en-IN grouping", () => {
    expect(rupees(0)).toBe("₹0");
    expect(rupees(13990)).toBe("₹13,990");
    expect(rupees(150000)).toBe("₹1,50,000");
  });
  it("routes relative image paths through the media proxy, passes absolutes through", () => {
    expect(resolveImageUrl("/images/abc.webp")).toBe("/api/media/images/abc.webp");
    expect(resolveImageUrl("https://cdn.example.com/x.png")).toBe("https://cdn.example.com/x.png");
    expect(resolveImageUrl("")).toBe("");
    expect(resolveImageUrl(null)).toBe("");
  });
  it("parses hex colours and falls back on garbage", () => {
    expect(parseColor("#1e8e5a", "#000")).toBe("#1e8e5a");
    expect(parseColor("nope", "#fallback")).toBe("#fallback");
    expect(parseColor(null, "#fallback")).toBe("#fallback");
  });
});

// A minimal product row shaped like the backend's Prisma projection (Decimal as string).
function productRow(id: number, name = `P${id}`) {
  return {
    id,
    name,
    mrp: "200.00",
    sellingPrice: "150.00",
    ratingAvg: "4.5",
    ratingCount: 60,
    brand: "Acme",
    shop: { slug: "acme-store" },
    images: [{ url: `/images/p${id}.webp` }],
  };
}

describe("mapFeed", () => {
  it("maps banners, flash deals, trending and category pucks", () => {
    const feed = mapFeed({
      heroBanners: [{ id: 1, title: "Big Sale", subtitle: "Save", template: "CLASSIC", imageUrl: "/images/h.webp", brandLabel: "ACME" }],
      flashDeals: [{ id: 9, flashPrice: "99.00", soldCount: 5, stockLimit: 10, endAt: "2999-01-01T00:00:00Z", product: productRow(2) }],
      trending: [{ product: productRow(3), isAd: true, promotionId: 7 }],
      categoryPucks: [{ id: 4, slug: "mobiles", name: "Mobiles" }],
      newArrivals: [productRow(5)],
    });
    expect(feed.heroSlides[0]).toMatchObject({ title: "Big Sale", template: "classic", bannerId: 1 });
    expect(feed.flashDeals[0]).toMatchObject({ saleId: 9, productId: 2, discountPct: expect.any(Number) });
    expect(feed.flashDeals[0].soldPct).toBeCloseTo(0.5);
    expect(feed.trending[0]).toMatchObject({ productId: 3, isAd: true, promotionId: 7, discountPct: 25 });
    expect(feed.trending[0].price).toBe("₹150");
    expect(feed.categoryPucks[0]).toMatchObject({ slug: "mobiles", label: "Mobiles" });
    expect(feed.newInStock[0].productId).toBe(5);
  });

  it("drops products with no usable price", () => {
    const feed = mapFeed({ trending: [{ product: { id: 1, name: "x", sellingPrice: "0", images: [] } }] });
    expect(feed.trending).toHaveLength(0);
  });
});

describe("mapPersonalized", () => {
  it("unwraps recently-viewed rows and maps recommended", () => {
    const { recommended, recentlyViewed } = mapPersonalized({
      recommended: [productRow(1)],
      recentlyViewed: [{ product: productRow(2) }],
    });
    expect(recommended[0].productId).toBe(1);
    expect(recentlyViewed[0].productId).toBe(2);
  });
});

describe("appendHomeBlocks", () => {
  function card(id: number): ProductCard {
    return {
      productId: id,
      name: `P${id}`,
      price: "₹150",
      originalPrice: "₹200",
      bankPrice: "₹142",
      rating: 4.5,
      ratingCount: "60",
      ratingCountRaw: 60,
      imageUrl: `/api/media/images/p${id}.webp`,
      bgColor: "#EFEEE7",
      isAd: false,
      promotionId: null,
      shopSlug: "acme",
      brand: "Acme",
      discountPct: 25,
      freeDelivery: true,
    };
  }

  const baseFeed = {
    heroSlides: [],
    categoryPucks: [],
    flashDeals: [],
    adStrip: [],
    brandSpotlights: [],
    promoBanners: [],
    curatedRails: [],
    collectionTiles: [],
    trending: Array.from({ length: 24 }, (_, i) => card(i + 1)),
    offers: [],
    bestValue: [],
    newInStock: [],
    sponsoredProducts: [],
    recommended: [],
    recentlyViewed: [],
  };

  it("composes product blocks from the pool and never repeats a SKU", () => {
    const state = newCycleState();
    const blocks = appendHomeBlocks(state, baseFeed, []);
    expect(blocks.length).toBeGreaterThan(0);
    expect(blocks[0].kind).toBe("mosaic"); // first cycle step

    const seen = new Set<number>();
    let dupes = 0;
    for (const b of blocks) {
      const products =
        "products" in b ? b.products : b.kind === "mosaic" ? [b.hero, b.topRight, b.bottomRight] : [];
      for (const p of products) {
        if (seen.has(p.productId)) dupes++;
        seen.add(p.productId);
      }
    }
    expect(dupes).toBe(0);
  });

  it("is deterministic for the same feed + state seed", () => {
    const a = appendHomeBlocks(newCycleState(), baseFeed, []).map((b) => b.kind);
    const b = appendHomeBlocks(newCycleState(), baseFeed, []).map((x) => x.kind);
    expect(a).toEqual(b);
  });
});
