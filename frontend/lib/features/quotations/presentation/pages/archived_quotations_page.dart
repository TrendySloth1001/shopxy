import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/quotations/data/datasources/quotations_remote_data_source.dart';
import 'package:shopxy/features/quotations/domain/entities/quotation.dart';
import 'package:shopxy/features/quotations/presentation/pages/quotation_detail_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/widgets/archived_documents_page.dart';

class ArchivedQuotationsPage extends StatelessWidget {
  const ArchivedQuotationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final source = context.read<QuotationsRemoteDataSource>();

    return ArchivedDocumentsPage<Quotation>(
      title: l10n.archivedTitle,
      emptyTitle: l10n.quotationsArchivedEmptyTitle,
      emptyBody: l10n.quotationsArchivedEmptyBody,
      filters: [
        ArchivedFilter(label: l10n.quotationsFilterAll),
        ArchivedFilter(
          label: l10n.quotationsFilterAccepted,
          value: 'ACCEPTED',
        ),
        ArchivedFilter(
          label: l10n.quotationsFilterDeclined,
          value: 'DECLINED',
        ),
        ArchivedFilter(
          label: l10n.quotationsFilterCancelled,
          value: 'CANCELLED',
        ),
      ],
      load: (filter) => source.list(archived: true, status: filter),
      restore: (quotation) => source.setArchived(quotation.id, false),
      dateOf: (quotation) => quotation.createdAt,
      rowOf: (quotation) => ArchivedRowData(
        number: quotation.quotationNo,
        status: quotation.status,
        subtitle: quotation.partyName,
        trailing:
            '${AppStrings.currencySymbol}${quotation.total.toStringAsFixed(2)}',
      ),
      onOpen: (context, quotation) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuotationDetailPage(quotation: quotation),
        ),
      ),
    );
  }
}
