import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart'
    show reasonCodeLabel;
import 'package:shopxy/features/stock_adjustments/data/datasources/stock_adjustments_remote_data_source.dart';
import 'package:shopxy/features/stock_adjustments/domain/entities/stock_adjustment.dart';
import 'package:shopxy/features/stock_adjustments/presentation/pages/create_stock_adjustment_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

class StockAdjustmentsPage extends StatefulWidget {
  const StockAdjustmentsPage({super.key});

  @override
  State<StockAdjustmentsPage> createState() => _StockAdjustmentsPageState();
}

class _StockAdjustmentsPageState extends State<StockAdjustmentsPage> {
  List<StockAdjustment> _items = const [];
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
      final items = await ds.list(limit: 50);
      if (!mounted) return;
      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Stock adjustments')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'stock_adjustments_fab',
        onPressed: _openCreate,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorView(onRetry: _load);
    }
    if (_items.isEmpty) {
      return EmptyState.line(
        kind: LineArt.emptyClipboard,
        title: 'No adjustments yet',
        subtitle: 'Tap + to record damage, expired stock, or a count correction.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.black,
      backgroundColor: AppColors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const AppDivider(),
        itemBuilder: (_, i) => _AdjustmentTile(adjustment: _items[i]),
      ),
    );
  }
}

class _AdjustmentTile extends StatelessWidget {
  const _AdjustmentTile({required this.adjustment});
  final StockAdjustment adjustment;

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
    final dateStr =
        DateFormat('d MMM yyyy · hh:mm a').format(adjustment.createdAt.toLocal());
    final count = adjustment.itemCount ?? adjustment.items.length;

    return InkWell(
      onTap: null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            const AppIconAvatar.outlined(icon: Icons.tune_rounded),
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
                  const SizedBox(height: 2),
                  Text(
                    '$count ${count == 1 ? 'item' : AppStrings.items} · $dateStr',
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
