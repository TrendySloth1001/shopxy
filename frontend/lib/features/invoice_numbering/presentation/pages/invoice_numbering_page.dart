import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/invoice_numbering/domain/entities/numbering_scheme.dart';
import 'package:shopxy/features/invoice_numbering/presentation/providers/invoice_numbering_provider.dart';
import 'package:shopxy/features/invoice_numbering/presentation/widgets/numbering_scheme_editor_sheet.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Series label + which group each belongs to, resolved at build time so
/// the labels stay localized. Grouping mirrors the merchant-web page.
List<({String titleKey, List<NumberingSeries> series})> _groups(
  AppLocalizations l10n,
) => [
  (
    titleKey: l10n.numberingGroupInvoices,
    series: const [
      NumberingSeries.saleInvoice,
      NumberingSeries.purchaseInvoice,
      NumberingSeries.estimate,
      NumberingSeries.creditNote,
      NumberingSeries.debitNote,
    ],
  ),
  (titleKey: l10n.numberingGroupChallan, series: const [NumberingSeries.challan]),
  (titleKey: l10n.numberingGroupQuotation, series: const [NumberingSeries.quotation]),
];

String _seriesLabel(AppLocalizations l10n, NumberingSeries series) => switch (series) {
  NumberingSeries.saleInvoice => l10n.numberingSeriesSaleInvoice,
  NumberingSeries.purchaseInvoice => l10n.numberingSeriesPurchaseInvoice,
  NumberingSeries.estimate => l10n.numberingSeriesEstimate,
  NumberingSeries.creditNote => l10n.numberingSeriesCreditNote,
  NumberingSeries.debitNote => l10n.numberingSeriesDebitNote,
  NumberingSeries.challan => l10n.numberingSeriesChallan,
  NumberingSeries.quotation => l10n.numberingSeriesQuotation,
};

class InvoiceNumberingPage extends StatefulWidget {
  const InvoiceNumberingPage({super.key});

  @override
  State<InvoiceNumberingPage> createState() => _InvoiceNumberingPageState();
}

class _InvoiceNumberingPageState extends State<InvoiceNumberingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InvoiceNumberingProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<InvoiceNumberingProvider>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.numberingTitle),
      body: provider.isLoading && !provider.hasLoadedOnce
          ? const Center(child: CircularProgressIndicator())
          : provider.error != null && provider.schemes.isEmpty
          ? AppErrorView(onRetry: () => provider.load())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSizes.lg,
                FloatingAppBar.contentTopInset(context) + AppSizes.md,
                AppSizes.lg,
                AppSizes.huge,
              ),
              children: [
                Text(
                  l10n.numberingSubtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.xl),
                for (final group in _groups(l10n)) ...[
                  _GroupSection(
                    title: group.titleKey,
                    series: group.series,
                    schemesBySeries: {
                      for (final s in provider.schemes) s.series: s,
                    },
                    l10n: l10n,
                  ),
                  const SizedBox(height: AppSizes.xl),
                ],
              ],
            ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.title,
    required this.series,
    required this.schemesBySeries,
    required this.l10n,
  });

  final String title;
  final List<NumberingSeries> series;
  final Map<NumberingSeries, NumberingScheme> schemesBySeries;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < series.length; i++) {
      final scheme = schemesBySeries[series[i]];
      if (scheme == null) continue;
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 1));
      }
      rows.add(_SeriesRow(series: series[i], scheme: scheme, l10n: l10n));
    }
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, 0, AppSizes.sm),
          child: Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: AppColors.surface,
            shape: AppShapes.squircle(
              AppSizes.radiusMd,
              side: BorderSide(color: AppColors.hairline),
            ),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }
}

class _SeriesRow extends StatelessWidget {
  const _SeriesRow({required this.series, required this.scheme, required this.l10n});

  final NumberingSeries series;
  final NumberingScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => showNumberingSchemeEditorSheet(
        context,
        _seriesLabel(l10n, series),
        scheme,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _seriesLabel(l10n, series),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xxs),
                  Text(
                    scheme.nextPreview,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            if (scheme.isCustom)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: 3,
                ),
                decoration: ShapeDecoration(
                  color: AppColors.brandSoft,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
                child: Text(
                  l10n.numberingCustomized,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.brandStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Text(
                l10n.numberingDefault,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.subtle,
                ),
              ),
            const SizedBox(width: AppSizes.sm),
            AppIcon(
              AppIcons.chevronRightRounded,
              size: 20,
              color: AppColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}
