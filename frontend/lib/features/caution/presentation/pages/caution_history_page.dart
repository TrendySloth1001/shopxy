import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/caution/data/datasources/caution_remote_data_source.dart';
import 'package:shopxy/features/caution/domain/entities/caution_txn.dart';
import 'package:shopxy/features/caution/presentation/widgets/caution_info_sheet.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_list_section.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';

/// Full caution ledger for a party: held balance + every deposit, refund and
/// set-off, most recent first.
class CautionHistoryPage extends StatefulWidget {
  const CautionHistoryPage({
    super.key,
    required this.partyId,
    required this.partyName,
  });

  final int partyId;
  final String partyName;

  @override
  State<CautionHistoryPage> createState() => _CautionHistoryPageState();
}

class _CautionHistoryPageState extends State<CautionHistoryPage> {
  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _dateFmt = DateFormat('d MMM y');

  CautionHistory? _history;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ds = context.read<CautionRemoteDataSource>();
      final history = await ds.getHistory(widget.partyId);
      if (mounted) {
        setState(() {
          _history = history;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caution deposits'),
        actions: [
          IconButton(
            onPressed: () => showCautionInfoSheet(
              context,
              variant: CautionInfoVariant.history,
            ),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'About caution deposits',
          ),
        ],
      ),
      body: _isLoading
          ? const _CautionHistorySkeleton()
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _buildBody(_history!),
                ),
    );
  }

  Widget _buildBody(CautionHistory history) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.sm,
          ),
          child: Row(
            children: [
              const Icon(Icons.savings_outlined, color: AppColors.brand),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CAUTION HELD',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      widget.partyName,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Text(
                _currency.format(history.balance),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        const AppDivider.flush(),
        const SizedBox(height: AppSizes.md),
        if (history.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSizes.xl),
            child: Text(
              'No caution on file yet.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          )
        else ...[
          AppListSection(
            title: 'History',
            flushDividers: true,
            children: [
              for (final e in history.entries)
                _CautionRow(txn: e, currency: _currency, dateFmt: _dateFmt),
            ],
          ),
          const SizedBox(height: AppSizes.xl),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton widgets — shown while _isLoading is true
// ---------------------------------------------------------------------------

/// Full-page skeleton that mirrors the layout of [_buildBody] + [_CautionRow].
class _CautionHistorySkeleton extends StatelessWidget {
  const _CautionHistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Header card — icon + two-line text column + large balance amount
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.sm,
          ),
          child: Row(
            children: [
              AppShimmerBox(
                width: AppSizes.iconMd,
                height: AppSizes.iconMd,
                radius: AppSizes.iconMd / 2,
              ),
              const SizedBox(width: AppSizes.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmerLine(widthFactor: 0.35, height: 10),
                    SizedBox(height: AppSizes.xs),
                    AppShimmerLine(widthFactor: 0.55, height: 13),
                  ],
                ),
              ),
              const AppShimmerLine(widthFactor: 0.22, height: 22),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        const AppDivider.flush(),
        const SizedBox(height: AppSizes.md),
        // 5 transaction row skeletons
        for (var i = 0; i < 5; i++) ...[
          const _CautionRowSkeleton(),
          if (i < 4) const AppDivider.flush(),
        ],
        const SizedBox(height: AppSizes.xl),
      ],
    );
  }
}

/// Single transaction row skeleton — mirrors [_CautionRow].
class _CautionRowSkeleton extends StatelessWidget {
  const _CautionRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          AppShimmerBox(
            width: AppSizes.iconMd,
            height: AppSizes.iconMd,
            radius: AppSizes.iconMd / 2,
          ),
          const SizedBox(width: AppSizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.3, height: 13),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.55, height: 11),
              ],
            ),
          ),
          const AppShimmerLine(widthFactor: 0.2, height: 13),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CautionRow extends StatelessWidget {
  const _CautionRow({
    required this.txn,
    required this.currency,
    required this.dateFmt,
  });
  final CautionTxn txn;
  final NumberFormat currency;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final increases = txn.increasesBalance;
    final (icon, label, color) = switch (txn.type) {
      'DEPOSIT' => (Icons.south_west_rounded, 'Deposit', AppColors.success),
      'REFUND' => (Icons.north_east_rounded, 'Refund', AppColors.error),
      'FORFEIT' => (Icons.gavel_rounded, 'Forfeited', AppColors.error),
      _ => (Icons.call_merge_rounded, 'Set-off', AppColors.brand),
    };
    final subtitleParts = <String>[
      dateFmt.format(txn.createdAt),
      if (txn.isAdjustment && txn.invoiceNo != null) 'Inv ${txn.invoiceNo}',
      if (!txn.isAdjustment && txn.mode != null) txn.mode!,
      if (txn.receiptNo != null) txn.receiptNo!,
      if (txn.isForfeit && txn.gstTreatment == 'SUPPLY') 'GST applies',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: AppSizes.iconMd),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitleParts.join(' · '),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                if (txn.note != null && txn.note!.isNotEmpty)
                  Text(
                    txn.note!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.subtle),
                  ),
              ],
            ),
          ),
          Text(
            '${increases ? '+' : '-'}${currency.format(txn.amount)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: increases ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
