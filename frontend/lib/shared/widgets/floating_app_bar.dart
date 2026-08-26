import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

class FloatingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FloatingAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    this.bottom,
    this.showBack,
    this.onBack,
  }) : _brand = false;

  const FloatingAppBar.brand({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    this.bottom,
  }) : _brand = true,
       showBack = false,
       onBack = null;

  final String? title;

  final Widget? titleWidget;
  final List<Widget> actions;

  final PreferredSizeWidget? bottom;

  final bool? showBack;
  final VoidCallback? onBack;
  final bool _brand;

  static const double _islandHeight = 48;
  static const double _vMargin = 8;

  @override
  Size get preferredSize => Size.fromHeight(
    _islandHeight + _vMargin * 2 + (bottom?.preferredSize.height ?? 0),
  );

  static double contentTopInset(BuildContext context) {
    final statusBar = MediaQueryData.fromView(View.of(context)).padding.top;
    return statusBar + _islandHeight + _vMargin * 2;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final showBackBtn = showBack ?? (!_brand && canPop);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle =
        (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
            );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top + AppSizes.md,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.canvas,
                    AppColors.canvas,
                    AppColors.canvas.withValues(alpha: 0),
                  ],
                  stops: const [0.0, 0.72, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg,
                    vertical: _vMargin,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _LeadingIsland(
                            brand: _brand,
                            title: title,
                            titleWidget: titleWidget,
                            showBack: showBackBtn,
                            onBack: onBack ?? () => Navigator.maybePop(context),
                          ),
                        ),
                      ),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(width: AppSizes.sm),
                        _TrailingIsland(actions: actions),
                      ],
                    ],
                  ),
                ),
                if (bottom != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.lg,
                    ),
                    child: bottom,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Island extends StatelessWidget {
  const _Island({required this.child, required this.padding});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            height: FloatingAppBar._islandHeight,
            padding: padding,
            decoration: ShapeDecoration(
              color: AppColors.surface.withValues(alpha: 0.55),
              shape: AppShapes.squircle(
                AppSizes.radiusFull,
                side: BorderSide(color: AppColors.hairline),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _LeadingIsland extends StatelessWidget {
  const _LeadingIsland({
    required this.brand,
    required this.title,
    required this.titleWidget,
    required this.showBack,
    required this.onBack,
  });

  final bool brand;
  final String? title;
  final Widget? titleWidget;
  final bool showBack;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget titleChip({Widget? leading}) {
      return _Island(
        padding: EdgeInsets.only(
          left: leading != null ? AppSizes.sm : AppSizes.lg,
          right: AppSizes.lg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading,
              const SizedBox(width: AppSizes.sm),
            ],
            Flexible(
              child:
                  titleWidget ??
                  Text(
                    title ?? AppStrings.appName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: brand ? FontWeight.w800 : FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
            ),
          ],
        ),
      );
    }

    if (brand) {
      return titleChip(
        leading: ClipOval(
          child: Image.asset('assets/shopxy-icon.png', width: 30, height: 30),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showBack) ...[
          _Island(
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: onBack,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: FloatingAppBar._islandHeight,
                height: FloatingAppBar._islandHeight,
                child: AppIcon(
                  AppIcons.arrowBackIosNewRounded,
                  size: AppSizes.iconSm,
                  color: AppColors.black,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
        ],
        Flexible(child: titleChip()),
      ],
    );
  }
}

class _TrailingIsland extends StatelessWidget {
  const _TrailingIsland({required this.actions});
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return _Island(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
      child: IconButtonTheme(
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: actions),
      ),
    );
  }
}
