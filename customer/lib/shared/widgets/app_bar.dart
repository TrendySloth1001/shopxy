import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// The one app bar. Material's [AppBar] with our defaults locked in:
/// canvas background (no surface step), 1px hairline divider at the
/// bottom, ink-black title, no shadow.
///
/// Pages should use this everywhere instead of constructing
/// [AppBar] from scratch — keeps the title weight, height, and
/// chrome consistent across the app.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AppAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions,
    this.centerTitle = false,
    this.backgroundColor,
    this.bottom,
    this.automaticallyImplyLeading = true,
  });

  /// Convenience for nested pages — adds a back button automatically
  /// (Flutter's default behaviour, but kept explicit so callers can
  /// see at a glance which app bars expect a back stack).
  const AppAppBar.subpage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
  })  : leading = null,
        centerTitle = false,
        backgroundColor = null,
        automaticallyImplyLeading = true;

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool centerTitle;
  final Color? backgroundColor;
  final PreferredSizeWidget? bottom;
  /// Forwarded to [AppBar]. Set false for embedded shell pages (e.g.
  /// the Cart tab) where there's no route to pop back to.
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => Size.fromHeight(
        AppSizes.appBarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasSubtitle = subtitle != null && subtitle!.isNotEmpty;

    return AppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      backgroundColor: backgroundColor ?? AppColors.canvas,
      foregroundColor: AppColors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      titleSpacing: leading == null ? AppSizes.lg : 0,
      title: Column(
        crossAxisAlignment:
            centerTitle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.black,
              letterSpacing: -0.4,
            ),
          ),
          if (hasSubtitle) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
      actions: actions,
      bottom: bottom ??
          const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.hairline),
          ),
    );
  }
}
