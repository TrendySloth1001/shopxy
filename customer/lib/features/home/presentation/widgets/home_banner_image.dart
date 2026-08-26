import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/banner_detail/presentation/pages/banner_detail_page.dart';
import 'package:shopxy_customer/features/home/domain/banner_link.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/banner_link_router.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';

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
