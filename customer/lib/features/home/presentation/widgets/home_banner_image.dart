import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/search/presentation/pages/search_page.dart';

/// A banner placement is now JUST an image + an optional link. This
/// renders the image (cover-fit, optionally rounded) and makes it
/// tappable when [linkUrl] is set.
///
/// Link resolution is intentionally light-touch: the backend hands us a
/// free-text [linkUrl]. App-route hints (those starting with '/') don't
/// map cleanly onto the customer app's navigator yet, so for now any
/// tappable banner just opens search — a non-null link keeps the banner
/// interactive without pretending to deep-link somewhere we can't reach.
class HomeBannerImage extends StatelessWidget {
  const HomeBannerImage({
    super.key,
    required this.url,
    this.linkUrl,
    this.borderRadius,
  });

  final String url;
  final String? linkUrl;
  final BorderRadius? borderRadius;

  void _onTap(BuildContext context) {
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
    if (linkUrl == null || linkUrl!.isEmpty) return image;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTap(context),
      child: image,
    );
  }
}
