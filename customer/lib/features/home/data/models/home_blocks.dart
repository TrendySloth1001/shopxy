import 'package:shopxy_customer/features/home/data/models/home_feed_mapper.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';

/// Typed feed block emitted below the spotlight.
///
/// The home page used to be a parade of horizontal product carousels —
/// all the same shape, all the same gesture. The block model breaks that
/// up: each `HomeBlock` carries one display pattern (mosaic, grid,
/// reels, comparison, …) plus the products to render. A composer turns
/// the raw `HomeFeed` into an ordered `List<HomeBlock>` that the page
/// iterates over.
///
/// Why client-side composition (not backend-driven yet): we already have
/// enough product slices in the existing payload to produce a rich,
/// long-scroll feed. Doing this in the client first lets us iterate on
/// the layouts without round-tripping a schema; once the patterns
/// stabilise the server can emit a `feed.blocks` array and the renderer
/// stays the same.
sealed class HomeBlock {
  const HomeBlock();
}

class MosaicBlock extends HomeBlock {
  const MosaicBlock({
    required this.eyebrow,
    required this.title,
    required this.hero,
    required this.topRight,
    required this.bottomRight,
  });
  final String eyebrow;
  final String title;
  final ProductCard hero;
  final ProductCard topRight;
  final ProductCard bottomRight;
}

class Grid2ColBlock extends HomeBlock {
  const Grid2ColBlock({
    required this.eyebrow,
    required this.title,
    required this.products,
  });
  final String eyebrow;
  final String title;
  final List<ProductCard> products;
}

class VerticalCardsBlock extends HomeBlock {
  const VerticalCardsBlock({
    required this.eyebrow,
    required this.title,
    required this.products,
  });
  final String eyebrow;
  final String title;
  final List<ProductCard> products;
}

class ReelsTallBlock extends HomeBlock {
  const ReelsTallBlock({
    required this.eyebrow,
    required this.title,
    required this.products,
  });
  final String eyebrow;
  final String title;
  final List<ProductCard> products;
}

class Grid3CompactBlock extends HomeBlock {
  const Grid3CompactBlock({
    required this.eyebrow,
    required this.title,
    required this.products,
  });
  final String eyebrow;
  final String title;
  final List<ProductCard> products;
}

class CategoryCapsuleBlock extends HomeBlock {
  const CategoryCapsuleBlock({
    required this.category,
    required this.products,
  });
  final String category;
  final List<ProductCard> products;
}

class QuickAddChipsBlock extends HomeBlock {
  const QuickAddChipsBlock({required this.title, required this.products});
  final String title;
  final List<ProductCard> products;
}

class ComparisonBlock extends HomeBlock {
  const ComparisonBlock({
    required this.title,
    required this.left,
    required this.right,
  });
  final String title;
  final ProductCard left;
  final ProductCard right;
}

class CarouselBlock extends HomeBlock {
  const CarouselBlock({
    required this.eyebrow,
    required this.title,
    required this.products,
  });
  final String eyebrow;
  final String title;
  final List<ProductCard> products;
}

class CuratedRailBlock extends HomeBlock {
  const CuratedRailBlock(this.slide);
  final HeroSlide slide;
}

class CollectionBannerBlock extends HomeBlock {
  const CollectionBannerBlock({required this.title, required this.tiles});
  final String title;
  final List<CollectionTile> tiles;
}

class SponsoredCarouselBlock extends HomeBlock {
  const SponsoredCarouselBlock(this.products);
  final List<ProductCard> products;
}

class RecentlyViewedBlock extends HomeBlock {
  const RecentlyViewedBlock(this.products);
  final List<ProductCard> products;
}

/// Single-card promo blocks. These are the de-clumped versions of the
/// hero / ad-strip / flash / spotlight / promo carousels that used to
/// sit in the fixed prelude. The composer now drips them through the
/// feed at a low ratio, cursor-rotating the source list so every
/// insertion shows a different slide.
class HeroSingleBlock extends HomeBlock {
  const HeroSingleBlock(this.slide);
  final HeroSlide slide;
}

class AdSingleBlock extends HomeBlock {
  const AdSingleBlock(this.slide);
  final HeroSlide slide;
}

class PromoSingleBlock extends HomeBlock {
  const PromoSingleBlock(this.slide);
  final HeroSlide slide;
}

class FlashSingleBlock extends HomeBlock {
  const FlashSingleBlock(this.deal);
  final FlashDealProduct deal;
}

