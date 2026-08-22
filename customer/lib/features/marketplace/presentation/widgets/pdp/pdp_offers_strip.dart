import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

/// Merchant-entered coupon / EMI / exchange offers. Legacy `kind == 'BANK'`
/// rows are filtered out — bank offers were removed from the platform.
class PdpOffersStrip extends StatelessWidget {
  const PdpOffersStrip({super.key, required this.offers});

  final List<ProductOffer> offers;

  @override
  Widget build(BuildContext context) {
    final productOffers = offers
        .where((o) => o.kind != 'BANK')
        .toList(growable: false);
    if (productOffers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSizes.sm, 0, AppSizes.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Text(
              'Offers',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.black,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              itemCount: productOffers.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSizes.sm),
              itemBuilder: (_, i) => _OfferCard(offer: productOffers[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});
  final ProductOffer offer;

  ({Color bg, Color fg, AppIconData icon, String label}) _kindMeta() {
    switch (offer.kind) {
      case 'EMI':
        return (
          bg: AppColors.brandSoft,
          fg: AppColors.brandStrong,
          icon: AppIcons.calendarMonthRounded,
          label: 'NO-COST EMI',
        );
      case 'EXCHANGE':
        return (
          bg: AppColors.accentRoseSoft,
          fg: AppColors.accentRose,
          icon: AppIcons.swapHorizRounded,
          label: 'EXCHANGE',
        );
      case 'COUPON':
      default:
        return (
          bg: AppColors.warningSoft,
          fg: AppColors.warning,
          icon: AppIcons.localOfferOutlined,
          label: 'COUPON',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = _kindMeta();
    return Container(
      width: 260,
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: ShapeDecoration(
        color: meta.bg,
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: ShapeDecoration(
              color: AppColors.white,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: AppIcon(meta.icon, size: AppSizes.iconMd, color: meta.fg),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meta.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: meta.fg,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  offer.headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                if (offer.detail != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.xs),
                    child: Text(
                      offer.detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
