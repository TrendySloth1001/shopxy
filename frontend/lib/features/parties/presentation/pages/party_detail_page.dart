import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/challans/presentation/pages/challan_detail_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/domain/entities/party_overview.dart';
import 'package:shopxy/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:shopxy/features/payments/domain/entities/payment.dart';
import 'package:shopxy/features/payments/presentation/widgets/record_payment_sheet.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/contact_changes_section.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';

class PartyDetailPage extends StatefulWidget {
  const PartyDetailPage({super.key, required this.partyId});
  final int partyId;

  @override
  State<PartyDetailPage> createState() => _PartyDetailPageState();
}

class _PartyDetailPageState extends State<PartyDetailPage> {
  PartyOverview? _overview;
  Ledger? _ledger;
  bool _isLoading = true;
  String? _error;

  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _dateFmt = DateFormat('d MMM y');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final partiesDs = context.read<PartiesRemoteDataSource>();
      final paymentsDs = context.read<PaymentsRemoteDataSource>();
      final results = await Future.wait([
        partiesDs.getPartyOverview(widget.partyId),
        paymentsDs.getPartyLedger(widget.partyId),
      ]);
      if (mounted) {
        setState(() {
          _overview = results[0] as PartyOverview;
          _ledger = results[1] as Ledger;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = friendlyError(e);
        });
      }
    }
  }

  Future<void> _openRecordPayment() async {
    final overview = _overview;
    if (overview == null) return;
    final created = await RecordPaymentSheet.show(
      context,
      type: 'RECEIPT',
      partyId: overview.id,
      partyName: overview.name,
    );
    if (created != null && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canRecord = !_isLoading &&
        _overview != null &&
        !(_overview!.isSystem);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.partiesPartyTitle),
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              onPressed: _openRecordPayment,
              icon: const Icon(AppIcons.paymentsOutlined),
              label: Text(l10n.partiesRecordPayment),
            )
          : null,
      body: _isLoading
          ? const _PartyDetailSkeleton()
          : _error != null
              ? SafeArea(
                  top: true,
                  bottom: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.xl),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.only(
                      top: AppSizes.md + FloatingAppBar.contentTopInset(context),
                      bottom: AppSizes.md,
                    ),
                    children: _buildBody(_overview!),
                  ),
                ),
    );
  }

  List<Widget> _buildBody(PartyOverview p) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final ledger = _ledger;
    return [
      _Header(party: p),
      const SizedBox(height: AppSizes.lg),
      _BalanceTile(party: p, currency: _currency),
      const SizedBox(height: AppSizes.lg),
      _Totals(party: p, currency: _currency),
      const SizedBox(height: AppSizes.xl),
      if (ledger != null && ledger.entries.isNotEmpty) ...[
        AppSectionHeader(title: l10n.partiesLedger),
        const AppDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < ledger.entries.length; i++) ...[
                  if (i > 0) const AppDivider.flush(),
                  _LedgerRow(
                    entry: ledger.entries[i],
                    currency: _currency,
                    dateFmt: _dateFmt,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.xl),
      ],
      if (p.recentInvoices.isNotEmpty) ...[
        AppSectionHeader(title: l10n.partiesRecentInvoices),
        const AppDivider(),
        for (final inv in p.recentInvoices)
          _InvoiceRow(invoice: inv, currency: _currency, dateFmt: _dateFmt),
        const SizedBox(height: AppSizes.xl),
      ],
      if (p.recentChallans.isNotEmpty) ...[
        AppSectionHeader(title: l10n.partiesRecentChallans),
        const AppDivider(),
        for (final c in p.recentChallans)
          _ChallanRow(challan: c, dateFmt: _dateFmt),
        const SizedBox(height: AppSizes.xl),
      ],
      ContactChangesSection(endpoint: '/parties/${p.id}'),
      if (p.recentInvoices.isEmpty && p.recentChallans.isEmpty)
        Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Text(
            l10n.partiesNoActivityYet,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
    ];
  }
}

// ── Skeleton ─────────────────────────────────────────────────────────────────

