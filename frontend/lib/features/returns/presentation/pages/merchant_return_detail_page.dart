import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/features/returns/data/datasources/merchant_returns_remote_data_source.dart';
import 'package:shopxy/features/returns/domain/merchant_return.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';

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
      if (mounted) {
        setState(() {
        _row = r;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
      }
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
          friendlyError(e),
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
    final l10n = AppLocalizations.of(context);
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
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            )),
            const SizedBox(height: AppSizes.md),
            TextField(
              controller: ctrl,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: hint ?? l10n.returnsNoteOptional,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: Text(l10n.returnsCancel),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final v = ctrl.text.trim();
                      if (noteRequired && v.isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(l10n.returnsNoteRequired)),
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
      return const _ReturnDetailSkeleton();
    }
    if (_error != null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FloatingAppBar(),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Center(child: Text(_error!)),
        ),
      );
    }
    final l10n = AppLocalizations.of(context);
    final row = _row!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.returnsDetailTitle(row.id)),
      body: SafeArea(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
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
                      title: l10n.returnsBuyerNote,
                      body: row.note!,
                      icon: Icons.chat_bubble_outline,
                    ),
                  ],
                  if (row.decisionNote != null &&
                      row.decisionNote!.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.md),
                    _NoteCard(
                      title: l10n.returnsYourNote,
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
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: Text(
                              l10n.returnsRefundedToOriginal(
                                _currency.format(row.refundAmount),
                                row.customerName,
                              ),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                  title: l10n.returnsApproveTitle,
                  confirmLabel: l10n.returnsApprove,
                  hint: l10n.returnsApproveHint,
                );
                if (note == null) return;
                await _run(
                  (ds) => ds.approve(row.id, note: note.isEmpty ? null : note),
                  l10n.returnsApprovedToast,
                );
              },
              onReject: () async {
                final note = await _askForNote(
                  title: l10n.returnsRejectTitle,
                  confirmLabel: l10n.returnsReject,
                  hint: l10n.returnsRejectHint,
                  noteRequired: true,
                );
                if (note == null) return;
                await _run(
                  (ds) => ds.reject(row.id, note: note),
                  l10n.returnsRejectedToast,
                );
              },
              onPickedUp: () => _run(
                (ds) => ds.markPickedUp(row.id),
                l10n.returnsPickedUpToast,
              ),
              onReceived: () => _run(
                (ds) => ds.markReceived(row.id),
                l10n.returnsReceivedToast,
              ),
              onRefund: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(
                      l10n.returnsRefundConfirmTitle(
                        _currency.format(row.refundAmount),
                      ),
                    ),
                    content: Text(l10n.returnsRefundConfirmBody),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(l10n.returnsCancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(l10n.returnsRefund),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                await _run(
                  (ds) async {
                    await ds.refund(row.id);
                  },
                  l10n.returnsRefundIssuedToast,
                );
              },
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton
// ---------------------------------------------------------------------------

class _ReturnDetailSkeleton extends StatelessWidget {
  const _ReturnDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(titleWidget: const AppShimmerLine(widthFactor: 0.4, height: 18)),
      body: SafeArea(
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.lg),
                children: const [
                  _HeaderCardSkeleton(),
                  SizedBox(height: AppSizes.md),
                  _ItemsCardSkeleton(),
                  SizedBox(height: AppSizes.md),
                  _TimelineCardSkeleton(),
                ],
              ),
            ),
            _ActionBarSkeleton(),
          ],
        ),
        ),
      ),
    );
  }
}

