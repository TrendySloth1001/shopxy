import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/presentation/pages/create_invoice_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_filter_pill.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InvoicesProvider>().loadInvoices();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreate() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateInvoicePage()),
    );
    if (created == true && mounted) {
      context.read<InvoicesProvider>().loadInvoices(refresh: true);
    }
  }

  Future<void> _openFilterSheet(InvoicesProvider provider) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.bottomSheetRadius)),
      ),
      builder: (_) => _InvoiceFilterSheet(
        documentType: provider.documentTypeFilter,
        status: provider.statusFilter,
        onApply: (doc, status) {
          provider.setDocumentTypeFilter(doc);
          provider.setStatusFilter(status);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoicesProvider>();
    final activeSecondary = [
      if (provider.documentTypeFilter != null) provider.documentTypeFilter!,
      if (provider.statusFilter != null) provider.statusFilter!,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text(AppStrings.navInvoices),
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: 'Filters',
                onPressed: () => _openFilterSheet(provider),
              ),
              if (activeSecondary.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: AppStrings.createInvoice,
            onPressed: _openCreate,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              0,
            ),
            child: AppSearchBar(
              hint: AppStrings.searchInvoices,
              controller: _searchCtrl,
              onChanged: provider.updateSearch,
            ),
          ),
          // Primary axis filter — direction of money. Document type +
          // status live in the filter sheet (tune icon in the AppBar)
          // since they're orthogonal and would crowd the header.
          AppFilterStrip(
            children: [
              AppFilterPill(
                label: AppStrings.filterAll,
                selected: provider.typeFilter == null,
                onTap: () => provider.setTypeFilter(null),
              ),
              AppFilterPill(
                label: AppStrings.invoiceTypeSale,
                icon: Icons.arrow_upward_rounded,
                selected: provider.typeFilter == 'SALE',
                onTap: () => provider.setTypeFilter(
                  provider.typeFilter == 'SALE' ? null : 'SALE',
                ),
              ),
              AppFilterPill(
                label: AppStrings.invoiceTypePurchase,
                icon: Icons.arrow_downward_rounded,
                selected: provider.typeFilter == 'PURCHASE',
                onTap: () => provider.setTypeFilter(
                  provider.typeFilter == 'PURCHASE' ? null : 'PURCHASE',
                ),
              ),
            ],
          ),
          if (activeSecondary.isNotEmpty)
            _ActiveSecondaryFiltersRow(
              documentType: provider.documentTypeFilter,
              status: provider.statusFilter,
              onClearDocumentType: () => provider.setDocumentTypeFilter(null),
              onClearStatus: () => provider.setStatusFilter(null),
            ),
          const AppDivider.flush(),
          Expanded(
            child: provider.isLoading && provider.invoices.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null && provider.invoices.isEmpty
                    ? EmptyState.line(
                        kind: LineArt.warning,
                        title: AppStrings.error,
                        action: AppButton.secondary(
                          label: AppStrings.retry,
                          onPressed: () =>
                              provider.loadInvoices(refresh: true),
                        ),
                      )
                    : provider.invoices.isEmpty
                        ? EmptyState.line(
                            kind: LineArt.invoice,
                            title: AppStrings.noInvoices,
                            subtitle: AppStrings.noInvoicesHint,
                            action: AppButton.primary(
                              label: AppStrings.createInvoice,
                              icon: Icons.add_rounded,
                              onPressed: _openCreate,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () =>
                                provider.loadInvoices(refresh: true),
                            color: AppColors.black,
                            backgroundColor: AppColors.white,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSizes.sm,
                              ).copyWith(bottom: 100),
                              itemCount: provider.invoices.length,
                              separatorBuilder: (_, _) => const AppDivider(),
                              itemBuilder: (context, i) {
                                final invoice = provider.invoices[i];
                                return _InvoiceTile(
                                  invoice: invoice,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => InvoiceDetailPage(
                                        invoiceId: invoice.id,
                                      ),
                                    ),
                                  ),
                                  onDownload: () =>
                                      _downloadPdf(context, invoice),
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

/// Inline row showing the secondary filters (document type + status) as
/// removable chips so the user can see at a glance what's filtered and
/// kill any single facet without re-opening the sheet.
class _ActiveSecondaryFiltersRow extends StatelessWidget {
  const _ActiveSecondaryFiltersRow({
    this.documentType,
    this.status,
    required this.onClearDocumentType,
    required this.onClearStatus,
  });

  final String? documentType;
  final String? status;
  final VoidCallback onClearDocumentType;
  final VoidCallback onClearStatus;

  String _documentLabel(String d) => switch (d) {
        'TAX_INVOICE' => 'Tax Invoice',
        'BILL_OF_SUPPLY' => 'Bill of Supply',
        'ESTIMATE' => 'Estimate',
        'PROFORMA' => 'Proforma',
        'CREDIT_NOTE' => 'Credit Note',
        'DEBIT_NOTE' => 'Debit Note',
        _ => d,
      };

  String _statusLabel(String s) => switch (s) {
        'DRAFT' => 'Draft',
        'CONFIRMED' => 'Confirmed',
        'CANCELLED' => 'Cancelled',
        _ => s,
      };

  (Color, Color) _statusColors(String s) => switch (s) {
        'DRAFT' => (AppColors.warning, AppColors.warningSoft),
        'CONFIRMED' => (AppColors.success, AppColors.successSoft),
        'CANCELLED' => (AppColors.error, AppColors.errorSoft),
        _ => (AppColors.muted, AppColors.surfaceTint),
      };

  Widget _chip(BuildContext context, String label, VoidCallback onClear,
      {Color? color, Color? soft}) {
    final c = color ?? AppColors.brandStrong;
    final s = soft ?? AppColors.brandSoft;
    return Material(
      color: s,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: BorderSide(color: c),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onClear,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSizes.md, 6, 6, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: c,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close_rounded, size: 14, color: c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (documentType != null) {
      chips.add(_chip(context, _documentLabel(documentType!), onClearDocumentType));
    }
    if (status != null) {
      final (c, s) = _statusColors(status!);
      chips.add(_chip(context, _statusLabel(status!), onClearStatus, color: c, soft: s));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, 0, AppSizes.lg, AppSizes.sm),
      child: Wrap(
        spacing: AppSizes.sm,
        runSpacing: AppSizes.xs,
        children: chips,
      ),
    );
  }
}

/// Bottom sheet that consolidates the orthogonal invoice filters
/// (document type + status). Picks are buffered locally and only
/// pushed to the provider on Apply, so the user can experiment
/// without spamming reloads.
class _InvoiceFilterSheet extends StatefulWidget {
  const _InvoiceFilterSheet({
    required this.documentType,
    required this.status,
    required this.onApply,
  });

  final String? documentType;
  final String? status;
  final void Function(String? documentType, String? status) onApply;

  @override
  State<_InvoiceFilterSheet> createState() => _InvoiceFilterSheetState();
}

class _InvoiceFilterSheetState extends State<_InvoiceFilterSheet> {
  late String? _documentType = widget.documentType;
  late String? _status = widget.status;

  static const _documentOptions = <(String?, String, IconData)>[
    (null, 'All documents', Icons.layers_outlined),
    ('TAX_INVOICE', 'Tax Invoice', Icons.receipt_long_rounded),
    ('BILL_OF_SUPPLY', 'Bill of Supply', Icons.description_outlined),
    ('ESTIMATE', 'Estimate', Icons.request_quote_outlined),
    ('PROFORMA', 'Proforma', Icons.article_outlined),
    ('CREDIT_NOTE', 'Credit Note', Icons.undo_rounded),
    ('DEBIT_NOTE', 'Debit Note', Icons.redo_rounded),
  ];

  static const _statusOptions = <(String?, String, Color?)>[
    (null, 'Any status', null),
    ('DRAFT', 'Draft', AppColors.warning),
    ('CONFIRMED', 'Confirmed', AppColors.success),
    ('CANCELLED', 'Cancelled', AppColors.error),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              Text('Filters', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSizes.lg),
              Text(
                'Document type',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.muted,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Wrap(
                spacing: AppSizes.sm,
                runSpacing: AppSizes.sm,
                children: [
                  for (final (value, label, icon) in _documentOptions)
                    AppFilterPill(
                      label: label,
                      icon: icon,
                      selected: _documentType == value,
                      onTap: () => setState(() => _documentType = value),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              Text(
                'Status',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.muted,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              Wrap(
                spacing: AppSizes.sm,
                runSpacing: AppSizes.sm,
                children: [
                  for (final (value, label, _) in _statusOptions)
                    AppFilterPill(
                      label: label,
                      selected: _status == value,
                      onTap: () => setState(() => _status = value),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.xl),
              Row(
                children: [
                  Expanded(
                    child: AppButton.secondary(
                      label: 'Clear all',
                      onPressed: () => setState(() {
                        _documentType = null;
                        _status = null;
                      }),
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    flex: 2,
                    child: AppButton.primary(
                      label: 'Apply',
                      onPressed: () {
                        widget.onApply(_documentType, _status);
                        Navigator.pop(context);
                      },
                    ),
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

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({
    required this.invoice,
    required this.onTap,
    required this.onDownload,
  });

  final Invoice invoice;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  AppStatusTone get _statusTone {
    switch (invoice.status) {
      case 'CONFIRMED':
        return AppStatusTone.success;
      case 'CANCELLED':
        return AppStatusTone.error;
      default:
        return AppStatusTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd MMM yyyy');

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.surfaceTint,
        highlightColor: AppColors.surfaceTint,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
            children: [
              AppIconAvatar(
                icon: invoice.isSale
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 44,
                filled: invoice.isSale,
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            invoice.invoiceNo,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        AppStatusBadge(
                          label: invoice.status,
                          tone: _statusTone,
                          dense: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      invoice.partyName,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      df.format(invoice.invoiceDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
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
                      color: AppColors.muted,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: AppSizes.iconMd),
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
