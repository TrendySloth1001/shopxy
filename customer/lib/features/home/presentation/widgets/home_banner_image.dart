import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/banner_detail/presentation/pages/banner_detail_page.dart';
import 'package:shopxy_customer/features/home/domain/banner_link.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/banner_link_router.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';

/// A banner placement is an image + an optional link, and may also have
/// products pinned to it. This renders the image (cover-fit, optionally
/// rounded) and makes it tappable:
///
///   * [productCount] > 0 → open the banner-detail page (image + the
///     pinned product grid). This takes priority over [linkUrl].
///   * else a parseable [linkUrl] → its real destination (see [BannerLink]).
///   * else → decorative, not tappable.
///
/// An unparseable link is decorative too. It used to be passed to the search
/// box verbatim, so a banner linking to `https://x` searched for the literal
/// text "https://x" and one linking to `/shop/acme` opened an empty search.
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
  final String bannerId;
  final String? linkUrl;
  final int productCount;
  final BorderRadius? borderRadius;

  bool get _isTappable => productCount > 0 || BannerLink.parse(linkUrl) != null;

  void _onTap(BuildContext context) {
    if (productCount > 0) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BannerDetailPage(bannerId: bannerId)),
      );
      return;
    }
    final link = BannerLink.parse(linkUrl);
    if (link == null) return;
    openBannerLink(context, link);
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
