import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/coupons/data/datasources/merchant_coupons_remote_data_source.dart';
import 'package:shopxy/features/coupons/domain/merchant_coupon.dart';
import 'package:shopxy/features/coupons/presentation/widgets/coupon_editor_sheet.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/utils/error_text.dart';

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
        _error = friendlyError(e);
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
    final l10n = AppLocalizations.of(context);
    final ds = context.read<MerchantCouponsRemoteDataSource>();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.couponsDeactivateConfirmTitle(c.code)),
        content: Text(l10n.couponsDeactivateConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.couponsCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l10n.couponsDeactivate),
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
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.couponsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(l10n.couponsNewCoupon),
      ),
      body: _loading
          ? const _CouponListSkeleton()
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final discount = row.discountType == 'PERCENT'
        ? l10n.couponsPercentOff(row.discountValue.toStringAsFixed(0))
        : l10n.couponsAmountOff(currencyFormat.format(row.discountValue));
    final tone = !row.isActive
        ? AppStatusTone.error
        : row.isExpired
            ? AppStatusTone.warning
            : row.isExhausted
                ? AppStatusTone.warning
                : AppStatusTone.success;
    final label = !row.isActive
        ? l10n.couponsStatusInactive
        : row.isExpired
            ? l10n.couponsStatusExpired
            : row.isExhausted
                ? l10n.couponsStatusExhausted
                : l10n.couponsStatusLive;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.surface,
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
                const SizedBox(height: AppSizes.xs),
                Text(row.title,
                    style: theme.textTheme.bodyMedium),
                if (row.isPublic || row.firstOrderOnly) ...[
                  const SizedBox(height: AppSizes.xs),
                  Wrap(
                    spacing: AppSizes.sm,
                    runSpacing: AppSizes.xs,
                    children: [
                      if (row.isPublic)
                        AppStatusBadge(
                          label: l10n.couponsBadgePublicAutoApplies,
                          tone: AppStatusTone.info,
                          weight: AppStatusWeight.soft,
                          dense: true,
                        ),
                      if (row.firstOrderOnly)
                        AppStatusBadge(
                          label: l10n.couponsBadgeFirstOrderOnly,
                          tone: AppStatusTone.warning,
                          weight: AppStatusWeight.soft,
                          dense: true,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSizes.xs),
                Text(
                  l10n.couponsValidityRedeemed(
                    dateFormat.format(row.validFrom),
                    dateFormat.format(row.validUntil),
                    '${row.totalRedemptions}'
                        '${row.totalCap > 0 ? '/${row.totalCap}' : ''}',
                  ),
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
                      icon: const Icon(Icons.power_settings_new,
                          size: AppSizes.iconSm),
                      label: Text(l10n.couponsDeactivate),
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

// ---------------------------------------------------------------------------
// Skeleton loading widgets
// ---------------------------------------------------------------------------

/// A single skeleton card that mirrors the visual structure of [_CouponRow].
class _CouponRowSkeleton extends StatelessWidget {
  const _CouponRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: code + discount text on the left, status badge on right
              Row(
                children: [
                  Expanded(
                    child: AppShimmerLine(widthFactor: 0.55, height: 16),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  AppShimmerBox(width: 56, height: 22, radius: AppSizes.radiusSm),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              // Title line
              AppShimmerLine(widthFactor: 0.75, height: 13),
              const SizedBox(height: AppSizes.xs),
              // Optional feature badge row (Public / First order)
              Row(
                children: [
                  AppShimmerBox(width: 100, height: 20, radius: AppSizes.radiusSm),
                  const SizedBox(width: AppSizes.sm),
                  AppShimmerBox(width: 80, height: 20, radius: AppSizes.radiusSm),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              // Metadata line: dates + redemption count
              AppShimmerLine(widthFactor: 0.9, height: 11),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders 4 skeleton coupon cards inside the same padding as the real list.
class _CouponListSkeleton extends StatelessWidget {
  const _CouponListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.sm,
      ),
      itemCount: 4,
      itemBuilder: (context, i) => const _CouponRowSkeleton(),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyBlock extends StatelessWidget {
  const _EmptyBlock();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_offer_outlined,
                size: AppSizes.iconHuge, color: AppColors.subtle),
            const SizedBox(height: AppSizes.md),
            Text(
              l10n.couponsEmptyBody,
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
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.md),
            FilledButton(onPressed: onRetry, child: Text(l10n.couponsRetry)),
          ],
        ),
      ),
    );
  }
}
