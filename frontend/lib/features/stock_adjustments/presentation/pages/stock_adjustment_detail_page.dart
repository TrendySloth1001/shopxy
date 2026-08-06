import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart'
    show reasonCodeLabel;
import 'package:shopxy/features/stock/presentation/pages/stock_ledger_page.dart';
import 'package:shopxy/features/stock_adjustments/data/datasources/stock_adjustments_remote_data_source.dart';
import 'package:shopxy/features/stock_adjustments/domain/entities/stock_adjustment.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/widgets/glass_widgets.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Read-only detail for one posted stock adjustment.
///
/// An adjustment is an immutable audit document: posting it already moved
/// every listed product's stock and wrote a permanent row into that
/// product's stock ledger. Nothing here is editable — the page's job is to
/// explain what moved and let the user follow each line through to the
/// product it hit.
class StockAdjustmentDetailPage extends StatefulWidget {
  const StockAdjustmentDetailPage({super.key, required this.adjustmentId});

  final String adjustmentId;

  @override
  State<StockAdjustmentDetailPage> createState() =>
      _StockAdjustmentDetailPageState();
}

class _StockAdjustmentDetailPageState extends State<StockAdjustmentDetailPage> {
  StockAdjustment? _adjustment;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ds = context.read<StockAdjustmentsRemoteDataSource>();
      final adjustment = await ds.getById(widget.adjustmentId);
      if (!mounted) return;
      setState(() {
        _adjustment = adjustment;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  void _openLedger(StockAdjustmentItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockLedgerPage(
          productId: item.productId,
          productName: item.productName,
          productUnit: item.unit,
        ),
      ),
    );
  }

  bool get _isStockIn => _adjustment?.direction == 'IN';

