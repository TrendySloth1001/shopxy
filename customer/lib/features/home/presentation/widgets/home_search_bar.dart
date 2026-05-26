import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/search/presentation/pages/search_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({super.key});

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar> {
  int _hintIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(
        () => _hintIndex = (_hintIndex + 1) % HomeStaticData.searchHints.length,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brand,
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchPage()),
              ),
              child: Container(
              height: 46,
              decoration: ShapeDecoration(
                color: AppColors.white,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    color: AppColors.muted,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.5),
                          end: Offset.zero,
                        ).animate(anim),
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Text(
                        HomeStaticData.searchHints[_hintIndex],
                        key: ValueKey(_hintIndex),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Container(
                    width: 1,
                    height: 18,
                    color: AppColors.hairline,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  const Icon(
                    Icons.mic_none_rounded,
                    color: AppColors.brand,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  const Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.brand,
                    size: AppSizes.iconMd,
                  ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
