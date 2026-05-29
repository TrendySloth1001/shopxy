import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/caution/data/datasources/caution_remote_data_source.dart';
import 'package:shopxy/features/caution/domain/entities/caution_txn.dart';
import 'package:shopxy/features/caution/presentation/widgets/caution_info_sheet.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';

/// Shop-wide inbox of party-initiated caution requests awaiting review.
/// Approving one turns it into a confirmed deposit on that party's ledger;
/// rejecting it (optionally with a reason) notifies the customer.
class CautionRequestsPage extends StatefulWidget {
  const CautionRequestsPage({super.key});

  @override
  State<CautionRequestsPage> createState() => _CautionRequestsPageState();
}

class _CautionRequestsPageState extends State<CautionRequestsPage> {
  final _currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
  final _dateFmt = DateFormat('d MMM yyyy');

  List<CautionRequest> _requests = const [];
  bool _loading = true;
  String? _error;
  int? _busyId;

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
      final ds = context.read<CautionRemoteDataSource>();
      final list = await ds.listShopRequests(status: 'PENDING');
      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _approve(CautionRequest r) async {
    setState(() => _busyId = r.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context
          .read<CautionRemoteDataSource>()
          .approveRequest(r.partyId, r.id);
      if (!mounted) return;
      setState(() {
        _requests = _requests.where((x) => x.id != r.id).toList();
        _busyId = null;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Approved · ${_currency.format(r.amount)} added')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _reject(CautionRequest r) async {
    final ds = context.read<CautionRemoteDataSource>();
    final messenger = ScaffoldMessenger.of(context);
    final reason = await _askReason();
    if (reason == null) return; // cancelled the dialog
    setState(() => _busyId = r.id);
    try {
      await ds.rejectRequest(
        r.partyId,
        r.id,
        reviewNote: reason.isEmpty ? null : reason,
      );
      if (!mounted) return;
      setState(() {
        _requests = _requests.where((x) => x.id != r.id).toList();
        _busyId = null;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Request declined')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Returns the reason string (possibly empty) on confirm, or null on cancel.
  Future<String?> _askReason() {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline request'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Shown to the customer',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Caution requests'),
        actions: [
          IconButton(
            onPressed: () => showCautionInfoSheet(
              context,
              variant: CautionInfoVariant.requests,
            ),
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'About caution requests',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: AppSizes.md),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _requests.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.inbox_outlined,
                                size: 44, color: AppColors.muted),
                            SizedBox(height: AppSizes.md),
                            Center(
                              child: Text(
                                'No pending caution requests.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding:
                              const EdgeInsets.symmetric(vertical: AppSizes.sm),
                          itemCount: _requests.length,
                          separatorBuilder: (_, _) => const AppDivider.flush(),
                          itemBuilder: (_, i) => _RequestRow(
                            req: _requests[i],
                            currency: _currency,
                            dateFmt: _dateFmt,
                            busy: _busyId == _requests[i].id,
                            onApprove: () => _approve(_requests[i]),
                            onReject: () => _reject(_requests[i]),
                          ),
                        ),
                ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({
    required this.req,
    required this.currency,
    required this.dateFmt,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });
  final CautionRequest req;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = <String>[
      dateFmt.format(req.createdAt.toLocal()),
      if (req.mode != null) req.mode!,
      if (req.modeReference != null && req.modeReference!.isNotEmpty)
        req.modeReference!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      req.partyName,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Text(
                currency.format(req.amount),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          if (req.note != null && req.note!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            Text(req.note!, style: theme.textTheme.bodyMedium),
          ],
          if (req.hasBasket) ...[
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                const Icon(Icons.shopping_basket_outlined,
                    size: 15, color: AppColors.brandStrong),
                const SizedBox(width: 6),
                Text(
                  'Plans to buy${req.basketValue != null ? ' · ${currency.format(req.basketValue)}' : ''}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.brandStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            for (final line in req.basket.take(4))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${line.qty.toStringAsFixed(line.qty == line.qty.roundToDouble() ? 0 : 2)} × ${line.name} · ${currency.format(line.lineTotal)}',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (req.basket.length > 4)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '+${req.basket.length - 4} more',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ),
          ],
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onApprove,
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
