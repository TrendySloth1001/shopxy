import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/pages/add_edit_product_page.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_icon_catalog.dart';
import 'package:shopxy/features/custom_fields/data/datasources/custom_fields_remote_data_source.dart';
import 'package:shopxy/features/custom_fields/domain/entities/custom_field.dart';
import 'package:shopxy/features/custom_fields/presentation/providers/custom_fields_provider.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/products/presentation/widgets/product_image_carousel.dart';
import 'package:shopxy/features/products/presentation/widgets/product_thumbnail.dart';
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

  // Custom field values for this product. Empty by default — populated
  // alongside the supplier history on every refresh so the detail page
  // never shows stale specs.
  List<ProductCustomFieldValue> _customFieldValues = const [];

  // Draft invoices that contain this product. Stock movements created
  // from the stock-in/out sheet land here until the user confirms them
  // — surfacing them on the detail page tells the user "your stock count
  // will change once these are confirmed" so the count never feels stale.
  List<Invoice> _pendingDrafts = const [];

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    // Tree lookup (sections + their names) is needed to label the
    // Specifications groups. Provider caches across pages so this is
    // a no-op once the user has visited settings or another product.
    final cf = context.read<CustomFieldsProvider>();
    final treeFuture = cf.hasLoadedOnce ? Future.value() : cf.load();

    await Future.wait([
      _loadProduct(),
      _loadSupplierHistory(),
      _loadCustomFieldValues(),
      _loadPendingDrafts(),
      treeFuture,
    ]);
  }

  /// Pulls the list of DRAFT invoices that include this product so the
  /// detail page can show a callout. Backend filters via
  /// `items.some.productId`, so we only get the relevant drafts — keeps
  /// the response small even on shops with hundreds of open drafts.
  Future<void> _loadPendingDrafts() async {
    try {
      final ds = context.read<InvoicesRemoteDataSource>();
      final drafts = await ds.getInvoices(
        status: 'DRAFT',
        productId: widget.productId,
        limit: 20,
      );
      if (!mounted) return;
      setState(() => _pendingDrafts = drafts);
    } catch (_) {
      // Non-blocking — if the call fails we just don't show the callout.
    }
  }

  /// Build the SPECIFICATIONS area as one [_DetailSection] per
  /// shop-side section, plus a fallback group for ungrouped values.
  /// Sections with no filled-in values collapse away — the page stays
  /// tight even when many definitions exist.
  List<Widget> _buildCustomFieldSections() {
    if (_customFieldValues.isEmpty) return const [];

    // Section-id → name resolved from the provider. Definitions
    // shipped on each value already carry sectionId, so this is
    // a cheap lookup once the tree is loaded.
    final cf = context.watch<CustomFieldsProvider>();
    final sectionNames = <int, String>{
      for (final s in cf.sections) s.id: s.name,
    };

    final Map<int?, List<ProductCustomFieldValue>> bySection = {};
    for (final v in _customFieldValues
        .where((v) => v.value.trim().isNotEmpty)) {
      bySection.putIfAbsent(v.definition.sectionId, () => []).add(v);
    }
    if (bySection.isEmpty) return const [];

    final widgets = <Widget>[];
    final ungrouped = bySection.remove(null);
    if (ungrouped != null) {
      widgets.add(_buildSection(AppStrings.specifications, ungrouped));
      widgets.add(const SizedBox(height: AppSizes.lg));
    }
    // Render sections in provider order (which itself is sortOrder-
    // then-name) so the detail page matches the form's grouping.
    final orderedSectionIds = [
      for (final s in cf.sections) s.id,
      ...bySection.keys.where((id) => id != null && !sectionNames.containsKey(id)),
    ];
    for (final sectionId in orderedSectionIds) {
      final values = bySection[sectionId];
      if (values == null || values.isEmpty) continue;
      widgets.add(_buildSection(
        sectionNames[sectionId] ?? AppStrings.specifications,
        values,
      ));
      widgets.add(const SizedBox(height: AppSizes.lg));
    }
    return widgets;
  }

  Widget _buildSection(
    String title,
    List<ProductCustomFieldValue> values,
  ) {
    return _DetailSection(
      title: title.toUpperCase(),
      rows: values
          .map(
            (v) => _DetailRow(
              v.definition.name,
              _formatCustomFieldValue(v),
              // Paragraphy values stack label-above-value so reading
              // them isn't a right-aligned eye-strain exercise. Same
              // rule for any TEXT/DROPDOWN value that's long enough
              // to need wrapping — a single short word like "DC" can
              // stay inline on the right.
              stack: v.definition.type == CustomFieldType.LONG_TEXT ||
                  v.value.length > 40 ||
                  v.value.contains('\n'),
            ),
          )
          .toList(),
    );
  }

  /// Pretty-print a custom field value for the DETAILS-style row.
  /// Backend stores everything as a string; type-aware rendering lives
  /// here so the wire format stays uniform.
  String _formatCustomFieldValue(ProductCustomFieldValue v) {
    switch (v.definition.type) {
      case CustomFieldType.DATE:
        final parsed = DateTime.tryParse(v.value);
        if (parsed == null) return v.value;
        return DateFormat('dd MMM yyyy').format(parsed.toLocal());
      case CustomFieldType.BOOLEAN:
        return v.value == 'true' ? 'Yes' : 'No';
      case CustomFieldType.NUMBER:
        final suffix = v.definition.unitSuffix;
        if (suffix == null || suffix.isEmpty) return v.value;
        return '${v.value} $suffix';
      case CustomFieldType.TEXT:
      case CustomFieldType.LONG_TEXT:
      case CustomFieldType.DROPDOWN:
        return v.value;
    }
  }

  Future<void> _loadCustomFieldValues() async {
    try {
      final ds = context.read<CustomFieldsRemoteDataSource>();
      final values = await ds.listValuesForProduct(widget.productId);
      if (!mounted) return;
      setState(() => _customFieldValues = values);
    } catch (_) {
      // Specs are non-blocking; if they fail we just don't render the
      // section, rather than erroring the whole detail page.
    }
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

  Future<void> _openStockSheet(String type) async {
    if (_product == null) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => StockBottomSheet(product: _product!, initialType: type),
    );
    if (!mounted) return;
    // Only the product (stock count / cached purchase price) and the
    // supplier history actually move when a stock entry is posted. The
    // custom-field tree and the per-product values don't — re-fetching
    // them on every open/dismiss multiplied DB load for nothing.
    if (saved == true) {
      // The stock sheet creates a new DRAFT invoice — refresh the
      // pending-drafts callout too so the user immediately sees their
      // entry waiting to be confirmed.
      await Future.wait([
        _loadProduct(),
        _loadSupplierHistory(),
        _loadPendingDrafts(),
      ]);
    }
  }

  void _openInvoice(int id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoiceId: id)),
    ).then((_) {
      // Coming back from invoice detail: the user may have confirmed
      // or cancelled drafts that affect this product, so refresh.
      if (mounted) _loadPendingDrafts();
      if (mounted) _loadProduct();
    });
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
      bottomNavigationBar: _StockActionBar(
        onStockIn: () => _openStockSheet('STOCK_IN'),
        onStockOut: () => _openStockSheet('STOCK_OUT'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: AppColors.black,
        backgroundColor: AppColors.white,
        child: ListView(
          // No outer padding — the carousel needs to bleed full-
          // width to the screen edges. The content below is wrapped
          // in its own Padding instead.
          padding: EdgeInsets.zero,
          children: [
            // Carousel pages through every image the product has;
            // falls back to a monogram band when there are none.
            // Tap any image opens a pinch-zoom lightbox. Lives in
            // the scroll view so the user can scroll past it
            // instead of having it occupy permanent top real-estate.
            ProductImageCarousel(product: p),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.lg,
                AppSizes.lg,
                AppSizes.huge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProductHeaderCard(product: p),
            const SizedBox(height: AppSizes.md),
            _StockStatusCard(product: p),
            if (_pendingDrafts.isNotEmpty) ...[
              const SizedBox(height: AppSizes.md),
              _PendingDraftsCard(
                drafts: _pendingDrafts,
                productUnit: p.unit,
                onTap: _openInvoice,
              ),
            ],
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
                          AppStrings.stockLedger,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        Text(
                          AppStrings.stockLedgerHint,
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
                _DetailRow(AppStrings.profitMargin, '${p.margin.toStringAsFixed(1)}%'),
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
            // Custom-field values render between supplier history and
            // the immutable DETAILS section, grouped by their section
            // definitions (one [_DetailSection] per shop-side
            // [CustomFieldSection]). Values with no section land in a
            // generic SPECIFICATIONS group.
            ..._buildCustomFieldSections(),
            _DetailSection(
              title: 'DETAILS',
              rows: [
                if (p.barcode != null)
                  _DetailRow(AppStrings.barcode, p.barcode!),
                if (p.hsnCode != null)
                  _DetailRow(AppStrings.hsnCode, p.hsnCode!),
                _DetailRow(AppStrings.unit, AppUnits.label(p.unit)),
                _DetailRow(
                  AppStrings.created,
                  DateFormat('dd MMM yyyy').format(p.createdAt.toLocal()),
                ),
              ],
            ),
                  const SizedBox(height: AppSizes.huge),
                ],
              ),
            ),
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
              // Same thumbnail primitive used by the list row and the
              // hero — picks the product's photo when present, else
              // its hash-tinted monogram. Always identifies the row.
              ProductThumbnail(product: product, size: 56),
              const SizedBox(width: AppSizes.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.name, style: theme.textTheme.titleMedium),
                    if (product.category != null) ...[
                      const SizedBox(height: 4),
                      AppStatusBadge(
                        label: product.category!.name,
                        icon: resolveCategoryIcon(product.category!.iconName),
                        dense: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          // Identifier ribbon — SKU + barcode as tap-to-copy chips so
          // they're one tap away during inventory work (printing
          // labels, looking up a row in invoices, etc).
          _IdentifierRibbon(
            sku: product.sku,
            barcode: product.barcode,
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
                  child: rows[i].stack
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows[i].label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              rows[i].value,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rows[i].label,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                            const SizedBox(width: AppSizes.md),
                            // Expanded + soft-wrap so a long value
                            // breaks to the next line instead of
                            // overflowing the row off-screen.
                            Expanded(
                              child: Text(
                                rows[i].value,
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
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
  const _DetailRow(this.label, this.value, {this.stack = false});
  final String label;
  final String value;

  /// When `true`, render the value below the label on its own line
  /// (label small/muted, value full-width). Used for long-text custom
  /// field values where a right-aligned wrap looks awkward.
  final bool stack;
}

/// Sticky bottom action bar with the two stock movements. Always
/// reachable regardless of scroll position — critical because the
/// page now hosts carousel, pricing, supplier history, and (soon)
/// custom fields, so the previous in-flow buttons were getting
/// pushed far down off-screen.
class _StockActionBar extends StatelessWidget {
  const _StockActionBar({
    required this.onStockIn,
    required this.onStockOut,
  });

  final VoidCallback onStockIn;
  final VoidCallback onStockOut;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.sm,
          AppSizes.lg,
          AppSizes.sm,
        ),
        // Bounded height — AppButton's inner `Center` would otherwise
        // expand to fill the bottomNavigationBar slot vertically, the
        // result being two giant rectangles instead of buttons.
        child: SizedBox(
          height: 52,
          child: Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: AppStrings.stockIn,
                  icon: Icons.add_rounded,
                  onPressed: onStockIn,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: AppButton.primary(
                  label: AppStrings.stockOut,
                  icon: Icons.remove_rounded,
                  onPressed: onStockOut,
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Identifier chips for SKU + optional barcode. Tap to copy. Lives
/// directly under the product name so it's the first thing the user
/// can act on — labels, lookups, scans all start here.
class _IdentifierRibbon extends StatelessWidget {
  const _IdentifierRibbon({required this.sku, required this.barcode});

  final String sku;
  final String? barcode;

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.xs,
      children: [
        _IdentifierChip(
          icon: Icons.tag_rounded,
          label: AppStrings.sku,
          value: sku,
          onTap: () => _copy(context, sku, AppStrings.sku),
        ),
        if (barcode != null && barcode!.isNotEmpty)
          _IdentifierChip(
            icon: Icons.qr_code_2_rounded,
            label: AppStrings.barcode,
            value: barcode!,
            onTap: () => _copy(context, barcode!, AppStrings.barcode),
          ),
      ],
    );
  }
}

class _IdentifierChip extends StatelessWidget {
  const _IdentifierChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surfaceTint,
      shape: AppShapes.squircle(AppSizes.radiusFull),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppSizes.iconSm - 2, color: AppColors.muted),
              const SizedBox(width: AppSizes.xs),
              Text(
                value,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              const Icon(
                Icons.copy_rounded,
                size: 12,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Callout card listing every DRAFT invoice that includes this product.
/// Each row shows the doc number, customer/vendor + quantity, and the
/// direction of stock movement that's pending. Tapping a row opens the
/// invoice so the user can confirm or cancel it — once confirmed, the
/// product's stock count actually moves.
class _PendingDraftsCard extends StatelessWidget {
  const _PendingDraftsCard({
    required this.drafts,
    required this.productUnit,
    required this.onTap,
  });

  final List<Invoice> drafts;
  final String productUnit;
  final void Function(int invoiceId) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitLabel = AppUnits.label(productUnit);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Container(
                  width: 32,
                  height: 32,
                  decoration: ShapeDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    shape: AppShapes.squircle(AppSizes.radiusSm),
                  ),
                  child: const Icon(
                    Icons.hourglass_top_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending drafts (${drafts.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Stock will move once these are confirmed.',
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
          const AppDivider.flush(),
          for (int i = 0; i < drafts.length; i++) ...[
            if (i > 0) const AppDivider.flush(),
            _PendingDraftRow(
              invoice: drafts[i],
              productUnit: unitLabel,
              onTap: () => onTap(drafts[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingDraftRow extends StatelessWidget {
  const _PendingDraftRow({
    required this.invoice,
    required this.productUnit,
    required this.onTap,
  });

  final Invoice invoice;
  final String productUnit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSale = invoice.isSale;
    final qty = invoice.items.fold<double>(
      0,
      (sum, item) => sum + item.quantity,
    );
    final qtyLabel = qty.truncateToDouble() == qty
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
    final counterparty = isSale
        ? ((invoice.customerName?.isNotEmpty ?? false)
            ? invoice.customerName!
            : AppStrings.customer)
        : (invoice.vendorName ?? AppStrings.vendor);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Icon(
              isSale
                  ? Icons.north_east_rounded
                  : Icons.south_west_rounded,
              size: 18,
              color: isSale ? AppColors.error : AppColors.success,
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNo,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${isSale ? 'Sale' : 'Purchase'} · $counterparty',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              '${isSale ? '-' : '+'}$qtyLabel $productUnit',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSale ? AppColors.error : AppColors.success,
              ),
            ),
            const SizedBox(width: AppSizes.xs),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

