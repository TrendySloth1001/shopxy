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

const _categoryLabels = <String>[
  'In Fashion',
  'In Electronics',
  'In Home & decor',
  'In Beauty',
  'In Grocery',
  'In Mobiles',
  'In Appliances',
  'In Sports & fitness',
];

/// Builds the post-spotlight block list from a [HomeFeed]. Walks a fixed
/// layout cycle and consumes products from a deduplicated global pool;
/// rotates intros + category labels so the feed reads as "endless"
/// without literally infinite scroll. Non-product blocks (curated rails,
/// collection banners, recently-viewed, sponsored) are inserted at
/// sensible cadences so they don't all clump at the top.
List<HomeBlock> composeHomeBlocks(HomeFeed feed) {
  final blocks = <HomeBlock>[];

  // Build a deduplicated product pool from every list the backend gave
  // us. Order favours the personalised + freshest slices first so a
  // logged-in user sees their recommendations near the top of the
  // block feed.
  final seen = <int>{};
  final pool = <ProductCard>[];
  void absorb(Iterable<ProductCard> src) {
    for (final p in src) {
      if (seen.add(p.productId)) pool.add(p);
    }
  }

  absorb(feed.recommended);
  absorb(feed.trending);
  absorb(feed.newInStock);
  absorb(feed.bestValue);
  absorb(feed.offers);

  // Sponsored products are kept aside so they render in a clearly-marked
  // block rather than getting mixed into organic slots.
  final sponsored = feed.sponsoredProducts;
  final curated = feed.curatedRails;
  final collection = feed.collectionTiles;
  final recent = feed.recentlyViewed;

  // Pull a slice of N cards off the pool. Returns an empty list when the
  // pool has fewer than `min` items so blocks degrade gracefully near
  // the tail of the feed instead of rendering half-empty grids.
  List<ProductCard> take(int n, {int min = 0}) {
    if (pool.length < (min == 0 ? n : min)) return const [];
    final out = pool.take(n).toList();
    pool.removeRange(0, out.length);
    return out;
  }

  var introIdx = 0;
  (String, String) intro() {
    final v = _intros[introIdx % _intros.length];
    introIdx++;
    return v;
  }

  var categoryIdx = 0;
  String category() {
    final v = _categoryLabels[categoryIdx % _categoryLabels.length];
    categoryIdx++;
    return v;
  }

  // Side queues consumed at the cadence below. `take(<n>)` pulls from
  // the front each rotation; once empty, the cycle skips that block.
  final curatedQ = [...curated];
  var collectionUsed = false;
  var sponsoredUsed = false;
  var recentUsed = false;

  // The layout cycle. Drives variety: no two carousels back to back,
  // editorial + product + comparison + grid all interleaved. Bumping
  // the length here adds more variation per cycle.
  final cycle = <String>[
    'mosaic',
    'carousel',
    'grid2',
    'curated',
    'reels',
    'category',
    'vertical',
    'collection',
    'compare',
    'grid3',
    'chips',
    'sponsored',
    'carousel',
    'recent',
  ];

  var safety = 0;
  while (pool.isNotEmpty && safety < 200) {
    safety++;
    final step = cycle[(blocks.length) % cycle.length];

    switch (step) {
      case 'mosaic':
        final items = take(3, min: 3);
        if (items.length == 3) {
          final (e, t) = intro();
          blocks.add(MosaicBlock(
            eyebrow: e,
            title: t,
            hero: items[0],
            topRight: items[1],
            bottomRight: items[2],
          ));
        }

      case 'carousel':
        final items = take(8, min: 4);
        if (items.length >= 4) {
          final (e, t) = intro();
          blocks.add(CarouselBlock(eyebrow: e, title: t, products: items));
        }

      case 'grid2':
        final items = take(6, min: 4);
        if (items.length >= 4) {
          final (e, t) = intro();
          blocks.add(Grid2ColBlock(eyebrow: e, title: t, products: items));
        }

      case 'curated':
        if (curatedQ.isNotEmpty) {
          blocks.add(CuratedRailBlock(curatedQ.removeAt(0)));
        }

      case 'reels':
        final items = take(8, min: 4);
        if (items.length >= 4) {
          final (e, t) = intro();
          blocks.add(ReelsTallBlock(eyebrow: e, title: t, products: items));
        }

      case 'category':
        final items = take(4, min: 4);
        if (items.length == 4) {
          blocks.add(
            CategoryCapsuleBlock(category: category(), products: items),
          );
        }

      case 'vertical':
        final items = take(3, min: 2);
        if (items.length >= 2) {
          final (e, t) = intro();
          blocks.add(VerticalCardsBlock(eyebrow: e, title: t, products: items));
        }

      case 'collection':
        if (!collectionUsed && collection.isNotEmpty) {
          collectionUsed = true;
          blocks.add(CollectionBannerBlock(
            title: collection.first.label,
            tiles: collection,
          ));
        }

      case 'compare':
        final items = take(2, min: 2);
        if (items.length == 2) {
          blocks.add(ComparisonBlock(
            title: 'This or that?',
            left: items[0],
            right: items[1],
          ));
        }

      case 'grid3':
        final items = take(6, min: 6);
        if (items.length == 6) {
          final (e, t) = intro();
          blocks.add(Grid3CompactBlock(eyebrow: e, title: t, products: items));
        }

      case 'chips':
        final items = take(8, min: 4);
        if (items.length >= 4) {
          blocks.add(QuickAddChipsBlock(
            title: 'Quick adds',
            products: items,
          ));
        }

      case 'sponsored':
        if (!sponsoredUsed && sponsored.isNotEmpty) {
          sponsoredUsed = true;
          blocks.add(SponsoredCarouselBlock(sponsored));
        }

      case 'recent':
        if (!recentUsed && recent.isNotEmpty) {
          recentUsed = true;
          blocks.add(RecentlyViewedBlock(recent));
        }
    }
  }

  // Tail-flush: surface any non-product blocks the cycle didn't reach
  // (e.g. user scrolled a short feed and the recent rail never fired)
  // so they don't get dropped entirely.
  if (!sponsoredUsed && sponsored.isNotEmpty) {
    blocks.add(SponsoredCarouselBlock(sponsored));
  }
  if (!collectionUsed && collection.isNotEmpty) {
    blocks.add(CollectionBannerBlock(
      title: collection.first.label,
      tiles: collection,
    ));
  }
  while (curatedQ.isNotEmpty) {
    blocks.add(CuratedRailBlock(curatedQ.removeAt(0)));
  }
  if (!recentUsed && recent.isNotEmpty) {
    blocks.add(RecentlyViewedBlock(recent));
  }

  return blocks;
}
