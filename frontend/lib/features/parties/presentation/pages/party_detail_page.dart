import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/caution/presentation/pages/caution_history_page.dart';
import 'package:shopxy/features/caution/presentation/pages/caution_requests_page.dart';
import 'package:shopxy/features/caution/presentation/widgets/caution_sheet.dart';
import 'package:shopxy/features/challans/presentation/pages/challan_detail_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/domain/entities/party_overview.dart';
import 'package:shopxy/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:shopxy/features/payments/domain/entities/payment.dart';
import 'package:shopxy/features/payments/presentation/widgets/record_payment_sheet.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/widgets/contact_changes_section.dart';

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
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
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
          _error = e.toString();
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

  Future<void> _openCautionAction(String action) async {
    final overview = _overview;
    if (overview == null) return;
    final double? newBalance;
    if (action == 'DEPOSIT' || action == 'REFUND') {
      newBalance = await CautionSheet.show(
        context,
        type: action,
        partyId: overview.id,
        partyName: overview.name,
        currentBalance: overview.cautionBalance,
      );
    } else if (action == 'FORFEIT') {
      newBalance = await CautionForfeitSheet.show(
        context,
        partyId: overview.id,
        partyName: overview.name,
        currentBalance: overview.cautionBalance,
      );
    } else {
      newBalance = await CautionAdjustSheet.show(
        context,
        partyId: overview.id,
        partyName: overview.name,
        currentBalance: overview.cautionBalance,
      );
    }
    if (newBalance != null && mounted) {
      await _load();
    }
  }

  Future<void> _openCautionRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CautionRequestsPage()),
    );
    if (mounted) await _load();
  }

  void _openCautionHistory() {
    final overview = _overview;
    if (overview == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CautionHistoryPage(
          partyId: overview.id,
          partyName: overview.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRecord = !_isLoading &&
        _overview != null &&
        !(_overview!.isSystem);
    return Scaffold(
      appBar: AppBar(title: const Text('Party')),
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              onPressed: _openRecordPayment,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Record payment'),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                    children: _buildBody(_overview!),
                  ),
                ),
    );
  }

  List<Widget> _buildBody(PartyOverview p) {
    final theme = Theme.of(context);

    final ledger = _ledger;
    return [
      _Header(party: p),
      const SizedBox(height: AppSizes.lg),
      _BalanceTile(party: p, currency: _currency),
      if (!p.isSystem) ...[
        const SizedBox(height: AppSizes.lg),
        _CautionCard(
          party: p,
          currency: _currency,
          onAction: _openCautionAction,
          onTapHistory: _openCautionHistory,
          onTapRequests: _openCautionRequests,
        ),
      ],
      const SizedBox(height: AppSizes.lg),
      _Totals(party: p, currency: _currency),
      const SizedBox(height: AppSizes.xl),
      if (ledger != null && ledger.entries.isNotEmpty) ...[
        const AppSectionHeader(title: 'Ledger'),
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
        const AppSectionHeader(title: 'Recent invoices'),
        const AppDivider(),
        for (final inv in p.recentInvoices)
          _InvoiceRow(invoice: inv, currency: _currency, dateFmt: _dateFmt),
        const SizedBox(height: AppSizes.xl),
      ],
      if (p.recentChallans.isNotEmpty) ...[
        const AppSectionHeader(title: 'Recent challans'),
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
            'No activity yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.party});
  final PartyOverview party;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppMonogramAvatar(label: party.name, size: 56),
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
                        padding: const EdgeInsets.only(top: 2),
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
                const AppStatusBadge(
                  label: 'Linked',
                  icon: Icons.verified_outlined,
                  tone: AppStatusTone.success,
                ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          if (party.phone != null && party.phone!.isNotEmpty)
            _ContactLine(icon: Icons.phone_outlined, value: party.phone!),
          if (party.email != null && party.email!.isNotEmpty)
            _ContactLine(icon: Icons.email_outlined, value: party.email!),
          if (party.address != null && party.address!.isNotEmpty)
            _ContactLine(icon: Icons.place_outlined, value: party.address!),
          if (party.gstin != null && party.gstin!.isNotEmpty)
            _ContactLine(icon: Icons.badge_outlined, value: 'GSTIN ${party.gstin}'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        children: [
          Expanded(
            child: _StatBlock(
              label: 'Net billed',
              value: currency.format(party.netBilled),
              hint: '${party.invoiceCount} invoices',
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: _StatBlock(
              label: 'Sales',
              value: currency.format(party.totalSales),
              hint: '${party.totals.where((t) => t.type == "SALE").fold(0, (s, t) => s + t.count)} bills',
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: _StatBlock(
              label: 'Returns',
              value: currency.format(party.totalReturns),
              hint: '${party.challanCount} challans',
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
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
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
    return Material(
      color: AppColors.white,
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
                      '${dateFmt.format(invoice.invoiceDate)} · ${invoice.itemCount} items',
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
                  const SizedBox(height: 2),
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
    final balance = party.balance;
    final positive = balance > 0;
    final settled = balance.abs() < 0.005;
    final color = settled
        ? AppColors.muted
        : (positive ? AppColors.error : AppColors.success);
    final label = settled
        ? 'No outstanding'
        : positive
            ? 'Owes you'
            : 'Advance / credit';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Row(
          children: [
            Icon(
              positive
                  ? Icons.arrow_downward_rounded
                  : settled
                      ? Icons.check_circle_outline_rounded
                      : Icons.arrow_upward_rounded,
              color: color,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BALANCE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
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

/// Caution / security deposit summary on the party detail page. Shows the
/// held balance and Add / Refund / Set-off actions; tapping the card opens
/// the full history.
class _CautionCard extends StatelessWidget {
  const _CautionCard({
    required this.party,
    required this.currency,
    required this.onAction,
    required this.onTapHistory,
    required this.onTapRequests,
  });
  final PartyOverview party;
  final NumberFormat currency;
  final ValueChanged<String> onAction;
  final VoidCallback onTapHistory;
  final VoidCallback onTapRequests;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final balance = party.cautionBalance;
    final hasBalance = balance > 0.005;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSizes.lg),
        onTap: onTapHistory,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.savings_outlined, color: AppColors.brand),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CAUTION DEPOSIT',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasBalance ? 'Held on file' : 'None on file',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  currency.format(balance),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: hasBalance ? AppColors.brand : AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onAction('DEPOSIT'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add'),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasBalance ? () => onAction('REFUND') : null,
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: const Text('Refund'),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasBalance ? () => onAction('ADJUST') : null,
                    icon: const Icon(Icons.call_merge_rounded, size: 18),
                    label: const Text('Set off'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasBalance ? () => onAction('FORFEIT') : null,
                    icon: const Icon(Icons.gavel_rounded, size: 18),
                    label: const Text('Forfeit'),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTapRequests,
                    icon: const Icon(Icons.inbox_rounded, size: 18),
                    label: const Text('Requests'),
                  ),
                ),
              ],
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
                ? Icons.receipt_long_outlined
                : Icons.payments_outlined,
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
              const SizedBox(height: 2),
              Text(
                'Bal ${currency.format(entry.runningBalance)}',
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
    return Material(
      color: AppColors.white,
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
                      '${dateFmt.format(challan.createdAt)} · ${challan.itemCount} items',
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
