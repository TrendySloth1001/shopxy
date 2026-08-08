import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/widgets/archived_documents_page.dart';

/// Invoices the merchant filed out of the working list.
///
/// Self-contained rather than a mode on `InvoicesProvider`: that provider
/// backs the main list (and is reset on logout), and giving it a second
/// meaning would make "which list am I holding?" ambiguous for every reader.
class ArchivedInvoicesPage extends StatelessWidget {
  const ArchivedInvoicesPage({super.key});

  /// Enough to cover any realistic archive without paging; the list is a
  /// filing cabinet, not a working queue.
  static const _limit = 100;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final source = context.read<InvoicesRemoteDataSource>();

    return ArchivedDocumentsPage<Invoice>(
      title: l10n.archivedTitle,
      emptyTitle: l10n.invoicesArchivedEmptyTitle,
      emptyBody: l10n.invoicesArchivedEmptyBody,
      // Same primary axis the invoice list filters on — direction of money.
      // Applied server-side rather than over the loaded page so the filter
      // still means something past the fetch limit.
      filters: [
        ArchivedFilter(label: l10n.invoicesFilterAll),
        ArchivedFilter(
          label: l10n.invoicesFilterSales,
          value: 'SALE',
          icon: AppIcons.arrowUpwardRounded,
        ),
        ArchivedFilter(
          label: l10n.invoicesFilterPurchases,
          value: 'PURCHASE',
          icon: AppIcons.arrowDownwardRounded,
        ),
      ],
      load: (filter) async {
        final page = await source.getInvoicesPage(
          archived: true,
          type: filter,
          limit: _limit,
        );
        return page.items;
      },
      restore: (invoice) => source.setArchived(invoice.id, false),
      // Grouped by invoiceDate — what the server sorts on, and the day
      // printed on the document.
      dateOf: (invoice) => invoice.invoiceDate,
      rowOf: (invoice) => ArchivedRowData(
        number: invoice.invoiceNo,
        status: invoice.status,
        subtitle: invoice.isSale
            ? (invoice.customerName ?? '—')
            : (invoice.vendorName ?? '—'),
        trailing:
            '${AppStrings.currencySymbol}${invoice.total.toStringAsFixed(2)}',
      ),
      onOpen: (context, invoice) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InvoiceDetailPage(invoiceId: invoice.id),
        ),
      ),
    );
  }
}
