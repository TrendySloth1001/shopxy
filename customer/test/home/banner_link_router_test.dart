import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy_customer/features/categories/presentation/pages/category_products_page.dart';
import 'package:shopxy_customer/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/home/domain/banner_link.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/banner_link_router.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/shop_profile_page.dart';
import 'package:shopxy_customer/features/search/presentation/pages/search_page.dart';
import 'package:shopxy_customer/shared/domain/entities/category.dart';

class _FakeCategories extends CategoriesProvider {
  _FakeCategories(this.seed)
    : super(CategoriesRemoteDataSource(ApiClient(TokenManager())));

  final List<CategoryNode> seed;

  @override
  List<CategoryNode> get tree => seed;
}

const _electronics = Category(
  id: '1',
  slug: 'electronics',
  name: 'Electronics',
);
const _laptops = Category(id: '2', slug: 'laptops', name: 'Laptops');

Future<Widget> _destination(
  WidgetTester tester,
  BannerLink link, {
  List<CategoryNode> categories = const [],
}) async {
  late Widget built;
  await tester.pumpWidget(
    ChangeNotifierProvider<CategoriesProvider>.value(
      value: _FakeCategories(categories),
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            final route = bannerLinkRoute(context, link);
            built = route == null
                ? const SizedBox.shrink()
                : (route as MaterialPageRoute<void>).builder(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return built;
}

void main() {
  testWidgets('a product link opens that product', (tester) async {
    final page = await _destination(
      tester,
      const BannerLink(BannerLinkKind.product, 'sp2rhACi'),
    );
    expect(page, isA<ProductDetailPage>());
    expect((page as ProductDetailPage).productId, 'sp2rhACi');
  });

  testWidgets('a shop link opens that storefront', (tester) async {
    final page = await _destination(
      tester,
      const BannerLink(BannerLinkKind.shop, 'sharma-electronics'),
    );
    expect(page, isA<ShopProfilePage>());
    expect((page as ShopProfilePage).slug, 'sharma-electronics');
  });

  testWidgets('a search link opens results for the phrase', (tester) async {
    final page = await _destination(
      tester,
      const BannerLink(BannerLinkKind.search, 'winter jackets'),
    );
    expect(page, isA<SearchPage>());
    expect((page as SearchPage).initialQuery, 'winter jackets');
  });

  testWidgets('a category link opens the listing, found at any depth', (
    tester,
  ) async {
    final page = await _destination(
      tester,
      const BannerLink(BannerLinkKind.category, 'laptops'),
      categories: const [
        CategoryNode(
          category: _electronics,
          children: [CategoryNode(category: _laptops, children: [])],
        ),
      ],
    );
    expect(page, isA<CategoryProductsPage>());
    expect((page as CategoryProductsPage).category.slug, 'laptops');
  });

  testWidgets('an unloaded category falls back to searching its words', (
    tester,
  ) async {
    final page = await _destination(
      tester,
      const BannerLink(BannerLinkKind.category, 'home-kitchen'),
    );
    expect(page, isA<SearchPage>());
    expect((page as SearchPage).initialQuery, 'home kitchen');
  });
}
