import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_filter_pill.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/widgets/section_divider.dart';

/// Documents the merchant filed out of the working list.
///
/// They are not deleted and cannot be: the serial is allocated at create time
/// and Rule 46(b) needs the run consecutive, so every archived row still holds
/// its number. This screen is the way back — restoring returns the document to
/// the invoice list unchanged.
///
/// Self-contained rather than a mode on `InvoicesProvider`: that provider backs
/// the main list (and is reset on logout), and giving it a second meaning would
/// make "which list am I holding?" ambiguous for every reader of it.
class ArchivedInvoicesPage extends StatefulWidget {
  const ArchivedInvoicesPage({super.key});

  @override
  State<ArchivedInvoicesPage> createState() => _ArchivedInvoicesPageState();
}

class _ArchivedInvoicesPageState extends State<ArchivedInvoicesPage> {
  List<Invoice> _items = [];
  bool _loading = true;
  String? _error;
  final _restoring = <String>{};

  /// Same primary axis the invoice list filters on — direction of money.
  /// Null is "All". Applied server-side rather than over the loaded page so
  /// the filter still means something once there are more than [_limit]
  /// archived documents.
  String? _typeFilter;

  static const _limit = 100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context
          .read<InvoicesRemoteDataSource>()
          .getInvoicesPage(archived: true, type: _typeFilter, limit: _limit);
      if (!mounted) return;
      setState(() {
        _items = page.items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  void _setTypeFilter(String? type) {
    if (_typeFilter == type) return;
    setState(() => _typeFilter = type);
    _load();
  }

  Future<void> _restore(Invoice invoice) async {
    if (_restoring.contains(invoice.id)) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _restoring.add(invoice.id));
    try {
      await context.read<InvoicesRemoteDataSource>().setArchived(
        invoice.id,
        false,
      );
      if (!mounted) return;
      setState(() {
        _items = _items.where((i) => i.id != invoice.id).toList();
        _restoring.remove(invoice.id);
      });
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.invoicesRestoredNamed(invoice.invoiceNo))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _restoring.remove(invoice.id));
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.invoicesArchivedFilter),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
            AppFilterStrip(
              children: [
                AppFilterPill(
                  label: l10n.invoicesFilterAll,
                  selected: _typeFilter == null,
                  onTap: () => _setTypeFilter(null),
                ),
                AppFilterPill(
                  label: l10n.invoicesFilterSales,
                  icon: AppIcons.arrowUpwardRounded,
                  selected: _typeFilter == 'SALE',
                  onTap: () =>
                      _setTypeFilter(_typeFilter == 'SALE' ? null : 'SALE'),
                ),
                AppFilterPill(
                  label: l10n.invoicesFilterPurchases,
                  icon: AppIcons.arrowDownwardRounded,
                  selected: _typeFilter == 'PURCHASE',
                  onTap: () => _setTypeFilter(
                    _typeFilter == 'PURCHASE' ? null : 'PURCHASE',
                  ),
                ),
              ],
            ),
            const AppDivider.flush(),
            Expanded(
              child: RefreshIndicator(onRefresh: _load, child: _body(l10n)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l10n) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return AppErrorView(message: _error, onRetry: _load);
    }
    if (_items.isEmpty) {
      // Always scrollable so pull-to-refresh still works on an empty list.
      return ListView(
        padding: const EdgeInsets.only(top: AppSizes.huge),
        children: [
          EmptyState(
            icon: AppIcons.archiveOutlined,
            title: l10n.invoicesArchivedEmptyTitle,
            subtitle: l10n.invoicesArchivedEmptyBody,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.huge,
      ),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSizes.sm),
      itemBuilder: (context, i) {
        final invoice = _items[i];
        // Grouped by invoiceDate, matching the main list and the server's
        // ordering — group by anything the list isn't sorted on and the day
        // headings repeat as you scroll.
        final newDay =
            i == 0 ||
            !SectionDivider.isSameDay(
              invoice.invoiceDate,
              _items[i - 1].invoiceDate,
            );
        final tile = _ArchivedRow(
          invoice: invoice,
          busy: _restoring.contains(invoice.id),
          // Reload on return: the detail page can restore the document, which
          // takes it out of this list.
          onOpen: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InvoiceDetailPage(invoiceId: invoice.id),
              ),
            );
            if (mounted) await _load();
          },
          onRestore: () => _restore(invoice),
        );
        if (!newDay) return tile;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [SectionDivider.date(invoice.invoiceDate), tile],
        );
      },
    );
  }
}

class _ArchivedRow extends StatelessWidget {
  const _ArchivedRow({
    required this.invoice,
    required this.busy,
    required this.onOpen,
    required this.onRestore,
  });

  final Invoice invoice;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final counterparty = invoice.isSale
        ? (invoice.customerName ?? '—')
        : (invoice.vendorName ?? '—');

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      onTap: onOpen,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        invoice.invoiceNo,
                        style: theme.textTheme.bodyMedium?.semibold,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    // The number is the point: it stays allocated, which is
                    // what makes archiving legal where deleting wasn't.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.sm,
                        vertical: 1,
                      ),
                      decoration: ShapeDecoration(
                        color: AppColors.heroPanel,
                        shape: AppShapes.squircle(AppSizes.radiusFull),
                      ),
                      child: Text(
                        invoice.status,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // The date moved into the day divider above, so the row keeps
                // only what differs between rows in the same group.
                Text(
                  counterparty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                  overflow: TextOverflow.ellipsis,
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
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              busy
                  ? const SizedBox(
                      width: AppSizes.iconSm,
                      height: AppSizes.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : TextButton.icon(
                      onPressed: onRestore,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: AppIcon(
                        AppIcons.unarchiveRounded,
                        size: AppSizes.iconSm,
                        color: AppColors.brandStrong,
                      ),
                      label: Text(
                        l10n.invoicesRestore,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.brandStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
