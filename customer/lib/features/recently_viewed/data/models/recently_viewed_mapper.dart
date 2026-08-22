import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Maps a row from `GET /me/recently-viewed` into a `ProductCard` so the
/// recently-viewed page can render with the same widgets the home rail
/// uses. Row shape:
///   { id, lastViewedAt, product: { id, name, sellingPrice, mrp,
///       ratingAvg, ratingCount, images: [{ url }], shop: { name, slug } } }
class RecentlyViewedMapper {
  RecentlyViewedMapper._();

  static ProductCard? fromRow(Map<String, dynamic> row) {
    final product = row['product'];
    if (product is! Map<String, dynamic>) return null;

    final mrp = _asDouble(product['mrp']);
    final selling = _asDouble(product['sellingPrice']) ?? mrp ?? 0;
    if (selling <= 0) return null;

    final imgs = product['images'];
    final image = imgs is List && imgs.isNotEmpty
        ? ((imgs.first as Map<String, dynamic>?)?['url'] ?? '') as String
        : '';

    final ratingCount = _asInt(product['ratingCount']) ?? 0;
    final shop = product['shop'] as Map<String, dynamic>?;
    final discountPct = (mrp != null && mrp > selling)
        ? ((1 - selling / mrp) * 100).clamp(0, 99).round()
        : 0;

    return ProductCard(
      productId: product['id']?.toString() ?? '',
      name: (product['name'] ?? '') as String,
      price: _money(selling),
      originalPrice: mrp != null && mrp > selling ? _money(mrp) : '',
      rating: _asDouble(product['ratingAvg']) ?? 0,
      ratingCount: ratingCount > 999
          ? '${(ratingCount / 1000).toStringAsFixed(1)}k'
          : '$ratingCount',
      ratingCountRaw: ratingCount,
      imageUrl: image,
      bgColor: AppColors.heroPanel,
      shopSlug: shop?['slug'] as String?,
      discountPct: discountPct,
    );
  }

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  // MOD-1: shared formatter — see AppFormat.
  static String _money(double v) => AppFormat.rupees(v);
}
