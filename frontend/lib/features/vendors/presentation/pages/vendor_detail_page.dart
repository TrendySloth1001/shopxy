import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:shopxy/features/payments/domain/entities/payment.dart';
import 'package:shopxy/features/payments/presentation/widgets/record_payment_sheet.dart';
import 'package:shopxy/features/vendors/data/datasources/vendors_remote_data_source.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor_overview.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/widgets/contact_changes_section.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';

class VendorDetailPage extends StatefulWidget {
  const VendorDetailPage({super.key, required this.vendorId});
  final int vendorId;

  @override
  State<VendorDetailPage> createState() => _VendorDetailPageState();
}

class _VendorDetailPageState extends State<VendorDetailPage> {
  VendorOverview? _overview;
  Ledger? _ledger;
  bool _isLoading = true;
  String? _error;

  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  static final _dateFmt = DateFormat('d MMM y');
  static final _qtyFmt = NumberFormat.decimalPattern('en_IN');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final vendorsDs = context.read<VendorsRemoteDataSource>();
      final paymentsDs = context.read<PaymentsRemoteDataSource>();
      final results = await Future.wait([
        vendorsDs.getVendorOverview(widget.vendorId),
        paymentsDs.getVendorLedger(widget.vendorId),
      ]);
      if (mounted) {
        setState(() {
          _overview = results[0] as VendorOverview;
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
      type: 'PAYMENT',
      vendorId: overview.id,
      vendorName: overview.name,
    );
    if (created != null && mounted) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canRecord = !_isLoading && _overview != null;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.vendorsDetailTitle),
      floatingActionButton: canRecord
          ? FloatingActionButton.extended(
              onPressed: _openRecordPayment,
              icon: const Icon(AppIcons.paymentsOutlined),
              label: Text(l10n.vendorsRecordPayment),
            )
          : null,
      body: _isLoading
          ? const _VendorDetailSkeleton()
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
                        bottom: AppSizes.md),
                    children: _buildBody(_overview!),
                  ),
                ),
    );
  }

  List<Widget> _buildBody(VendorOverview v) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final ledger = _ledger;
    return [
      _Header(vendor: v),
      const SizedBox(height: AppSizes.lg),
      _BalanceTile(vendor: v, currency: _currency),
      const SizedBox(height: AppSizes.lg),
      _Totals(vendor: v, currency: _currency),
      const SizedBox(height: AppSizes.xl),
      if (ledger != null && ledger.entries.isNotEmpty) ...[
        AppSectionHeader(title: l10n.vendorsLedger),
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
      if (v.recentInvoices.isNotEmpty) ...[
        AppSectionHeader(title: l10n.vendorsRecentBills),
        const AppDivider(),
        for (final inv in v.recentInvoices)
          _InvoiceRow(invoice: inv, currency: _currency, dateFmt: _dateFmt),
        const SizedBox(height: AppSizes.xl),
      ],
      if (v.recentStockIns.isNotEmpty) ...[
        AppSectionHeader(title: l10n.vendorsRecentStockIn),
        const AppDivider(),
        for (final s in v.recentStockIns)
          _StockInRow(
            entry: s,
            currency: _currency,
            qty: _qtyFmt,
            dateFmt: _dateFmt,
          ),
        const SizedBox(height: AppSizes.xl),
      ],
      ContactChangesSection(endpoint: '/vendors/${v.id}'),
      if (v.recentInvoices.isEmpty && v.recentStockIns.isEmpty)
        Padding(
          padding: const EdgeInsets.all(AppSizes.xl),
          child: Text(
            l10n.vendorsNoActivity,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
          ),
        ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.vendor});
  final VendorOverview vendor;

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
              AppMonogramAvatar(label: vendor.name, size: AppSizes.avatarMd),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vendor.name,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (vendor.contactName != null && vendor.contactName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          vendor.contactName!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                  ],
                ),
              ),
              if (vendor.linkedUser != null)
                AppStatusBadge(
                  label: l10n.vendorsLinked,
                  icon: AppIcons.verifiedOutlined,
                  tone: AppStatusTone.success,
                ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          if (vendor.phone != null && vendor.phone!.isNotEmpty)
            _ContactLine(icon: AppIcons.phoneOutlined, value: vendor.phone!),
          if (vendor.email != null && vendor.email!.isNotEmpty)
            _ContactLine(icon: AppIcons.emailOutlined, value: vendor.email!),
          if (vendor.address != null && vendor.address!.isNotEmpty)
            _ContactLine(icon: AppIcons.placeOutlined, value: vendor.address!),
          if (vendor.gstin != null && vendor.gstin!.isNotEmpty)
            _ContactLine(
                icon: AppIcons.badgeOutlined,
                value: '${l10n.vendorsGstin} ${vendor.gstin}'),
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
  const _Totals({required this.vendor, required this.currency});
  final VendorOverview vendor;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        children: [
          Expanded(
            child: _StatBlock(
              label: l10n.vendorsNetPurchased,
              value: currency.format(vendor.netPurchased),
              hint: '${vendor.invoiceCount} ${l10n.vendorsBillsUnit}',
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: _StatBlock(
              label: l10n.vendorsStockIns,
              value: '${vendor.stockInCount}',
              hint: l10n.vendorsLedgerRows,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: _StatBlock(
              label: l10n.vendorsReturns,
              value: currency.format(vendor.totalReturns),
              hint: '${vendor.totals.where((t) => t.type == "PURCHASE_RETURN").fold(0, (s, t) => s + t.count)} ${l10n.vendorsBillsUnit}',
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
  final VendorInvoiceRef invoice;
  final NumberFormat currency;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final itemsUnit =
        invoice.itemCount == 1 ? l10n.vendorsItemUnit : l10n.vendorsItemsUnit;
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
                      '${dateFmt.format(invoice.invoiceDate)} · ${invoice.itemCount} $itemsUnit',
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
                    tone: _toneFor(invoice.status),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  AppStatusTone _toneFor(String status) {
    if (status == 'CONFIRMED') return AppStatusTone.success;
    if (status == 'CANCELLED') return AppStatusTone.error;
    return AppStatusTone.warning;
  }
}

class _StockInRow extends StatelessWidget {
  const _StockInRow({
    required this.entry,
    required this.currency,
    required this.qty,
    required this.dateFmt,
  });
  final VendorStockInRef entry;
  final NumberFormat currency;
  final NumberFormat qty;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
                  entry.productName,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${entry.productSku} · ${dateFmt.format(entry.createdAt)}',
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
                '+${qty.format(entry.quantity)} ${entry.unit}',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (entry.totalValue != null)
                Text(
                  currency.format(entry.totalValue),
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

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.vendor, required this.currency});
  final VendorOverview vendor;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final balance = vendor.balance;
    // Vendor balance convention: positive = we owe the vendor; negative = advance.
    final positive = balance > 0;
    final settled = balance.abs() < 0.005;
    final color = settled
        ? AppColors.muted
        : (positive ? AppColors.error : AppColors.success);
    final label = settled
        ? l10n.vendorsNoOutstanding
        : positive
            ? l10n.vendorsYouOwe
            : l10n.vendorsAdvanceWithVendor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Row(
          children: [
            Icon(
              positive
                  ? AppIcons.arrowUpwardRounded
                  : settled
                      ? AppIcons.checkCircleOutlineRounded
                      : AppIcons.arrowDownwardRounded,
              color: color,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.vendorsBalanceLabel,
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

// ── Skeleton ────────────────────────────────────────────────────────────────

class _VendorDetailSkeleton extends StatelessWidget {
  const _VendorDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(
          top: AppSizes.md + FloatingAppBar.contentTopInset(context),
          bottom: AppSizes.md),
      children: const [
        _HeaderSkeleton(),
        SizedBox(height: AppSizes.lg),
        _BalanceCardSkeleton(),
        SizedBox(height: AppSizes.lg),
        _StatRowSkeleton(),
        SizedBox(height: AppSizes.xl),
        _LedgerSectionSkeleton(),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                AppShimmerLine(widthFactor: 0.6, height: AppSizes.lg),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.45, height: AppSizes.md),
                SizedBox(height: AppSizes.sm),
                AppShimmerLine(widthFactor: 0.55, height: AppSizes.md),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCardSkeleton extends StatelessWidget {
  const _BalanceCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: AppCard(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Row(
          children: [
            const AppShimmerBox(
              width: AppSizes.iconLg,
              height: AppSizes.iconLg,
              radius: AppSizes.radiusFull,
            ),
            const SizedBox(width: AppSizes.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppShimmerLine(widthFactor: 0.3, height: AppSizes.sm),
                  SizedBox(height: AppSizes.xs),
                  AppShimmerLine(widthFactor: 0.5, height: AppSizes.md),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            const AppShimmerLine(widthFactor: 0.25, height: AppSizes.xl),
          ],
        ),
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
        AppShimmerLine(widthFactor: 0.7, height: AppSizes.sm),
        SizedBox(height: AppSizes.xs),
        AppShimmerLine(widthFactor: 0.9, height: AppSizes.xl),
        SizedBox(height: AppSizes.xs),
        AppShimmerLine(widthFactor: 0.5, height: AppSizes.sm),
      ],
    );
  }
}

class _StatRowSkeleton extends StatelessWidget {
  const _StatRowSkeleton();

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

class _LedgerRowSkeleton extends StatelessWidget {
  const _LedgerRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          const AppShimmerBox(
            width: AppSizes.iconMd,
            height: AppSizes.iconMd,
            radius: AppSizes.radiusSm,
          ),
          const SizedBox(width: AppSizes.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.55, height: AppSizes.md),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.35, height: AppSizes.sm),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              AppShimmerLine(widthFactor: 0.2, height: AppSizes.md),
              SizedBox(height: AppSizes.xs),
              AppShimmerLine(widthFactor: 0.15, height: AppSizes.sm),
            ],
          ),
        ],
      ),
    );
  }
}

class _LedgerSectionSkeleton extends StatelessWidget {
  const _LedgerSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (int i = 0; i < 4; i++) ...[
              if (i > 0) const AppDivider.flush(),
              const _LedgerRowSkeleton(),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Ledger row ───────────────────────────────────────────────────────────────

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
    // Vendor side: invoice = bill we owe (credit); payment = money we paid (debit).
    final isInvoice = entry.isInvoice;
    final amount = isInvoice ? entry.credit : entry.debit;
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
            color: isInvoice ? AppColors.error : AppColors.success,
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
                '${l10n.vendorsBalShort} ${currency.format(entry.runningBalance)}',
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
