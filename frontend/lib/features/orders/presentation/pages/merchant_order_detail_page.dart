import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/orders/domain/entities/merchant_order.dart';
import 'package:shopxy/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

class MerchantOrderDetailPage extends StatefulWidget {
  const MerchantOrderDetailPage({super.key, required this.orderId});
  final int orderId;

  @override
  State<MerchantOrderDetailPage> createState() => _MerchantOrderDetailPageState();
}

class _MerchantOrderDetailPageState extends State<MerchantOrderDetailPage> {
  MerchantOrderDetail? _order;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  static final _date = DateFormat('d MMM y · h:mm a');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await context.read<OrdersProvider>().loadDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _order = o;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _confirm() async {
    final ordersProvider = context.read<OrdersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final result = await ordersProvider.confirm(widget.orderId);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Invoice ${result.invoiceNo} created')),
      );
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => InvoiceDetailPage(invoiceId: result.invoiceId),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reject() async {
    final note = await _askNote(reason: 'Reason for declining (optional)');
    if (!mounted || note == null) return;
    final ordersProvider = context.read<OrdersProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ordersProvider.reject(widget.orderId, note: note);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Order declined')));
      navigator.pop();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _busy = false);
      }
    }
  }

  Future<String?> _askNote({required String reason}) async {
    final ctrl = TextEditingController();
    final note = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(reason),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return note;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Order #${widget.orderId}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _Body(order: _order!, dateFmt: _date),
      bottomNavigationBar: _order == null || !_order!.isPending
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  border: Border(top: BorderSide(color: AppColors.hairline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _reject,
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.error),
                        label: const Text(
                          'Decline',
                          style: TextStyle(color: AppColors.error),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _confirm,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Confirm → invoice'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order, required this.dateFmt});
  final MerchantOrderDetail order;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (order.customerPhone != null)
                      Text(order.customerPhone!,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: AppColors.muted)),
                    if (order.customerEmail != null)
                      Text(order.customerEmail!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              if (order.isLinkedCustomer)
                const AppStatusBadge(
                  label: 'Linked party',
                  icon: Icons.verified_outlined,
                  tone: AppStatusTone.success,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Row(
            children: [
              Text(
                dateFmt.format(order.createdAt),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const Spacer(),
              AppStatusBadge(
                label: order.status,
                tone: _tone(order),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        const AppDivider(),
        for (final item in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        item.productSku,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${item.quantity % 1 == 0 ? item.quantity.toInt() : item.quantity.toStringAsFixed(2)} ${item.unit}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: AppSizes.md),
                SizedBox(
                  width: 80,
                  child: Text(
                    '₹${item.total.toStringAsFixed(2)}',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        const AppDivider(),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
            children: [
              const Expanded(child: Text('Estimated total')),
              Text(
                '₹${order.estimatedTotal.toStringAsFixed(2)}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        if (order.note != null && order.note!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Customer's note",
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AppColors.muted),
                ),
                Container(
                  margin: const EdgeInsets.only(top: AppSizes.xs),
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: ShapeDecoration(
                    color: AppColors.surfaceTint,
                    shape: AppShapes.squircle(AppSizes.radiusMd),
                  ),
                  child: Text(order.note!),
                ),
              ],
            ),
          ),
        ],
        if (order.linkedInvoiceNo != null) ...[
          const SizedBox(height: AppSizes.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            child: FilledButton.tonalIcon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailPage(invoiceId: order.invoiceId!),
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text('Open invoice ${order.linkedInvoiceNo!}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ],
    );
  }

  AppStatusTone _tone(MerchantOrder o) {
    if (o.isConfirmed) return AppStatusTone.success;
    if (o.isRejected) return AppStatusTone.error;
    if (o.isCancelled) return AppStatusTone.neutral;
    return AppStatusTone.warning;
  }
}
