import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/presentation/pages/create_invoice_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InvoicesProvider>().loadInvoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoicesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.navInvoices),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: AppStrings.filter,
            onSelected: (value) {
              if (value == 'all') {
                provider.setTypeFilter(null);
              } else {
                provider.setTypeFilter(value);
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'all', child: Text('All Invoices')),
              const PopupMenuItem(value: 'SALE', child: Text('Sales Only')),
              const PopupMenuItem(
                value: 'PURCHASE',
                child: Text('Purchases Only'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const CreateInvoicePage()),
          );
          if (created == true && context.mounted) {
            context.read<InvoicesProvider>().loadInvoices(refresh: true);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(AppStrings.createInvoice),
      ),
      body: Column(
        children: [
          if (provider.typeFilter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.md,
                AppSizes.lg,
                0,
              ),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      provider.typeFilter == 'SALE'
                          ? AppStrings.saleInvoice
                          : AppStrings.purchaseInvoice,
                    ),
                    onDeleted: () => provider.setTypeFilter(null),
                  ),
                ],
              ),
            ),
          Expanded(
            child: provider.isLoading && provider.invoices.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null && provider.invoices.isEmpty
                ? Center(
                    child: EmptyState(
                      icon: Icons.error_outline_rounded,
                      title: AppStrings.error,
                      action: TextButton(
                        onPressed: () => provider.loadInvoices(refresh: true),
                        child: const Text(AppStrings.retry),
                      ),
                    ),
                  )
                : provider.invoices.isEmpty
                ? EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: AppStrings.noInvoices,
                    subtitle: AppStrings.noInvoicesHint,
                    action: FilledButton.icon(
                      onPressed: () async {
                        final created = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CreateInvoicePage(),
                          ),
                        );
                        if (created == true && context.mounted) {
                          context.read<InvoicesProvider>().loadInvoices(
                            refresh: true,
                          );
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(AppStrings.createInvoice),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => provider.loadInvoices(refresh: true),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.lg,
                        AppSizes.md,
                        AppSizes.lg,
                        100,
                      ),
                      itemCount: provider.invoices.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSizes.sm),
                      itemBuilder: (context, i) {
                        final invoice = provider.invoices[i];
                        return _InvoiceTile(
                          invoice: invoice,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  InvoiceDetailPage(invoiceId: invoice.id),
                            ),
                          ),
                          onDownload: () => _downloadPdf(context, invoice),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context, Invoice invoice) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text(AppStrings.generatingPdf)),
    );

    try {
      final ds = context.read<InvoicesRemoteDataSource>();
      final response = await ds.downloadPdf(invoice.id);

      if (response.statusCode != 200) throw Exception('Failed to generate PDF');

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${invoice.invoiceNo}.pdf');
      await file.writeAsBytes(response.bodyBytes);

      await OpenFilex.open(file.path);
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
    required this.invoice,
    required this.onTap,
    required this.onDownload,
  });

  final Invoice invoice;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd MMM yyyy');

    Color statusColor;
    switch (invoice.status) {
      case 'CONFIRMED':
        statusColor = const Color(0xFF1F8A5B);
      case 'CANCELLED':
        statusColor = theme.colorScheme.error;
      default:
        statusColor = theme.colorScheme.onSurfaceVariant;
    }

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: invoice.isSale
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Icon(
                  invoice.isSale
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: invoice.isSale
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          invoice.invoiceNo,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusSm,
                            ),
                          ),
                          child: Text(
                            invoice.status,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(invoice.partyName, style: theme.textTheme.bodySmall),
                    Text(
                      df.format(invoice.invoiceDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${AppStrings.currencySymbol}${invoice.total.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${invoice.itemCount ?? invoice.items.length} items',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.download_rounded,
                      size: AppSizes.iconMd,
                    ),
                    onPressed: onDownload,
                    tooltip: AppStrings.downloadInvoice,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
