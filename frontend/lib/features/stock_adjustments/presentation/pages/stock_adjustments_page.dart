import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart'
    show reasonCodeLabel;
import 'package:shopxy/features/stock_adjustments/data/datasources/stock_adjustments_remote_data_source.dart';
import 'package:shopxy/features/stock_adjustments/domain/entities/stock_adjustment.dart';
import 'package:shopxy/features/stock_adjustments/presentation/pages/create_stock_adjustment_page.dart';
import 'package:shopxy/features/stock_adjustments/presentation/pages/stock_adjustment_detail_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/widgets/section_divider.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class StockAdjustmentsPage extends StatefulWidget {
  const StockAdjustmentsPage({super.key});

  @override
  State<StockAdjustmentsPage> createState() => _StockAdjustmentsPageState();
}

class _StockAdjustmentsPageState extends State<StockAdjustmentsPage> {
  List<StockAdjustment> _items = const [];
  bool _isLoading = true;
  String? _error;
  final _scrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _scrollHaptics;

  @override
  void initState() {
    super.initState();
    _scrollHaptics = ScrollBoundaryHaptics(_scrollCtrl);
    _load();
  }

  @override
  void dispose() {
    _scrollHaptics.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ds = context.read<StockAdjustmentsRemoteDataSource>();
      final items = await ds.list(limit: 50);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  void _openDetail(StockAdjustment adjustment) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            StockAdjustmentDetailPage(adjustmentId: adjustment.id),
      ),
    );
  }

  void _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateStockAdjustmentPage()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.stockAdjTitle),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'stock_adjustments_fab',
        onPressed: _openCreate,
        child: const AppIcon(AppIcons.addRounded),
      ),
    );
  }

  Widget _buildBody() {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return const _StockAdjustmentsSkeleton();
    }
    if (_error != null) {
      return SafeArea(
        top: true,
        bottom: false,
        child: AppErrorView(onRetry: _load),
      );
    }
    if (_items.isEmpty) {
      return SafeArea(
        top: true,
        bottom: false,
        child: EmptyState.line(
          kind: LineArt.emptyClipboard,
          title: l10n.stockAdjEmptyTitle,
          subtitle: l10n.stockAdjEmptySubtitle,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.black,
      backgroundColor: AppColors.surface,
      child: ListView.separated(
        controller: _scrollCtrl,
        padding: EdgeInsets.only(
          top: AppSizes.sm + FloatingAppBar.contentTopInset(context),
          bottom: AppSizes.sm,
        ),
        itemCount: _items.length,
        // Suppress the hairline directly above a day header — the pill
        // divider already draws its own rules, and stacking both reads as
        // a double line.
        separatorBuilder: (_, i) =>
            _startsNewDay(i + 1) ? const SizedBox.shrink() : const AppDivider(),
        itemBuilder: (_, i) {
          final date = _items[i].createdAt.toLocal();
          final tile = _AdjustmentTile(
            adjustment: _items[i],
            onTap: () => _openDetail(_items[i]),
          );
          if (!_startsNewDay(i)) return tile;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [SectionDivider.date(date), tile],
          );
        },
      ),
    );
  }

  bool _startsNewDay(int i) {
    if (i == 0) return true;
    return !SectionDivider.isSameDay(
      _items[i].createdAt.toLocal(),
      _items[i - 1].createdAt.toLocal(),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

class _StockAdjustmentsSkeleton extends StatelessWidget {
  const _StockAdjustmentsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: AppSizes.sm + FloatingAppBar.contentTopInset(context),
        bottom: AppSizes.sm,
      ),
      itemCount: 6,
      separatorBuilder: (_, _) => const AppDivider(),
      itemBuilder: (_, _) => const _AdjustmentTileSkeleton(),
    );
  }
}

class _AdjustmentTileSkeleton extends StatelessWidget {
  const _AdjustmentTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          // Icon avatar placeholder
          AppShimmerBox(
            width: AppSizes.avatarXs,
            height: AppSizes.avatarXs,
            radius: AppSizes.avatarXs / 2,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Adjustment number line
                    const Expanded(
                      child: AppShimmerLine(widthFactor: 0.55, height: 14),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    // Status badge placeholder
                    AppShimmerBox(width: 60, height: 20, radius: AppSizes.xs),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                // Subtitle line (count · date)
                const AppShimmerLine(widthFactor: 0.75, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _AdjustmentTile extends StatelessWidget {
  const _AdjustmentTile({required this.adjustment, this.onTap});
  final StockAdjustment adjustment;
  final VoidCallback? onTap;

  AppStatusTone get _tone {
    switch (adjustment.reasonCode) {
      case 'DAMAGE':
      case 'EXPIRED':
      case 'SHRINKAGE':
        return AppStatusTone.error;
      case 'RECOUNT':
        return AppStatusTone.warning;
      case 'OPENING':
        return AppStatusTone.neutral;
      default:
        return AppStatusTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final dateStr = DateFormat(
      'd MMM yyyy · hh:mm a',
    ).format(adjustment.createdAt.toLocal());
    final count = adjustment.itemCount ?? adjustment.items.length;
    final itemsLabel = count == 1
        ? l10n.stockAdjItemSingular
        : l10n.stockAdjItemPlural;

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
            const AppIconAvatar.outlined(icon: AppIcons.tuneRounded),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          adjustment.adjustmentNo,
                          style: theme.textTheme.bodyMedium?.bold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      AppStatusBadge(
                        label: reasonCodeLabel(adjustment.reasonCode),
                        tone: _tone,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    '$count $itemsLabel · $dateStr',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
