import { describe, expect, it } from "vitest";
import { rupees, resolveImageUrl, parseColor } from "./format";
import { mapFeed, mapPersonalized } from "./mapper";

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
  it("maps image banners, trending and category pucks", () => {
    const feed = mapFeed({
      heroBanners: [{ id: 1, imageUrl: "/images/h.webp", linkUrl: "/search?q=sale" }],
      adStripBanners: [{ id: 2, imageUrl: "/images/ad.webp", linkUrl: null }],
      trending: [{ product: productRow(3) }],
      categoryPucks: [{ id: 4, slug: "mobiles", name: "Mobiles" }],
      newArrivals: [productRow(5)],
    });
    expect(feed.heroSlides[0]).toMatchObject({ bannerId: 1, imageUrl: "/images/h.webp", linkUrl: "/search?q=sale" });
    expect(feed.adStrip[0]).toMatchObject({ bannerId: 2, linkUrl: null });
    expect(feed.trending[0]).toMatchObject({ productId: 3, discountPct: 25 });
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
