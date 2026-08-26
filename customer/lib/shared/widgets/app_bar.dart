import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

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

  const AppAppBar.subpage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.bottom,
  }) : leading = null,
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
        crossAxisAlignment: centerTitle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
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
            const SizedBox(height: AppSizes.xxs),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
      actions: actions,
      bottom:
          bottom ??
          const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.hairline),
          ),
    );
  }
}
