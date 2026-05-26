import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/addresses/data/datasources/addresses_remote_data_source.dart';
import 'package:shopxy_customer/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:shopxy_customer/features/catalog/data/datasources/cart_remote_data_source.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy_customer/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy_customer/features/home_v2/data/datasources/home_feed_remote_data_source.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_mapper.dart';
import 'package:shopxy_customer/features/home_v2/presentation/pages/home_v2_page.dart';
import 'package:shopxy_customer/features/home_v2/presentation/providers/home_feed_provider.dart';
import 'package:shopxy_customer/features/home_v2/presentation/providers/tracking_service.dart';
import 'package:shopxy_customer/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';

/// In-memory provider that bypasses the network — replays the seed
/// HomeFeed verbatim so widget tests don't have to spin up an HTTP
/// fake.
class _FakeHomeFeedProvider extends HomeFeedProvider {
  _FakeHomeFeedProvider({
    HomeFeedStatus status = HomeFeedStatus.ready,
    HomeFeed seed = HomeFeed.empty,
    String? error,
  })  : _statusOverride = status,
        _seed = seed,
        _errorOverride = error,
        super(HomeFeedRemoteDataSource(ApiClient(TokenManager())));

  final HomeFeedStatus _statusOverride;
  final HomeFeed _seed;
  final String? _errorOverride;

  @override
  HomeFeedStatus get status => _statusOverride;
  @override
  HomeFeed get feed => _seed;
  @override
  String? get error => _errorOverride;
  @override
  bool get isInitial =>
      _seed.heroSlides.isEmpty &&
      _seed.flashDeals.isEmpty &&
      _seed.trending.isEmpty;
  @override
  bool get isLoading => _statusOverride == HomeFeedStatus.loading;
  @override
  Future<void> load({bool force = false}) async {}
  @override
  Future<void> refresh() async {}
  @override
  Future<void> refreshPersonalized() async {}
}

class _NoopTracking implements TrackingService {
  @override
  void recordImpression(int productId, {String source = 'home', String? sessionId}) {}
  @override
  void recordTap(int productId, {String source = 'home', String? sessionId}) {}
  @override
  void recordView(int productId, {String source = 'pdp', String? sessionId}) {}
  @override
  void recordWishlistAdd(int productId, {String source = 'pdp'}) {}
  @override
  void recordAddToCart(int productId, {String source = 'pdp'}) {}
  @override
  Future<void> flush() async {}
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(HomeFeedProvider provider) {
  // The top bar now reads unread-count from NotificationsProvider and
  // line-count from CartProvider via Selector; stub both with empty
  // providers so the widget can pump without a real backend.
  final apiClient = ApiClient(TokenManager());
  return MediaQuery(
    data: const MediaQueryData(size: Size(414, 896)),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<HomeFeedProvider>.value(value: provider),
        Provider<TrackingService>.value(value: _NoopTracking()),
        ChangeNotifierProvider<NotificationsProvider>(
          create: (_) => NotificationsProvider(
            NotificationsRemoteDataSource(apiClient),
            InvitationsRemoteDataSource(apiClient),
          ),
        ),
        ChangeNotifierProvider<CartProvider>(
          create: (_) =>
              CartProvider(OrdersRemoteDataSource(apiClient), CartRemoteDataSource(apiClient)),
        ),
        ChangeNotifierProvider<AddressesProvider>(
          create: (_) => AddressesProvider(AddressesRemoteDataSource(apiClient)),
        ),
        // Empty tree → CategoriesRail collapses to SizedBox.shrink. The
        // real provider would fire a network request on load; here we
        // never call load() so the tree stays empty.
        ChangeNotifierProvider<CategoriesProvider>(
          create: (_) =>
              CategoriesProvider(CategoriesRemoteDataSource(apiClient)),
        ),
      ],
      child: const MaterialApp(home: HomeV2Page()),
    ),
  );
}

void main() {
  testWidgets('shows skeleton on first load', (tester) async {
    await tester.pumpWidget(
      _harness(_FakeHomeFeedProvider(status: HomeFeedStatus.loading)),
    );
    await tester.pump();

    // No real sections render yet; the skeleton placeholder is the
    // only ListView in the body region.
    expect(find.byType(ListView), findsWidgets);
    // Top bar still renders so navigation chrome is consistent.
    expect(find.byType(HomeV2Page), findsOneWidget);
  });

  testWidgets('renders the populated feed when ready', (tester) async {
    final feed = HomeFeedMapper.fromFeed(_sampleFeed);
    await tester.pumpWidget(
      _harness(_FakeHomeFeedProvider(seed: feed)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Hero brand label is rendered (uppercased by the widget).
    expect(find.text('Festive Edit'), findsOneWidget);
    // Flash deal name from the seed lands on a card.
    expect(find.text('Wireless Earbuds'), findsOneWidget);
  });

  testWidgets('shows retry CTA when the initial load errors', (tester) async {
    await tester.pumpWidget(
      _harness(_FakeHomeFeedProvider(
        status: HomeFeedStatus.error,
        error: 'connection refused',
      )),
    );
    await tester.pump();

    expect(find.text("Couldn't load your home feed"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}

const _sampleFeed = <String, dynamic>{
  'heroBanners': [
    {
      'id': 1,
      'title': 'Festive Edit',
      'subtitle': 'Up to 70% off',
      'brandLabel': 'ETHNIC',
      'imageUrl': '/images/hero.webp',
      'bgColor': '#EFE4D6',
      'accentColor': '#B23A2E',
    },
  ],
  'adStripBanners': [],
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
        'images': [
          {'url': '/images/earbuds.webp', 'sortOrder': 0},
        ],
      },
    },
  ],
  'brandSpotlights': [],
  'collections': [],
  'trending': [],
  'categoryPucks': [],
};