class SpotlightSingleBlock extends HomeBlock {
  const SpotlightSingleBlock(this.spotlight);
  final BrandSpotlight spotlight;
}

// ── Layout designs added in round 8 ─────────────────────────────

/// Editorial poster: one product, full-bleed image, large title +
/// price chip overlay. Reads like a campaign card.
class PosterProductBlock extends HomeBlock {
  const PosterProductBlock({required this.eyebrow, required this.product});
  final String eyebrow;
  final ProductCard product;
}

/// Numbered "Top N in <category>" ranking. The compose layer picks
/// any title; the render layer draws 1..5 rank chips.
class LeaderboardBlock extends HomeBlock {
  const LeaderboardBlock({required this.title, required this.products});
  final String title;
  final List<ProductCard> products; // 3..5 items
}

/// Brand-led grid: "Spotlight: <brand>" + 6 products from that brand.
/// Composer hunts the pool for a brand cluster — falls back to first
/// brand it finds.
class BrandFocusBlock extends HomeBlock {
  const BrandFocusBlock({required this.brand, required this.products});
  final String brand;
  final List<ProductCard> products;
}

/// Price-band themed strip: "Under ₹X" callout + 6 mini cards.
class PriceBandBlock extends HomeBlock {
  const PriceBandBlock({required this.ceilingLabel, required this.products});
  final String ceilingLabel;
  final List<ProductCard> products;
}

/// Editorial duo — one tall hero card + one square paired card, with
/// a "Best pair" label between.
class ZigZagDuoBlock extends HomeBlock {
  const ZigZagDuoBlock({required this.title, required this.hero, required this.pair});
  final String title;
  final ProductCard hero;
  final ProductCard pair;
}

/// Shop showcase: shop name + tagline + 4-tile grid of products from
/// that shop. Composer keys on the first product's `shopSlug`.
class ShopShowcaseBlock extends HomeBlock {
  const ShopShowcaseBlock({required this.shopName, required this.shopSlug, required this.products});
  final String shopName;
  final String? shopSlug;
  final List<ProductCard> products;
}

/// Eyebrow + title pairs cycled through as we generate new blocks from
/// the product pool. Kept here (not on the block widgets) so a future
/// localization pass has one file to translate.
const _intros = <(String, String)>[
  ('PICKED FOR YOU', 'Handpicked finds'),
  ('TRENDING', "What's hot today"),
  ('FRESH ARRIVALS', 'Just in'),
  ('SAVE BIG', 'Best value picks'),
  ('STAFF FAVOURITES', 'Loved by our team'),
  ('UNDER ₹999', 'Easy on the wallet'),
  ('CRAFTED PICKS', 'Made with care'),
  ('WORTH A LOOK', 'You might like these'),
  ('TOP RATED', '4★ and above'),
  ('LIMITED BATCH', 'Stocks running low'),
  ('EDITORS PICK', 'Curated for taste'),
];

/// Fallback labels for `CategoryCapsuleBlock` when the feed didn't
/// supply real category pucks. The composer prefers the actual
/// canonical category names from `feed.categoryPucks` and falls back
/// to this list only for cold-start renders.
const _fallbackCategoryLabels = <String>[
  'In Mobiles',
  'In Audio',
  'In Laptops',
  'In Cameras',
  'In Wearables',
  'In Smart Home',
  'In Gaming',
  'In TV & Streaming',
];

/// State carried across successive [appendHomeBlocks] calls so the
/// endless feed keeps cycling through layouts, intros and category
/// labels instead of restarting from "mosaic" every page.
class HomeBlockCycleState {
  final Set<int> seenProductIds = <int>{};
  int blockCount = 0;
  int introIdx = 0;
  int categoryIdx = 0;
  // Side-queue indices. Promos cycle (curated, collection, sponsored,
  // recent rotate back to 0 once consumed) so each scroll page sees a
  // fresh banner. Recently-viewed is one-shot.
  int curatedCursor = 0;
  int collectionCursor = 0;
  int sponsoredCursor = 0;
  // Drip cursors for the de-clumped promo widgets that used to sit
  // in the fixed prelude. Each insertion advances its own cursor so
  // page N never shows the same slide twice in a row.
  int heroCursor = 0;
  int adCursor = 0;
  int promoCursor = 0;
  int flashCursor = 0;
  int spotlightCursor = 0;
  bool recentInjected = false;
  /// Count of product blocks since the last banner block. Banner
  /// steps refuse to emit when this is below the cooldown floor —
  /// stops the feed from becoming banner-dominant after the pool
  /// depletes (banner steps don't need products, so without a
  /// cooldown they keep emitting while product steps starve).
  int productsSinceBanner = 1000; // start high so first banner can emit
}

