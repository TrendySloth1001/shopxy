import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/presentation/pages/create_invoice_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
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
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<InvoicesProvider>().loadInvoices();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Fetch the next page once the user scrolls within ~600px of the end.
  /// The provider guards against concurrent/exhausted loads, so an eager
  /// threshold is safe and keeps the list feeling continuous.
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 600) {
      context.read<InvoicesProvider>().loadMore();
    }
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
      backgroundColor: AppColors.surface,
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
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<InvoicesProvider>();
    final canManage = context.select<AuthProvider, bool>(
        (a) => a.user?.canManage('invoices') ?? false);
    final activeSecondary = [
      if (provider.documentTypeFilter != null) provider.documentTypeFilter!,
      if (provider.statusFilter != null) provider.statusFilter!,
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: l10n.invoicesNavTitle,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                tooltip: l10n.invoicesFiltersTooltip,
                onPressed: () => _openFilterSheet(provider),
              ),
              if (activeSecondary.isNotEmpty)
                Positioned(
                  right: AppSizes.sm,
                  top: AppSizes.sm,
                  child: Container(
                    width: AppSizes.sm,
                    height: AppSizes.sm,
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          AccessReloadButton(
              onReload: () => provider.loadInvoices(refresh: true)),
          LockedIconButton(
            allowed: canManage,
            icon: Icons.add_rounded,
            tooltip: l10n.invoicesCreateTitle,
            what: 'create invoices',
            onPressed: _openCreate,
          ),
        ],
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
        children: [
          SizedBox(height: FloatingAppBar.contentTopInset(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              0,
            ),
            child: AppSearchBar(
              hint: l10n.invoicesSearchHint,
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
                label: l10n.invoicesFilterAll,
                selected: provider.typeFilter == null,
                onTap: () => provider.setTypeFilter(null),
              ),
              AppFilterPill(
                label: l10n.invoicesFilterSales,
                icon: Icons.arrow_upward_rounded,
                selected: provider.typeFilter == 'SALE',
                onTap: () => provider.setTypeFilter(
                  provider.typeFilter == 'SALE' ? null : 'SALE',
                ),
              ),
              AppFilterPill(
                label: l10n.invoicesFilterPurchases,
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
                ? const _InvoicesListSkeleton()
                : provider.error != null && provider.invoices.isEmpty
                    ? EmptyState.line(
                        kind: LineArt.warning,
                        title: l10n.invoicesErrorTitle,
                        action: AppButton.secondary(
                          label: l10n.invoicesRetry,
                          onPressed: () =>
                              provider.loadInvoices(refresh: true),
                        ),
                      )
                    : provider.invoices.isEmpty
                        ? EmptyState.line(
                            kind: LineArt.invoice,
                            title: l10n.invoicesEmptyTitle,
                            subtitle: l10n.invoicesEmptyBody,
                            action: MaybeLocked(
                              allowed: canManage,
                              what: 'create invoices',
                              child: AppButton.primary(
                                label: l10n.invoicesCreateTitle,
                                icon: Icons.add_rounded,
                                onPressed: _openCreate,
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () =>
                                provider.loadInvoices(refresh: true),
                            color: AppColors.black,
                            backgroundColor: AppColors.surface,
                            child: ListView.separated(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(
                                AppSizes.lg,
                                AppSizes.sm,
                                AppSizes.lg,
                                100,
                              ),
                              itemCount: provider.invoices.length +
                                  (provider.hasMore ? 1 : 0),
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSizes.sm),
                              itemBuilder: (context, i) {
                                if (i >= provider.invoices.length) {
                                  return const _InvoicesLoadMoreFooter();
                                }
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
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context, Invoice invoice) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.invoicesGeneratingPdf)),
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
        messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
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

  String _documentLabel(AppLocalizations l10n, String d) => switch (d) {
        'TAX_INVOICE' => l10n.invoicesDocTaxInvoice,
        'BILL_OF_SUPPLY' => l10n.invoicesDocBillOfSupply,
        'ESTIMATE' => l10n.invoicesDocEstimate,
        'PROFORMA' => l10n.invoicesDocProforma,
        'CREDIT_NOTE' => l10n.invoicesDocCreditNote,
        'DEBIT_NOTE' => l10n.invoicesDocDebitNote,
        _ => d,
      };

  String _statusLabel(AppLocalizations l10n, String s) => switch (s) {
        'DRAFT' => l10n.invoicesStatusDraft,
        'CONFIRMED' => l10n.invoicesStatusConfirmed,
        'CANCELLED' => l10n.invoicesStatusCancelled,
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
          padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.sm, AppSizes.sm, AppSizes.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: c,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: AppSizes.xs),
              Padding(
                padding: const EdgeInsets.all(AppSizes.xs),
                child: Icon(Icons.close_rounded, size: AppSizes.iconSm, color: c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chips = <Widget>[];
    if (documentType != null) {
      chips.add(_chip(context, _documentLabel(l10n, documentType!), onClearDocumentType));
    }
    if (status != null) {
      final (c, s) = _statusColors(status!);
      chips.add(_chip(context, _statusLabel(l10n, status!), onClearStatus, color: c, soft: s));
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

  static const _documentOptions = <(String?, IconData)>[
    (null, Icons.layers_outlined),
    ('TAX_INVOICE', Icons.receipt_long_rounded),
    ('BILL_OF_SUPPLY', Icons.description_outlined),
    ('ESTIMATE', Icons.request_quote_outlined),
    ('PROFORMA', Icons.article_outlined),
    ('CREDIT_NOTE', Icons.undo_rounded),
    ('DEBIT_NOTE', Icons.redo_rounded),
  ];

  // Getter, not `static final`: the status colours are theme-aware getters, so
  // a cached list would freeze the light-mode values and not flip in dark.
  static List<(String?, Color?)> get _statusOptions => [
        (null, null),
        ('DRAFT', AppColors.warning),
        ('CONFIRMED', AppColors.success),
        ('CANCELLED', AppColors.error),
      ];

  String _documentOptionLabel(AppLocalizations l10n, String? value) =>
      switch (value) {
        null => l10n.invoicesFilterAllDocuments,
        'TAX_INVOICE' => l10n.invoicesDocTaxInvoice,
        'BILL_OF_SUPPLY' => l10n.invoicesDocBillOfSupply,
        'ESTIMATE' => l10n.invoicesDocEstimate,
        'PROFORMA' => l10n.invoicesDocProforma,
        'CREDIT_NOTE' => l10n.invoicesDocCreditNote,
        'DEBIT_NOTE' => l10n.invoicesDocDebitNote,
        _ => value,
      };

  String _statusOptionLabel(AppLocalizations l10n, String? value) =>
      switch (value) {
        null => l10n.invoicesFilterAnyStatus,
        'DRAFT' => l10n.invoicesStatusDraft,
        'CONFIRMED' => l10n.invoicesStatusConfirmed,
        'CANCELLED' => l10n.invoicesStatusCancelled,
        _ => value,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                  width: AppSizes.xxxl,
                  height: AppSizes.xs,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: AppShapes.squircleRadius(AppSizes.radiusFull),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.lg),
              Text(l10n.invoicesFiltersTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSizes.lg),
              Text(
                l10n.invoicesDocumentTypeLabel,
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
                  for (final (value, icon) in _documentOptions)
                    AppFilterPill(
                      label: _documentOptionLabel(l10n, value),
                      icon: icon,
                      selected: _documentType == value,
                      onTap: () => setState(() => _documentType = value),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.lg),
              Text(
                l10n.invoicesStatusLabel,
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
                  for (final (value, _) in _statusOptions)
                    AppFilterPill(
                      label: _statusOptionLabel(l10n, value),
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
                      label: l10n.invoicesClearAll,
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
                      label: l10n.invoicesApply,
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

// ---------------------------------------------------------------------------
// Skeleton loading state — mirrors the _InvoiceTile layout
// ---------------------------------------------------------------------------

/// Trailing item in the invoice list while more pages exist. Shows a
/// compact spinner during a fetch and a quiet placeholder otherwise, so
/// the scroll position stays stable as the next page streams in.
class _InvoicesLoadMoreFooter extends StatelessWidget {
  const _InvoicesLoadMoreFooter();

  @override
  Widget build(BuildContext context) {
    final loadingMore =
        context.select<InvoicesProvider, bool>((p) => p.isLoadingMore);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
      child: Center(
        child: SizedBox(
          height: 22,
          width: 22,
          child: loadingMore
              ? CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.muted,
                )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _InvoicesListSkeleton extends StatelessWidget {
  const _InvoicesListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        100,
      ),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: AppSizes.sm),
      itemBuilder: (context, index) => const _InvoiceTileSkeleton(),
    );
  }
}

class _InvoiceTileSkeleton extends StatelessWidget {
  const _InvoiceTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          // Icon avatar placeholder
          AppShimmerBox(
            width: AppSizes.iconHuge,
            height: AppSizes.iconHuge,
            radius: AppSizes.radiusMd,
          ),
          const SizedBox(width: AppSizes.md),
          // Left column: invoice number + badge, party name, date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: AppShimmerLine(
                        widthFactor: 0.45,
                        height: AppSizes.md,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    AppShimmerBox(
                      width: AppSizes.xxxl,
                      height: AppSizes.md,
                      radius: AppSizes.radiusFull,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.6, height: AppSizes.sm),
                const SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.35, height: AppSizes.sm),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          // Right column: amount and item count
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppShimmerLine(widthFactor: 1.0, height: AppSizes.md),
              const SizedBox(height: AppSizes.xs),
              AppShimmerLine(widthFactor: 0.7, height: AppSizes.sm),
              const SizedBox(height: AppSizes.xs),
              // Placeholder for the download icon button area
              AppShimmerBox(
                width: AppSizes.iconMd + AppSizes.sm,
                height: AppSizes.iconMd + AppSizes.sm,
                radius: AppSizes.radiusSm,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final df = DateFormat('dd MMM yyyy');
    final count = invoice.itemCount ?? invoice.items.length;

    return Material(
      color: AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusLg,
        side: BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
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
                size: AppSizes.iconHuge,
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
                    const SizedBox(height: AppSizes.xs),
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
                    '$count ${count == 1 ? l10n.invoicesItemUnit : l10n.invoicesItemsUnit}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: AppSizes.iconMd),
                    onPressed: onDownload,
                    tooltip: l10n.invoicesDownloadTooltip,
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
