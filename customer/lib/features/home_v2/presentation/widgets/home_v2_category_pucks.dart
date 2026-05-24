import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home_v2/data/home_feed_models.dart';
import 'package:shopxy_customer/features/home_v2/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

class HomeV2CategoryPucks extends StatelessWidget {
  const HomeV2CategoryPucks({super.key, required this.pucks});
  final List<CategoryPuck> pucks;

  @override
  Widget build(BuildContext context) {
    if (pucks.isEmpty) return const SizedBox.shrink();
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: SizedBox(
        height: 92,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          itemCount: pucks.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppSizes.lg),
          itemBuilder: (context, i) => _CategoryPuck(puck: pucks[i]),
        ),
      ),
    );
  }
}

class _CategoryPuck extends StatelessWidget {
  const _CategoryPuck({required this.puck});
  final CategoryPuck puck;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: puck.tint,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(4),
            child: ClipOval(
              child: puck.imageUrl != null && puck.imageUrl!.isNotEmpty
                  ? NetworkImageBox(
                      url: resolveImageUrl(puck.imageUrl!),
                      placeholderColor: puck.tint,
                    )
                  : _Initial(label: puck.label, tint: puck.tint),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            puck.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.label, required this.tint});
  final String label;
  final Color tint;
  @override
  Widget build(BuildContext context) {
    final letter = label.isNotEmpty ? label.substring(0, 1).toUpperCase() : '?';
    return Container(
      color: tint,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: AppColors.black,
          fontWeight: FontWeight.w800,
          fontSize: 22,
        ),
      ),
    );
  }
}
