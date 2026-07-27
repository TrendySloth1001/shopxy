import 'package:flutter/material.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/products/data/models/hsn_dto.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// GST rate — a **readout**, not an input.
///
/// This is the point of the whole HSN feature. Two free-text boxes that had to
/// agree (a code and a rate, with nothing connecting them) is what let two
/// shops bill the identical shirt at different rates. Here the merchant
/// classifies, and the rate is a consequence they can read and check.
///
/// The manual path still exists, because nil exceptions and advance rulings are
/// real — but it's a deliberate act, it's visibly flagged when it disagrees
/// with the code, and the server records it as MANUAL so a divergence becomes a
/// report rather than a discovery.
class GstRateField extends StatelessWidget {
  const GstRateField({
    super.key,
    required this.controller,
    required this.manual,
    required this.onManualChanged,
    required this.resolution,
    required this.unknownCode,
  });

  final TextEditingController controller;

  /// True when the merchant has taken the rate off the code.
  final bool manual;
  final ValueChanged<bool> onManualChanged;

  /// What the code resolved to, or null when no code is set / none matched.
  final HsnResolution? resolution;

  /// A code was entered but the master carries no rate for it.
  final bool unknownCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rate = resolution;

    // A manual rate that happens to equal the code's rate isn't a divergence
    // worth shouting about — only flag a real disagreement.
    final typed = double.tryParse(controller.text.trim());
    final diverges =
        manual && rate != null && typed != null && (typed - rate.gstRate).abs() > 0.005;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (manual)
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: l10n.productsGst,
              suffixText: '%',
            ),
          )
        else
          _Readout(rate: rate, unknownCode: unknownCode),

        // Where the number came from — never an unexplained figure.
        if (!manual && rate != null) ...[
          const SizedBox(height: AppSizes.xs),
          _Note(
            icon: AppIcons.infoOutline,
            color: AppColors.muted,
            text: [
              rate.exact
                  ? l10n.productsHsnRateFrom(rate.code)
                  : l10n.productsHsnRateFromHeading(rate.code),
              if (rate.rule?.testedPrice != null)
                l10n.productsGstRuleApplied(
                  formatHsnRate(rate.rule!.testedPrice!),
                  formatHsnRate(rate.rule!.threshold),
                ),
              if (rate.rateNote != null && rate.rateNote!.isNotEmpty) rate.rateNote!,
            ].join(' '),
          ),
        ],

        if (!manual && unknownCode) ...[
          const SizedBox(height: AppSizes.xs),
          _Note(
            icon: AppIcons.warningAmberRounded,
            color: AppColors.error,
            text: l10n.productsHsnRateUnknown,
          ),
        ],

        if (diverges) ...[
          const SizedBox(height: AppSizes.xs),
          _Note(
            icon: AppIcons.warningAmberRounded,
            color: AppColors.warning,
            text: l10n.productsGstManualDiverges(
              rate.code,
              formatHsnRate(rate.gstRate),
            ),
          ),
        ],

        const SizedBox(height: AppSizes.xs),
        TextButton.icon(
          onPressed: () {
            final next = !manual;
            onManualChanged(next);
            // Leaving manual mode hands the rate back to the code, so the field
            // can't keep showing a stale hand-typed number.
            if (!next && rate != null) controller.text = formatHsnRate(rate.gstRate);
          },
          icon: AppIcon(AppIcons.editOutlined, size: AppSizes.iconSm),
          label: Text(
            manual ? l10n.productsGstUseHsnRate : l10n.productsGstSetManually,
            style: theme.textTheme.bodySmall,
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}

/// The derived rate, styled to read as output rather than an empty field
/// waiting to be filled.
class _Readout extends StatelessWidget {
  const _Readout({required this.rate, required this.unknownCode});
  final HsnResolution? rate;
  final bool unknownCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final badge = switch (rate?.source) {
      'HSN_RULE' => (l10n.productsGstFromRule, AppColors.brand, AppColors.brandSoft),
      'OVERRIDE' => (l10n.productsGstFromOverride, AppColors.warning, AppColors.warningSoft),
      _ => null,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.md,
      ),
      decoration: ShapeDecoration(
        color: AppColors.field,
        shape: AppShapes.squircle(
          AppSizes.radiusInput,
          side: BorderSide(color: AppColors.hairline, width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            l10n.productsGst,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(width: AppSizes.md),
          Text(
            rate != null
                ? '${formatHsnRate(rate!.gstRate)}%'
                : unknownCode
                    ? '—'
                    : l10n.productsGstAwaitingCode,
            style: theme.textTheme.titleMedium,
          ),
          if (badge != null) ...[
            const SizedBox(width: AppSizes.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.xxs,
              ),
              decoration: ShapeDecoration(
                color: badge.$3,
                shape: AppShapes.squircle(AppSizes.radiusFull),
              ),
              child: Text(
                badge.$1,
                style: theme.textTheme.bodySmall?.copyWith(color: badge.$2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});
  final AppIconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSizes.xxs),
          child: AppIcon(icon, size: AppSizes.iconSm, color: color),
        ),
        const SizedBox(width: AppSizes.xs),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
