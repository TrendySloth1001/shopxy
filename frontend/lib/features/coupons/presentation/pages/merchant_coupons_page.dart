import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/coupons/data/datasources/merchant_coupons_remote_data_source.dart';
import 'package:shopxy/features/coupons/domain/merchant_coupon.dart';
import 'package:shopxy/features/coupons/presentation/widgets/coupon_editor_sheet.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

/// Merchant-facing list of coupons attached to the caller's shop.
/// Tapping a row opens the editor sheet; the FAB opens the same sheet
/// in create mode.
class MerchantCouponsPage extends StatefulWidget {
  const MerchantCouponsPage({super.key});

  @override
  State<MerchantCouponsPage> createState() => _MerchantCouponsPageState();
}

class _MerchantCouponsPageState extends State<MerchantCouponsPage> {
  List<MerchantCoupon> _rows = const [];
  bool _loading = true;
  String? _error;

  static final _date = DateFormat('d MMM y');
  static final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

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
      final ds = context.read<MerchantCouponsRemoteDataSource>();
      final rows = await ds.list();
      if (mounted) {
        setState(() {
        _rows = rows;
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

  Future<void> _openEditor({MerchantCoupon? existing}) async {
    final saved = await showCouponEditorSheet(
      context: context,
      existing: existing,
    );
    if (saved == true) _load();
  }

  Future<void> _deactivate(MerchantCoupon c) async {
    // Snapshot the data source + messenger BEFORE any await so we
    // don't read from `context` after an async gap (lint
    // use_build_context_synchronously).
    final ds = context.read<MerchantCouponsRemoteDataSource>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate ${c.code}?'),
        content: const Text(
          'Buyers won\'t see this coupon anymore. Existing redemptions '
          'are unaffected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ds.deactivate(c.id);
      if (!mounted) return;
      _load();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coupons')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New coupon'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                        itemBuilder: (_, i) => _CouponRow(
                          row: _rows[i],
                          onEdit: () => _openEditor(existing: _rows[i]),
                          onDeactivate: () => _deactivate(_rows[i]),
                          dateFormat: _date,
                          currencyFormat: _currency,
                        ),
                      ),
                    ),
    );
  }
}

class _CouponRow extends StatelessWidget {
  const _CouponRow({
    required this.row,
    required this.onEdit,
    required this.onDeactivate,
    required this.dateFormat,
    required this.currencyFormat,
  });
  final MerchantCoupon row;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discount = row.discountType == 'PERCENT'
        ? '${row.discountValue.toStringAsFixed(0)}% off'
        : '${currencyFormat.format(row.discountValue)} off';
    final tone = !row.isActive
        ? AppStatusTone.error
        : row.isExpired
            ? AppStatusTone.warning
            : row.isExhausted
                ? AppStatusTone.warning
                : AppStatusTone.success;
    final label = !row.isActive
        ? 'Inactive'
        : row.isExpired
            ? 'Expired'
            : row.isExhausted
                ? 'Exhausted'
                : 'Live';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
        child: InkWell(
          customBorder: AppShapes.squircle(AppSizes.radiusMd),
          onTap: onEdit,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${row.code} · $discount',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    AppStatusBadge(
                      label: label,
                      tone: tone,
                      weight: AppStatusWeight.soft,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(row.title,
                    style: theme.textTheme.bodyMedium),
                if (row.isPublic || row.firstOrderOnly) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (row.isPublic)
                        const AppStatusBadge(
                          label: 'Public · auto-applies',
                          tone: AppStatusTone.info,
                          weight: AppStatusWeight.soft,
                          dense: true,
                        ),
                      if (row.firstOrderOnly)
                        const AppStatusBadge(
                          label: 'First order only',
                          tone: AppStatusTone.warning,
                          weight: AppStatusWeight.soft,
                          dense: true,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'Valid ${dateFormat.format(row.validFrom)} – '
                  '${dateFormat.format(row.validUntil)} · '
                  '${row.totalRedemptions}'
                  '${row.totalCap > 0 ? '/${row.totalCap}' : ''} redeemed',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                if (row.isActive) ...[
                  const SizedBox(height: AppSizes.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onDeactivate,
                      icon: const Icon(Icons.power_settings_new, size: 16),
                      label: const Text('Deactivate'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        visualDensity: VisualDensity.compact,
                      ),
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
          children: const [
            Icon(Icons.local_offer_outlined,
                size: 56, color: AppColors.subtle),
            SizedBox(height: AppSizes.md),
            Text(
              'No coupons yet. Tap "New coupon" to create your first one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
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
