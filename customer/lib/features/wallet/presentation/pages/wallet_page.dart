import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/wallet/data/datasources/wallet_remote_data_source.dart';
import 'package:shopxy_customer/features/wallet/domain/entities/wallet_entry.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';

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
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(snap.error.toString()
                    .replaceFirst('Exception: ', '')),
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
                const Text(
                  'RECENT ACTIVITY',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
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
          const Row(
            children: [
              Icon(Icons.account_balance_wallet_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text(
                'WALLET BALANCE',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            '₹${balance.toStringAsFixed(balance == balance.roundToDouble() ? 0 : 2)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 36,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Use at checkout — refunds, coupons and rewards land here.',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.1),
            ),
            child: Icon(_icon(), color: color, size: 18),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('d MMM · h:mm a').format(entry.createdAt.toLocal()),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Text(
            '$sign₹${entry.amount.abs().toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
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
      child: const Center(
        child: Column(
          children: [
            Icon(Icons.history_rounded, color: AppColors.muted, size: 32),
            SizedBox(height: 6),
            Text(
              'No activity yet',
              style: TextStyle(
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
