import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/returns/data/datasources/merchant_returns_remote_data_source.dart';
import 'package:shopxy/features/returns/domain/merchant_return.dart';
import 'package:shopxy/features/returns/presentation/pages/merchant_return_detail_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

/// Merchant returns inbox. Tabs filter by status; each row is tappable
/// → `MerchantReturnDetailPage`. The inbox doesn't paginate beyond the
/// first page yet — return volume is order-of-magnitude lower than
/// orders, so we keep it simple and revisit if a merchant ever fills
/// the first page.
class MerchantReturnsPage extends StatefulWidget {
  const MerchantReturnsPage({super.key});

  @override
  State<MerchantReturnsPage> createState() => _MerchantReturnsPageState();
}

class _MerchantReturnsPageState extends State<MerchantReturnsPage> {
  static const _tabs = [
    (label: 'Open', status: 'REQUESTED'),
    (label: 'Approved', status: 'APPROVED'),
    (label: 'Received', status: 'RECEIVED'),
    (label: 'Refunded', status: 'REFUNDED'),
    (label: 'All', status: null),
  ];
  int _index = 0;
  List<MerchantReturn> _rows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = context.read<MerchantReturnsRemoteDataSource>();
      final res = await ds.list(status: _tabs[_index].status);
      if (mounted) {
        setState(() {
        _rows = res.data;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Returns')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.sm),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < _tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSizes.sm),
                      child: ChoiceChip(
                        label: Text(_tabs[i].label),
                        selected: _index == i,
                        onSelected: (_) {
                          setState(() => _index = i);
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const _ReturnsSkeleton()
                : _error != null
                    ? _ErrorBlock(message: _error!, onRetry: _load)
                    : _rows.isEmpty
                        ? const _EmptyBlock()
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.lg, vertical: AppSizes.sm),
                              itemCount: _rows.length,
                              itemBuilder: (_, i) => _ReturnRow(
                                row: _rows[i],
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => MerchantReturnDetailPage(
                                        returnId: _rows[i].id,
                                      ),
                                    ),
                                  );
                                  if (mounted) _load();
                                },
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ReturnRow extends StatelessWidget {
  const _ReturnRow({required this.row, required this.onTap});
  final MerchantReturn row;
  final VoidCallback onTap;

  static final _currency =
      NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  static final _date = DateFormat('d MMM · h:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemCount = row.items.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
        child: InkWell(
          customBorder: AppShapes.squircle(AppSizes.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Return #${row.id} · ${row.customerName}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AppStatusBadge(
                      label: _statusLabel(row.status),
                      tone: _toneFor(row.status),
                      weight: AppStatusWeight.soft,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  '$itemCount item${itemCount == 1 ? '' : 's'} · '
                  'Refund ${_currency.format(row.refundAmount)} · '
                  '${_date.format(row.createdAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                if (row.items.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.sm),
                  Text(
                    row.items.map((i) => i.productName).join(', '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static AppStatusTone _toneFor(String s) {
    switch (s) {
      case 'REQUESTED':
        return AppStatusTone.warning;
      case 'REFUNDED':
        return AppStatusTone.success;
      case 'REJECTED':
      case 'CANCELLED':
        return AppStatusTone.error;
      default:
        return AppStatusTone.info;
    }
  }

  static String _statusLabel(String s) {
    switch (s) {
      case 'REQUESTED':
        return 'Requested';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      case 'PICKED_UP':
        return 'Picked up';
      case 'RECEIVED':
        return 'Received';
      case 'REFUNDED':
        return 'Refunded';
      default:
        return s;
    }
  }
}

// ---------------------------------------------------------------------------
// Skeleton loading state
// ---------------------------------------------------------------------------

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row: text (80%) + status badge placeholder
              Row(
                children: [
                  const Expanded(
                    child: AppShimmerLine(widthFactor: 0.8, height: 16),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  AppShimmerBox(
                    width: 72,
                    height: 22,
                    radius: AppSizes.radiusSm,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              // Metadata line (60%)
              const AppShimmerLine(widthFactor: 0.6, height: 12),
              const SizedBox(height: AppSizes.sm),
              // Product names line (70%)
              const AppShimmerLine(widthFactor: 0.7, height: 13),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReturnsSkeleton extends StatelessWidget {
  const _ReturnsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg, vertical: AppSizes.sm),
      itemCount: 5,
      itemBuilder: (_, _) => const _SkeletonRow(),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_return_outlined,
                size: AppSizes.iconHuge, color: AppColors.subtle),
            const SizedBox(height: AppSizes.md),
            Text(
              'No returns in this view yet.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.md),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
