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

/// Cycle order for the single status chip: ALL → DRAFT → CONFIRMED →
/// CANCELLED → ALL. Tapping the chip walks through this loop, which
/// keeps the filter row tight without losing the option to slice by
/// status.
const _statusCycle = <String?>[null, 'DRAFT', 'CONFIRMED', 'CANCELLED'];

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

  void _cycleStatus(InvoicesProvider provider) {
    final i = _statusCycle.indexOf(provider.statusFilter);
    final next = _statusCycle[(i + 1) % _statusCycle.length];
    provider.setStatusFilter(next);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InvoicesProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text(AppStrings.navInvoices),
        actions: [
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
          _StatusChipRow(
            current: provider.statusFilter,
            onCycle: () => _cycleStatus(provider),
            onClear: () => provider.setStatusFilter(null),
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

/// Single chip that cycles through DRAFT / CONFIRMED / CANCELLED / ALL.
/// When a real status is selected the chip carries that status's color
/// so the active filter is obvious from across the room. A close
/// affordance appears so the user can clear without cycling all the way
/// through.
class _StatusChipRow extends StatelessWidget {
  const _StatusChipRow({
    required this.current,
    required this.onCycle,
    required this.onClear,
  });
  final String? current;
  final VoidCallback onCycle;
  final VoidCallback onClear;

  (String, Color, Color) _visual(String? s) {
    switch (s) {
      case 'DRAFT':
        return ('Draft', AppColors.warning, AppColors.warningSoft);
      case 'CONFIRMED':
        return ('Confirmed', AppColors.success, AppColors.successSoft);
      case 'CANCELLED':
        return ('Cancelled', AppColors.error, AppColors.errorSoft);
      default:
        return ('Any status', AppColors.muted, AppColors.surfaceTint);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, soft) = _visual(current);
    final active = current != null;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        0,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          Text(
            'Status',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Material(
            color: soft,
            shape: AppShapes.squircle(
              AppSizes.radiusFull,
              side: BorderSide(color: active ? color : AppColors.hairline),
            ),
            child: InkWell(
              customBorder: AppShapes.squircle(AppSizes.radiusFull),
              onTap: onCycle,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.md,
                  6,
                  active ? 4 : AppSizes.md,
                  6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    if (active) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onClear,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.close_rounded, size: 14, color: color),
                        ),
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          Icons.unfold_more_rounded,
                          size: 14,
                          color: color,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
