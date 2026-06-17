import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/banner_detail/presentation/pages/banner_detail_page.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/search/presentation/pages/search_page.dart';

/// A banner placement is an image + an optional link, and may now also
/// have products pinned to it. This renders the image (cover-fit,
/// optionally rounded) and makes it tappable:
///
///   * [productCount] > 0 → open the banner-detail page (image + the
///     pinned product grid). This takes priority over [linkUrl].
///   * else [linkUrl] set → open search (in-app route hints aren't
///     resolvable yet, so a non-link query falls back to search).
///   * else → decorative, not tappable.
class HomeBannerImage extends StatelessWidget {
  const HomeBannerImage({
    super.key,
    required this.url,
    required this.bannerId,
    this.linkUrl,
    this.productCount = 0,
    this.borderRadius,
  });

  final String url;
  final int bannerId;
  final String? linkUrl;
  final int productCount;
  final BorderRadius? borderRadius;

  bool get _isTappable =>
      productCount > 0 || (linkUrl != null && linkUrl!.isNotEmpty);

  void _onTap(BuildContext context) {
    if (productCount > 0) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BannerDetailPage(bannerId: bannerId)),
      );
      return;
    }
    final link = linkUrl;
    if (link == null || link.isEmpty) return;
    // In-app route hints aren't resolvable yet; fall back to search.
    final query = link.startsWith('/') ? null : link;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SearchPage(initialQuery: query)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = SizedBox.expand(
      child: NetworkImageBox(
        url: url,
        fit: BoxFit.cover,
        borderRadius: borderRadius,
      ),
    );
    if (!_isTappable) return image;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTap(context),
      child: image,
    );
  }
}
