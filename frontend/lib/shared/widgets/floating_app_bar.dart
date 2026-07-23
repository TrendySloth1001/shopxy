import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// The app-wide **floating app bar** — the single source of truth for every
/// screen's top bar. Replace `AppBar(...)` with `FloatingAppBar(...)`.
///
/// Instead of a flat, edge-to-edge Material bar, content sits inside rounded
/// "islands" that float over the page:
///
/// ```
///  ┌──────────────┐            ┌───────────┐
///  │ ◫  Shopxy     │           │  🔔   👤  │
///  └──────────────┘            └───────────┘
/// ```
///
/// - **Leading island** — a brand lockup (`FloatingAppBar.brand`) on the
///   primary bottom-nav destinations, or a back button + page title on
///   pushed screens (`FloatingAppBar`).
/// - **Trailing island** — groups the action buttons; hidden when there are
///   none. Any `IconButton` passed as an action is auto-compacted to fit.
///
/// It implements [PreferredSizeWidget], so it is a drop-in for
/// `Scaffold.appBar`. The Scaffold adds the status-bar inset on top of
/// [preferredSize]; the inner [SafeArea] consumes it, leaving exactly the
/// island band visible.
class FloatingAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// Pushed-screen bar: a back button (auto-shown when the route can pop) and
  /// the page [title].
  const FloatingAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions = const [],
    this.bottom,
    this.showBack,
    this.onBack,
  }) : _brand = false;

  /// Root-screen bar: the Shopxy mark + wordmark instead of a back button.
  /// Use on the primary bottom-nav destinations.
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

  /// Overrides [title] when the title needs to be more than plain text.
  final Widget? titleWidget;
  final List<Widget> actions;

  /// Optional band below the islands — e.g. a `TabBar`. Rendered inset to the
  /// island margins so it lines up with them.
  final PreferredSizeWidget? bottom;

  /// Whether to show a back button. Null = auto (shown when the route can pop).
  final bool? showBack;
  final VoidCallback? onBack;
  final bool _brand;

  static const double _islandHeight = 48;
  static const double _vMargin = 8;

  @override
  Size get preferredSize => Size.fromHeight(
    _islandHeight + _vMargin * 2 + (bottom?.preferredSize.height ?? 0),
  );

  /// The top inset a page's scroll content needs so it clears (and can scroll
  /// behind) this bar: the device status bar + the island band. Read from the
  /// raw view, so it's correct whether measured at the page build context or a
  /// nested body context — unlike `MediaQuery.paddingOf(context).top`, which
  /// changes by depth under an `extendBodyBehindAppBar` Scaffold.
  static double contentTopInset(BuildContext context) {
    final statusBar = MediaQueryData.fromView(View.of(context)).padding.top;
    return statusBar + _islandHeight + _vMargin * 2;
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final showBackBtn = showBack ?? (!_brand && canPop);

    // The bar paints no background of its own — the islands float over
    // whatever is behind them. Material `AppBar` used to manage the system
    // status-bar style; since we replace it, restore a transparent status
    // bar with icons that suit the current theme brightness.
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
          // Status-bar safe area: a clean, solid surface scrim covering the
          // OS status bar (clock, battery, signal) so it always has a
          // dedicated, legible backdrop — content never collides with system
          // indicators. Solid over the status-bar height, then a short fade
          // into the transparent bar below (no blur box).
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
                      // Leading island hugs its content on the left and
                      // ellipsises long titles rather than colliding with the
                      // trailing island.
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

/// Shared rounded-pill container for both islands.
class _Island extends StatelessWidget {
  const _Island({required this.child, required this.padding});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates the island so page repaints behind it don't also
    // repaint the bar chrome. The blur sigma is kept moderate (12, not 18): a
    // BackdropFilter re-blurs the live content behind it every scrolled frame
    // and the kernel cost scales with the radius, so this shaves the per-frame
    // GPU cost on the ~60 pages that carry this bar while staying frosted.
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: BackdropFilter(
          // Frosted glass: blur whatever scrolls behind the island so its
          // text/icons stay legible, while the page still shows through.
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

    // The label chip: a frosted pill with the title (and, in brand mode, the
    // logo tile in front of it).
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

    // Brand lockup: logo tile + wordmark in a single chip. The asset is the
    // self-contained CloudNSofts badge (its own orange ground), clipped to a
    // circle here so it echoes the round launcher icon. It reads on any theme.
    if (brand) {
      return titleChip(
        leading: ClipOval(
          child: Image.asset('assets/shopxy-icon.png', width: 30, height: 30),
        ),
      );
    }

    // Pushed pages: the back button gets its OWN round chip, separate from
    // the title chip.
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
    // Force any IconButton passed as an action into a compact, square tap
    // target so several fit neatly inside one pill.
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
