import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_mapper.dart';

void main() {
  group('HomeFeedMapper.fromFeed', () {
    test('parses each section into the right presentation class', () {
      final feed = HomeFeedMapper.fromFeed(_sampleFeed);

      // Hero banner → HeroSlide with parsed colours + relative image.
      expect(feed.heroSlides, hasLength(1));
      expect(feed.heroSlides.first.title, 'Festive Edit');
      expect(feed.heroSlides.first.imageUrl, '/images/hero-md.webp');
      expect(feed.heroSlides.first.ctaTarget, 'category:fashion');

      // Ad strip banner → AdCard.
      expect(feed.adStrip, hasLength(1));
      expect(feed.adStrip.first.brand, 'MYNTRA');
      expect(feed.adStrip.first.headline, 'EOSS — flat 70%');

      // Brand spotlight → BrandSpotlight.
      expect(feed.brandSpotlights, hasLength(1));
      expect(feed.brandSpotlights.first.brand, 'Acme Stores');
      expect(feed.brandSpotlights.first.dealLabel, 'Up to 50% Off');

      // Flash sale → FlashDealProduct with computed discount.
      expect(feed.flashDeals, hasLength(1));
      final deal = feed.flashDeals.first;
      expect(deal.name, 'Wireless Earbuds');
      expect(deal.imageUrl, '/images/earbuds.webp');
      expect(deal.discountPct, 50); // 999 / 1999 ≈ 50%
      expect(deal.soldPct, closeTo(0.4, 0.001)); // 40 sold of 100

      // Collection tile.
      expect(feed.collectionTiles, hasLength(1));
      expect(feed.collectionTiles.first.label, 'Wedding Edit');

      // Trending product (note: prefers `sellingPrice` over `mrp`).
      expect(feed.trending, hasLength(1));
      expect(feed.trending.first.name, 'Trendy Kurta');
      expect(feed.trending.first.imageUrl, '/images/kurta.webp');

      // Category pucks pulled from `categoryPucks`.
      expect(feed.categoryPucks, hasLength(1));
      expect(feed.categoryPucks.first.label, 'Fashion');
      expect(feed.categoryPucks.first.slug, 'fashion');
    });

    test('parses Prisma Decimal fields that arrive as JSON strings', () {
      // Prisma serialises Decimal columns (mrp / sellingPrice /
      // ratingAvg / flashPrice) as quoted strings. Earlier `as num`
      // casts threw "type 'String' is not a subtype of type 'num'"
      // on every product card. This locks in the fix.
      final feed = HomeFeedMapper.fromFeed({
        'heroBanners': [],
        'adStripBanners': [],
        'promoBanners': [],
        'curatedRailBanners': [],
        'flashDeals': [
          {
            'id': 1,
            'flashPrice': '499.00',
            'stockLimit': 50,
            'soldCount': 10,
            'endAt': '2026-05-25T00:00:00Z',
            'product': {
              'id': 2,
              'name': 'Decimal Product',
              'mrp': '1999.00',
              'sellingPrice': '999.00',
              'images': [
                {'url': '/images/decimal.webp', 'sortOrder': 0},
              ],
            },
          },
        ],
        'brandSpotlights': [],
        'collections': [],
        'trending': [
          {
            'score': '12.345',
            'product': {
              'id': 3,
              'name': 'Stringly Priced',
              'mrp': '500',
              'sellingPrice': '299',
              'ratingAvg': '4.3',
              'ratingCount': '52',
              'images': [
                {'url': '/images/sp.webp', 'sortOrder': 0},
              ],
            },
          },
        ],
        'categoryPucks': [],
      });

      expect(feed.flashDeals.single.discountPct, 75); // 1 - 499/1999 = ~75%
      expect(feed.trending.single.name, 'Stringly Priced');
      expect(feed.trending.single.rating, 4.3);
    });

    test('survives empty arrays + bad colour strings without throwing', () {
      final feed = HomeFeedMapper.fromFeed(const {
        'heroBanners': [],
        'adStripBanners': null, // intentionally broken
        'flashDeals': [
          {'id': 1, 'flashPrice': 0}, // missing product → filtered out
        ],
        'brandSpotlights': [],
        'collections': [],
        'trending': [],
        'categoryPucks': [],
      });
      expect(feed.heroSlides, isEmpty);
      expect(feed.adStrip, isEmpty);
      expect(feed.flashDeals, isEmpty); // missing product → skipped
      expect(feed.trending, isEmpty);
    });
  });

  group('HomeFeedMapper.fromPersonalized', () {
    test('maps recommended + recentlyViewed product blobs', () {
      final result = HomeFeedMapper.fromPersonalized({
        'recommended': [_sampleProduct(id: 42, name: 'For You')],
        'recentlyViewed': [
          {'lastViewedAt': '2026-05-24T13:00:00Z', 'product': _sampleProduct(id: 7, name: 'Seen Earlier')},
        ],
      });
      expect(result.recommended.single.productId, 42);
      expect(result.recommended.single.name, 'For You');
      expect(result.recentlyViewed.single.productId, 7);
    });
  });
}

