import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/pages/add_edit_product_page.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/stock/presentation/widgets/stock_bottom_sheet.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/app_units.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});
  final int productId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Product? _product;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      _product = await ds.getProduct(widget.productId);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _openEdit() async {
    if (_product == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditProductPage(product: _product),
      ),
    );
    if (updated == true) _loadProduct();
  }

  void _openStockSheet(String type) {
    if (_product == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSizes.bottomSheetRadius),
        ),
      ),
      builder: (_) => StockBottomSheet(
        product: _product!,
        initialType: type,
      ),
    ).then((_) => _loadProduct());
  }

  void _showQrDialog() {
    if (_product == null) return;
    final code = _product!.barcode ?? _product!.sku;
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          title: const Text(AppStrings.generateQr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: QrImageView(
                  data: code,
                  size: AppSizes.qrCodeSize,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Text(
                code,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                _product!.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.deleteProductConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<ProductsProvider>().deleteProduct(widget.productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.productDeleted)),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: AppStrings.currencySymbol,
      decimalDigits: 2,
    );

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text(AppStrings.error)),
      );
    }

    final p = _product!;
    final stockColor = p.isOutOfStock
        ? theme.colorScheme.error
        : p.isLowStock
            ? const Color(0xFFF59E0B)
            : const Color(0xFF1F8A5B);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.productDetails),
        actions: [
          IconButton(
            onPressed: _showQrDialog,
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: AppStrings.generateQr,
          ),
          IconButton(
            onPressed: _openEdit,
            icon: const Icon(Icons.edit_rounded),
          ),
          PopupMenuButton(
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text(AppStrings.delete),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') _deleteProduct();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadProduct,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            // Product header
            Container(
              padding: const EdgeInsets.all(AppSizes.xl),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: theme.colorScheme.primary,
                          size: AppSizes.iconXl,
                        ),
                      ),
                      const SizedBox(width: AppSizes.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name, style: theme.textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              'SKU: ${p.sku}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (p.category != null)
                              Text(
                                p.category!.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (p.description != null && p.description!.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.md),
                    Text(
                      p.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSizes.lg),

            // Stock status card
            Container(
              padding: const EdgeInsets.all(AppSizes.lg),
              decoration: BoxDecoration(
                color: stockColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(color: stockColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    p.isOutOfStock
                        ? Icons.error_outline_rounded
                        : p.isLowStock
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                    color: stockColor,
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_formatQty(p.stockQuantity)} ${AppUnits.label(p.unit)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: stockColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Low stock alert at ${_formatQty(p.lowStockThreshold)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.md),

            // Stock action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openStockSheet('STOCK_IN'),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(AppStrings.stockIn),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1F8A5B),
                      side: const BorderSide(color: Color(0xFF1F8A5B)),
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openStockSheet('STOCK_OUT'),
                    icon: const Icon(Icons.remove_rounded),
                    label: const Text(AppStrings.stockOut),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xxl),

            // Pricing details
            _DetailSection(
              title: 'Pricing',
              rows: [
                _DetailRow(AppStrings.mrp, currencyFormat.format(p.mrp)),
                _DetailRow(AppStrings.sellingPrice, currencyFormat.format(p.sellingPrice)),
                _DetailRow(AppStrings.purchasePrice, currencyFormat.format(p.purchasePrice)),
                _DetailRow(AppStrings.taxPercent, '${p.taxPercent}%'),
                _DetailRow('Profit Margin', '${p.margin.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: AppSizes.lg),

            // Additional details
            _DetailSection(
              title: 'Details',
              rows: [
                if (p.barcode != null) _DetailRow(AppStrings.barcode, p.barcode!),
                if (p.hsnCode != null) _DetailRow(AppStrings.hsnCode, p.hsnCode!),
                _DetailRow(AppStrings.unit, AppUnits.label(p.unit)),
                _DetailRow('Created', DateFormat('dd MMM yyyy').format(p.createdAt.toLocal())),
              ],
            ),
            const SizedBox(height: AppSizes.huge),
          ],
        ),
      ),
    );
  }

  String _formatQty(double qty) {
    return qty.truncateToDouble() == qty
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.rows});
  final String title;
  final List<_DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: rows.map((row) {
              final isLast = row == rows.last;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : AppSizes.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      row.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      row.value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DetailRow {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
}
