import 'package:flutter/material.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

Future<DateTime?> showGstEffectiveDateSheet(BuildContext context) {
  return showModalBottomSheet<DateTime?>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusLg),
      ),
    ),
    builder: (sheetContext) => const _GstEffectiveDateSheet(),
  );
}

Future<bool> showGstEffectiveDateNudgeSheet(BuildContext context) async {
  final declared = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusLg),
      ),
    ),
    builder: (sheetContext) => const _GstEffectiveDateSheet(inline: false),
  );
  return declared ?? false;
}

class _GstEffectiveDateSheet extends StatelessWidget {
  const _GstEffectiveDateSheet({this.inline = true});

  final bool inline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md,
          AppSizes.lg,
          AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: AppSizes.handleHeight,
                decoration: ShapeDecoration(
                  color: AppColors.hairline,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.warningSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: AppIcon(
                AppIcons.calendarTodayOutlined,
                color: AppColors.warning,
                size: AppSizes.iconLg,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              l10n.profileGstEffectiveSheetTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              l10n.profileGstEffectiveSheetBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inverseSurface,
                foregroundColor: AppColors.onInverse,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              ),
              onPressed: !inline
                  ? () => Navigator.of(context).pop(true)
                  : () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: now,
                        firstDate: DateTime(now.year - 10),
                        lastDate: DateTime(now.year + 10),
                      );
                      if (context.mounted) Navigator.of(context).pop(picked);
                    },
              child: Text(l10n.profileGstEffectiveSheetDeclare),
            ),
            const SizedBox(height: AppSizes.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(inline ? null : false),
              child: Text(l10n.profileGstEffectiveSheetSkip),
            ),
          ],
        ),
      ),
    );
  }
}
