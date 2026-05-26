import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

class HomeTrustStrip extends StatelessWidget {
  const HomeTrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final items = HomeStaticData.trustItems;
    return Container(
      color: AppColors.brandSoft,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(child: _TrustCell(item: items[i])),
            if (i < items.length - 1)
              Container(
                width: 1,
                height: 20,
                color: AppColors.brand.withValues(alpha: 0.2),
              ),
          ],
        ],
      ),
    );
  }
}

class _TrustCell extends StatelessWidget {
  const _TrustCell({required this.item});
  final TrustItem item;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(item.icon, color: AppColors.brandStrong, size: 22),
        const SizedBox(height: 4),
        Text(
          item.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.brandStrong,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
