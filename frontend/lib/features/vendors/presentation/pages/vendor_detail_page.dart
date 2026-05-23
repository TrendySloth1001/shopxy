import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/vendors/data/datasources/vendors_remote_data_source.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor_overview.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

class VendorDetailPage extends StatefulWidget {
  const VendorDetailPage({super.key, required this.vendorId});
  final int vendorId;

  @override
  State<VendorDetailPage> createState() => _VendorDetailPageState();
}

class _VendorDetailPageState extends State<VendorDetailPage> {
  VendorOverview? _overview;
  bool _isLoading = true;
  String? _error;

  static final _currency =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
  static final _dateFmt = DateFormat('d MMM y');
  static final _qtyFmt = NumberFormat.decimalPattern('en_IN');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ds = context.read<VendorsRemoteDataSource>();
      final overview = await ds.getVendorOverview(widget.vendorId);
      if (mounted) {
        setState(() {
          _overview = overview;
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
      appBar: AppBar(title: const Text('Vendor')),
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

  List<Widget> _buildBody(VendorOverview v) {
    final theme = Theme.of(context);

    return [
      _Header(vendor: v),
      const SizedBox(height: AppSizes.lg),
      _Totals(vendor: v, currency: _currency),
      const SizedBox(height: AppSizes.xl),
      if (v.recentInvoices.isNotEmpty) ...[
        const AppSectionHeader(title: 'Recent bills'),
        const AppDivider(),
        for (final inv in v.recentInvoices)
          _InvoiceRow(invoice: inv, currency: _currency, dateFmt: _dateFmt),
        const SizedBox(height: AppSizes.xl),
      ],
      if (v.recentStockIns.isNotEmpty) ...[
        const AppSectionHeader(title: 'Recent stock-in'),
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
      if (v.recentInvoices.isEmpty && v.recentStockIns.isEmpty)
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
  const _Header({required this.vendor});
  final VendorOverview vendor;

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
              AppMonogramAvatar(label: vendor.name, size: 56),
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
                const AppStatusBadge(
                  label: 'Linked',
                  icon: Icons.verified_outlined,
                  tone: AppStatusTone.success,
                ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          if (vendor.phone != null && vendor.phone!.isNotEmpty)
            _ContactLine(icon: Icons.phone_outlined, value: vendor.phone!),
          if (vendor.email != null && vendor.email!.isNotEmpty)
            _ContactLine(icon: Icons.email_outlined, value: vendor.email!),
          if (vendor.address != null && vendor.address!.isNotEmpty)
            _ContactLine(icon: Icons.place_outlined, value: vendor.address!),
          if (vendor.gstin != null && vendor.gstin!.isNotEmpty)
            _ContactLine(
                icon: Icons.badge_outlined, value: 'GSTIN ${vendor.gstin}'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        children: [
          Expanded(
            child: _StatBlock(
              label: 'Net purchased',
              value: currency.format(vendor.netPurchased),
              hint: '${vendor.invoiceCount} bills',
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: _StatBlock(
              label: 'Stock-ins',
              value: '${vendor.stockInCount}',
              hint: 'Ledger rows',
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: _StatBlock(
              label: 'Returns',
              value: currency.format(vendor.totalReturns),
              hint: '${vendor.totals.where((t) => t.type == "PURCHASE_RETURN").fold(0, (s, t) => s + t.count)} bills',
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
