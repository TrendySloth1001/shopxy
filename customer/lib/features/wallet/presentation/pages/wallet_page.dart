import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/wallet/data/datasources/wallet_remote_data_source.dart';
import 'package:shopxy_customer/features/wallet/domain/entities/wallet_entry.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

/// Wallet page — header balance card + ledger of credits/debits.
/// Phase 3 ships read-only; Phase 4 (coupons) and Phase 5 (loyalty /
/// referral) layer redemption + manual top-ups on top.
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late Future<WalletSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<WalletSnapshot> _load() {
    return context.read<WalletRemoteDataSource>().snapshot();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: 'Wallet'),
      body: FutureBuilder<WalletSnapshot>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const _WalletSkeleton();
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.xxl),
                child: Text(friendlyError(snap.error ?? '')),
              ),
            );
          }
          final data = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.huge,
              ),
              children: [
                _BalanceCard(balance: data.balance),
                const SizedBox(height: AppSizes.lg),
                Text(
                  'RECENT ACTIVITY',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.sm),
                if (data.entries.isEmpty)
                  const _EmptyLedger()
                else
                  Container(
                    decoration: ShapeDecoration(
                      color: AppColors.white,
                      shape: AppShapes.squircle(AppSizes.radiusMd),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < data.entries.length; i++) ...[
                          if (i != 0)
                            const Divider(
                              height: 1,
                              color: AppColors.hairline,
                              indent: AppSizes.md,
                              endIndent: AppSizes.md,
                            ),
                          _LedgerRow(entry: data.entries[i]),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final double balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.black,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.white, size: AppSizes.iconMd),
              const SizedBox(width: AppSizes.sm),
              Text(
                'WALLET BALANCE',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.white.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            AppFormat.rupeesSmart(balance),
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            'Use at checkout — refunds, coupons and rewards land here.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.white.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry});
  final WalletEntry entry;

  IconData _icon() {
    switch (entry.source) {
      case 'REFUND':
        return Icons.assignment_return_outlined;
      case 'COUPON':
        return Icons.local_offer_outlined;
      case 'REFERRAL':
        return Icons.group_add_outlined;
      case 'LOYALTY':
        return Icons.workspace_premium_outlined;
      case 'CHECKOUT':
        return Icons.shopping_bag_outlined;
      case 'MANUAL':
      default:
        return Icons.account_balance_wallet_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final positive = entry.isCredit;
    final color = positive ? AppColors.success : AppColors.error;
    final sign = positive ? '+' : '-';
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          Container(
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
            ),
            child: Icon(_icon(), color: color, size: AppSizes.iconMd),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  DateFormat('d MMM · h:mm a').format(entry.createdAt.toLocal()),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Text(
            '$sign${AppFormat.rupees(entry.amount.abs())}',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.xl),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.history_rounded,
                color: AppColors.muted, size: AppSizes.iconXl),
            const SizedBox(height: AppSizes.sm),
            Text(
              'No activity yet',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton loading state ────────────────────────────────────────────────────

/// Full-page skeleton that mirrors the wallet layout while data loads.
/// Mirrors: balance card at the top, "RECENT ACTIVITY" label, 4 ledger rows.
class _WalletSkeleton extends StatelessWidget {
  const _WalletSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.md, AppSizes.md, AppSizes.md, AppSizes.huge,
      ),
      children: [
        const _BalanceCardSkeleton(),
        const SizedBox(height: AppSizes.lg),
        // "RECENT ACTIVITY" label placeholder
        const AppShimmerLine(widthFactor: 0.38, height: AppSizes.md),
        const SizedBox(height: AppSizes.sm),
        Container(
          decoration: ShapeDecoration(
            color: AppColors.white,
            shape: AppShapes.squircle(AppSizes.radiusMd),
          ),
          child: Column(
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i != 0)
                  const Divider(
                    height: 1,
                    color: AppColors.hairline,
                    indent: AppSizes.md,
                    endIndent: AppSizes.md,
                  ),
                const _LedgerRowSkeleton(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Skeleton for the black balance card: icon chip + label, large amount line,
/// description line — all using dark shimmer tones on a black background.
class _BalanceCardSkeleton extends StatelessWidget {
  const _BalanceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.black,
        shape: AppShapes.squircle(AppSizes.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + "WALLET BALANCE" label row
          Row(
            children: [
              AppShimmerBox(
                width: AppSizes.iconMd,
                height: AppSizes.iconMd,
                radius: AppSizes.radiusSm,
              ),
              const SizedBox(width: AppSizes.sm),
              const AppShimmerLine(widthFactor: 0.4, height: AppSizes.md),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          // Large amount
          const AppShimmerLine(widthFactor: 0.55, height: AppSizes.xxxl),
          const SizedBox(height: AppSizes.sm),
          // Description text
          const AppShimmerLine(widthFactor: 0.85, height: AppSizes.md),
        ],
      ),
    );
  }
}

/// Skeleton for one ledger row: circular icon, description + date lines,
/// amount placeholder on the right — matching _LedgerRow geometry.
class _LedgerRowSkeleton extends StatelessWidget {
  const _LedgerRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          // Circular icon placeholder
          AppShimmerBox(
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            radius: AppSizes.xxxl / 2,
          ),
          const SizedBox(width: AppSizes.md),
          // Description + date lines
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.72, height: AppSizes.md),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.45, height: AppSizes.sm),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // Amount placeholder
          const AppShimmerBox(
            width: AppSizes.massive,
            height: AppSizes.md,
            radius: AppSizes.radiusSm,
          ),
        ],
      ),
    );
  }
}
