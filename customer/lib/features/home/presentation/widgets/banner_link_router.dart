import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/features/categories/presentation/pages/category_products_page.dart';
import 'package:shopxy_customer/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy_customer/features/home/domain/banner_link.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/shop_profile_page.dart';
import 'package:shopxy_customer/features/search/presentation/pages/search_page.dart';
import 'package:shopxy_customer/shared/domain/entities/category.dart';

/// Turns a parsed [BannerLink] into a route push.
///
/// Kept out of the widget so the same resolution is reused wherever a banner
/// is tappable, and so the mapping can be asserted in a test.
void openBannerLink(BuildContext context, BannerLink link) {
  final route = bannerLinkRoute(context, link);
  if (route == null) return;
  Navigator.of(context).push(route);
}

/// The destination for [link], or null when it can't be resolved on this
/// device right now. Separate from the push so tests can assert the mapping
/// without driving a Navigator.
Route<void>? bannerLinkRoute(BuildContext context, BannerLink link) {
  switch (link.kind) {
    case BannerLinkKind.product:
      return MaterialPageRoute(
        builder: (_) => ProductDetailPage(productId: link.value),
      );
    case BannerLinkKind.shop:
      return MaterialPageRoute(
        builder: (_) => ShopProfilePage(slug: link.value),
      );
    case BannerLinkKind.search:
      return MaterialPageRoute(
        builder: (_) => SearchPage(initialQuery: link.value),
      );
    case BannerLinkKind.category:
      // CategoryProductsPage wants the whole Category, not a slug, so resolve
      // it from the tree the app already has. A cold start that hasn't loaded
      // categories yet falls back to searching the slug's words — a worse
      // destination than the listing, but a real one.
      final category = findCategoryBySlug(context, link.value);
      if (category != null) {
        return MaterialPageRoute(
          builder: (_) => CategoryProductsPage(category: category),
        );
      }
      return MaterialPageRoute(
        builder: (_) =>
            SearchPage(initialQuery: link.value.replaceAll('-', ' ')),
      );
  }
}

/// Depth-first lookup through the loaded category tree. Returns null when the
/// tree hasn't loaded or holds no such slug.
@visibleForTesting
Category? findCategoryBySlug(BuildContext context, String slug) {
  final nodes = context.read<CategoriesProvider>().tree;
  Category? walk(List<CategoryNode> level) {
    for (final node in level) {
      if (node.category.slug == slug) return node.category;
      final hit = walk(node.children);
      if (hit != null) return hit;
    }
    return null;
  }

  return walk(nodes);
}
