import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_invoice_detail_page.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

class ShopInvoicesPage extends StatefulWidget {
  const ShopInvoicesPage({super.key, required this.shop});
  final LinkedShop shop;

  @override
  State<ShopInvoicesPage> createState() => _ShopInvoicesPageState();
}

class _ShopInvoicesPageState extends State<ShopInvoicesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ShopsProvider>().loadInvoices(widget.shop);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ShopsProvider>();
    final loading = p.isLoadingInvoices(widget.shop);
    final invoices = p.invoicesFor(widget.shop) ?? const [];
    final err = p.invoiceErrorFor(widget.shop);

    return Scaffold(
      appBar: AppBar(title: Text(widget.shop.name)),
      body: RefreshIndicator(
        onRefresh: () => p.loadInvoices(widget.shop),
        color: AppColors.brand,
        child: loading && invoices.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : err != null && invoices.isEmpty
                ? _Error(err: err, onRetry: () => p.loadInvoices(widget.shop))
                : invoices.isEmpty
                    ? const _EmptyInvoices()
                    : ListView.separated(
                        itemCount: invoices.length,
                        separatorBuilder: (_, __) =>
                            Container(height: 1, color: AppColors.hairline),
                        itemBuilder: (_, i) => _InvoiceTile(
                          invoice: invoices[i],
                          shop: widget.shop,
                        ),
                      ),
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice, required this.shop});
  final ShopInvoice invoice;
  final LinkedShop shop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = invoice.isSale ? AppColors.success : AppColors.accentIndigo;
    final accentSoft = invoice.isSale ? AppColors.successSoft : AppColors.accentIndigoSoft;
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ShopInvoiceDetailPage(
            shop: shop,
            invoiceId: invoice.id,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: ShapeDecoration(
                color: accentSoft,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(
                invoice.isSale ? Icons.south_west_rounded : Icons.north_east_rounded,
                color: accent,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNo,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${DateFormat('d MMM yyyy').format(invoice.invoiceDate.toLocal())} · '
                    '${invoice.itemCount} ${AppStrings.items}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${AppStrings.currencySymbol}${invoice.total.toStringAsFixed(2)}',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: AppSizes.xs),
            const Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}

class _EmptyInvoices extends StatelessWidget {
  const _EmptyInvoices();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined,
                color: AppColors.muted, size: 48),
            const SizedBox(height: AppSizes.lg),
            Text(
              AppStrings.noInvoicesTitle,
              style:
                  theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              AppStrings.noInvoicesHint,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.err, required this.onRetry});
  final String err;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
            const SizedBox(height: AppSizes.sm),
            Text(err, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.md),
            FilledButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
          ],
        ),
      ),
    );
  }
}
