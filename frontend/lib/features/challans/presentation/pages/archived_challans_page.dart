import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/challans/data/datasources/challans_remote_data_source.dart';
import 'package:shopxy/features/challans/domain/entities/challan.dart';
import 'package:shopxy/features/challans/presentation/pages/challan_detail_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/widgets/archived_documents_page.dart';

/// Delivery challans the merchant filed out of the working list.
///
/// Only settled ones get here — the backend refuses to archive a PENDING
/// challan, because goods are physically out against it and it has been
/// neither invoiced nor cancelled. So the filter axis is the settled states,
/// not the full status set.
class ArchivedChallansPage extends StatelessWidget {
  const ArchivedChallansPage({super.key});

  static const _limit = 100;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final source = context.read<ChallansRemoteDataSource>();

    return ArchivedDocumentsPage<Challan>(
      title: l10n.archivedTitle,
      emptyTitle: l10n.challansArchivedEmptyTitle,
      emptyBody: l10n.challansArchivedEmptyBody,
      filters: [
        ArchivedFilter(label: l10n.challansFilterAll),
        ArchivedFilter(
          label: l10n.challansStatusConverted,
          value: 'CONVERTED',
        ),
        ArchivedFilter(
          label: l10n.challansStatusCancelled,
          value: 'CANCELLED',
        ),
      ],
      load: (filter) async {
        final page = await source.listChallans(
          archived: true,
          status: filter,
          limit: _limit,
        );
        return page.challans;
      },
      restore: (challan) => source.setArchived(challan.id, false),
      // createdAt is what the server sorts challans by.
      dateOf: (challan) => challan.createdAt,
      rowOf: (challan) => ArchivedRowData(
        number: challan.challanNo,
        status: challan.status,
        subtitle: challan.partyName,
        // A challan carries no money — the count of lines is the useful
        // figure at a glance.
        trailing: l10n.documentItemCount(challan.itemCount),
      ),
      onOpen: (context, challan) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChallanDetailPage(challanId: challan.id),
        ),
      ),
    );
  }
}