/// Builds the post-spotlight block list from a [HomeFeed]. Backwards-
/// Parses the rendered price string ("₹13,990") back into a number for
/// the `PriceBandBlock` bucketer. Returns `double.infinity` on parse
/// failure so unknown-priced products never qualify for the cheapest
/// band by accident.
double _priceValue(String rendered) {
  final cleaned = rendered.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return double.infinity;
  return double.tryParse(cleaned) ?? double.infinity;
}

/// compatible facade — for a finite single-shot feed (legacy callers),
/// wraps [appendHomeBlocks] with a one-off state object.
List<HomeBlock> composeHomeBlocks(HomeFeed feed) {
  return appendHomeBlocks(
    state: HomeBlockCycleState(),
    feed: feed,
    newProducts: const [],
    blocks: [],
  );
}

/// Stateful, appendable composer. Pulls products from [feed.recommended]
/// + [feed.trending] (only on the very first call, when
/// `state.blockCount == 0`) and from [newProducts] on every call. The
/// cycle counter, intro index and side-queue cursors live on [state],
/// so each invocation continues the layout pattern instead of resetting.
///
/// Returns the **complete** running list of blocks. Mutates [state]
/// and [blocks] in place — callers can pass their existing list and
/// get the appended view back.
List<HomeBlock> appendHomeBlocks({
  required HomeBlockCycleState state,
  required HomeFeed feed,
  required List<ProductCard> newProducts,
  required List<HomeBlock> blocks,
}) {
  // Per-call rolling pool — combines (on first call) the eager
  // recommended/trending/etc. lists with whatever new products this
  // page brought in. De-duplication uses the cross-call
  // `state.seenProductIds` set so the same SKU never renders twice
  // even after wrap-around shuffles.
  final pool = <ProductCard>[];
  void absorb(Iterable<ProductCard> src) {
    for (final p in src) {
      if (state.seenProductIds.add(p.productId)) pool.add(p);
    }
  }

  if (state.blockCount == 0) {
    absorb(feed.recommended);
    absorb(feed.trending);
    absorb(feed.newInStock);
    absorb(feed.bestValue);
    absorb(feed.offers);
  }
  absorb(newProducts);

  // Side queues — banners cycle (curated, collection, sponsored) so
  // every page reshuffles which promo lands where. Recently-viewed is
  // still one-shot because re-rendering the same "you saw…" rail on
  // every page would feel repetitive.
  final curated = feed.curatedRails;
  final collection = feed.collectionTiles;
  final sponsored = feed.sponsoredProducts;
  final recent = feed.recentlyViewed;

  HeroSlide? nextCurated() {
    if (curated.isEmpty) return null;
    final s = curated[state.curatedCursor % curated.length];
    state.curatedCursor++;
    return s;
  }

  CollectionBannerBlock? nextCollectionBlock() {
    if (collection.isEmpty) return null;
    // Rotate the tile order so the same collection card doesn't
    // always lead with the same image when re-injected on later pages.
    final start = state.collectionCursor % collection.length;
    final rotated = [
      ...collection.sublist(start),
      ...collection.sublist(0, start),
    ];
    state.collectionCursor++;
    return CollectionBannerBlock(title: rotated.first.label, tiles: rotated);
  }

  SponsoredCarouselBlock? nextSponsored() {
    if (sponsored.isEmpty) return null;
    // Stable rotation so an ad block on page 3 isn't the same as one
    // on page 1 — gives the impression of fresh sponsor inventory.
    final start = state.sponsoredCursor % sponsored.length;
    final rotated = [
      ...sponsored.sublist(start),
      ...sponsored.sublist(0, start),
    ];
    state.sponsoredCursor++;
    return SponsoredCarouselBlock(rotated);
  }

  List<ProductCard> take(int n, {int min = 0}) {
    if (pool.length < (min == 0 ? n : min)) return const [];
    final out = pool.take(n).toList();
    pool.removeRange(0, out.length);
    return out;
  }

  /// Like `take` but skips products whose image URL is empty. Used by
  /// layouts where a missing image looks especially bad (capsule grid,
  /// mosaic hero, poster). Pulls extras out of the pool to fill until
  /// it has either `n` good cards or the pool runs dry.
  List<ProductCard> takeImaged(int n, {int min = 0}) {
    final out = <ProductCard>[];
    final rejected = <ProductCard>[];
    while (pool.isNotEmpty && out.length < n) {
      final p = pool.removeAt(0);
      if (p.imageUrl.isNotEmpty) {
        out.add(p);
      } else {
        rejected.add(p);
      }
    }
    // Reject-list goes back to the tail so a later carousel can still
    // surface them — they're not wasted, just deprioritised for the
    // image-sensitive layouts.
    pool.addAll(rejected);
    if (out.length < (min == 0 ? n : min)) {
      // Not enough imaged products this round; put what we pulled back
      // so the cycle can retry later when the pool grows.
      pool.insertAll(0, out);
      return const [];
    }
    return out;
  }

  (String, String) intro() {
    final v = _intros[state.introIdx % _intros.length];
    state.introIdx++;
    return v;
  }

  String category() {
    // Pull from the real canonical category names when the feed
    // supplied them — keeps the chip honest to the catalog ("In
    // Smartphones" instead of the legacy "In Fashion"). Falls back
    // to a hand-curated list if cold-start.
    final source = feed.categoryPucks.isNotEmpty
        ? feed.categoryPucks.map((p) => 'In ${p.label}').toList()
        : _fallbackCategoryLabels;
    final v = source[state.categoryIdx % source.length];
    state.categoryIdx++;
    return v;
  }

  // Layout cycle in four "bursts":
  //   Burst A — 5 product blocks → 1 single banner
  //   Burst B — 5 product blocks → 3 banners (spotlight + promo + flash)
  //   Burst C — 5 product blocks → 1 single banner
  //   Burst D — 5 product blocks → 3 editorial blocks (ad + sponsored + collection)
  //
  // 20 product slots vs 8 banner slots per cycle (71% products). The
  // 3-banner clusters match the "then 2-3 banners different like promo
  // etc, then again same and repeat" pattern. `recent` is no longer
  // here — recently-viewed surfaces in the prelude instead.
  //
  // Banner cooldown: see `bannerSteps` below — these refuse to emit
  // unless `productsSinceBanner >= bannerCooldown`. Stops the feed
  // from going banner-heavy when the product pool depletes faster
  // than pages refill it (banner steps don't need products, so
  // without throttling they'd take over).
  const bannerSteps = <String>{
    'heroOne', 'adOne', 'promoOne', 'flashOne', 'spotlightOne',
    'curated', 'collection', 'sponsored',
  };
  const bannerCooldown = 2; // ≥2 product blocks between consecutive banners

  const cycle = <String>[
    // Burst A — products + 1 single banner
    'mosaic',
    'carousel',
    'poster',         // ⊕ new: editorial single-product poster
    'grid2',
    'reels',
    'leaderboard',    // ⊕ new: top-5 ranking
    'vertical',
    'heroOne',

    // Burst B — products + 3-banner cluster
    'chips',
    'category',
    'brandFocus',     // ⊕ new: spotlight one brand
    'compare',
    'grid3',
    'mosaic',
    'spotlightOne',
    'promoOne',
    'flashOne',

    // Burst C — products + 1 single banner
    'reels',
    'priceBand',      // ⊕ new: "Under ₹X" themed strip
    'carousel',
    'grid2',
    'zigzag',         // ⊕ new: editorial duo
    'vertical',
    'chips',
    'curated',

    // Burst D — products + 3 editorial / ad blocks
    'mosaic',
    'shopShowcase',   // ⊕ new: single-shop spotlight
    'category',
    'grid3',
    'compare',
    'carousel',
    'adOne',
    'sponsored',
    'collection',
  ];

  // Layout loop. Two invariants:
  //   1. blockCount ALWAYS advances each iteration. Earlier impl only
  //      bumped on a successful emit, which made a step that could
  //      never satisfy its needs (e.g. `recent` after first injection,
  //      or any product step when the pool is below `min`) lock the
  //      cycle forever — the user saw a stuck "loading" spinner.
  //   2. Cap blocks added per call at maxBlocksPerCall so each fetched
  //      page produces a digestible chunk instead of an avalanche.
  const maxBlocksPerCall = 18;
  var addedThisCall = 0;
  var safety = 0;
  while (addedThisCall < maxBlocksPerCall && safety < 200) {
    safety++;
    final step = cycle[state.blockCount % cycle.length];
    var added = false;

    // Banner cooldown gate: if this step is a banner-type but we
    // haven't shown enough product blocks since the last banner,
    // advance the cycle without emitting. Prevents the post-pool-
    // depletion "banner avalanche" the user reported when scrolling
    // deeper into the feed.
    if (bannerSteps.contains(step) &&
        state.productsSinceBanner < bannerCooldown) {
      state.blockCount++;
      continue;
    }

    switch (step) {
      case 'mosaic':
        final items = takeImaged(3, min: 3);
        if (items.length == 3) {
          final (e, t) = intro();
          blocks.add(MosaicBlock(
            eyebrow: e,
            title: t,
            hero: items[0],
            topRight: items[1],
            bottomRight: items[2],
          ));
          added = true;
        }

      case 'carousel':
        final items = take(6, min: 4);
        if (items.length >= 4) {
          final (e, t) = intro();
          blocks.add(CarouselBlock(eyebrow: e, title: t, products: items));
          added = true;
        }

      case 'grid2':
        final items = take(6, min: 4);
        if (items.length >= 4) {
          final (e, t) = intro();
          blocks.add(Grid2ColBlock(eyebrow: e, title: t, products: items));
          added = true;
        }

      case 'curated':
        final slide = nextCurated();
        if (slide != null) {
          blocks.add(CuratedRailBlock(slide));
          added = true;
        }

      case 'reels':
        final items = take(6, min: 4);
        if (items.length >= 4) {
          final (e, t) = intro();
          blocks.add(ReelsTallBlock(eyebrow: e, title: t, products: items));
          added = true;
        }

      case 'category':
        final items = takeImaged(4, min: 4);
        if (items.length == 4) {
          blocks.add(
            CategoryCapsuleBlock(category: category(), products: items),
          );
          added = true;
        }

      case 'vertical':
        final items = take(3, min: 2);
        if (items.length >= 2) {
          final (e, t) = intro();
          blocks.add(VerticalCardsBlock(eyebrow: e, title: t, products: items));
          added = true;
        }

      case 'collection':
        final b = nextCollectionBlock();
        if (b != null) {
          blocks.add(b);
          added = true;
        }

      case 'compare':
        final items = take(2, min: 2);
        if (items.length == 2) {
          blocks.add(ComparisonBlock(
            title: 'This or that?',
            left: items[0],
            right: items[1],
          ));
          added = true;
        }

      case 'grid3':
        final items = take(6, min: 6);
        if (items.length == 6) {
          final (e, t) = intro();
          blocks.add(Grid3CompactBlock(eyebrow: e, title: t, products: items));
          added = true;
        }

      case 'chips':
        final items = take(6, min: 4);
        if (items.length >= 4) {
          blocks.add(QuickAddChipsBlock(
            title: 'Quick adds',
            products: items,
          ));
          added = true;
        }

      case 'sponsored':
        final b = nextSponsored();
        if (b != null) {
          blocks.add(b);
          added = true;
        }

      case 'recent':
        if (!state.recentInjected && recent.isNotEmpty) {
          state.recentInjected = true;
          blocks.add(RecentlyViewedBlock(recent));
          added = true;
        }

      case 'heroOne':
        if (feed.heroSlides.isNotEmpty) {
          final slide = feed.heroSlides[state.heroCursor % feed.heroSlides.length];
          state.heroCursor++;
          blocks.add(HeroSingleBlock(slide));
          added = true;
        }

      case 'adOne':
        if (feed.adStrip.isNotEmpty) {
          final slide = feed.adStrip[state.adCursor % feed.adStrip.length];
          state.adCursor++;
          blocks.add(AdSingleBlock(slide));
          added = true;
        }

      case 'promoOne':
        if (feed.promoBanners.isNotEmpty) {
          final slide = feed.promoBanners[state.promoCursor % feed.promoBanners.length];
          state.promoCursor++;
          blocks.add(PromoSingleBlock(slide));
          added = true;
        }

      case 'flashOne':
        if (feed.flashDeals.isNotEmpty) {
          final deal = feed.flashDeals[state.flashCursor % feed.flashDeals.length];
          state.flashCursor++;
          blocks.add(FlashSingleBlock(deal));
          added = true;
        }

      case 'spotlightOne':
        if (feed.brandSpotlights.isNotEmpty) {
          final s = feed.brandSpotlights[state.spotlightCursor % feed.brandSpotlights.length];
          state.spotlightCursor++;
          blocks.add(SpotlightSingleBlock(s));
          added = true;
        }

      case 'poster':
        final items = takeImaged(1, min: 1);
        if (items.length == 1) {
          final (e, _) = intro();
          blocks.add(PosterProductBlock(eyebrow: e, product: items[0]));
          added = true;
        }

      case 'leaderboard':
        final items = takeImaged(5, min: 3);
        if (items.isNotEmpty) {
          blocks.add(LeaderboardBlock(
            title: 'Top ${items.length} ${category().substring(3)}',
            products: items,
          ));
          added = true;
        }

      case 'brandFocus':
        // Find the most-represented brand in the pool. Falls back to
        // the first imaged product's brand if the histogram is flat.
        final byBrand = <String, List<ProductCard>>{};
        for (final p in pool) {
          if (p.brand == null || p.brand!.isEmpty) continue;
          if (p.imageUrl.isEmpty) continue;
          byBrand.putIfAbsent(p.brand!, () => []).add(p);
        }
        if (byBrand.isNotEmpty) {
          final brand = byBrand.entries
              .reduce((a, b) => a.value.length >= b.value.length ? a : b)
              .key;
          final picks = byBrand[brand]!.take(6).toList();
          if (picks.length >= 3) {
            for (final p in picks) { pool.remove(p); }
            blocks.add(BrandFocusBlock(brand: brand, products: picks));
            added = true;
          }
        }

      case 'priceBand':
        // Bucket the pool by price ceiling and pick whichever band
        // has 6+ products. Tries cheapest first so a fresh page tends
        // to surface the most accessible band.
        const bands = <(int, String)>[
          (999, 'Under ₹999'),
          (1999, 'Under ₹1,999'),
          (4999, 'Under ₹4,999'),
          (9999, 'Under ₹9,999'),
        ];
        var emitted = false;
        for (final (ceiling, label) in bands) {
          final picks = pool
              .where((p) => p.imageUrl.isNotEmpty && _priceValue(p.price) <= ceiling)
              .take(6)
              .toList();
          if (picks.length >= 4) {
            for (final p in picks) { pool.remove(p); }
            blocks.add(PriceBandBlock(ceilingLabel: label, products: picks));
            emitted = true;
            added = true;
            break;
          }
        }
        if (!emitted) {
          // No price band hit the threshold — let the cycle move on.
        }

      case 'zigzag':
        final items = takeImaged(2, min: 2);
        if (items.length == 2) {
          blocks.add(ZigZagDuoBlock(
            title: 'Pair them up',
            hero: items[0],
            pair: items[1],
          ));
          added = true;
        }

      case 'shopShowcase':
        // Group pool by shopSlug and pick the shop with most products.
        final byShop = <String, List<ProductCard>>{};
        for (final p in pool) {
          if (p.shopSlug == null || p.shopSlug!.isEmpty) continue;
          if (p.imageUrl.isEmpty) continue;
          byShop.putIfAbsent(p.shopSlug!, () => []).add(p);
        }
        if (byShop.isNotEmpty) {
          final entry = byShop.entries
              .reduce((a, b) => a.value.length >= b.value.length ? a : b);
          final picks = entry.value.take(4).toList();
          if (picks.length >= 3) {
            for (final p in picks) { pool.remove(p); }
            blocks.add(ShopShowcaseBlock(
              shopName: 'Shop on ShopXY',
              shopSlug: entry.key,
              products: picks,
            ));
            added = true;
          }
        }
    }

    // Always advance the cycle, even when the step couldn't emit —
    // this is what unsticks the dead-step lockup.
    state.blockCount++;
    if (added) {
      addedThisCall++;
      // Track product-vs-banner cadence for the cooldown gate above.
      if (bannerSteps.contains(step)) {
        state.productsSinceBanner = 0;
      } else {
        state.productsSinceBanner++;
      }
    }
    // Bail out early if every product-consuming step in a full cycle
    // has already been visited without consuming. Saves up to 200
    // wasted iterations when pool is empty and only promo steps fire.
    if (pool.isEmpty && addedThisCall == 0 && safety >= cycle.length) {
      break;
    }
  }

  // Drain leftover products into a fallback carousel so we never leave
  // a half-pool sitting between pages. Two-product minimum keeps the
  // tile widget happy without making a "lonely card" row.
  if (pool.length >= 2 && addedThisCall < maxBlocksPerCall) {
    final (e, t) = intro();
    blocks.add(CarouselBlock(eyebrow: e, title: t, products: List.of(pool)));
    pool.clear();
    state.blockCount++;
  }

  return blocks;
}
