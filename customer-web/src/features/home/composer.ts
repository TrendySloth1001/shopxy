/**
 * Stateful, appendable home-feed block composer — a faithful port of
 * `appendHomeBlocks` from the Flutter customer app
 * (`customer/lib/features/home/data/models/home_blocks.dart`).
 *
 * It threads a `CycleState` (intro/category cursors, side-queue cursors, a
 * cross-call seen-product set, banner cooldown) across endless-scroll pages so
 * the feed keeps cycling layouts instead of restarting from "mosaic" each page.
 * Given the same feed + product pages it produces the same block sequence as
 * the mobile app.
 */

import type { BrandSpotlight, HeroSlide, HomeBlock, HomeFeed, ProductCard } from "./types";

export interface CycleState {
  seenProductIds: Set<number>;
  blockCount: number;
  introIdx: number;
  categoryIdx: number;
  curatedCursor: number;
  collectionCursor: number;
  sponsoredCursor: number;
  heroCursor: number;
  adCursor: number;
  promoCursor: number;
  flashCursor: number;
  spotlightCursor: number;
  recentInjected: boolean;
  /** Product blocks since the last banner — gates the banner cooldown. */
  productsSinceBanner: number;
}

export function newCycleState(): CycleState {
  return {
    seenProductIds: new Set<number>(),
    blockCount: 0,
    introIdx: 0,
    categoryIdx: 0,
    curatedCursor: 0,
    collectionCursor: 0,
    sponsoredCursor: 0,
    heroCursor: 0,
    adCursor: 0,
    promoCursor: 0,
    flashCursor: 0,
    spotlightCursor: 0,
    recentInjected: false,
    productsSinceBanner: 1000, // start high so the first banner can emit
  };
}

const INTROS: Array<[string, string]> = [
  ["PICKED FOR YOU", "Handpicked finds"],
  ["TRENDING", "What's hot today"],
  ["FRESH ARRIVALS", "Just in"],
  ["SAVE BIG", "Best value picks"],
  ["STAFF FAVOURITES", "Loved by our team"],
  ["UNDER ₹999", "Easy on the wallet"],
  ["CRAFTED PICKS", "Made with care"],
  ["WORTH A LOOK", "You might like these"],
  ["TOP RATED", "4★ and above"],
  ["LIMITED BATCH", "Stocks running low"],
  ["EDITORS PICK", "Curated for taste"],
];

const FALLBACK_CATEGORY_LABELS = [
  "In Mobiles",
  "In Audio",
  "In Laptops",
  "In Cameras",
  "In Wearables",
  "In Smart Home",
  "In Gaming",
  "In TV & Streaming",
];

const BANNER_STEPS = new Set<string>([
  "heroOne",
  "adOne",
  "promoOne",
  "flashOne",
  "spotlightOne",
  "curated",
  "collection",
  "sponsored",
]);
const BANNER_COOLDOWN = 2;

const CYCLE: string[] = [
  // Burst A — products + 1 single banner
  "mosaic",
  "carousel",
  "poster",
  "grid2",
  "reels",
  "leaderboard",
  "vertical",
  "heroOne",
  // Burst B — products + 3-banner cluster
  "chips",
  "category",
  "brandFocus",
  "compare",
  "grid3",
  "mosaic",
  "spotlightOne",
  "promoOne",
  "flashOne",
  // Burst C — products + 1 single banner
  "reels",
  "priceBand",
  "carousel",
  "grid2",
  "zigzag",
  "vertical",
  "chips",
  "curated",
  // Burst D — products + 3 editorial / ad blocks
  "mosaic",
  "shopShowcase",
  "category",
  "grid3",
  "compare",
  "carousel",
  "adOne",
  "sponsored",
  "collection",
];

const MAX_BLOCKS_PER_CALL = 18;

