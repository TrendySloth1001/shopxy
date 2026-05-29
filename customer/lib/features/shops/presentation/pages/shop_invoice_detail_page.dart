import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_divider.dart';

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
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Invoice'),
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.black,
        elevation: 0,
      ),
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
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              0,
              AppSizes.md,
              0,
              AppSizes.huge,
            ),
            children: [
              _Header(invoice: inv),
              const _SpacedDivider(),
              _Counterparty(invoice: inv, fallbackName: widget.shop.name),
              const SizedBox(height: AppSizes.xl),
              _Eyebrow(
                text: 'ITEMS',
                trailing: '${inv.items.length}'
                    ' item${inv.items.length == 1 ? '' : 's'}',
              ),
              const AppDivider.flush(),
              for (int i = 0; i < inv.items.length; i++) ...[
                if (i > 0) const AppDivider.flush(),
                _ItemRow(item: inv.items[i], money: money),
              ],
              const _SpacedDivider(),
              _Totals(invoice: inv, money: money),
              if (inv.note != null) ...[
                const SizedBox(height: AppSizes.xl),
                const _Eyebrow(text: 'NOTE'),
                const AppDivider.flush(),
                _Note(text: inv.note!),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A hairline with breathing room above/below — the flat-layout replacement
/// for the gap between the old bordered cards.
class _SpacedDivider extends StatelessWidget {
  const _SpacedDivider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
        child: AppDivider.flush(),
      );
}

class _Header extends StatelessWidget {
  const _Header({required this.invoice});
  final ShopInvoiceDetail invoice;

  @override
  Widget build(BuildContext context) {
    final eyebrow = invoice.isSale ? 'SALES INVOICE' : 'PURCHASE BILL';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  eyebrow,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _StatusPill(status: invoice.status),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            invoice.invoiceNo,
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(
                Icons.event_rounded,
                color: AppColors.muted,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('d MMM yyyy').format(invoice.invoiceDate.toLocal()),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();
    final (label, fg, bg) = switch (normalized) {
      'PAID' => ('Paid', AppColors.success, AppColors.successSoft),
      'UNPAID' || 'DUE' || 'PENDING' =>
        ('Unpaid', AppColors.warning, AppColors.warningSoft),
      'PARTIAL' || 'PARTIALLY_PAID' =>
        ('Partial', AppColors.info, AppColors.infoSoft),
      'CANCELLED' || 'VOID' =>
        ('Cancelled', AppColors.muted, AppColors.heroPanel),
      _ => (
          normalized.isEmpty ? '—' : status,
          AppColors.muted,
          AppColors.heroPanel,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Counterparty extends StatelessWidget {
  const _Counterparty({
    required this.invoice,
    required this.fallbackName,
  });
  final ShopInvoiceDetail invoice;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final name = invoice.shopName ?? fallbackName;
    final eyebrow = invoice.isSale ? 'ISSUED TO' : 'ISSUED BY';
    final iconData = invoice.isSale
        ? Icons.person_outline_rounded
        : Icons.storefront_outlined;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: ShapeDecoration(
              color: AppColors.brandSoft,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(iconData, color: AppColors.brand, size: 20),
          ),
          const SizedBox(width: AppSizes.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                ),
                if (invoice.shopPhone != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    invoice.shopPhone!,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (invoice.shopGstin != null)
                  Text(
                    'GSTIN ${invoice.shopGstin!}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text, this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        0,
        AppSizes.lg,
        AppSizes.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.money});
  final ShopInvoiceItem item;
  final NumberFormat money;

  String _qty() => item.quantity.truncateToDouble() == item.quantity
      ? item.quantity.toStringAsFixed(0)
      : item.quantity.toStringAsFixed(2);

  String _meta() {
    final qty = '${_qty()} ${item.unit}';
    final unit = '@ ${money.format(item.unitPrice)}';
    final tax = item.taxPercent > 0
        ? '${item.taxPercent.truncateToDouble() == item.taxPercent ? item.taxPercent.toStringAsFixed(0) : item.taxPercent.toStringAsFixed(2)}% tax'
        : null;
    return [qty, unit, ?tax].join('  ·  ');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      // Name + meta stack on the left, total on the right. The total
      // is wrapped in its own Column with right-alignment so a long
      // name can't shove the price into a cramped column.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _meta(),
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Text(
            money.format(item.total),
            style: const TextStyle(
              color: AppColors.black,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.invoice, required this.money});
  final ShopInvoiceDetail invoice;
  final NumberFormat money;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        children: [
          _TotalsRow(label: 'Subtotal', value: money.format(invoice.subtotal)),
          _TotalsRow(label: 'Tax', value: money.format(invoice.taxAmount)),
          if (invoice.discount > 0)
            _TotalsRow(
              label: 'Discount',
              value: '− ${money.format(invoice.discount)}',
              valueColor: AppColors.success,
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: AppDivider.flush(),
          ),
          _TotalsRow(
            label: 'Total',
            value: money.format(invoice.total),
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
  });
  final String label;
  final String value;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? AppColors.black : AppColors.muted,
                fontSize: strong ? 14 : 13,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: strong ? -0.1 : 0,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.black,
              fontSize: strong ? 17 : 13,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: strong ? -0.2 : 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.sticky_note_2_outlined,
            color: AppColors.muted,
            size: 16,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
