import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class ShopInvoiceDetailPage extends StatefulWidget {
  const ShopInvoiceDetailPage({
    super.key,
    required this.shop,
    required this.invoiceId,
  });

  final LinkedShop shop;
  final int invoiceId;

  @override
  State<ShopInvoiceDetailPage> createState() => _ShopInvoiceDetailPageState();
}

class _ShopInvoiceDetailPageState extends State<ShopInvoiceDetailPage> {
  late Future<ShopInvoiceDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ShopsProvider>().loadInvoiceDetail(
          widget.shop,
          widget.invoiceId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      symbol: AppStrings.currencySymbol,
      decimalDigits: 2,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Invoice')),
      body: FutureBuilder<ShopInvoiceDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppSizes.xxl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 36),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      snap.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final inv = snap.data!;
          final theme = Theme.of(context);
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.invoiceNo,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      DateFormat('d MMM yyyy').format(inv.invoiceDate.toLocal()),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    Container(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      decoration: ShapeDecoration(
                        color: AppColors.heroPanel,
                        shape: AppShapes.squircle(AppSizes.radiusMd),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv.isSale ? 'Issued to' : 'Issued by',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            inv.shopName ?? widget.shop.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (inv.shopPhone != null)
                            Text(
                              inv.shopPhone!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          if (inv.shopGstin != null)
                            Text(
                              'GSTIN ${inv.shopGstin!}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xl),
              const _Eyebrow('ITEMS'),
              for (int i = 0; i < inv.items.length; i++) ...[
                if (i > 0) Container(height: 1, color: AppColors.hairline),
                _ItemRow(item: inv.items[i], money: money),
              ],
              const SizedBox(height: AppSizes.xl),
              _TotalsBlock(invoice: inv, money: money),
              if (inv.note != null) ...[
                const SizedBox(height: AppSizes.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    decoration: ShapeDecoration(
                      color: AppColors.heroPanel,
                      shape: AppShapes.squircle(AppSizes.radiusMd),
                    ),
                    child: Text(
                      inv.note!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSizes.huge),
            ],
          );
        },
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSizes.lg, 0, AppSizes.lg, AppSizes.sm),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.money});
  final ShopInvoiceItem item;
  final NumberFormat money;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qtyText = item.quantity.truncateToDouble() == item.quantity
        ? item.quantity.toStringAsFixed(0)
        : item.quantity.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$qtyText ${item.unit} · @ ${money.format(item.unitPrice)}'
                  '${item.taxPercent > 0 ? "  · ${item.taxPercent.toStringAsFixed(item.taxPercent.truncateToDouble() == item.taxPercent ? 0 : 2)}%" : ""}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            money.format(item.total),
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsBlock extends StatelessWidget {
  const _TotalsBlock({required this.invoice, required this.money});
  final ShopInvoiceDetail invoice;
  final NumberFormat money;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        children: [
          _Row(label: 'Subtotal', value: money.format(invoice.subtotal)),
          _Row(label: 'Tax', value: money.format(invoice.taxAmount)),
          if (invoice.discount > 0)
            _Row(label: 'Discount', value: '− ${money.format(invoice.discount)}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: Divider(height: 1),
          ),
          _Row(
            label: 'Total',
            value: money.format(invoice.total),
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: (strong ? theme.textTheme.titleMedium : theme.textTheme.bodyMedium)
                ?.copyWith(
              color: AppColors.black,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
