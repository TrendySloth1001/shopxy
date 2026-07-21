import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/features/wishlist/presentation/widgets/wishlist_heart_button.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shadows.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

/// PDP gallery — paginated image carousel with page indicator and an
/// overlaid coupon pill when the product carries an `offers[]` row with
/// `kind == 'COUPON'`. Each frame is wrapped in an [InteractiveViewer]
/// so the customer can pinch-zoom the image in place. The heart button
/// pins to the top-right corner so it doesn't fight with the SliverAppBar
/// action slot when the gallery scrolls under it.
class PdpGallery extends StatefulWidget {
  const PdpGallery({
    super.key,
    required this.productId,
    required this.urls,
    required this.offers,
  });
  final int productId;
  final List<String> urls;
  final List<ProductOffer> offers;

  @override
  State<PdpGallery> createState() => _PdpGalleryState();
}

class _PdpGalleryState extends State<PdpGallery> {
  late final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  ProductOffer? get _couponOffer {
    for (final o in widget.offers) {
      if (o.kind == 'COUPON') return o;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return Container(
        height: 320,
        color: AppColors.heroPanel,
        alignment: Alignment.center,
        child: const AppIcon(
          AppIcons.imageOutlined,
          size: AppSizes.iconHuge,
          color: AppColors.muted,
        ),
      );
    }
    final coupon = _couponOffer;
    return Column(
      children: [
        SizedBox(
          height: 360,
          child: Stack(
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: widget.urls.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => Container(
                  color: AppColors.heroPanel,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    clipBehavior: Clip.hardEdge,
                    child: NetworkImageBox(
                      url: resolveImageUrl(widget.urls[i]),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              if (coupon != null)
                Positioned(
                  left: AppSizes.lg,
                  bottom: AppSizes.md,
                  child: _CouponPill(offer: coupon),
                ),
              Positioned(
                right: AppSizes.sm,
                top: AppSizes.sm,
                child: WishlistHeartButton.flat(productId: widget.productId),
              ),
            ],
          ),
        ),
        if (widget.urls.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < widget.urls.length; i++)
                  Container(
                    width: i == _index ? AppSizes.lg : AppSizes.sm,
                    height: AppSizes.sm,
                    margin: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.black : AppColors.hairline,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CouponPill extends StatelessWidget {
  const _CouponPill({required this.offer});
  final ProductOffer offer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE05A2A),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        boxShadow: AppShadows.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(
            AppIcons.localOfferRounded,
            color: AppColors.white,
            size: AppSizes.iconSm,
          ),
          const SizedBox(width: AppSizes.sm),
          Text(
            offer.code != null && offer.code!.isNotEmpty
                ? '${offer.headline} · ${offer.code}'
                : offer.headline,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