class _HeaderCardSkeleton extends StatelessWidget {
  const _HeaderCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: AppShimmerLine(widthFactor: 0.55, height: 16),
              ),
              const SizedBox(width: AppSizes.md),
              AppShimmerBox(
                width: 72,
                height: 24,
                radius: AppSizes.radiusSm,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          const AppShimmerLine(widthFactor: 0.70, height: 12),
          const SizedBox(height: AppSizes.xs),
          const AppShimmerLine(widthFactor: 0.85, height: 12),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              AppShimmerBox(
                width: AppSizes.iconSm,
                height: AppSizes.iconSm,
                radius: AppSizes.radiusSm,
              ),
              const SizedBox(width: AppSizes.xs),
              const AppShimmerLine(widthFactor: 0.35, height: 14),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemsCardSkeleton extends StatelessWidget {
  const _ItemsCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppShimmerLine(widthFactor: 0.25, height: 14),
          const SizedBox(height: AppSizes.sm),
          for (int i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
              child: Row(
                children: [
                  AppShimmerBox(
                    width: AppSizes.productThumbSize,
                    height: AppSizes.productThumbSize,
                    radius: AppSizes.radiusSm,
                  ),
                  const SizedBox(width: AppSizes.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmerLine(widthFactor: 0.65, height: 14),
                        SizedBox(height: AppSizes.xs),
                        AppShimmerLine(widthFactor: 0.50, height: 12),
                        SizedBox(height: AppSizes.xs),
                        AppShimmerLine(widthFactor: 0.30, height: 20),
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

class _TimelineCardSkeleton extends StatelessWidget {
  const _TimelineCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppShimmerLine(widthFactor: 0.30, height: 14),
          const SizedBox(height: AppSizes.sm),
          for (int i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
              child: Row(
                children: [
                  AppShimmerBox(
                    width: AppSizes.iconSm,
                    height: AppSizes.iconSm,
                    radius: AppSizes.radiusSm,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: AppShimmerLine(
                      widthFactor: 0.45 + (i % 3) * 0.1,
                      height: 12,
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  AppShimmerBox(width: 72, height: 12, radius: AppSizes.radiusSm),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionBarSkeleton extends StatelessWidget {
  const _ActionBarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.md),
      child: Row(
        children: [
          Expanded(
            child: AppShimmerBox(
              width: double.infinity,
              height: 44,
              radius: AppSizes.radiusMd,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: AppShimmerBox(
              width: double.infinity,
              height: 44,
              radius: AppSizes.radiusMd,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Real content widgets
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.row});
  final MerchantReturn row;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.surface,
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
                label: _statusLabel(l10n, row.status),
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
          const SizedBox(height: AppSizes.xs),
          Text(
            l10n.returnsOrderSlice(row.parentOrderId, row.shopOrderId),
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
              Icon(Icons.account_balance_wallet_outlined,
                  size: AppSizes.iconSm, color: AppColors.muted),
              const SizedBox(width: AppSizes.xs),
              Text(
                l10n.returnsRefundPreview,
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.returnsItems, style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: AppSizes.sm),
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
                    child: it.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: it.imageUrl!,
                            width: AppSizes.productThumbSize,
                            height: AppSizes.productThumbSize,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Container(
                              width: AppSizes.productThumbSize,
                              height: AppSizes.productThumbSize,
                              color: AppColors.surfaceTint,
                            ),
                          )
                        : Container(
                            width: AppSizes.productThumbSize,
                            height: AppSizes.productThumbSize,
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
                          '${l10n.returnsRefundLabel} ₹${it.refundAmount.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: AppSizes.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.sm, vertical: AppSizes.xs,
                          ),
                          decoration: ShapeDecoration(
                            color: AppColors.tileBg(AppColors.brandSoft),
                            shape: AppShapes.squircle(AppSizes.radiusSm),
                          ),
                          child: Text(
                            _reasonLabel(l10n, it.reason),
                            style: theme.textTheme.labelSmall?.copyWith(
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.returnsTimeline, style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: AppSizes.sm),
          for (final e in events)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
              child: Row(
                children: [
                  Icon(_iconFor(e.type), size: AppSizes.iconSm, color: AppColors.brand),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(child: Text(_statusLabel(l10n, e.type))),
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

}

/// Localised label for a return status / timeline event code. Lives at
/// file scope so both the header badge and the timeline can share it.
String _statusLabel(AppLocalizations l10n, String code) {
  switch (code) {
    case 'REQUESTED':
      return l10n.returnsStatusRequested;
    case 'APPROVED':
      return l10n.returnsStatusApproved;
    case 'REJECTED':
      return l10n.returnsStatusRejected;
    case 'CANCELLED':
      return l10n.returnsStatusCancelled;
    case 'PICKED_UP':
      return l10n.returnsStatusPickedUp;
    case 'RECEIVED':
      return l10n.returnsStatusReceived;
    case 'REFUNDED':
      return l10n.returnsStatusRefunded;
    default:
      return code;
  }
}

/// Localised label for a return reason code (mirrors [reasonLabel] in the
/// domain layer, but resolved against the active locale).
String _reasonLabel(AppLocalizations l10n, String code) {
  switch (code) {
    case 'DAMAGED':
      return l10n.returnsReasonDamaged;
    case 'WRONG_ITEM':
      return l10n.returnsReasonWrongItem;
    case 'NOT_AS_DESCRIBED':
      return l10n.returnsReasonNotAsDescribed;
    case 'SIZE_FIT':
      return l10n.returnsReasonSizeFit;
    case 'CHANGED_MIND':
      return l10n.returnsReasonChangedMind;
    case 'DEFECTIVE':
      return l10n.returnsReasonDefective;
    case 'OTHER':
    default:
      return l10n.returnsReasonOther;
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconMd, color: AppColors.brand),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: AppSizes.xs),
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
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
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
                  side: BorderSide(color: AppColors.error),
                ),
                child: Text(l10n.returnsReject),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : onApprove,
                child: Text(l10n.returnsApprove),
              ),
            ),
          ] else if (row.canMarkPickedUp && !row.canMarkReceived) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onPickedUp,
                icon: const Icon(Icons.local_shipping_outlined),
                label: Text(l10n.returnsMarkPickedUp),
              ),
            ),
          ] else if (row.canMarkReceived && !row.canRefund) ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onReceived,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(l10n.returnsMarkReceived),
              ),
            ),
          ] else if (row.canRefund) ...[
            if (row.canMarkPickedUp)
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onPickedUp,
                  child: Text(l10n.returnsStatusPickedUp),
                ),
              ),
            if (row.canMarkReceived) ...[
              if (row.canMarkPickedUp) const SizedBox(width: AppSizes.md),
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onReceived,
                  child: Text(l10n.returnsStatusReceived),
                ),
              ),
            ],
            if (row.canMarkPickedUp || row.canMarkReceived)
              const SizedBox(width: AppSizes.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: busy ? null : onRefund,
                icon: const Icon(Icons.account_balance_wallet_outlined),
                label: Text(l10n.returnsRefund),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
