import 'package:flutter/material.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Shown the moment a merchant saves a NEW (or changed) GSTIN — prompts
/// them to declare exactly which date GST starts applying, same nudge
/// pattern as [showPayoutSetupSheet]. "Declare" opens the date picker right
/// there and returns the picked date; "Skip for now" returns null and lets
/// the caller leave the merchant on the form to set it whenever they want —
/// the field stays editable indefinitely either way.
///
/// Returns the declared date, or null if skipped (or the date picker itself
/// was dismissed without a pick — treated the same as skipping).
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

/// Dashboard startup-nudge variant — the merchant may not even have a GSTIN
/// saved yet at this point, so there's nothing to attach a picked date to
/// right here. "Declare" doesn't open an inline picker; it just tells the
/// caller to take the merchant to Invoice Settings and open the picker
/// there. "Skip for now" does nothing else — just dismisses the sheet.
///
/// Returns true if the merchant tapped "Declare the date", false if they
/// skipped (or dismissed the sheet any other way).
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

  /// True when "Declare" should open [showDatePicker] right in this sheet
  /// and pop the picked [DateTime] (the in-context Invoice Settings save
  /// flow). False when "Declare" should just pop `true` and let the caller
  /// navigate elsewhere to actually pick the date (the dashboard nudge).
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
                      // The sheet is still open behind the date-picker
                      // dialog — pop it now with whatever was picked (null
                      // if the picker itself was cancelled, which we treat
                      // the same as skip).
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
