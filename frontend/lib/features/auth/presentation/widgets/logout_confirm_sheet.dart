import 'package:flutter/material.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

/// The app's single logout confirmation — a bottom sheet with the logout mark,
/// a title/message, a destructive confirm button and a cancel. Shared so every
/// logout entry point (Profile, Settings, …) uses the *same* affordance rather
/// than a plain dialog. Returns `true` when the user confirms.
Future<bool?> showLogoutConfirmSheet(BuildContext context) {
  final theme = Theme.of(context);
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusDialog),
      ),
      side: BorderSide(color: AppColors.hairline),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          0,
          AppSizes.lg,
          AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppSizes.huge,
              height: AppSizes.huge,
              decoration: ShapeDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: AppShapes.squircle(AppSizes.radiusMd),
              ),
              alignment: Alignment.center,
              child: AppIcon(
                AppIcons.logoutRounded,
                color: AppColors.error,
                size: AppSizes.iconLg,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              l10n.profileLogout,
              style: theme.textTheme.titleMedium?.extraBold,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              l10n.profileLogoutConfirm,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                icon: const AppIcon(
                  AppIcons.logoutRounded,
                  size: AppSizes.iconSm,
                ),
                label: Text(l10n.profileLogout),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                  textStyle: theme.textTheme.labelLarge?.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.muted,
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                ),
                child: Text(l10n.profileCancel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
