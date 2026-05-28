import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Presentation-only view-data for the trust strip. Carries `IconData`,
/// so it lives next to the widget that renders it rather than in
/// features/home/data/models/ (where it polluted a pure-data layer).
class TrustItem {
  const TrustItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

const List<TrustItem> _kTrustItems = [
  TrustItem(icon: Icons.local_shipping_outlined, label: 'Free delivery'),
  TrustItem(icon: Icons.replay_outlined, label: '7-day returns'),
  TrustItem(icon: Icons.verified_outlined, label: '100% authentic'),
  TrustItem(icon: Icons.savings_outlined, label: 'Lowest prices'),
];

class HomeTrustStrip extends StatelessWidget {
  const HomeTrustStrip({super.key});

  @override
  Widget build(BuildContext context) {
    const items = _kTrustItems;
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
