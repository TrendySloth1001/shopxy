import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/returns/data/datasources/merchant_returns_remote_data_source.dart';
import 'package:shopxy/features/returns/domain/merchant_return.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

/// Workflow-heavy detail page. Header shows the customer + refund
/// total; each item gets a small thumbnail + reason chip; the bottom
/// of the page surfaces the right action buttons for the current
/// status (approve/reject → picked up → received → refund).
class MerchantReturnDetailPage extends StatefulWidget {
  const MerchantReturnDetailPage({super.key, required this.returnId});
  final int returnId;

  @override
  State<MerchantReturnDetailPage> createState() =>
      _MerchantReturnDetailPageState();
}

class _MerchantReturnDetailPageState extends State<MerchantReturnDetailPage> {
  MerchantReturn? _row;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  static final _currency =
      NumberFormat.currency(symbol: '₹', decimalDigits: 2);

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
      final ds = context.read<MerchantReturnsRemoteDataSource>();
      final r = await ds.getById(widget.returnId);
      if (mounted) setState(() {
        _row = r;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _run(
    Future<void> Function(MerchantReturnsRemoteDataSource ds) op,
    String successMessage,
  ) async {
    setState(() => _busy = true);
    try {
      final ds = context.read<MerchantReturnsRemoteDataSource>();
      await op(ds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e.toString().replaceFirst('Exception: ', ''),
        )),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Common confirmation sheet for the destructive / financial actions.
  /// Returns the merchant's optional note (or null if they cancelled).
  Future<String?> _askForNote({
    required String title,
    required String confirmLabel,
    String? hint,
    bool noteRequired = false,
  }) {
    final ctrl = TextEditingController();
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.lg,
          right: AppSizes.lg,
          top: AppSizes.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16,
            )),
            const SizedBox(height: AppSizes.md),
            TextField(
              controller: ctrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: hint ?? 'Note (optional)',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final v = ctrl.text.trim();
                      if (noteRequired && v.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Note required')),
                        );
                        return;
                      }
                      Navigator.of(ctx).pop(v);
                    },
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    final row = _row!;
    return Scaffold(
      appBar: AppBar(title: Text('Return #${row.id}')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.lg),
                children: [
                  _HeaderCard(row: row),
                  const SizedBox(height: AppSizes.md),
                  _ItemsCard(items: row.items),
                  const SizedBox(height: AppSizes.md),
                  _TimelineCard(events: row.events),
                  if (row.note != null && row.note!.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.md),
                    _NoteCard(
                      title: 'Buyer note',
                      body: row.note!,
                      icon: Icons.chat_bubble_outline,
                    ),
                  ],
                  if (row.decisionNote != null &&
                      row.decisionNote!.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.md),
                    _NoteCard(
                      title: 'Your note',
                      body: row.decisionNote!,
                      icon: Icons.assignment_outlined,
                    ),
                  ],
                  if (row.refundMethod != null) ...[
                    const SizedBox(height: AppSizes.md),
                    Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: ShapeDecoration(
                        color: AppColors.successSoft,
                        shape: AppShapes.squircle(AppSizes.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: Text(
                              'Refunded ${_currency.format(row.refundAmount)} '
                              'to ${row.customerName}\'s wallet '
                              '(${row.refundMethod})',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _ActionBar(
              row: row,
              busy: _busy,
              onApprove: () async {
                final note = await _askForNote(
                  title: 'Approve return',
                  confirmLabel: 'Approve',
                  hint: 'Pickup instructions for the buyer (optional)',
                );
                if (note == null) return;
                await _run(
                  (ds) => ds.approve(row.id, note: note.isEmpty ? null : note),
                  'Return approved',
                );
              },
              onReject: () async {
                final note = await _askForNote(
                  title: 'Reject return',
                  confirmLabel: 'Reject',
                  hint: 'Why? Shown to the buyer',
                  noteRequired: true,
                );
                if (note == null) return;
                await _run(
                  (ds) => ds.reject(row.id, note: note),
                  'Return rejected',
                );
              },
              onPickedUp: () => _run(
                (ds) => ds.markPickedUp(row.id),
                'Marked as picked up',
              ),
              onReceived: () => _run(
                (ds) => ds.markReceived(row.id),
                'Marked as received',
              ),
              onRefund: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      'Refund ${_currency.format(row.refundAmount)}?',
                    ),
                    content: Text(
                      'This will credit the buyer\'s wallet immediately. '
                      'The action can\'t be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Refund'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                await _run(
                  (ds) async {
                    await ds.refund(row.id);
                  },
                  'Refund credited',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.row});
  final MerchantReturn row;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.customerName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              AppStatusBadge(
                label: row.status,
                tone: row.canRefund
                    ? AppStatusTone.warning
                    : row.status == 'REFUNDED'
                        ? AppStatusTone.success
                        : row.status == 'REJECTED' || row.status == 'CANCELLED'
                            ? AppStatusTone.error
                            : AppStatusTone.info,
                weight: AppStatusWeight.soft,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Order #${row.parentOrderId} · Slice #${row.shopOrderId}',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          if (row.customerAddress != null && row.customerAddress!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            Text(row.customerAddress!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                )),
          ],
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: AppColors.muted),
              const SizedBox(width: 4),
              Text(
                'Refund preview: ',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              Text(
                NumberFormat.currency(symbol: '₹', decimalDigits: 2)
                    .format(row.refundAmount),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.items});
  final List<MerchantReturnItem> items;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Items', style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: AppSizes.sm),
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: it.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: it.imageUrl!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: AppColors.surfaceTint,
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: AppColors.surfaceTint,
                          ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.productName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            )),
                        Text(
                          '${it.quantity.toStringAsFixed(0)} ${it.unit} · '
                          'Refund ₹${it.refundAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brandSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            reasonLabel(it.reason),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brandStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.events});
  final List<MerchantReturnEvent> events;

  static final _date = DateFormat('d MMM · h:mm a');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Timeline', style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: AppSizes.sm),
          for (final e in events)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(_iconFor(e.type), size: 16, color: AppColors.brand),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(child: Text(_label(e.type))),
                  Text(_date.format(e.occurredAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static IconData _iconFor(String type) {
    switch (type) {
      case 'REQUESTED':
        return Icons.receipt_outlined;
      case 'APPROVED':
        return Icons.check_circle_outline;
      case 'REJECTED':
        return Icons.cancel_outlined;
      case 'CANCELLED':
        return Icons.cancel_outlined;
      case 'PICKED_UP':
        return Icons.local_shipping_outlined;
      case 'RECEIVED':
        return Icons.inventory_2_outlined;
      case 'REFUNDED':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  static String _label(String type) {
    switch (type) {
      case 'REQUESTED':
        return 'Requested';
      case 'APPROVED':
        return 'Approved';
      case 'REJECTED':
        return 'Rejected';
      case 'CANCELLED':
        return 'Cancelled';
      case 'PICKED_UP':
        return 'Picked up';
      case 'RECEIVED':
        return 'Received';
      case 'REFUNDED':
        return 'Refunded';
      default:
        return type;
    }
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.title, required this.body, required this.icon,
  });
  final String title;
  final String body;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.brand),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 2),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.row,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onPickedUp,
    required this.onReceived,
    required this.onRefund,
  });
  final MerchantReturn row;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onPickedUp;
  final VoidCallback onReceived;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    if (row.isClosed) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.md),
      child: Row(
        children: [
          if (row.canApprove) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : onApprove,
                child: const Text('Approve'),
              ),
            ),
          ] else if (row.canMarkPickedUp && !row.canMarkReceived) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onPickedUp,
                icon: const Icon(Icons.local_shipping_outlined),
                label: const Text('Mark as picked up'),
              ),
            ),
          ] else if (row.canMarkReceived && !row.canRefund) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onReceived,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Mark as received'),
              ),
            ),
          ] else if (row.canRefund) ...[
            if (row.canMarkPickedUp)
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onPickedUp,
                  child: const Text('Picked up'),
                ),
              ),
            if (row.canMarkReceived) ...[
              if (row.canMarkPickedUp) const SizedBox(width: AppSizes.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReceived,
                  child: const Text('Received'),
                ),
              ),
            ],
            if (row.canMarkPickedUp || row.canMarkReceived)
              const SizedBox(width: AppSizes.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onRefund,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: const Text('Refund'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
