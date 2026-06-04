import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
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
import 'package:shopxy/shared/constants/app_durations.dart';
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
  bool _isTogglingPublish = false;
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
    final draftId = await showModalBottomSheet<int>(
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
    if (draftId != null) {
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

  /// True when the variants payload carries more than just the auto-
  /// created single default — i.e. the merchant has actually authored
  /// a variant axis. Single-variant products are common (every product
  /// has at least one default variant under the hood) and we don't want
  /// to clutter the page with a one-row table that just mirrors the
  /// main pricing card.
  bool _shouldShowVariants(Product p) {
    if (p.variantAxes.isEmpty) return false;
    return p.variants.length > 1 ||
        (p.variants.length == 1 && p.variants.first.attributes.isNotEmpty);
  }

  Future<void> _togglePublish(bool next) async {
    if (_product == null || _isTogglingPublish) return;
    setState(() => _isTogglingPublish = true);
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      final updated = await ds.setPublished(_product!.id, next);
      if (!mounted) return;
      setState(() => _product = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            next
                ? 'Listed on the marketplace.'
                : 'Hidden from the marketplace.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Couldn't update visibility: $e")),
      );
    } finally {
      if (mounted) setState(() => _isTogglingPublish = false);
    }
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
    final (canWriteProducts, canStock) =
        context.select<AuthProvider, (bool, bool)>((a) {
      final u = a.user;
      return (u?.canWriteProducts ?? false, u?.canWriteStock ?? false);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.productDetails),
        actions: [
          IconButton(
            onPressed: _showQrDialog,
            icon: const Icon(Icons.qr_code_rounded),
            tooltip: AppStrings.generateQr,
          ),
          // Edit is a product write — shown locked (greyed + padlock) for
          // roles without products:manage so they know it exists.
          LockedIconButton(
            allowed: canWriteProducts,
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            what: 'edit products',
            onPressed: _openEdit,
          ),
          if (canWriteProducts)
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
      // Stock in/out is inventory:write — Stockists keep it, Cashiers don't.
      bottomNavigationBar: canStock
          ? _StockActionBar(
              onStockIn: () => _openStockSheet('STOCK_IN'),
              onStockOut: () => _openStockSheet('STOCK_OUT'),
            )
          : null,
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
                  _MarketplaceCard(
                    product: p,
                    isToggling: _isTogglingPublish,
                    onToggle: _togglePublish,
                  ),
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
                  _SalesPerformanceCard(product: p),
                  if (p.lastStockInAt != null || p.lastStockOutAt != null) ...[
                    const SizedBox(height: AppSizes.md),
                    _LastActivityCard(product: p),
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
                  if (p.variants.isNotEmpty && _shouldShowVariants(p)) ...[
                    const SizedBox(height: AppSizes.lg),
                    _VariantsSection(
                      axes: p.variantAxes,
                      variants: p.variants,
                      currencyFormat: currencyFormat,
                      unitLabel: AppUnits.label(p.unit),
                    ),
                  ],
                  if (p.highlights.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.lg),
                    _HighlightsSection(items: p.highlights),
                  ],
                  if (p.specs.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.lg),
                    _ProductSpecsSection(groups: p.specs),
                  ],
                  if (p.offers.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.lg),
                    _OffersSection(offers: p.offers),
                  ],
                  if (p.contentBlocks.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.lg),
                    _ContentBlocksSection(blocks: p.contentBlocks),
                  ],
                  if (p.tags.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.lg),
                    _TagsSection(tags: p.tags),
                  ],
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
                      if (p.hsnCode != null)
                        _DetailRow(AppStrings.hsnCode, p.hsnCode!),
                      _DetailRow(AppStrings.unit, AppUnits.label(p.unit)),
                      if (p.category != null)
                        _DetailRow('Category', p.category!.name),
                      _DetailRow(
                        AppStrings.created,
                        DateFormat('dd MMM yyyy, hh:mm a').format(p.createdAt.toLocal()),
                      ),
                      _DetailRow(
                        'Last updated',
                        DateFormat('dd MMM yyyy, hh:mm a').format(p.updatedAt.toLocal()),
                      ),
                      _DetailRow(
                        'Status',
                        p.isActive ? 'Active' : 'Inactive',
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
              ProductThumbnail(product: product, size: AppSizes.avatarMd),
              const SizedBox(width: AppSizes.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.brand != null && product.brand!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          product.brand!.toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
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
          if (product.systemTags.isNotEmpty) ...[
            const SizedBox(height: AppSizes.md),
            _SystemTagsRow(tags: product.systemTags),
          ],
          const SizedBox(height: AppSizes.md),
          // Status row — at a glance: is it active, is it ranked, what
          // are the reviews like. Each chip is read-only here; the
          // marketplace toggle lives in [_MarketplaceCard] below so
          // the publish action stays one focused affordance.
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppStatusBadge(
                label: product.isActive ? 'Active' : 'Inactive',
                tone: product.isActive
                    ? AppStatusTone.success
                    : AppStatusTone.neutral,
                icon: product.isActive
                    ? Icons.check_circle_outline_rounded
                    : Icons.pause_circle_outline_rounded,
                dense: true,
              ),
              if (product.ratingAvg != null)
                AppStatusBadge(
                  label:
                      '${product.ratingAvg!.toStringAsFixed(1)} · ${product.ratingCount} review${product.ratingCount == 1 ? '' : 's'}',
                  tone: AppStatusTone.neutral,
                  icon: Icons.star_rounded,
                  dense: true,
                )
              else
                const AppStatusBadge(
                  label: 'No reviews yet',
                  tone: AppStatusTone.neutral,
                  icon: Icons.star_outline_rounded,
                  dense: true,
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

/// Curated badges that the merchant can't write — set by admin or
/// computed by the trending / new-arrival jobs. Rendered as compact
/// pills so the merchant immediately sees the marketplace's editorial
/// signals on their own SKU.
class _SystemTagsRow extends StatelessWidget {
  const _SystemTagsRow({required this.tags});
  final List<String> tags;

  String _label(String tag) => switch (tag) {
        'BESTSELLER' => 'Bestseller',
        'EDITORS_PICK' => "Editor's pick",
        'NEW_ARRIVAL' => 'New arrival',
        'TRENDING' => 'Trending',
        _ => tag,
      };

  ({Color bg, Color fg}) _palette(String tag) => switch (tag) {
        'BESTSELLER' => (bg: AppColors.black, fg: AppColors.white),
        'EDITORS_PICK' => (bg: AppColors.info, fg: AppColors.white),
        'NEW_ARRIVAL' => (bg: AppColors.success, fg: AppColors.white),
        'TRENDING' => (bg: AppColors.accentAmber, fg: AppColors.white),
        _ => (bg: AppColors.black, fg: AppColors.white),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.xs,
      children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm, vertical: 3),
            decoration: ShapeDecoration(
              color: _palette(t).bg,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            child: Text(
              _label(t),
              style: theme.textTheme.labelSmall?.copyWith(
                color: _palette(t).fg,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
      ],
    );
  }
}

/// Marketplace visibility card. One affordance — flip the publish
/// switch — plus a hint line that explains what each state means. The
/// merchant doesn't need to enter the edit form just to list / unlist
/// a SKU; this is the most common single-tap action against a row.
class _MarketplaceCard extends StatelessWidget {
  const _MarketplaceCard({
    required this.product,
    required this.isToggling,
    required this.onToggle,
  });
  final Product product;
  final bool isToggling;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final published = product.isPublished;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.sm,
        AppSizes.md,
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatarXs,
            height: AppSizes.avatarXs,
            decoration: ShapeDecoration(
              color: published
                  ? AppColors.brandSoft
                  : AppColors.surfaceTint,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            child: Icon(
              published
                  ? Icons.storefront_rounded
                  : Icons.visibility_off_outlined,
              size: 18,
              color: published ? AppColors.brand : AppColors.muted,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  published ? 'Listed on marketplace' : 'Not listed',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  published
                      ? 'Customers can find and buy this product.'
                      : 'Visible to you only. Flip to publish.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (isToggling)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSizes.sm),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Switch.adaptive(
              value: published,
              onChanged: onToggle,
              activeThumbColor: AppColors.brand,
            ),
        ],
      ),
    );
  }
}