class _PartyDetailSkeleton extends StatelessWidget {
  const _PartyDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
        top: AppSizes.md + FloatingAppBar.contentTopInset(context),
        bottom: AppSizes.md,
      ),
      children: const [
        _HeaderSkeleton(),
        SizedBox(height: AppSizes.lg),
        _BalanceTileSkeleton(),
        SizedBox(height: AppSizes.lg),
        _StatsSkeleton(),
        SizedBox(height: AppSizes.xl),
        _LedgerSectionSkeleton(),
        SizedBox(height: AppSizes.xl),
        _InvoiceSectionSkeleton(),
      ],
    );
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppShimmerBox(
                width: AppSizes.avatarMd,
                height: AppSizes.avatarMd,
                radius: AppSizes.radiusFull,
              ),
              const SizedBox(width: AppSizes.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppShimmerLine(widthFactor: 0.55, height: AppSizes.lg),
                    SizedBox(height: AppSizes.xs),
                    AppShimmerLine(widthFactor: 0.38, height: AppSizes.md),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          const AppShimmerLine(widthFactor: 0.45, height: AppSizes.md),
          const SizedBox(height: AppSizes.xs),
          const AppShimmerLine(widthFactor: 0.60, height: AppSizes.md),
        ],
      ),
    );
  }
}

class _BalanceTileSkeleton extends StatelessWidget {
  const _BalanceTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        ),
        child: const Row(
          children: [
            AppShimmerBox(
              width: AppSizes.iconLg,
              height: AppSizes.iconLg,
              radius: AppSizes.radiusSm,
            ),
            SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerLine(widthFactor: 0.30, height: AppSizes.sm),
                  SizedBox(height: AppSizes.xs),
                  AppShimmerLine(widthFactor: 0.50, height: AppSizes.md),
                ],
              ),
            ),
            SizedBox(width: AppSizes.md),
            AppShimmerBox(width: 72, height: AppSizes.xl, radius: AppSizes.radiusSm),
          ],
        ),
      ),
    );
  }
}

class _StatsSkeleton extends StatelessWidget {
  const _StatsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        children: [
          Expanded(child: _StatBlockSkeleton()),
          SizedBox(width: AppSizes.md),
          Expanded(child: _StatBlockSkeleton()),
          SizedBox(width: AppSizes.md),
          Expanded(child: _StatBlockSkeleton()),
        ],
      ),
    );
  }
}

class _StatBlockSkeleton extends StatelessWidget {
  const _StatBlockSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppShimmerLine(widthFactor: 0.70, height: AppSizes.sm),
        SizedBox(height: AppSizes.xs),
        AppShimmerLine(widthFactor: 0.90, height: AppSizes.xl),
        SizedBox(height: AppSizes.xs),
        AppShimmerLine(widthFactor: 0.50, height: AppSizes.sm),
      ],
    );
  }
}

class _LedgerSectionSkeleton extends StatelessWidget {
  const _LedgerSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppShimmerLine(widthFactor: 0.30, height: AppSizes.lg),
          const SizedBox(height: AppSizes.sm),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            ),
            child: Column(
              children: List.generate(5, (i) => const _LedgerRowSkeleton()),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRowSkeleton extends StatelessWidget {
  const _LedgerRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          AppShimmerBox(
            width: AppSizes.iconMd,
            height: AppSizes.iconMd,
            radius: AppSizes.radiusSm,
          ),
          SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.55, height: AppSizes.md),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.38, height: AppSizes.sm),
              ],
            ),
          ),
          SizedBox(width: AppSizes.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppShimmerBox(width: 56, height: AppSizes.md, radius: AppSizes.radiusSm),
              SizedBox(height: AppSizes.xs),
              AppShimmerBox(width: 44, height: AppSizes.sm, radius: AppSizes.radiusSm),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceSectionSkeleton extends StatelessWidget {
  const _InvoiceSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: AppShimmerLine(widthFactor: 0.35, height: AppSizes.lg),
        ),
        const SizedBox(height: AppSizes.sm),
        ...List.generate(4, (_) => const _InvoiceRowSkeleton()),
      ],
    );
  }
}

class _InvoiceRowSkeleton extends StatelessWidget {
  const _InvoiceRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.45, height: AppSizes.md),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.60, height: AppSizes.sm),
              ],
            ),
          ),
          SizedBox(width: AppSizes.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppShimmerBox(width: 60, height: AppSizes.md, radius: AppSizes.radiusSm),
              SizedBox(height: AppSizes.xs),
              AppShimmerBox(width: 48, height: AppSizes.sm, radius: AppSizes.radiusSm),
            ],
          ),
        ],
      ),
    );
  }
}

