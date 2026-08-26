import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_divider.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class ShopInvoiceDetailPage extends StatefulWidget {
  const ShopInvoiceDetailPage({
    super.key,
    required this.shop,
    required this.invoiceId,
  });

  final LinkedShop shop;
  final String invoiceId;

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
    final money = AppFormat.inrPrecise;
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
            return const _ShopInvoiceDetailSkeleton();
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppSizes.xxl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(
                      AppIcons.errorOutlineRounded,
                      color: AppColors.error,
                      size: AppSizes.iconXl,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      friendlyError(snap.error ?? ''),
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
                trailing:
                    '${inv.items.length}'
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
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _StatusPill(status: invoice.status),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            invoice.invoiceNo,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Row(
            children: [
              const AppIcon(
                AppIcons.eventRounded,
                color: AppColors.muted,
                size: AppSizes.iconSm,
              ),
              const SizedBox(width: AppSizes.xs),
              Text(
                DateFormat('d MMM yyyy').format(invoice.invoiceDate.toLocal()),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
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
      'UNPAID' ||
      'DUE' ||
      'PENDING' => ('Unpaid', AppColors.warning, AppColors.warningSoft),
      'PARTIAL' ||
      'PARTIALLY_PAID' => ('Partial', AppColors.info, AppColors.infoSoft),
      'CANCELLED' ||
      'VOID' => ('Cancelled', AppColors.muted, AppColors.heroPanel),
      _ => (
        normalized.isEmpty ? '—' : status,
        AppColors.muted,
        AppColors.heroPanel,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Counterparty extends StatelessWidget {
  const _Counterparty({required this.invoice, required this.fallbackName});
  final ShopInvoiceDetail invoice;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final name = invoice.shopName ?? fallbackName;
    final eyebrow = invoice.isSale ? 'ISSUED TO' : 'ISSUED BY';
    final iconData = invoice.isSale
        ? AppIcons.personOutlineRounded
        : AppIcons.storefrontOutlined;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.avatarSm,
            height: AppSizes.avatarSm,
            decoration: ShapeDecoration(
              color: AppColors.brandSoft,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              iconData,
              color: AppColors.brand,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                    height: 1.2,
                  ),
                ),
                if (invoice.shopPhone != null) ...[
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    invoice.shopPhone!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (invoice.shopGstin != null)
                  Text(
                    'GSTIN ${invoice.shopGstin!}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
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
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  _meta(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Text(
            money.format(item.total),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.black,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  (strong
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodySmall)
                      ?.copyWith(
                        color: strong ? AppColors.black : AppColors.muted,
                        fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                        letterSpacing: strong ? -0.1 : 0,
                      ),
            ),
          ),
          Text(
            value,
            style:
                (strong
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodySmall)
                    ?.copyWith(
                      color: valueColor ?? AppColors.black,
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
          const AppIcon(
            AppIcons.stickyNote2Outlined,
            color: AppColors.muted,
            size: AppSizes.iconSm,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.black,
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

class _ShopInvoiceDetailSkeleton extends StatelessWidget {
  const _ShopInvoiceDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, AppSizes.md, 0, AppSizes.huge),
      children: const [
        _SkeletonHeader(),
        _SkeletonSpacedDivider(),
        _SkeletonCounterparty(),
        SizedBox(height: AppSizes.xl),
        _SkeletonItemsSection(),
        _SkeletonSpacedDivider(),
        _SkeletonTotals(),
      ],
    );
  }
}

class _SkeletonHeader extends StatelessWidget {
  const _SkeletonHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              Expanded(child: AppShimmerLine(widthFactor: 0.35, height: 12)),
              AppShimmerBox(width: 56, height: 22, radius: AppSizes.radiusFull),
            ],
          ),
          SizedBox(height: AppSizes.sm),
          AppShimmerLine(widthFactor: 0.6, height: 22),
          SizedBox(height: AppSizes.xs),
          Row(
            children: [
              AppShimmerBox(width: 14, height: 14, radius: 3),
              SizedBox(width: AppSizes.xs),
              AppShimmerLine(widthFactor: 0.3, height: 12),
            ],
          ),
        ],
      ),
    );
  }
}

class _SkeletonSpacedDivider extends StatelessWidget {
  const _SkeletonSpacedDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
    child: AppDivider.flush(),
  );
}

class _SkeletonCounterparty extends StatelessWidget {
  const _SkeletonCounterparty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          AppShimmerBox(
            width: AppSizes.avatarSm,
            height: AppSizes.avatarSm,
            radius: AppSizes.radiusSm,
          ),
          SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.25, height: 11),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.55, height: 16),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.4, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonItemsSection extends StatelessWidget {
  const _SkeletonItemsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.lg,
            0,
            AppSizes.lg,
            AppSizes.sm,
          ),
          child: Row(
            children: [
              Expanded(child: AppShimmerLine(widthFactor: 0.2, height: 11)),
              AppShimmerLine(widthFactor: 0.1, height: 11),
            ],
          ),
        ),
        AppDivider.flush(),
        _SkeletonItemRow(),
        AppDivider.flush(),
        _SkeletonItemRow(),
        AppDivider.flush(),
        _SkeletonItemRow(),
        AppDivider.flush(),
        _SkeletonItemRow(),
      ],
    );
  }
}

class _SkeletonItemRow extends StatelessWidget {
  const _SkeletonItemRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.55, height: 14),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.75, height: 11),
              ],
            ),
          ),
          SizedBox(width: AppSizes.md),
          AppShimmerLine(widthFactor: 0.18, height: 14),
        ],
      ),
    );
  }
}

class _SkeletonTotals extends StatelessWidget {
  const _SkeletonTotals();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Column(
        children: const [
          _SkeletonTotalsRow(labelFactor: 0.2, valueFactor: 0.22),
          _SkeletonTotalsRow(labelFactor: 0.12, valueFactor: 0.18),
          _SkeletonTotalsRow(labelFactor: 0.18, valueFactor: 0.20),
          Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: AppDivider.flush(),
          ),
          _SkeletonTotalsRow(
            labelFactor: 0.14,
            valueFactor: 0.26,
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _SkeletonTotalsRow extends StatelessWidget {
  const _SkeletonTotalsRow({
    required this.labelFactor,
    required this.valueFactor,
    this.strong = false,
  });

  final double labelFactor;
  final double valueFactor;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final h = strong ? 16.0 : 12.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        children: [
          Expanded(
            child: AppShimmerLine(widthFactor: labelFactor, height: h),
          ),
          AppShimmerLine(widthFactor: valueFactor, height: h),
        ],
      ),
    );
  }
}