  AppStatusTone get _tone {
    switch (_adjustment?.reasonCode) {
      case 'DAMAGE':
      case 'EXPIRED':
      case 'SHRINKAGE':
        return AppStatusTone.error;
      case 'RECOUNT':
        return AppStatusTone.warning;
      default:
        return AppStatusTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _StockAdjustmentDetailSkeleton();

    final a = _adjustment;
    if (a == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FloatingAppBar(),
        body: SafeArea(
          top: true,
          bottom: false,
          child: AppErrorView(message: _error, onRetry: _load),
        ),
      );
    }

    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = _isStockIn ? AppColors.brandStrong : AppColors.error;
    final df = DateFormat('d MMM yyyy · hh:mm a');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: a.adjustmentNo),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
            GlassHero.line(
              kind: LineArt.ledger,
              height: AppSizes.heroHeightMd,
              illustrationSize: AppSizes.productImageSize,
              accent: accent,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.black,
                backgroundColor: AppColors.surface,
                child: ListView(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  a.adjustmentNo,
                                  style: theme.textTheme.headlineSmall?.bold,
                                ),
                              ),
                              const SizedBox(width: AppSizes.md),
                              AppStatusBadge(
                                label: reasonCodeLabel(a.reasonCode),
                                tone: _tone,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            df.format(a.createdAt.toLocal()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: AppSizes.md),
                          const AppDivider.flush(),
                          const SizedBox(height: AppSizes.md),
                          // The single most important fact on this page:
                          // which way stock moved.
                          Row(
                            children: [
                              AppIcon(
                                _isStockIn
                                    ? AppIcons.arrowDownwardRounded
                                    : AppIcons.arrowUpwardRounded,
                                color: accent,
                                size: AppSizes.iconMd,
                              ),
                              const SizedBox(width: AppSizes.sm),
                              Expanded(
                                child: Text(
                                  _isStockIn
                                      ? l10n.stockAdjAddsStock
                                      : l10n.stockAdjReducesStock,
                                  style: theme.textTheme.bodyMedium?.semibold
                                      .copyWith(color: accent),
                                ),
                              ),
                            ],
                          ),
                          if (a.createdByName != null) ...[
                            const SizedBox(height: AppSizes.sm),
                            _InfoRow(
                              label: l10n.stockAdjDetailRecordedBy,
                              value: a.createdByName!,
                            ),
                          ],
                          if (a.note != null && a.note!.isNotEmpty) ...[
                            const SizedBox(height: AppSizes.xs),
                            _InfoRow(
                              label: l10n.stockAdjNote,
                              value: a.note!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    _EffectExplainer(isStockIn: _isStockIn),
                    const SizedBox(height: AppSizes.md),
                    AppSectionHeader(
                      title: l10n.stockAdjDetailItemsHeader.toUpperCase(),
                      padding: const EdgeInsets.only(bottom: AppSizes.sm),
                    ),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (int i = 0; i < a.items.length; i++) ...[
                            if (i > 0) const AppDivider.flush(),
                            _ItemRow(
                              item: a.items[i],
                              isStockIn: _isStockIn,
                              onTap: () => _openLedger(a.items[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.xs,
                      ),
                      child: Text(
                        l10n.stockAdjDetailTapHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.huge),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Explainer
// ---------------------------------------------------------------------------

/// Spells out the inventory consequence, because "posted an adjustment" is
/// bookkeeping vocabulary — the user wants to know whether their on-hand
/// count already changed (it did) and whether this can be edited (it can't).
class _EffectExplainer extends StatelessWidget {
  const _EffectExplainer({required this.isStockIn});

  final bool isStockIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.tileBg(AppColors.infoSoft),
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.info),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(
            AppIcons.infoRounded,
            color: AppColors.info,
            size: AppSizes.iconMd,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              isStockIn
                  ? l10n.stockAdjDetailExplainerIn
                  : l10n.stockAdjDetailExplainerOut,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Item row
// ---------------------------------------------------------------------------

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.isStockIn,
    required this.onTap,
  });

  final StockAdjustmentItem item;
  final bool isStockIn;
  final VoidCallback onTap;

  static String _formatQty(double q) =>
      q.truncateToDouble() == q ? q.toInt().toString() : q.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = isStockIn ? AppColors.brandStrong : AppColors.error;
    final currency = NumberFormat.currency(
      symbol: AppStrings.currencySymbol,
      decimalDigits: 2,
    );

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.surfaceTint,
      highlightColor: AppColors.surfaceTint,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: theme.textTheme.bodyMedium?.medium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSizes.xxs),
                  Text(
                    item.productSku,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  if (item.unitCost != null)
                    Text(
                      l10n.stockAdjDetailUnitCost(
                        currency.format(item.unitCost),
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  if (item.note != null && item.note!.isNotEmpty)
                    Text(
                      item.note!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Text(
              '${isStockIn ? '+' : '-'}${_formatQty(item.quantity)} ${item.unit}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            AppIcon(
              AppIcons.chevronRightRounded,
              color: AppColors.muted,
              size: AppSizes.iconSm,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall?.medium),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

class _StockAdjustmentDetailSkeleton extends StatelessWidget {
  const _StockAdjustmentDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        titleWidget: AppShimmerLine(widthFactor: 0.4, height: AppSizes.iconSm),
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
            AppShimmerBox(width: double.infinity, height: AppSizes.heroHeightMd),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.lg),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: AppShimmerLine(
                                widthFactor: 0.55,
                                height: 20,
                              ),
                            ),
                            const SizedBox(width: AppSizes.md),
                            AppShimmerBox(
                              width: 72,
                              height: AppSizes.iconSm,
                              radius: AppSizes.radiusFull,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.xs),
                        const AppShimmerLine(widthFactor: 0.45, height: 13),
                        const SizedBox(height: AppSizes.md),
                        const AppDivider.flush(),
                        const SizedBox(height: AppSizes.md),
                        const AppShimmerLine(widthFactor: 0.5, height: 14),
                        const SizedBox(height: AppSizes.sm),
                        const AppShimmerLine(widthFactor: 0.65, height: 13),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  AppShimmerBox(
                    width: double.infinity,
                    height: 64,
                    radius: AppSizes.radiusLg,
                  ),
                  const SizedBox(height: AppSizes.md),
                  const AppShimmerLine(widthFactor: 0.35, height: 13),
                  const SizedBox(height: AppSizes.sm),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: List.generate(
                        3,
                        (_) => Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.lg,
                            vertical: AppSizes.md,
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AppShimmerLine(
                                      widthFactor: 0.65,
                                      height: 14,
                                    ),
                                    SizedBox(height: AppSizes.xs),
                                    AppShimmerLine(
                                      widthFactor: 0.4,
                                      height: 12,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSizes.md),
                              AppShimmerBox(
                                width: 52,
                                height: 14,
                                radius: AppSizes.radiusSm,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.huge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
