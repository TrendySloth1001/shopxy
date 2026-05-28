import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/features/search/presentation/pages/search_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class HomeSearchBar extends StatefulWidget {
  const HomeSearchBar({super.key, this.shrink = 0.0});

  /// 0.0 = fully visible, 1.0 = collapsed to zero height. Driven by
  /// the home page's scroll offset so the bar shrinks into the brand
  /// row's compact search icon as the user scrolls.
  final double shrink;

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
    final t = Curves.easeOut.transform(widget.shrink.clamp(0.0, 1.0));
    final visible = (1 - t).clamp(0.0, 1.0);
    return ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: visible,
        child: Opacity(
          opacity: visible,
          child: _buildPill(context),
        ),
      ),
    );
  }

  Widget _buildPill(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SearchPage()),
        ),
        child: Container(
          height: 56,
          decoration: ShapeDecoration(
            color: AppColors.white,
            shape: AppShapes.squircle(
              AppSizes.radiusLg,
              side: const BorderSide(color: AppColors.hairline, width: 0.8),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sm,
            vertical: AppSizes.xs + 2,
          ),
          child: Row(
            children: [
              // Filled brand affordance — anchors the bar and reads as
              // the primary entry point (vs. mic/camera as secondaries).
              Container(
                width: 36,
                height: 36,
                decoration: ShapeDecoration(
                  color: AppColors.brand,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.search_rounded,
                  color: AppColors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSizes.sm + 2),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SEARCH SHOPXY',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
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
                          color: AppColors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              Container(
                width: 1,
                height: 24,
                color: AppColors.hairline,
              ),
              const SizedBox(width: AppSizes.xs),
              const _SearchAction(
                icon: Icons.mic_none_rounded,
                filled: false,
              ),
              const SizedBox(width: 2),
              const _SearchAction(
                icon: Icons.qr_code_scanner_rounded,
                filled: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchAction extends StatelessWidget {
  const _SearchAction({required this.icon, required this.filled});
  final IconData icon;

  /// Filled = brand-soft fill (primary secondary action — scan).
  /// Outlined = transparent (tertiary action — voice).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: filled ? AppColors.brandSoft : Colors.transparent,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.brand, size: 18),
    );
  }
}