/// Sales + reviews summary. Backed by the denormalised counters on
/// the product row so we don't issue extra reads to populate this.
class _SalesPerformanceCard extends StatelessWidget {
  const _SalesPerformanceCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERFORMANCE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            children: [
              Expanded(
                child: _PerformanceMetric(
                  icon: Icons.sell_rounded,
                  label: 'Lifetime sold',
                  value: '${product.totalSold}',
                ),
              ),
              Expanded(
                child: _PerformanceMetric(
                  icon: Icons.timeline_rounded,
                  label: 'Sold (30d)',
                  value: '${product.soldLast30d}',
                ),
              ),
              Expanded(
                child: _PerformanceMetric(
                  icon: Icons.star_rounded,
                  label: 'Reviews',
                  value: product.ratingCount == 0
                      ? '—'
                      : '${product.ratingAvg?.toStringAsFixed(1) ?? '—'} · ${product.ratingCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PerformanceMetric extends StatelessWidget {
  const _PerformanceMetric({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.muted),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

/// Last in / out movement card. Pulled from the denormalised columns
/// the list view already uses; surfacing them here means the merchant
/// can answer "when did I last move this" without opening the ledger.
class _LastActivityCard extends StatelessWidget {
  const _LastActivityCard({required this.product});
  final Product product;

  String _ago(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAST ACTIVITY',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          if (product.lastStockInAt != null)
            _LastActivityRow(
              icon: Icons.south_west_rounded,
              tone: AppColors.success,
              label: 'Stocked in',
              ago: _ago(product.lastStockInAt!),
              subtitle: product.lastVendorName,
            ),
          if (product.lastStockInAt != null && product.lastStockOutAt != null)
            const SizedBox(height: AppSizes.sm),
          if (product.lastStockOutAt != null)
            _LastActivityRow(
              icon: Icons.north_east_rounded,
              tone: AppColors.error,
              label: 'Sold',
              ago: _ago(product.lastStockOutAt!),
            ),
        ],
      ),
    );
  }
}

class _LastActivityRow extends StatelessWidget {
  const _LastActivityRow({
    required this.icon,
    required this.tone,
    required this.label,
    required this.ago,
    this.subtitle,
  });
  final IconData icon;
  final Color tone;
  final String label;
  final String ago;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: tone),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
            ],
          ),
        ),
        Text(
          ago,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Variants table. Skipped when the product has only the default
/// auto-created variant (single-variant products are common and the
/// data adds nothing the pricing card doesn't already show).
class _VariantsSection extends StatelessWidget {
  const _VariantsSection({
    required this.axes,
    required this.variants,
    required this.currencyFormat,
    required this.unitLabel,
  });
  final List<VariantAxis> axes;
  final List<ProductVariant> variants;
  final NumberFormat currencyFormat;
  final String unitLabel;

  String _attrs(Map<String, String> attrs) {
    if (attrs.isEmpty) return 'Default';
    return axes
        .map((a) => attrs[a.name])
        .where((v) => v != null && v.isNotEmpty)
        .join(' · ');
  }

  String _formatQty(double qty) {
    return qty.truncateToDouble() == qty
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = [...variants]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'VARIANTS (${active.length})',
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (axes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final a in axes)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.brandSoft,
                            borderRadius: AppShapes.squircleRadius(
                                AppSizes.radiusFull),
                          ),
                          child: Text(
                            '${a.name}: ${a.values.join(' / ')}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.brandStrong,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              for (int i = 0; i < active.length; i++) ...[
                if (i > 0) const AppDivider.flush(),
                Padding(
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
                            Row(
                              children: [
                                if (active[i].isDefault)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(right: AppSizes.sm),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppSizes.xs, vertical: 1),
                                      decoration: ShapeDecoration(
                                        color: AppColors.brand,
                                        shape: AppShapes.squircle(
                                            AppSizes.radiusSm),
                                      ),
                                      child: Text(
                                        'DEFAULT',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (!active[i].isActive)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(right: AppSizes.sm),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: AppSizes.xs, vertical: 1),
                                      decoration: ShapeDecoration(
                                        color: AppColors.muted,
                                        shape: AppShapes.squircle(
                                            AppSizes.radiusSm),
                                      ),
                                      child: Text(
                                        'INACTIVE',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: AppColors.white,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.6,
                                        ),
                                      ),
                                    ),
                                  ),
                                Flexible(
                                  child: Text(
                                    _attrs(active[i].attributes),
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'SKU ${active[i].sku}${active[i].barcode != null ? ' · ${active[i].barcode}' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormat.format(active[i].sellingPrice),
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (active[i].mrp > active[i].sellingPrice)
                            Text(
                              currencyFormat.format(active[i].mrp),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            '${_formatQty(active[i].stockQuantity)} $unitLabel',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: active[i].stockQuantity <= 0
                                  ? AppColors.error
                                  : AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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

/// The merchant-authored "About this item" bullets that drive the
/// customer PDP. Render order matches the editor.
class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'HIGHLIGHTS (${items.length})',
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final h in items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8, right: AppSizes.sm),
                        child: SizedBox(
                          width: 4,
                          height: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          h,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Long-form PDP spec sheet. Distinct from the per-shop custom field
/// sections below — those are merchant-defined taxonomy, these are
/// the inline spec rows stored on the product itself.
class _ProductSpecsSection extends StatelessWidget {
  const _ProductSpecsSection({required this.groups});
  final List<SpecGroup> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'PRODUCT SPECS',
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int gi = 0; gi < groups.length; gi++) ...[
                if (gi > 0) const AppDivider.flush(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    AppSizes.md,
                    AppSizes.lg,
                    AppSizes.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              groups[gi].title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (groups[gi].tab != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceTint,
                                borderRadius: AppShapes.squircleRadius(
                                    AppSizes.radiusFull),
                              ),
                              child: Text(
                                groups[gi].tab!,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      for (final r in groups[gi].rows)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 110,
                                child: Text(
                                  r.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  r.value,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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

/// Bank / coupon / EMI / exchange offers that surface on the PDP
/// offer strip. Each row carries an icon to match its kind and renders
/// the coupon code as a copyable mono-style chip.
class _OffersSection extends StatelessWidget {
  const _OffersSection({required this.offers});
  final List<ProductOffer> offers;

  IconData _icon(String kind) => switch (kind) {
        'BANK' => Icons.account_balance_rounded,
        'COUPON' => Icons.local_offer_rounded,
        'EMI' => Icons.payments_rounded,
        'EXCHANGE' => Icons.swap_horiz_rounded,
        _ => Icons.local_offer_outlined,
      };

  Color _tint(String kind) => switch (kind) {
        'BANK' => AppColors.accentIndigo,
        'COUPON' => AppColors.brand,
        'EMI' => AppColors.accentTeal,
        'EXCHANGE' => AppColors.accentAmber,
        _ => AppColors.muted,
      };

  void _copy(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Coupon code copied'),
        duration: AppDurations.snackbar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'OFFERS (${offers.length})',
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < offers.length; i++) ...[
                if (i > 0) const AppDivider.flush(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg,
                    vertical: AppSizes.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_icon(offers[i].kind),
                          size: 20, color: _tint(offers[i].kind)),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offers[i].headline,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (offers[i].detail != null &&
                                offers[i].detail!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  offers[i].detail!,
                                  style:
                                      theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            if (offers[i].code != null &&
                                offers[i].code!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: GestureDetector(
                                  onTap: () =>
                                      _copy(context, offers[i].code!),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceTint,
                                      borderRadius: AppShapes.squircleRadius(
                                          AppSizes.radiusSm),
                                      border: Border.all(
                                        color: AppColors.hairline,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          offers[i].code!,
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures()
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.copy_rounded,
                                          size: 12,
                                          color: AppColors.muted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
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

/// A+ content block summary. The full editor lives on the edit page;
/// here we show the merchant what's saved so they can see at a glance
/// whether the rich description is populated.
class _ContentBlocksSection extends StatelessWidget {
  const _ContentBlocksSection({required this.blocks});
  final List<ContentBlock> blocks;

  ({IconData icon, String label, String preview}) _summary(ContentBlock b) {
    final d = b.data;
    return switch (b.kind) {
      'HERO' => (
          icon: Icons.image_rounded,
          label: 'Hero',
          preview: (d['headline'] as String?) ?? '',
        ),
      'FEATURE' => (
          icon: Icons.featured_play_list_rounded,
          label: 'Feature · ${d['side'] ?? 'LEFT'}',
          preview: (d['title'] as String?) ?? '',
        ),
      'COMPARISON' => (
          icon: Icons.compare_arrows_rounded,
          label: 'Comparison',
          preview:
              '${(d['columns'] as List?)?.length ?? 0} columns · ${(d['rows'] as List?)?.length ?? 0} rows',
        ),
      'GALLERY' => (
          icon: Icons.collections_rounded,
          label: 'Gallery',
          preview: '${(d['images'] as List?)?.length ?? 0} images',
        ),
      'TEXT' => (
          icon: Icons.text_snippet_rounded,
          label: 'Text',
          preview: ((d['markdown'] as String?) ?? '').split('\n').first,
        ),
      _ => (
          icon: Icons.widgets_rounded,
          label: b.kind,
          preview: '',
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'RICH CONTENT (${blocks.length})',
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < blocks.length; i++) ...[
                if (i > 0) const AppDivider.flush(),
                Builder(builder: (_) {
                  final s = _summary(blocks[i]);
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.lg,
                      vertical: AppSizes.md,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          alignment: Alignment.topCenter,
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(s.icon, size: 18, color: AppColors.muted),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.label,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.muted,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              if (s.preview.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    s.preview,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Free-form merchant tags. Chip row, read-only — editing happens on
/// the edit page.
class _TagsSection extends StatelessWidget {
  const _TagsSection({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: 'TAGS',
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.xs,
            children: [
              for (final t in tags)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brandSoft,
                    borderRadius: AppShapes.squircleRadius(AppSizes.radiusFull),
                  ),
                  child: Text(
                    '#$t',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.brandStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
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
        duration: AppDurations.snackbar,
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

