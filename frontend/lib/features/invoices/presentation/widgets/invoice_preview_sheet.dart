import 'package:flutter/material.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';

/// One line as it will appear on the issued document.
class InvoicePreviewLine {
  const InvoicePreviewLine({
    required this.name,
    required this.quantityLabel,
    required this.amount,
  });

  final String name;
  final String quantityLabel;
  final double amount;
}

/// A totals row. [emphasis] marks the grand total.
class InvoicePreviewTotal {
  const InvoicePreviewTotal(this.label, this.value, {this.emphasis = false});
  final String label;
  final String value;
  final bool emphasis;
}

/// Everything the preview shows. Assembled by the form rather than fetched, so
/// this is a faithful picture of what is about to be sent — not a re-read that
/// could differ from the unsaved state on screen.
class InvoicePreviewData {
  const InvoicePreviewData({
    required this.documentTypeLabel,
    required this.counterpartyLabel,
    required this.counterpartyName,
    required this.counterpartyAddress,
    required this.placeOfSupply,
    required this.supplyTypeLabel,
    required this.lines,
    required this.totals,
  });

  final String documentTypeLabel;
  final String counterpartyLabel;
  final String counterpartyName;

  /// Null when nothing is on file — rendered as an explicit "no address"
  /// rather than a blank, since that absence is exactly what the merchant is
  /// being asked to check.
  final String? counterpartyAddress;
  final String? placeOfSupply;
  final String supplyTypeLabel;
  final List<InvoicePreviewLine> lines;
  final List<InvoicePreviewTotal> totals;
}

/// Last look before an invoice is issued.
///
/// Confirming is the irreversible step — it issues the document, posts the
/// stock movement and burns an invoice number — so it gets a deliberate
/// review. Saving a draft does not, and deliberately stays one tap.
///
/// Returns true when the merchant confirmed.
Future<bool> showInvoicePreviewSheet(
  BuildContext context,
  InvoicePreviewData data,
) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _InvoicePreviewSheet(data: data),
  );
  return result == true;
}

class _InvoicePreviewSheet extends StatelessWidget {
  const _InvoicePreviewSheet({required this.data});

  final InvoicePreviewData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          const SizedBox(height: AppSizes.md),
          Container(
            width: AppSizes.handleWidth,
            height: AppSizes.handleHeight,
            decoration: ShapeDecoration(
              color: AppColors.hairline,
              shape: AppShapes.squircle(AppSizes.radiusFull),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.lg,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.invoicesPreviewTitle,
                  style: theme.textTheme.titleMedium?.bold,
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  l10n.invoicesPreviewSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const AppDivider(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.lg),
              children: [
                _Chip(text: data.documentTypeLabel),
                const SizedBox(height: AppSizes.lg),

                _Label(data.counterpartyLabel),
                Text(
                  data.counterpartyName,
                  style: theme.textTheme.bodyLarge?.semibold,
                ),
                const SizedBox(height: 2),
                Text(
                  data.counterpartyAddress ?? l10n.invoicesPreviewNoAddress,
                  style: theme.textTheme.bodySmall?.copyWith(
                    // An absent address is the thing most worth noticing here,
                    // so it reads as a flag rather than as muted filler.
                    color: data.counterpartyAddress == null
                        ? AppColors.warning
                        : AppColors.muted,
                  ),
                ),

                if (data.placeOfSupply != null) ...[
                  const SizedBox(height: AppSizes.lg),
                  _Label(l10n.invoicesPlaceOfSupply),
                  Text(
                    '${data.placeOfSupply}  ·  ${data.supplyTypeLabel}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],

                const SizedBox(height: AppSizes.xl),
                _Label(l10n.invoicesPreviewItemCount(data.lines.length)),
                const SizedBox(height: AppSizes.xs),
                for (var i = 0; i < data.lines.length; i++) ...[
                  if (i > 0) const AppDivider.flush(),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSizes.sm,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.lines[i].name,
                                style: theme.textTheme.bodyMedium,
                              ),
                              Text(
                                data.lines[i].quantityLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Text(
                          '${AppStrings.currencySymbol}${data.lines[i].amount.toStringAsFixed(2)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSizes.xl),
                for (final t in data.totals)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.label,
                            style: t.emphasis
                                ? theme.textTheme.bodyLarge?.bold
                                : theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.muted,
                                  ),
                          ),
                        ),
                        Text(
                          t.value,
                          style: t.emphasis
                              ? theme.textTheme.bodyLarge?.bold
                              : theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const AppDivider(),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Row(
              children: [
                AppButton.ghost(
                  label: l10n.invoicesPreviewBack,
                  onPressed: () => Navigator.pop(context, false),
                ),
                const Spacer(),
                AppButton.primary(
                  label: l10n.invoicesPreviewConfirm,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.muted,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: AppColors.brandSoft,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppColors.brandStrong,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}
