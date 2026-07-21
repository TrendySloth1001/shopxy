import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class HomeFooterStrip extends StatelessWidget {
  const HomeFooterStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.heroPanel,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Column(
        children: [
          const Text(
            'Why millions choose ShopXY',
            style: TextStyle(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: const [
              Expanded(
                child: _FooterCell(
                  icon: AppIcons.verifiedUserOutlined,
                  title: '100% Authentic',
                  subtitle: 'Sourced direct from brands',
                ),
              ),
              Expanded(
                child: _FooterCell(
                  icon: AppIcons.lockOutline,
                  title: 'Secure payments',
                  subtitle: 'UPI · Cards · COD',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: const [
              Expanded(
                child: _FooterCell(
                  icon: AppIcons.supportAgentOutlined,
                  title: '24×7 support',
                  subtitle: 'We\'re here when you need',
                ),
              ),
              Expanded(
                child: _FooterCell(
                  icon: AppIcons.assignmentReturnOutlined,
                  title: 'Easy returns',
                  subtitle: '7-day no-questions',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterCell extends StatelessWidget {
  const _FooterCell({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final AppIconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xs),
      child: Column(
        children: [
          AppIcon(icon, color: AppColors.brand, size: 24),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
