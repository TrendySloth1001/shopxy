import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/challans/data/datasources/challans_remote_data_source.dart';
import 'package:shopxy/features/challans/domain/entities/challan.dart';
import 'package:shopxy/features/challans/presentation/providers/challans_provider.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';

class ChallanDetailPage extends StatefulWidget {
  const ChallanDetailPage({super.key, required this.challanId});
  final int challanId;

  @override
  State<ChallanDetailPage> createState() => _ChallanDetailPageState();
}

class _ChallanDetailPageState extends State<ChallanDetailPage> {
  Challan? _challan;
  bool _isLoading = true;
  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ds = context.read<ChallansRemoteDataSource>();
      final challan = await ds.getChallanById(widget.challanId);
      if (mounted) setState(() { _challan = challan; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.cancelChallan),
        content: const Text(AppStrings.cancelChallanConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(AppStrings.no)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.yes, style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<ChallansProvider>();
    try {
      await provider.cancelChallan(widget.challanId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _convertToInvoice() async {
    setState(() => _isConverting = true);
    final provider = context.read<ChallansProvider>();
    try {
      final invoice = await provider.convertToInvoice(widget.challanId);
      if (!mounted) return;
      final invoiceId = invoice['id'] as int;
      // Replace current page with invoice detail so owner can review + confirm
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoiceId: invoiceId)),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isConverting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_challan == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text(AppStrings.error)));
    }

    final c = _challan!;
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(c.challanNo),
        actions: [
          if (c.isPending)
            PopupMenuButton<String>(
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text(AppStrings.cancelChallan),
                ),
              ],
              onSelected: (v) { if (v == 'cancel') _cancel(); },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.lg),
        children: [
          // Header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.challanNo,
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _StatusBadge(status: c.status),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    df.format(c.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _InfoRow(label: AppStrings.partyName, value: c.partyName),
                  if (c.partyPhone != null)
                    _InfoRow(label: AppStrings.phone, value: c.partyPhone!),
                  if (c.note != null && c.note!.isNotEmpty)
                    _InfoRow(label: AppStrings.note, value: c.note!),
                  if (c.isConverted && c.invoice != null) ...[
                    const SizedBox(height: AppSizes.sm),
                    _InfoRow(label: AppStrings.challanLinkedInvoice, value: c.invoice!.invoiceNo),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSizes.md),

          // Items section
          Text(
            AppStrings.challanItems,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Card(
            child: Column(
              children: c.items.isEmpty
                  ? [
                      const ListTile(
                        title: Text(AppStrings.challanEmptyItems),
                      )
                    ]
                  : c.items
                      .map((item) => ListTile(
                            dense: true,
                            title: Text(
                              item.productName,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(item.productSku),
                            trailing: Text(
                              '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity} ${item.unit}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ))
                      .toList(),
            ),
          ),

          const SizedBox(height: AppSizes.huge),
        ],
      ),
      // Convert to invoice button — only for owner (shown when PENDING)
      bottomNavigationBar: c.isPending
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: FilledButton.icon(
                  onPressed: _isConverting ? null : _convertToInvoice,
                  icon: _isConverting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.receipt_long_rounded),
                  label: const Text(AppStrings.convertToInvoice),
                ),
              ),
            )
          : null,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    switch (status) {
      case 'CONVERTED':
        color = const Color(0xFF1F8A5B);
      case 'CANCELLED':
        color = theme.colorScheme.error;
      default:
        color = theme.colorScheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: AppSizes.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
