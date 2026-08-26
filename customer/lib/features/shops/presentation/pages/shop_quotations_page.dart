import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/request_quotation_page.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_quotation_detail_page.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_list_section.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

class ShopQuotationsPage extends StatefulWidget {
  const ShopQuotationsPage({super.key, required this.shop});
  final LinkedShop shop;

  @override
  State<ShopQuotationsPage> createState() => _ShopQuotationsPageState();
}

class _ShopQuotationsPageState extends State<ShopQuotationsPage> {
  final NumberFormat _currency = AppFormat.inr;
  final _dateFmt = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ShopsProvider>().loadQuotations(widget.shop);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ShopsProvider>();
    final quotes = p.quotationsFor(widget.shop) ?? const <ShopQuotation>[];
    final loading = p.isLoadingQuotations(widget.shop);

    return Scaffold(
      appBar: AppBar(title: const Text('Quotations')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final prov = context.read<ShopsProvider>();
          final sent = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => RequestQuotationPage(shop: widget.shop),
            ),
          );
          if (sent == true) prov.loadQuotations(widget.shop);
        },
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.white,
        icon: const AppIcon(AppIcons.addRounded),
        label: Text(
          'Request a quote',
          style: Theme.of(context).textTheme.labelLarge?.extraBold,
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () => p.loadQuotations(widget.shop),
        child: loading && quotes.isEmpty
            ? const _QuotationListSkeleton()
            : quotes.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  const AppIcon(
                    AppIcons.requestQuoteOutlined,
                    size: AppSizes.iconHuge,
                    color: AppColors.muted,
                  ),
                  const SizedBox(height: AppSizes.md),
                  Center(
                    child: Text(
                      'No quotations yet. Tap “Request a quote” to ask\nthis shop to price a basket for you.',
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.only(top: AppSizes.sm),
                children: [
                  AppListSection(
                    flushDividers: true,
                    children: [
                      for (final q in quotes)
                        _QuotationRow(
                          q: q,
                          currency: _currency,
                          dateFmt: _dateFmt,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ShopQuotationDetailPage(
                                shop: widget.shop,
                                quotation: q,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _QuotationListSkeleton extends StatelessWidget {
  const _QuotationListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(top: AppSizes.sm),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        AppListSection(
          flushDividers: true,
          children: List.generate(6, (_) => const _QuotationRowSkeleton()),
        ),
      ],
    );
  }
}

class _QuotationRowSkeleton extends StatelessWidget {
  const _QuotationRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppShimmerBox(
                      width: 80,
                      height: 20,
                      radius: AppSizes.radiusSm,
                    ),
                    const SizedBox(width: AppSizes.sm),
                    AppShimmerBox(
                      width: 60,
                      height: 20,
                      radius: AppSizes.radiusFull,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                const AppShimmerLine(widthFactor: 0.65, height: 13),
              ],
            ),
          ),
          AppShimmerBox(width: 70, height: 20, radius: AppSizes.radiusSm),
          const SizedBox(width: AppSizes.xs),
          AppShimmerBox(width: 20, height: 20, radius: AppSizes.radiusSm),
        ],
      ),
    );
  }
}

class _QuotationRow extends StatelessWidget {
  const _QuotationRow({
    required this.q,
    required this.currency,
    required this.dateFmt,
    required this.onTap,
  });
  final ShopQuotation q;
  final NumberFormat currency;
  final DateFormat dateFmt;
  final VoidCallback onTap;

  (Color, Color, String) _style() {
    switch (q.status) {
      case 'REQUESTED':
        return (AppColors.brand, AppColors.brandSoft, 'Requested');
      case 'PENDING':
        return (AppColors.warning, AppColors.warningSoft, 'Awaiting you');
      case 'ACCEPTED':
        return (AppColors.success, AppColors.successSoft, 'Accepted');
      case 'DECLINED':
        return (AppColors.error, AppColors.errorSoft, 'Declined');
      case 'CANCELLED':
        return (AppColors.muted, AppColors.hairline, 'Withdrawn');
      default:
        return (AppColors.muted, AppColors.hairline, q.status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (fg, bg, label) = _style();
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        q.quotationNo,
                        style: theme.textTheme.bodyLarge?.extraBold,
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Container(
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
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    '${dateFmt.format(q.createdAt.toLocal())} · ${q.items.length} item(s)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              currency.format(q.total),
              style: theme.textTheme.bodyLarge?.extraBold,
            ),
            const SizedBox(width: AppSizes.xs),
            const AppIcon(AppIcons.chevronRightRounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