Map<String, dynamic> _sampleProduct({required int id, required String name}) => {
      'id': id,
      'name': name,
      'mrp': 1999,
      'sellingPrice': 999,
      'ratingAvg': 4.5,
      'ratingCount': 120,
      'images': [
        {'url': '/images/$name.webp', 'sortOrder': 0},
      ],
      'shop': {'id': 1, 'name': 'Test Shop', 'slug': 'test-shop'},
    };

const _sampleFeed = <String, dynamic>{
  'heroBanners': [
    {
      'id': 1,
      'placement': 'HERO',
      'title': 'Festive Edit',
      'subtitle': 'Up to 70% off',
      'brandLabel': 'ETHNIC',
      'imageUrl': '/images/hero-md.webp',
      'bgColor': '#EFE4D6',
      'accentColor': '#B23A2E',
      'ctaTarget': 'category:fashion',
    },
  ],
  'adStripBanners': [
    {
      'id': 2,
      'placement': 'AD_STRIP',
      'title': 'EOSS — flat 70%',
      'subtitle': 'Shop now',
      'brandLabel': 'MYNTRA',
      'imageUrl': '/images/myntra.webp',
      'bgColor': '#EFE4D6',
    },
  ],
  'promoBanners': [],
  'curatedRailBanners': [],
  'flashDeals': [
    {
      'id': 9,
      'flashPrice': 999,
      'stockLimit': 100,
      'soldCount': 40,
      'endAt': '2026-05-25T00:00:00Z',
      'product': {
        'id': 10,
        'name': 'Wireless Earbuds',
        'mrp': 1999,
        'sellingPrice': 1499,
        'images': [
          {'url': '/images/earbuds.webp', 'sortOrder': 0},
        ],
      },
    },
  ],
  'brandSpotlights': [
    {
      'id': 11,
      'dealLabel': 'Up to 50% Off',
      'subtitle': 'Limited time',
      'heroImageUrl': '/images/spotlight.webp',
      'bgColor': '#F4E4D8',
      'shop': {'id': 1, 'name': 'Acme Stores', 'slug': 'acme'},
    },
  ],
  'collections': [
    {
      'id': 21,
      'slug': 'wedding-edit',
      'title': 'Wedding Edit',
      'eyebrow': 'EDITORIAL',
      'subtitle': 'Sherwanis + lehengas',
      'ctaText': 'Explore',
      'coverImageUrl': '/images/wedding.webp',
      'bgColor': '#F4E4D8',
    },
  ],
  'trending': [
    {
      'score': 12.3,
      'product': {
        'id': 31,
        'name': 'Trendy Kurta',
        'mrp': 1500,
        'sellingPrice': 899,
        'ratingAvg': 4.4,
        'ratingCount': 1250,
        'images': [
          {'url': '/images/kurta.webp', 'sortOrder': 0},
        ],
        'shop': {'id': 1, 'name': 'Test Shop', 'slug': 'test-shop'},
      },
    },
  ],
  'categoryPucks': [
    {
      'id': 41,
      'slug': 'fashion',
      'name': 'Fashion',
      'imageUrl': null,
      'iconName': null,
    },
  ],
};
