import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/challans/presentation/pages/challan_detail_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/stock/data/datasources/stock_remote_data_source.dart';
import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Full chronological stock ledger for a single product.
///
/// Each row shows: when it happened, what kind of movement (reason code
/// badge), the signed quantity, the running stock after, and the source
/// document. Tapping a row with a source doc opens that invoice/challan.
class StockLedgerPage extends StatefulWidget {
  const StockLedgerPage({
    super.key,
    required this.productId,
    required this.productName,
    this.productUnit,
  });

  final int productId;
  final String productName;
  final String? productUnit;

  @override
  State<StockLedgerPage> createState() => _StockLedgerPageState();
}

class _StockLedgerPageState extends State<StockLedgerPage> {
  List<StockTransaction> _entries = const [];
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
      final ds = context.read<StockRemoteDataSource>();
      final entries = await ds.getTransactions(
        productId: widget.productId,
        limit: 200,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
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

  void _openSource(StockTransaction entry) {
    if (!entry.hasSourceDocument) return;
    final id = entry.sourceId!;
    Widget page;
    switch (entry.sourceType) {
      case 'INVOICE':
        page = InvoiceDetailPage(invoiceId: id);
        break;
      case 'CHALLAN':
        page = ChallanDetailPage(challanId: id);
        break;
      default:
        return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: l10n.stockLedgerTitle,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(AppSizes.xxl + AppSizes.xs),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSizes.lg,
              right: AppSizes.lg,
              bottom: AppSizes.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.productName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return const _StockLedgerSkeleton();
    }
    if (_error != null) {
      return SafeArea(
        top: true,
        bottom: false,
        child: AppErrorView(onRetry: _load),
      );
    }
    if (_entries.isEmpty) {
      return SafeArea(
        top: true,
        bottom: false,
        child: EmptyState.line(
          kind: LineArt.ledger,
          title: AppStrings.noData,
          subtitle: l10n.stockLedgerEmptySubtitle,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.black,
      backgroundColor: AppColors.surface,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md +
              FloatingAppBar.contentTopInset(context) +
              AppSizes.xxl +
              AppSizes.xs,
          AppSizes.lg,
          AppSizes.md,
        ),
        itemCount: _entries.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
        itemBuilder: (_, i) => _LedgerEntryCard(
          entry: _entries[i],
          unit: widget.productUnit,
          onTap: _entries[i].hasSourceDocument
              ? () => _openSource(_entries[i])
              : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton widgets
// ---------------------------------------------------------------------------

class _StockLedgerSkeleton extends StatelessWidget {
  const _StockLedgerSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md +
            FloatingAppBar.contentTopInset(context) +
            AppSizes.xxl +
            AppSizes.xs,
        AppSizes.lg,
        AppSizes.md,
      ),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
      itemBuilder: (_, _) => const _LedgerEntryCardSkeleton(),
    );
  }
}

class _LedgerEntryCardSkeleton extends StatelessWidget {
  const _LedgerEntryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary row: squircle icon + text column + quantity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Squircle icon placeholder
              AppShimmerBox(
                width: AppSizes.avatarSm,
                height: AppSizes.avatarSm,
                radius: AppSizes.radiusSm,
              ),
              const SizedBox(width: AppSizes.md),
              // Reason-code label + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmerLine(widthFactor: 0.45, height: 13),
                    const SizedBox(height: AppSizes.xs),
                    AppShimmerLine(widthFactor: 0.65, height: 11),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
              // Quantity box
              AppShimmerBox(width: 52, height: 18, radius: AppSizes.radiusXs),
            ],
          ),
          // Secondary section (badge + metadata lines)
          const SizedBox(height: AppSizes.md),
          const AppDivider.flush(),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              // Source-type badge placeholder
              AppShimmerBox(width: 60, height: 20, radius: AppSizes.radiusSm),
              const SizedBox(width: AppSizes.sm),
              // Supplier / created-by text line
              Expanded(child: AppShimmerLine(widthFactor: 0.5, height: 11)),
              // Balance text
              AppShimmerLine(widthFactor: 0.18, height: 11),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Entry card
// ---------------------------------------------------------------------------

class _LedgerEntryCard extends StatelessWidget {
  const _LedgerEntryCard({required this.entry, required this.unit, this.onTap});

  final StockTransaction entry;
  final String? unit;
  final VoidCallback? onTap;

  AppStatusTone get _tone {
    if (entry.isReversal) return AppStatusTone.neutral;
    switch (entry.reasonCode) {
      case 'SALE':
      case 'PURCHASE':
      case 'OPENING':
      case 'RETURN_IN':
        return entry.isStockIn ? AppStatusTone.success : AppStatusTone.neutral;
      case 'DAMAGE':
      case 'EXPIRED':
      case 'SHRINKAGE':
        return AppStatusTone.error;
      case 'RECOUNT':
        return AppStatusTone.warning;
      case 'RETURN_OUT':
        return AppStatusTone.warning;
      default:
        return AppStatusTone.neutral;
    }
  }

  String _formatQty(double q) {
    return q.truncateToDouble() == q
        ? q.toInt().toString()
        : q.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final sign = entry.isStockIn ? '+' : '-';
    final qtyStr = '$sign${_formatQty(entry.quantity)}';
    final unitLabel = unit ?? entry.productUnit ?? '';
    final accent = entry.isStockIn ? AppColors.brandStrong : AppColors.error;
    final dateStr = DateFormat(
      'd MMM yyyy · hh:mm a',
    ).format(entry.createdAt.toLocal());

    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppSizes.avatarSm,
                height: AppSizes.avatarSm,
                decoration: ShapeDecoration(
                  color: AppColors.inverseSurface,
                  shape: AppShapes.squircle(
                    AppSizes.radiusSm,
                    side: BorderSide(color: accent, width: 1.2),
                  ),
                ),
                alignment: Alignment.center,
                child: AppIcon(
                  entry.isStockIn
                      ? AppIcons.arrowDownwardRounded
                      : AppIcons.arrowUpwardRounded,
                  color: accent,
                  size: AppSizes.iconMd,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reasonCodeLabel(entry.reasonCode),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (entry.isReversal)
                          AppStatusBadge(
                            label: l10n.stockLedgerReversalBadge,
                            dense: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      dateStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Text(
                '$qtyStr${unitLabel.isEmpty ? '' : ' $unitLabel'}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (entry.hasSourceDocument ||
              entry.displaySupplier != null ||
              entry.note != null ||
              entry.stockAfter != null) ...[
            const SizedBox(height: AppSizes.md),
            const AppDivider.flush(),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: AppSizes.sm,
                    runSpacing: AppSizes.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AppStatusBadge(
                        label: sourceTypeLabel(entry.sourceType),
                        tone: _tone,
                        dense: true,
                      ),
                      if (entry.displaySupplier != null)
                        Text(
                          entry.displaySupplier!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      if (entry.createdByName != null)
                        Text(
                          l10n.stockLedgerByName(entry.createdByName!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (entry.stockAfter != null)
                  Text(
                    l10n.stockLedgerBalance(_formatQty(entry.stockAfter!)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
            if (entry.note != null && entry.note!.isNotEmpty) ...[
              const SizedBox(height: AppSizes.xs),
              Text(
                entry.note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
            if (onTap != null) ...[
              const SizedBox(height: AppSizes.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    l10n.stockLedgerViewSource,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  AppIcon(
                    AppIcons.arrowForwardRounded,
                    color: AppColors.black,
                    size: AppSizes.iconSm,
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
