import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

/// Snackbar variants. Maps to the four status colors in [AppColors] so
/// the visual treatment matches the message intent.
enum AppSnackbarTone { neutral, success, error, info }

/// Single entry-point for non-blocking feedback. Always prefer this
/// over raw [ScaffoldMessenger] calls — rule from DESIGN.md #8.
///
/// Behaviour:
/// * Auto-dismiss after 3s (5s when [action] is set, so the user has
///   time to act).
/// * Floating shape with hairline border to feel of-a-piece with cards.
/// * Single line by default; multi-line if the message is long.
/// * Action button is text-only on the right (Material guidance).
void showAppSnackbar(
  BuildContext context, {
  required String message,
  AppSnackbarTone tone = AppSnackbarTone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
  Duration? duration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.clearSnackBars();

  final (icon, fg, bg) = _styleFor(tone);
  final hasAction = actionLabel != null && onAction != null;

  messenger.showSnackBar(
    SnackBar(
      duration: duration ??
          (hasAction ? AppDurations.snackbarLong : AppDurations.snackbar),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        0,
        AppSizes.lg,
        AppSizes.lg,
      ),
      padding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      elevation: 0,
      content: Container(
        decoration: ShapeDecoration(
          color: bg,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSizes.iconMd, color: fg),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            if (hasAction) ...[
              const SizedBox(width: AppSizes.md),
              InkWell(
                onTap: () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
                customBorder: AppShapes.squircle(AppSizes.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: AppSizes.xs,
                  ),
                  child: Text(
                    actionLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

(IconData, Color, Color) _styleFor(AppSnackbarTone tone) {
  switch (tone) {
    case AppSnackbarTone.success:
      return (
        AppIcons.checkCircleRounded,
        AppColors.success,
        AppColors.successSoft,
      );
    case AppSnackbarTone.error:
      return (
        AppIcons.errorOutlineRounded,
        AppColors.error,
        AppColors.errorSoft,
      );
    case AppSnackbarTone.info:
      return (
        AppIcons.infoOutlineRounded,
        AppColors.info,
        AppColors.infoSoft,
      );
    case AppSnackbarTone.neutral:
      return (
        AppIcons.notificationsNoneRounded,
        AppColors.black,
        AppColors.white,
      );
  }
}