/** Parse a rendered price ("₹13,990") back to a number for price banding. */
function priceValue(rendered: string): number {
  const cleaned = rendered.replace(/[^0-9.]/g, "");
  if (cleaned === "") return Infinity;
  const n = Number.parseFloat(cleaned);
  return Number.isFinite(n) ? n : Infinity;
}

/**
 * Append blocks for one page of products. Mutates `state` and returns the
 * blocks produced this call (caller concatenates onto its running list).
 */
export function appendHomeBlocks(
  state: CycleState,
  feed: HomeFeed,
  newProducts: ProductCard[],
): HomeBlock[] {
  const out: HomeBlock[] = [];
  const pool: ProductCard[] = [];

  const absorb = (src: ProductCard[]) => {
    for (const p of src) {
      if (!state.seenProductIds.has(p.productId)) {
        state.seenProductIds.add(p.productId);
        pool.push(p);
      }
    }
  };

  if (state.blockCount === 0) {
    absorb(feed.recommended);
    absorb(feed.trending);
    absorb(feed.newInStock);
    absorb(feed.bestValue);
    absorb(feed.offers);
  }
  absorb(newProducts);

  const curated = feed.curatedRails;
  const collection = feed.collectionTiles;
  const sponsored = feed.sponsoredProducts;
  const recent = feed.recentlyViewed;

  const nextCurated = (): HeroSlide | null => {
    if (curated.length === 0) return null;
    const s = curated[state.curatedCursor % curated.length];
    state.curatedCursor++;
    return s;
  };

  const nextCollectionBlock = (): HomeBlock | null => {
    if (collection.length === 0) return null;
    const start = state.collectionCursor % collection.length;
    const rotated = [...collection.slice(start), ...collection.slice(0, start)];
    state.collectionCursor++;
    return { kind: "collection", title: rotated[0].label, tiles: rotated };
  };

  const nextSponsored = (): HomeBlock | null => {
    if (sponsored.length === 0) return null;
    const start = state.sponsoredCursor % sponsored.length;
    const rotated = [...sponsored.slice(start), ...sponsored.slice(0, start)];
    state.sponsoredCursor++;
    return { kind: "sponsored", products: rotated };
  };

  const take = (n: number, min = 0): ProductCard[] => {
    if (pool.length < (min === 0 ? n : min)) return [];
    return pool.splice(0, n);
  };

  const takeImaged = (n: number, min = 0): ProductCard[] => {
    const picked: ProductCard[] = [];
    const rejected: ProductCard[] = [];
    while (pool.length > 0 && picked.length < n) {
      const p = pool.shift() as ProductCard;
      if (p.imageUrl !== "") picked.push(p);
      else rejected.push(p);
    }
    pool.push(...rejected); // reject-list back to the tail
    if (picked.length < (min === 0 ? n : min)) {
      pool.unshift(...picked); // not enough — put them back for a later round
      return [];
    }
    return picked;
  };

  const intro = (): [string, string] => {
    const v = INTROS[state.introIdx % INTROS.length];
    state.introIdx++;
    return v;
  };

  const category = (): string => {
    const source =
      feed.categoryPucks.length > 0
        ? feed.categoryPucks.map((p) => `In ${p.label}`)
        : FALLBACK_CATEGORY_LABELS;
    const v = source[state.categoryIdx % source.length];
    state.categoryIdx++;
    return v;
  };

  /** Remove specific picks from the pool (brand/shop/price clustering). */
  const removeAll = (picks: ProductCard[]) => {
    for (const p of picks) {
      const i = pool.indexOf(p);
      if (i >= 0) pool.splice(i, 1);
    }
  };

  let addedThisCall = 0;
  let safety = 0;
  while (addedThisCall < MAX_BLOCKS_PER_CALL && safety < 200) {
    safety++;
    const step = CYCLE[state.blockCount % CYCLE.length];
    let added = false;

    if (BANNER_STEPS.has(step) && state.productsSinceBanner < BANNER_COOLDOWN) {
      state.blockCount++;
      continue;
    }

    switch (step) {
      case "mosaic": {
        const items = takeImaged(3, 3);
        if (items.length === 3) {
          const [e, t] = intro();
          out.push({ kind: "mosaic", eyebrow: e, title: t, hero: items[0], topRight: items[1], bottomRight: items[2] });
          added = true;
        }
        break;
      }
      case "carousel": {
        const items = take(6, 4);
        if (items.length >= 4) {
          const [e, t] = intro();
          out.push({ kind: "carousel", eyebrow: e, title: t, products: items });
          added = true;
        }
        break;
      }
      case "grid2": {
        const items = take(6, 4);
        if (items.length >= 4) {
          const [e, t] = intro();
          out.push({ kind: "grid2", eyebrow: e, title: t, products: items });
          added = true;
        }
        break;
      }
      case "curated": {
        const slide = nextCurated();
        if (slide) {
          out.push({ kind: "curated", slide });
          added = true;
        }
        break;
      }
      case "reels": {
        const items = take(6, 4);
        if (items.length >= 4) {
          const [e, t] = intro();
          out.push({ kind: "reels", eyebrow: e, title: t, products: items });
          added = true;
        }
        break;
      }
      case "category": {
        const items = takeImaged(4, 4);
        if (items.length === 4) {
          out.push({ kind: "category", category: category(), products: items });
          added = true;
        }
        break;
      }
      case "vertical": {
        const items = take(3, 2);
        if (items.length >= 2) {
          const [e, t] = intro();
          out.push({ kind: "vertical", eyebrow: e, title: t, products: items });
          added = true;
        }
        break;
      }
      case "collection": {
        const b = nextCollectionBlock();
        if (b) {
          out.push(b);
          added = true;
        }
        break;
      }
      case "compare": {
        const items = take(2, 2);
        if (items.length === 2) {
          out.push({ kind: "compare", title: "This or that?", left: items[0], right: items[1] });
          added = true;
        }
        break;
      }
      case "grid3": {
        const items = take(6, 6);
        if (items.length === 6) {
          const [e, t] = intro();
          out.push({ kind: "grid3", eyebrow: e, title: t, products: items });
          added = true;
        }
        break;
      }
      case "chips": {
        const items = take(6, 4);
        if (items.length >= 4) {
          out.push({ kind: "chips", title: "Quick adds", products: items });
          added = true;
        }
        break;
      }
      case "sponsored": {
        const b = nextSponsored();
        if (b) {
          out.push(b);
          added = true;
        }
        break;
      }
      case "recent": {
        if (!state.recentInjected && recent.length > 0) {
          state.recentInjected = true;
          out.push({ kind: "recentlyViewed", products: recent });
          added = true;
        }
        break;
      }
      case "heroOne": {
        if (feed.heroSlides.length > 0) {
          const slide = feed.heroSlides[state.heroCursor % feed.heroSlides.length];
          state.heroCursor++;
          out.push({ kind: "heroOne", slide });
          added = true;
        }
        break;
      }
      case "adOne": {
        if (feed.adStrip.length > 0) {
          const slide = feed.adStrip[state.adCursor % feed.adStrip.length];
          state.adCursor++;
          out.push({ kind: "adOne", slide });
          added = true;
        }
        break;
      }
      case "promoOne": {
        if (feed.promoBanners.length > 0) {
          const slide = feed.promoBanners[state.promoCursor % feed.promoBanners.length];
          state.promoCursor++;
          out.push({ kind: "promoOne", slide });
          added = true;
        }
        break;
      }
      case "flashOne": {
        if (feed.flashDeals.length > 0) {
          const deal = feed.flashDeals[state.flashCursor % feed.flashDeals.length];
          state.flashCursor++;
          out.push({ kind: "flashOne", deal });
          added = true;
        }
        break;
      }
      case "spotlightOne": {
        if (feed.brandSpotlights.length > 0) {
          const s: BrandSpotlight = feed.brandSpotlights[state.spotlightCursor % feed.brandSpotlights.length];
          state.spotlightCursor++;
          out.push({ kind: "spotlightOne", spotlight: s });
          added = true;
        }
        break;
      }
      case "poster": {
        const items = takeImaged(1, 1);
        if (items.length === 1) {
          const [e] = intro();
          out.push({ kind: "poster", eyebrow: e, product: items[0] });
          added = true;
        }
        break;
      }
      case "leaderboard": {
        const items = takeImaged(5, 3);
        if (items.length > 0) {
          out.push({ kind: "leaderboard", title: `Top ${items.length} ${category().substring(3)}`, products: items });
          added = true;
        }
        break;
      }
      case "brandFocus": {
        const byBrand = new Map<string, ProductCard[]>();
        for (const p of pool) {
          if (!p.brand || p.brand === "" || p.imageUrl === "") continue;
          const arr = byBrand.get(p.brand) ?? [];
          arr.push(p);
          byBrand.set(p.brand, arr);
        }
        if (byBrand.size > 0) {
          let bestBrand = "";
          let best: ProductCard[] = [];
          for (const [b, arr] of byBrand) {
            if (arr.length >= best.length) {
              best = arr;
              bestBrand = b;
            }
          }
          const picks = best.slice(0, 6);
          if (picks.length >= 3) {
            removeAll(picks);
            out.push({ kind: "brandFocus", brand: bestBrand, products: picks });
            added = true;
          }
        }
        break;
      }
      case "priceBand": {
        const bands: Array<[number, string]> = [
          [999, "Under ₹999"],
          [1999, "Under ₹1,999"],
          [4999, "Under ₹4,999"],
          [9999, "Under ₹9,999"],
        ];
        for (const [ceiling, label] of bands) {
          const picks = pool.filter((p) => p.imageUrl !== "" && priceValue(p.price) <= ceiling).slice(0, 6);
          if (picks.length >= 4) {
            removeAll(picks);
            out.push({ kind: "priceBand", ceilingLabel: label, products: picks });
            added = true;
            break;
          }
        }
        break;
      }
      case "zigzag": {
        const items = takeImaged(2, 2);
        if (items.length === 2) {
          out.push({ kind: "zigzag", title: "Pair them up", hero: items[0], pair: items[1] });
          added = true;
        }
        break;
      }
      case "shopShowcase": {
        const byShop = new Map<string, ProductCard[]>();
        for (const p of pool) {
          if (!p.shopSlug || p.shopSlug === "" || p.imageUrl === "") continue;
          const arr = byShop.get(p.shopSlug) ?? [];
          arr.push(p);
          byShop.set(p.shopSlug, arr);
        }
        if (byShop.size > 0) {
          let bestShop = "";
          let best: ProductCard[] = [];
          for (const [s, arr] of byShop) {
            if (arr.length >= best.length) {
              best = arr;
              bestShop = s;
            }
          }
          const picks = best.slice(0, 4);
          if (picks.length >= 3) {
            removeAll(picks);
            out.push({ kind: "shopShowcase", shopName: "Shop on ShopXY", shopSlug: bestShop, products: picks });
            added = true;
          }
        }
        break;
      }
    }

    state.blockCount++;
    if (added) {
      addedThisCall++;
      if (BANNER_STEPS.has(step)) state.productsSinceBanner = 0;
      else state.productsSinceBanner++;
    }
    if (pool.length === 0 && addedThisCall === 0 && safety >= CYCLE.length) break;
  }

  // Drain leftovers into a fallback carousel so no half-pool sits between pages.
  if (pool.length >= 2 && addedThisCall < MAX_BLOCKS_PER_CALL) {
    const [e, t] = intro();
    out.push({ kind: "carousel", eyebrow: e, title: t, products: [...pool] });
    pool.length = 0;
    state.blockCount++;
  }

  return out;
}
