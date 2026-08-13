import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_mapper.dart';

void main() {
  group('HomeFeedMapper.fromFeed', () {
    test('parses each section into the right presentation class', () {
      final feed = HomeFeedMapper.fromFeed(_sampleFeed);

      // Hero banner → slim HeroSlide (id + imageUrl + optional link +
      // pinned-product count).
      expect(feed.heroSlides, hasLength(1));
      expect(feed.heroSlides.first.id, '1');
      expect(feed.heroSlides.first.imageUrl, '/images/hero-md.webp');
      expect(feed.heroSlides.first.linkUrl, '/category/fashion');
      expect(feed.heroSlides.first.productCount, 5);

      // Ad strip banner → slim HeroSlide. No link → null. No
      // productCount in the payload → defaults to 0.
      expect(feed.adStrip, hasLength(1));
      expect(feed.adStrip.first.id, '2');
      expect(feed.adStrip.first.imageUrl, '/images/myntra.webp');
      expect(feed.adStrip.first.linkUrl, isNull);
      expect(feed.adStrip.first.productCount, 0);

      // Trending product (prefers `sellingPrice` over `mrp`).
      expect(feed.trending, hasLength(1));
      expect(feed.trending.first.name, 'Trendy Kurta');
      expect(feed.trending.first.imageUrl, '/images/kurta.webp');

      // New arrivals → raw product rows.
      expect(feed.newInStock, hasLength(1));
      expect(feed.newInStock.first.name, 'Just Landed');

      // Category pucks pulled from `categoryPucks`.
      expect(feed.categoryPucks, hasLength(1));
      expect(feed.categoryPucks.first.label, 'Fashion');
      expect(feed.categoryPucks.first.slug, 'fashion');
    });

    test('parses Prisma Decimal fields that arrive as JSON strings', () {
      // Prisma serialises Decimal columns (mrp / sellingPrice /
      // ratingAvg) as quoted strings. Earlier `as num` casts threw
      // "type 'String' is not a subtype of type 'num'" on every product
      // card. This locks in the fix.
      final feed = HomeFeedMapper.fromFeed({
        'heroBanners': [],
        'adStripBanners': [],
        'promoBanners': [],
        'curatedRailBanners': [],
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
        'newArrivals': [],
        'categoryPucks': [],
      });

      expect(feed.trending.single.name, 'Stringly Priced');
      expect(feed.trending.single.rating, 4.3);
    });

    test('survives empty / broken arrays without throwing', () {
      final feed = HomeFeedMapper.fromFeed(const {
        'heroBanners': [],
        'adStripBanners': null, // intentionally broken
        'trending': [],
        'newArrivals': null,
        'categoryPucks': [],
      });
      expect(feed.heroSlides, isEmpty);
      expect(feed.adStrip, isEmpty);
      expect(feed.trending, isEmpty);
      expect(feed.newInStock, isEmpty);
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
      expect(result.recommended.single.productId, '42');
      expect(result.recommended.single.name, 'For You');
      expect(result.recentlyViewed.single.productId, '7');
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
      'imageUrl': '/images/hero-md.webp',
      'linkUrl': '/category/fashion',
      'sortOrder': 0,
      'productCount': 5,
    },
  ],
  'adStripBanners': [
    {
      'id': 2,
      'placement': 'AD_STRIP',
      'imageUrl': '/images/myntra.webp',
      'sortOrder': 0,
    },
  ],
  'promoBanners': [],
  'curatedRailBanners': [],
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
  'newArrivals': [
    {
      'id': 51,
      'name': 'Just Landed',
      'mrp': 800,
      'sellingPrice': 600,
      'images': [
        {'url': '/images/new.webp', 'sortOrder': 0},
      ],
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
