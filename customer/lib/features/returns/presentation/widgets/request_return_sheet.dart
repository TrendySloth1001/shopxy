import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/orders/domain/entities/customer_order.dart';
import 'package:shopxy_customer/features/returns/data/datasources/returns_remote_data_source.dart';
import 'package:shopxy_customer/features/returns/domain/entities/return_request.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

/// Modal sheet that walks the customer through a return:
///   1. Pick line(s) to return + quantity per line.
///   2. Pick a reason (single, applies to the whole return).
///   3. Optional note.
/// On success returns the new return id (int); null on dismiss.
Future<int?> showRequestReturnSheet({
  required BuildContext context,
  required int parentOrderId,
  required ShopOrderDetail shopOrder,
}) {
  return showModalBottomSheet<int?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.canvas,
    useSafeArea: true,
    shape: AppShapes.squircleTop(AppSizes.radiusXl),
    builder: (_) => _Sheet(parentOrderId: parentOrderId, shopOrder: shopOrder),
  );
}

class _Sheet extends StatefulWidget {
  const _Sheet({required this.parentOrderId, required this.shopOrder});
  final int parentOrderId;
  final ShopOrderDetail shopOrder;

  @override
  State<_Sheet> createState() => _SheetState();
}

class _SheetState extends State<_Sheet> {
  /// productItemId → quantity to return. Absent means "don't return".
  final Map<int, double> _picks = {};
  String _reason = 'DAMAGED';
  final TextEditingController _noteCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _refundEstimate {
    var total = 0.0;
    for (final item in widget.shopOrder.items) {
      final q = _picks[item.id];
      if (q == null) continue;
      total += q * item.unitPrice;
    }
    return total;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_picks.isEmpty) {
      setState(() => _error = 'Pick at least one item to return');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ds = context.read<ReturnsRemoteDataSource>();
      final id = await ds.submit(
        parentOrderId: widget.parentOrderId,
        shopOrderId: widget.shopOrder.id,
        items: _picks.entries
            .map(
              (e) => (
                purchaseRequestItemId: e.key,
                quantity: e.value,
                reason: _reason,
              ),
            )
            .toList(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Return items',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          Expanded(
            // Freeze the form while the request is in flight so the
            // picks/reason/note can't drift from what's being submitted.
            child: AbsorbPointer(
              absorbing: _submitting,
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.md,
                  AppSizes.lg,
                  AppSizes.lg,
                ),
                children: [
                  const _SectionLabel('Choose items'),
                  for (final item in widget.shopOrder.items)
                    _ItemPickerRow(
                      item: item,
                      picked: _picks[item.id],
                      onChanged: (q) {
                        setState(() {
                          if (q == null || q <= 0) {
                            _picks.remove(item.id);
                          } else {
                            _picks[item.id] = q;
                          }
                        });
                      },
                    ),
                  const SizedBox(height: AppSizes.lg),
                  const _SectionLabel('Reason'),
                  Wrap(
                    spacing: AppSizes.sm,
                    runSpacing: AppSizes.sm,
                    children: [
                      for (final r in kReturnReasons)
                        _ReasonChip(
                          label: reasonLabel(r),
                          selected: _reason == r,
                          onTap: () => setState(() => _reason = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.lg),
                  const _SectionLabel('Add a note (optional)'),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Tell the seller what happened',
                      border: OutlineInputBorder(
                        borderRadius: AppShapes.squircleRadius(
                          AppSizes.radiusMd,
                        ),
                        borderSide: const BorderSide(color: AppColors.hairline),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: AppSizes.md),
                    Text(
                      _error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.hairline),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              AppSizes.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated refund',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        AppFormat.rupeesSmart(_refundEstimate),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.xl,
                      vertical: AppSizes.lg,
                    ),
                    shape: AppShapes.squircle(AppSizes.radiusMd),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text(
                          'Submit return',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSizes.sm),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
      ),
    ),
  );
}

class _ItemPickerRow extends StatelessWidget {
  const _ItemPickerRow({
    required this.item,
    required this.picked,
    required this.onChanged,
  });
  final CustomerOrderItem item;
  final double? picked;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = picked != null;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(
            color: selected ? AppColors.brand : AppColors.hairline,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: selected,
                onChanged: (v) => onChanged(v == true ? item.quantity : null),
                activeColor: AppColors.brand,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      'Ordered: ${item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 2)} ${item.unit} · ${AppFormat.rupeesSmart(item.unitPrice)} each',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                    if (selected) ...[
                      const SizedBox(height: 2),
                      // Refund math made explicit: "2 × ₹250 = ₹500".
                      Text(
                        'Refund: ${picked!.toStringAsFixed(picked! == picked!.roundToDouble() ? 0 : 2)} × ${AppFormat.rupeesSmart(item.unitPrice)} = ${AppFormat.rupeesSmart(picked! * item.unitPrice)}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (selected && item.quantity > 1) ...[
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                Text(
                  'Quantity:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                _QtyStepper(
                  value: picked!,
                  max: item.quantity,
                  onChanged: onChanged,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.value,
    required this.max,
    required this.onChanged,
  });
  final double value;
  final double max;
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline_rounded),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
        Text(
          value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: value < max ? () => onChanged(value + 1) : null,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.black : AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: BorderSide(
          color: selected ? AppColors.black : AppColors.hairline,
        ),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: selected ? AppColors.white : AppColors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Convenience helper for callers — opens the sheet and shows a toast.
Future<void> openRequestReturn(
  BuildContext context, {
  required int parentOrderId,
  required ShopOrderDetail shopOrder,
  VoidCallback? onSubmitted,
}) async {
  final id = await showRequestReturnSheet(
    context: context,
    parentOrderId: parentOrderId,
    shopOrder: shopOrder,
  );
  if (id == null || !context.mounted) return;
  showAppSnackbar(
    context,
    message: 'Return submitted · #$id',
    tone: AppSnackbarTone.success,
  );
  onSubmitted?.call();
}
