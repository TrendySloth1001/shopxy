import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});
  final int invoiceId;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  Invoice? _invoice;
  bool _isLoading = true;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ds = context.read<InvoicesRemoteDataSource>();
      final invoice = await ds.getInvoiceById(widget.invoiceId);
      if (mounted) {
        setState(() {
          _invoice = invoice;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_invoice == null) return;
    setState(() => _isDownloading = true);
    final invoiceNo = _invoice!.invoiceNo;
    final ds = context.read<InvoicesRemoteDataSource>();
    try {
      final response = await ds.downloadPdf(widget.invoiceId);
      if (response.statusCode != 200) throw Exception('Failed to generate PDF');
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$invoiceNo.pdf');
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    final provider = context.read<InvoicesProvider>();
    try {
      final updated = await provider.updateStatus(widget.invoiceId, status);
      if (mounted) setState(() => _invoice = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text(AppStrings.error)),
      );
    }

    final invoice = _invoice!;
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.invoiceNo),
        actions: [
          if (!_isDownloading)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: AppStrings.downloadInvoice,
              onPressed: _downloadPdf,
            )
          else
            const Padding(
              padding: EdgeInsets.all(AppSizes.md),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (invoice.isDraft) ...[
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded),
              tooltip: AppStrings.confirmInvoice,
              onPressed: () => _updateStatus('CONFIRMED'),
            ),
          ],
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              if (invoice.isDraft)
                const PopupMenuItem(
                  value: 'CANCELLED',
                  child: Text(AppStrings.cancelInvoice),
                ),
              if (!invoice.isConfirmed)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(AppStrings.delete),
                ),
            ],
            onSelected: (v) async {
              if (v == 'delete') {
                await context.read<InvoicesProvider>().deleteInvoice(
                  invoice.id,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
              } else {
                _updateStatus(v);
              }
            },
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
                          invoice.invoiceNo,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _StatusBadge(status: invoice.status),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    invoice.isSale
                        ? AppStrings.saleInvoice
                        : AppStrings.purchaseInvoice,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    df.format(invoice.invoiceDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSizes.md),
                  _InfoRow(
                    label: invoice.isSale
                        ? AppStrings.customer
                        : AppStrings.vendor,
                    value: invoice.partyName,
                  ),
                  if (invoice.isSale && invoice.customerPhone != null)
                    _InfoRow(
                      label: AppStrings.phone,
                      value: invoice.customerPhone!,
                    ),
                  if (invoice.isSale && invoice.customerGstin != null)
                    _InfoRow(
                      label: AppStrings.gstin,
                      value: invoice.customerGstin!,
                    ),
                  if (invoice.isPurchase && invoice.vendor?.name != null)
                    _InfoRow(
                      label: AppStrings.vendor,
                      value: invoice.vendor!.name,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),

          // Items
          Text(
            AppStrings.invoiceItems,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Card(
            child: Column(
              children: invoice.items
                  .map((item) => _ItemTile(item: item))
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSizes.md),

          // Totals
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                children: [
                  _TotalRow(
                    label: AppStrings.subtotal,
                    value: invoice.subtotal,
                  ),
                  _TotalRow(
                    label: AppStrings.taxAmount,
                    value: invoice.taxAmount,
                  ),
                  if (invoice.discount > 0)
                    _TotalRow(
                      label: AppStrings.discount,
                      value: -invoice.discount,
                    ),
                  const Divider(),
                  _TotalRow(
                    label: AppStrings.total,
                    value: invoice.total,
                    isHighlight: true,
                  ),
                ],
              ),
            ),
          ),

          if (invoice.note != null && invoice.note!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.note,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(invoice.note!),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSizes.huge),
        ],
      ),
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
      case 'CONFIRMED':
        color = const Color(0xFF1F8A5B);
      case 'CANCELLED':
        color = theme.colorScheme.error;
      default:
        color = theme.colorScheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Text(
        status,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final InvoiceItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      title: Text(
        item.productName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        '${item.quantity} ${item.unit} × ${AppStrings.currencySymbol}${item.unitPrice.toStringAsFixed(2)}'
        '${item.taxPercent > 0 ? ' + ${item.taxPercent.toStringAsFixed(0)}% GST' : ''}',
      ),
      trailing: Text(
        '${AppStrings.currencySymbol}${item.total.toStringAsFixed(2)}',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });
  final String label;
  final double value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isHighlight
                ? theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )
                : theme.textTheme.bodyMedium,
          ),
          Text(
            '${value < 0 ? '-' : ''}${AppStrings.currencySymbol}${value.abs().toStringAsFixed(2)}',
            style: isHighlight
                ? theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
          ),
        ],
      ),
    );
  }
}
