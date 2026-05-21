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
import 'package:shopxy/features/stock/presentation/pages/stock_ledger_page.dart';
import 'package:shopxy/features/stock/presentation/widgets/stock_bottom_sheet.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/app_units.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

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
      if (!mounted) return;
      setState(() {
        _stockInTransactions = transactions;
        _isSupplierHistoryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
      backgroundColor: AppColors.white,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => StockBottomSheet(product: _product!, initialType: type),
    ).then((_) => _refreshAll());
  }

  void _openLedger() {
    if (_product == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StockLedgerPage(
          productId: _product!.id,
          productName: _product!.name,
          productUnit: _product!.unit,
        ),
      ),
    );
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
                  color: AppColors.white,
                  shape: AppShapes.squircle(
                    AppSizes.radiusMd,
                    side: BorderSide(color: AppColors.hairline, width: 1),
                  ),
                ),
                child: QrImageView(
                  data: code,
                  size: AppSizes.qrCodeSize,
                  backgroundColor: AppColors.white,
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
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
          ),
          actions: [
            AppButton.ghost(
              label: 'Close',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }

  void _deleteProduct() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: AppStrings.delete,
      message: AppStrings.deleteProductConfirm,
      confirmLabel: AppStrings.delete,
      danger: true,
    );

    if (confirmed && mounted) {
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
            icon: const Icon(Icons.edit_outlined),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
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
        color: AppColors.black,
        backgroundColor: AppColors.white,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            _ProductHeaderCard(product: p),
            const SizedBox(height: AppSizes.md),
            _StockStatusCard(product: p),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: AppButton.secondary(
                    label: AppStrings.stockIn,
                    icon: Icons.add_rounded,
                    onPressed: () => _openStockSheet('STOCK_IN'),
                    fullWidth: true,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: AppButton.primary(
                    label: AppStrings.stockOut,
                    icon: Icons.remove_rounded,
                    onPressed: () => _openStockSheet('STOCK_OUT'),
                    fullWidth: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            AppCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg,
                vertical: AppSizes.md,
              ),
              onTap: _openLedger,
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    color: AppColors.black,
                    size: AppSizes.iconMd,
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock ledger',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          'Every movement with source documents',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: AppColors.muted,
                    size: AppSizes.iconSm,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            _DetailSection(
              title: 'PRICING',
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
            _DetailSection(
              title: 'DETAILS',
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
}

class _ProductHeaderCard extends StatelessWidget {
  const _ProductHeaderCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIconAvatar(
                icon: Icons.inventory_2_outlined,
                size: 56,
              ),
              const SizedBox(width: AppSizes.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${product.sku}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    if (product.category != null) ...[
                      const SizedBox(height: 4),
                      AppStatusBadge(
                        label: product.category!.name,
                        dense: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (product.description != null &&
              product.description!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.md),
            Text(
              product.description!,
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _StockStatusCard extends StatelessWidget {
  const _StockStatusCard({required this.product});

  final Product product;

  AppStatusTone get _tone {
    if (product.isOutOfStock) return AppStatusTone.error;
    if (product.isLowStock) return AppStatusTone.warning;
    return AppStatusTone.success;
  }

  IconData get _icon {
    if (product.isOutOfStock) return Icons.error_outline_rounded;
    if (product.isLowStock) return Icons.warning_amber_rounded;
    return Icons.check_circle_outline_rounded;
  }

  String get _label {
    if (product.isOutOfStock) return AppStrings.outOfStock;
    if (product.isLowStock) return AppStrings.lowStock;
    return AppStrings.inStock;
  }

  String _formatQty(double qty) {
    return qty.truncateToDouble() == qty
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatQty(product.stockQuantity)} ${AppUnits.label(product.unit)}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Low stock alert at ${_formatQty(product.lowStockThreshold)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          AppStatusBadge(label: _label, tone: _tone, icon: _icon),
        ],
      ),
    );
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
        AppSectionHeader(
          title: AppStrings.supplierPriceHistory.toUpperCase(),
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: _buildContent(theme, suppliers),
        ),
      ],
    );
  }

  Widget _buildContent(
    ThemeData theme,
    List<MapEntry<String, List<StockTransaction>>> suppliers,
  ) {
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
        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
      );
    }

    if (suppliers.isEmpty) {
      return Text(
        AppStrings.noSupplierHistory,
        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < suppliers.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: AppSizes.md),
            const AppDivider.flush(),
            const SizedBox(height: AppSizes.md),
          ],
          _SupplierHistoryTile(
            supplierName: suppliers[i].key,
            transactions: suppliers[i].value,
            currencyFormat: currencyFormat,
          ),
        ],
      ],
    );
  }

  List<MapEntry<String, List<StockTransaction>>> _groupBySupplier(
    List<StockTransaction> source,
  ) {
    final grouped = <String, List<StockTransaction>>{};
    for (final tx in source) {
      final key = tx.displaySupplier?.trim();
      if (key == null || key.isEmpty) continue;
      grouped.putIfAbsent(key, () => []).add(tx);
    }
    final entries = grouped.entries.toList();
    entries.sort(
      (a, b) => b.value.first.createdAt.compareTo(a.value.first.createdAt),
    );
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
    final sorted = [...transactions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                supplierName.isEmpty ? AppStrings.unknownSupplier : supplierName,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (isVendor)
              const AppStatusBadge(
                label: AppStrings.vendor,
                icon: Icons.business_rounded,
                dense: true,
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
          value:
              averagePrice == null ? '-' : currencyFormat.format(averagePrice),
        ),
        _SupplierMetricRow(
          label: AppStrings.totalQuantityBought,
          value:
              '${totalQty % 1 == 0 ? totalQty.toInt() : totalQty.toStringAsFixed(2)} (${transactions.length} ${AppStrings.transactions})',
        ),
        _SupplierMetricRow(
          label: AppStrings.lastStockIn,
          value: DateFormat('dd MMM yyyy, hh:mm a').format(lastStockIn.toLocal()),
        ),
        _SupplierMetricRow(label: AppStrings.policy, value: lastPolicy),
        const SizedBox(height: AppSizes.sm),
        Text(
          AppStrings.recentBuys,
          style: theme.textTheme.labelMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSizes.xs),
        ...sorted.take(5).map((tx) {
          final date = DateFormat('dd MMM yyyy').format(tx.createdAt.toLocal());
          final qty = tx.quantity % 1 == 0
              ? tx.quantity.toInt().toString()
              : tx.quantity.toStringAsFixed(2);
          final price =
              tx.unitPrice == null ? '-' : currencyFormat.format(tx.unitPrice);
          return Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    date,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ),
                Text(
                  'Qty: $qty',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Text(
                  price,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _policyLabel(String? mode) {
    if (mode == 'WEIGHTED_AVERAGE') return AppStrings.weightedAverage;
    if (mode == 'USE_LATEST') return AppStrings.useLatestPrice;
    if (mode == 'KEEP_CURRENT') return AppStrings.keepCurrentPrice;
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
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
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
        AppSectionHeader(
          title: title,
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                if (i > 0) const AppDivider.flush(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        rows[i].label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      Text(
                        rows[i].value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
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
