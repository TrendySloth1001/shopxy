import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/pages/add_edit_product_page.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/stock/data/datasources/stock_remote_data_source.dart';
import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';
import 'package:shopxy/features/stock/presentation/widgets/stock_bottom_sheet.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/app_units.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});
  final int productId;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Product? _product;
  bool _isLoading = true;
  bool _isSupplierHistoryLoading = true;
  String? _supplierHistoryError;
  List<StockTransaction> _stockInTransactions = const [];

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadProduct(), _loadSupplierHistory()]);
  }

  Future<void> _loadProduct() async {
    setState(() => _isLoading = true);
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      _product = await ds.getProduct(widget.productId);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSupplierHistory() async {
    setState(() {
      _isSupplierHistoryLoading = true;
      _supplierHistoryError = null;
    });

    try {
      final ds = context.read<StockRemoteDataSource>();
      final transactions = await ds.getTransactions(
        productId: widget.productId,
        type: 'STOCK_IN',
        limit: 100,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _stockInTransactions = transactions;
        _isSupplierHistoryLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _supplierHistoryError = e.toString();
        _isSupplierHistoryLoading = false;
      });
    }
  }

  void _openEdit() async {
    if (_product == null) return;
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddEditProductPage(product: _product)),
    );
    if (updated == true) {
      _refreshAll();
    }
  }

  void _openStockSheet(String type) {
    if (_product == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => StockBottomSheet(product: _product!, initialType: type),
    ).then((_) => _refreshAll());
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
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: AppShapes.squircle(AppSizes.radiusMd),
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
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            // Product header
            Container(
              padding: const EdgeInsets.all(AppSizes.xl),
              decoration: ShapeDecoration(
                color: theme.cardTheme.color,
                shape: AppShapes.squircle(
                  AppSizes.radiusLg,
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                  ),
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
                        decoration: ShapeDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          shape: AppShapes.squircle(AppSizes.radiusMd),
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
              decoration: ShapeDecoration(
                color: stockColor.withValues(alpha: 0.05),
                shape: AppShapes.squircle(
                  AppSizes.radiusMd,
                  side: BorderSide(color: stockColor.withValues(alpha: 0.2)),
                ),
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
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.md,
                      ),
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
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.md,
                      ),
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
                _DetailRow(
                  AppStrings.sellingPrice,
                  currencyFormat.format(p.sellingPrice),
                ),
                _DetailRow(
                  AppStrings.purchasePrice,
                  currencyFormat.format(p.purchasePrice),
                ),
                _DetailRow(AppStrings.taxPercent, '${p.taxPercent}%'),
                _DetailRow('Profit Margin', '${p.margin.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: AppSizes.lg),

            _SupplierPriceHistorySection(
              transactions: _stockInTransactions,
              isLoading: _isSupplierHistoryLoading,
              errorMessage: _supplierHistoryError,
              currencyFormat: currencyFormat,
            ),
            const SizedBox(height: AppSizes.lg),

            // Additional details
            _DetailSection(
              title: 'Details',
              rows: [
                if (p.barcode != null)
                  _DetailRow(AppStrings.barcode, p.barcode!),
                if (p.hsnCode != null)
                  _DetailRow(AppStrings.hsnCode, p.hsnCode!),
                _DetailRow(AppStrings.unit, AppUnits.label(p.unit)),
                _DetailRow(
                  'Created',
                  DateFormat('dd MMM yyyy').format(p.createdAt.toLocal()),
                ),
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

class _SupplierPriceHistorySection extends StatelessWidget {
  const _SupplierPriceHistorySection({
    required this.transactions,
    required this.isLoading,
    required this.errorMessage,
    required this.currencyFormat,
  });

  final List<StockTransaction> transactions;
  final bool isLoading;
  final String? errorMessage;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suppliers = _groupBySupplier(transactions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.supplierPriceHistory,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: ShapeDecoration(
            color: theme.cardTheme.color,
            shape: AppShapes.squircle(
              AppSizes.radiusMd,
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: _buildContent(context, suppliers),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<MapEntry<String, List<StockTransaction>>> suppliers,
  ) {
    final theme = Theme.of(context);

    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (errorMessage != null) {
      return Text(
        AppStrings.error,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
      );
    }

    if (suppliers.isEmpty) {
      return Text(
        AppStrings.noSupplierHistory,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: suppliers.map((entry) {
        final isLast = entry == suppliers.last;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : AppSizes.lg),
          child: _SupplierHistoryTile(
            supplierName: entry.key,
            transactions: entry.value,
            currencyFormat: currencyFormat,
          ),
        );
      }).toList(),
    );
  }

  List<MapEntry<String, List<StockTransaction>>> _groupBySupplier(
    List<StockTransaction> source,
  ) {
    final grouped = <String, List<StockTransaction>>{};

    for (final tx in source) {
      // Prefer vendorName, fall back to supplierName, skip if both null
      final key = tx.displaySupplier?.trim();
      if (key == null || key.isEmpty) continue;
      grouped.putIfAbsent(key, () => []).add(tx);
    }

    final entries = grouped.entries.toList();
    entries.sort((a, b) => b.value.first.createdAt.compareTo(a.value.first.createdAt));
    return entries;
  }
}

class _SupplierHistoryTile extends StatelessWidget {
  const _SupplierHistoryTile({
    required this.supplierName,
    required this.transactions,
    required this.currencyFormat,
  });

  final String supplierName;
  final List<StockTransaction> transactions;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sorted = [...transactions]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final priceValues = sorted
        .where((t) => t.unitPrice != null)
        .map((t) => t.unitPrice!)
        .toList();
    final latestPrice = priceValues.isNotEmpty ? priceValues.first : null;
    final averagePrice = priceValues.isEmpty
        ? null
        : priceValues.reduce((s, p) => s + p) / priceValues.length;
    final totalQty = transactions.fold<double>(0, (s, t) => s + t.quantity);
    final lastStockIn = sorted.first.createdAt;
    final lastPolicy = _policyLabel(sorted.first.purchasePriceMode);
    final isVendor = sorted.first.vendorId != null;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  supplierName.isEmpty ? AppStrings.unknownSupplier : supplierName,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (isVendor)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.business_rounded,
                        size: 11,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        AppStrings.vendor,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          _SupplierMetricRow(
            label: AppStrings.latestPrice,
            value: latestPrice == null ? '-' : currencyFormat.format(latestPrice),
          ),
          _SupplierMetricRow(
            label: AppStrings.averagePrice,
            value: averagePrice == null ? '-' : currencyFormat.format(averagePrice),
          ),
          _SupplierMetricRow(
            label: AppStrings.totalQuantityBought,
            value: '${totalQty % 1 == 0 ? totalQty.toInt() : totalQty.toStringAsFixed(2)} (${transactions.length} ${AppStrings.transactions})',
          ),
          _SupplierMetricRow(
            label: AppStrings.lastStockIn,
            value: DateFormat('dd MMM yyyy, hh:mm a').format(lastStockIn.toLocal()),
          ),
          _SupplierMetricRow(label: AppStrings.policy, value: lastPolicy),
          const SizedBox(height: AppSizes.sm),
          Text(
            AppStrings.recentBuys,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          ...sorted.take(5).map((tx) {
            final date = DateFormat('dd MMM yyyy').format(tx.createdAt.toLocal());
            final qty = tx.quantity % 1 == 0
                ? tx.quantity.toInt().toString()
                : tx.quantity.toStringAsFixed(2);
            final price = tx.unitPrice == null ? '-' : currencyFormat.format(tx.unitPrice);
            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      date,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Text(
                    'Qty: $qty',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Text(
                    price,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _policyLabel(String? mode) {
    if (mode == 'WEIGHTED_AVERAGE') {
      return AppStrings.weightedAverage;
    }
    if (mode == 'USE_LATEST') {
      return AppStrings.useLatestPrice;
    }
    if (mode == 'KEEP_CURRENT') {
      return AppStrings.keepCurrentPrice;
    }
    return '-';
  }
}

class _SupplierMetricRow extends StatelessWidget {
  const _SupplierMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
          decoration: ShapeDecoration(
            color: theme.cardTheme.color,
            shape: AppShapes.squircle(
              AppSizes.radiusMd,
              side: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
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
