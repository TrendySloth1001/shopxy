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
import 'package:shopxy_customer/features/home/data/datasources/home_feed_remote_data_source.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_mapper.dart';
import 'package:shopxy_customer/features/home/presentation/pages/home_page.dart';
import 'package:shopxy_customer/features/home/presentation/providers/home_feed_provider.dart';
import 'package:shopxy_customer/features/home/presentation/services/tracking_service.dart';
import 'package:shopxy_customer/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/features/shops/data/datasources/me_remote_data_source.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';

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
      _seed.newInStock.isEmpty &&
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
  void recordImpression(String productId, {String source = 'home', String? sessionId}) {}
  @override
  void recordTap(String productId, {String source = 'home', String? sessionId}) {}
  @override
  void recordView(String productId, {String source = 'pdp', String? sessionId}) {}
  @override
  void recordWishlistAdd(String productId, {String source = 'pdp'}) {}
  @override
  void recordAddToCart(String productId, {String source = 'pdp'}) {}
  @override
  Future<void> flush() async {}
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(HomeFeedProvider provider) {
  final apiClient = ApiClient(TokenManager());
  return MediaQuery(
    data: const MediaQueryData(size: Size(414, 896)),
    child: MultiProvider(
      providers: [
        ChangeNotifierProvider<HomeFeedProvider>.value(value: provider),
        Provider<TrackingService>.value(value: _NoopTracking()),
        ChangeNotifierProvider<OrdersProvider>(
          create: (_) => OrdersProvider(OrdersRemoteDataSource(apiClient)),
        ),
        ChangeNotifierProvider<ShopsProvider>(
          create: (_) => ShopsProvider(MeRemoteDataSource(apiClient)),
        ),
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
        ChangeNotifierProvider<CategoriesProvider>(
          create: (_) =>
              CategoriesProvider(CategoriesRemoteDataSource(apiClient)),
        ),
      ],
      child: const MaterialApp(home: HomePage()),
    ),
  );
}

void main() {
  testWidgets('shows skeleton on first load', (tester) async {
    await tester.pumpWidget(
      _harness(_FakeHomeFeedProvider(status: HomeFeedStatus.loading)),
    );
    await tester.pump();

    expect(find.byType(ListView), findsWidgets);
    expect(find.byType(HomePage), findsOneWidget);
  });

  testWidgets('renders the populated feed when ready', (tester) async {
    final feed = HomeFeedMapper.fromFeed(_sampleFeed);
    await tester.pumpWidget(
      _harness(_FakeHomeFeedProvider(seed: feed)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text("Couldn't load your home feed"), findsNothing);
    expect(find.byType(Scrollable), findsWidgets);
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
      'placement': 'HERO',
      'imageUrl': '/images/hero.webp',
      'linkUrl': '/category/fashion',
      'sortOrder': 0,
    },
  ],
  'adStripBanners': [],
  'promoBanners': [],
  'curatedRailBanners': [],
  'trending': [
    {
      'score': 5,
      'product': {
        'id': 10,
        'name': 'Wireless Earbuds',
        'mrp': 1999,
        'sellingPrice': 999,
        'images': [
          {'url': '/images/earbuds.webp', 'sortOrder': 0},
        ],
      },
    },
  ],
  'newArrivals': [],
  'categoryPucks': [],
};