// ── End Skeleton ──────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.party});
  final PartyOverview party;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppMonogramAvatar(label: party.name, size: AppSizes.avatarMd),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      party.name,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (party.contactName != null && party.contactName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSizes.xs),
                        child: Text(
                          party.contactName!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                  ],
                ),
              ),
              if (party.linkedUser != null)
                AppStatusBadge(
                  label: l10n.partiesInviteStatusLinked,
                  icon: AppIcons.verifiedOutlined,
                  tone: AppStatusTone.success,
                ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          if (party.phone != null && party.phone!.isNotEmpty)
            _ContactLine(icon: AppIcons.phoneOutlined, value: party.phone!),
          if (party.email != null && party.email!.isNotEmpty)
            _ContactLine(icon: AppIcons.emailOutlined, value: party.email!),
          if (party.address != null && party.address!.isNotEmpty)
            _ContactLine(icon: AppIcons.placeOutlined, value: party.address!),
          if (party.gstin != null && party.gstin!.isNotEmpty)
            _ContactLine(
                icon: AppIcons.badgeOutlined,
                value: '${l10n.partiesGstinLabel} ${party.gstin}'),
        ],
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  const _ContactLine({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: AppColors.muted),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.black),
            ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.party, required this.currency});
  final PartyOverview party;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final billsCount = party.totals
        .where((t) => t.type == "SALE")
        .fold(0, (s, t) => s + t.count);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        children: [
          Expanded(
            child: _StatBlock(
              label: l10n.partiesNetBilled,
              value: currency.format(party.netBilled),
              hint: '${party.invoiceCount} ${l10n.partiesInvoicesUnit}',
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: _StatBlock(
              label: l10n.partiesSales,
              value: currency.format(party.totalSales),
              hint: '$billsCount ${l10n.partiesBillsUnit}',
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: _StatBlock(
              label: l10n.partiesReturns,
              value: currency.format(party.totalReturns),
              hint: '${party.challanCount} ${l10n.partiesChallansUnit}',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.label, required this.value, required this.hint});
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.muted,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.subtle),
        ),
      ],
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.currency,
    required this.dateFmt,
  });
  final PartyInvoiceRef invoice;
  final NumberFormat currency;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailPage(invoiceId: invoice.id),
          ),
        ),
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
                      invoice.invoiceNo,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${dateFmt.format(invoice.invoiceDate)} · ${invoice.itemCount} ${l10n.partiesItemsUnit}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currency.format(invoice.total),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  AppStatusBadge(
                    label: invoice.status,
                    dense: true,
                    tone: _badgeTone(invoice),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppStatusTone _badgeTone(PartyInvoiceRef i) {
    if (i.status == 'CONFIRMED') return AppStatusTone.success;
    if (i.status == 'CANCELLED') return AppStatusTone.error;
    return AppStatusTone.warning;
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.party, required this.currency});
  final PartyOverview party;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final balance = party.balance;
    final positive = balance > 0;
    final settled = balance.abs() < 0.005;
    final color = settled
        ? AppColors.muted
        : (positive ? AppColors.error : AppColors.success);
    final label = settled
        ? l10n.partiesNoOutstanding
        : positive
            ? l10n.partiesOwesYou
            : l10n.partiesAdvanceCredit;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Row(
          children: [
            Icon(
              positive
                  ? AppIcons.arrowDownwardRounded
                  : settled
                      ? AppIcons.checkCircleOutlineRounded
                      : AppIcons.arrowUpwardRounded,
              color: color,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.partiesBalance,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Text(
              currency.format(balance.abs()),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({
    required this.entry,
    required this.currency,
    required this.dateFmt,
  });
  final LedgerEntry entry;
  final NumberFormat currency;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isInvoice = entry.isInvoice;
    final amount = isInvoice ? entry.debit : entry.credit;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Icon(
            isInvoice
                ? AppIcons.receiptLongOutlined
                : AppIcons.paymentsOutlined,
            color: isInvoice ? AppColors.brand : AppColors.success,
            size: AppSizes.iconMd,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  isInvoice
                      ? dateFmt.format(entry.date)
                      : '${dateFmt.format(entry.date)} · ${entry.mode ?? ''}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isInvoice ? '+' : '-'}${currency.format(amount)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isInvoice ? AppColors.error : AppColors.success,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                '${l10n.partiesBalanceShort} ${currency.format(entry.runningBalance)}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChallanRow extends StatelessWidget {
  const _ChallanRow({required this.challan, required this.dateFmt});
  final PartyChallanRef challan;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChallanDetailPage(challanId: challan.id),
          ),
        ),
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
                      challan.challanNo,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${dateFmt.format(challan.createdAt)} · ${challan.itemCount} ${l10n.partiesItemsUnit}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              AppStatusBadge(
                label: challan.status,
                dense: true,
                tone: challan.invoiceId != null
                    ? AppStatusTone.success
                    : AppStatusTone.neutral,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
