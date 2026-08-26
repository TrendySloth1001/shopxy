import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/domain/gst.dart';
import 'package:shopxy/features/reviews/data/datasources/reviews_remote_data_source.dart';
import 'package:shopxy/features/reviews/data/models/product_review.dart';
import 'package:shopxy/features/reviews/presentation/pages/product_reviews_page.dart';
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
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/app_units.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({super.key, required this.productId});
  final String productId;

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

  List<ProductCustomFieldValue> _customFieldValues = const [];

  List<Invoice> _pendingDrafts = const [];

  ReviewSummary? _reviewSummary;
  bool _isReviewSummaryLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  Future<void> _refreshAll() async {
    final cf = context.read<CustomFieldsProvider>();
    Future<void> treeFuture;
    if (cf.hasLoadedOnce) {
      treeFuture = Future.value();
    } else {
      final completer = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          completer.complete();
          return;
        }
        await cf.load();
        completer.complete();
      });
      treeFuture = completer.future;
    }

    await Future.wait([
      _loadProduct(),
      _loadSupplierHistory(),
      _loadCustomFieldValues(),
      _loadPendingDrafts(),
      _loadReviewSummary(),
      treeFuture,
    ]);
  }

  Future<void> _loadReviewSummary() async {
    setState(() => _isReviewSummaryLoading = true);
    try {
      final ds = context.read<ReviewsRemoteDataSource>();
      final summary = await ds.summary(widget.productId);
      if (!mounted) return;
      setState(() => _reviewSummary = summary);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isReviewSummaryLoading = false);
    }
  }

  Future<void> _shareProduct() async {
    final p = _product;
    if (p == null) return;
    final price = NumberFormat.currency(
      symbol: AppStrings.currencySymbol,
      decimalDigits: 2,
    ).format(p.sellingPrice);
    final lines = <String>[
      p.name,
      if (p.brand != null && p.brand!.isNotEmpty) 'Brand: ${p.brand}',
      'Price: $price',
      'SKU: ${p.sku}',
    ];
    await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  void _openAllReviews() {
    final p = _product;
    if (p == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductReviewsPage(
          productId: p.id,
          productName: p.name,
          ratingAvg: _reviewSummary?.ratingAvg ?? p.ratingAvg,
          ratingCount: _reviewSummary?.ratingCount ?? p.ratingCount,
        ),
      ),
    );
  }

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
    }
  }

  List<Widget> _buildCustomFieldSections() {
    if (_customFieldValues.isEmpty) return const [];

    final l10n = AppLocalizations.of(context);
    final cf = context.watch<CustomFieldsProvider>();
    final sectionNames = <String, String>{
      for (final s in cf.sections) s.id: s.name,
    };

    final Map<String?, List<ProductCustomFieldValue>> bySection = {};
    for (final v in _customFieldValues.where(
      (v) => v.value.trim().isNotEmpty,
    )) {
      bySection.putIfAbsent(v.definition.sectionId, () => []).add(v);
    }
    if (bySection.isEmpty) return const [];

    final widgets = <Widget>[];
    final ungrouped = bySection.remove(null);
    if (ungrouped != null) {
      widgets.add(_buildSection(l10n.productsSpecifications, ungrouped));
      widgets.add(const SizedBox(height: AppSizes.lg));
    }
    final orderedSectionIds = [
      for (final s in cf.sections) s.id,
      ...bySection.keys.where(
        (id) => id != null && !sectionNames.containsKey(id),
      ),
    ];
    for (final sectionId in orderedSectionIds) {
      final values = bySection[sectionId];
      if (values == null || values.isEmpty) continue;
      widgets.add(
        _buildSection(
          sectionNames[sectionId] ?? l10n.productsSpecifications,
          values,
        ),
      );
      widgets.add(const SizedBox(height: AppSizes.lg));
    }
    return widgets;
  }

  Widget _buildSection(String title, List<ProductCustomFieldValue> values) {
    return _DetailSection(
      title: title.toUpperCase(),
      rows: values
          .map(
            (v) => _DetailRow(
              v.definition.name,
              _formatCustomFieldValue(v),
              stack:
                  v.definition.type == CustomFieldType.LONG_TEXT ||
                  v.value.length > 40 ||
                  v.value.contains('\n'),
            ),
          )
          .toList(),
    );
  }

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
        _supplierHistoryError = friendlyError(e);
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
    final draftId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => StockBottomSheet(product: _product!, initialType: type),
    );
    if (!mounted) return;
    if (draftId != null) {
      await Future.wait([
        _loadProduct(),
        _loadSupplierHistory(),
        _loadPendingDrafts(),
      ]);
    }
  }

  void _openInvoice(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceDetailPage(invoiceId: id)),
    ).then((_) {
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
        final l10n = AppLocalizations.of(ctx);
        return AlertDialog(
          title: Text(l10n.productsGenerateQr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: ShapeDecoration(
                  color: AppColors.surface,
                  shape: AppShapes.squircle(
                    AppSizes.radiusMd,
                    side: BorderSide(color: AppColors.hairline, width: 1),
                  ),
                ),
                child: QrImageView(
                  data: code,
                  size: AppSizes.qrCodeSize,
                  backgroundColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Text(code, style: theme.textTheme.bodyMedium?.semibold),
              const SizedBox(height: AppSizes.xs),
              Text(
                _product!.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          actions: [
            AppButton.ghost(
              label: l10n.productsClose,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowVariants(Product p) {
    if (p.variantAxes.isEmpty) return false;
    return p.variants.length > 1 ||
        (p.variants.length == 1 && p.variants.first.attributes.isNotEmpty);
  }

  Future<void> _togglePublish(bool next) async {
    if (_product == null || _isTogglingPublish) return;
    final l10n = AppLocalizations.of(context);
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
                ? l10n.productsListedOnMarketplace
                : l10n.productsHiddenFromMarketplace,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.productsCouldntUpdateVisibility}: ${friendlyError(e)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isTogglingPublish = false);
    }
  }

  void _deleteProduct() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.productsDelete,
      message: l10n.productsDeleteConfirm,
      confirmLabel: l10n.productsDelete,
      danger: true,
    );

    if (confirmed && mounted) {
      await context.read<ProductsProvider>().deleteProduct(widget.productId);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.productsDeleted)));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      symbol: AppStrings.currencySymbol,
      decimalDigits: 2,
    );

    if (_isLoading) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FloatingAppBar(),
        body: const _ProductDetailSkeleton(),
      );
    }

    if (_product == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FloatingAppBar(),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Center(child: Text(l10n.productsError)),
        ),
      );
    }

    final p = _product!;
    final (canWriteProducts, canStock) = context
        .select<AuthProvider, (bool, bool)>((a) {
          final u = a.user;
          return (u?.canWriteProducts ?? false, u?.canWriteStock ?? false);
        });

    return Scaffold(
      extendBody: true,
      appBar: FloatingAppBar(
        title: l10n.productsDetailsTitle,
        actions: [
          IconButton(
            onPressed: _shareProduct,
            icon: const AppIcon(AppIcons.iosShareRounded),
            tooltip: l10n.productsShare,
          ),
          IconButton(
            onPressed: _showQrDialog,
            icon: const AppIcon(AppIcons.qrCodeRounded),
            tooltip: l10n.productsGenerateQr,
          ),
          LockedIconButton(
            allowed: canWriteProducts,
            icon: AppIcons.editOutlined,
            tooltip: l10n.productsEdit,
            what: 'edit products',
            onPressed: _openEdit,
          ),
          if (canWriteProducts)
            PopupMenuButton<String>(
              icon: const AppIcon(AppIcons.moreVertRounded),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.productsDelete),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') _deleteProduct();
              },
            ),
        ],
      ),
      bottomNavigationBar: canStock
          ? _StockActionBar(
              onStockIn: () => _openStockSheet('STOCK_IN'),
              onStockOut: () => _openStockSheet('STOCK_OUT'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        color: AppColors.black,
        backgroundColor: AppColors.surface,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ProductImageCarousel(
              product: p,
              onAddPhotos: canWriteProducts ? _openEdit : null,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.lg,
                AppSizes.lg,
                canStock ? AppSizes.huge + 52 + AppSizes.xl : AppSizes.huge,
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
                        AppIcon(
                          AppIcons.receiptLongRounded,
                          color: AppColors.black,
                          size: AppSizes.iconMd,
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.productsStockLedger,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.semibold,
                              ),
                              Text(
                                l10n.productsStockLedgerHint,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.muted),
                              ),
                            ],
                          ),
                        ),
                        AppIcon(
                          AppIcons.arrowForwardIosRounded,
                          color: AppColors.muted,
                          size: AppSizes.iconSm,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.xl),
                  _DetailSection(
                    title: l10n.productsPricingSection,
                    rows: [
                      _DetailRow(
                        l10n.productsMrp,
                        currencyFormat.format(p.mrp),
                      ),
                      _DetailRow(
                        l10n.productsSellingPrice,
                        currencyFormat.format(p.sellingPrice),
                      ),
                      _DetailRow(
                        l10n.productsPurchasePrice,
                        currencyFormat.format(p.purchasePrice),
                      ),
                      _DetailRow(
                        l10n.productsTaxPercent,
                        p.pricingMode != 'NO_GST' && p.taxPercent > 0
                            ? '${_formatRate(p.taxPercent)}% · ${currencyFormat.format(gstBreakdownForProduct(p.sellingPrice, p.taxPercent, p.pricingMode)?.gst ?? 0)}'
                            : l10n.productsNone,
                      ),
                      _DetailRow(
                        l10n.productsProfitMargin,
                        '${p.margin.toStringAsFixed(1)}%',
                      ),
                    ],
                  ),
                  if (p.pricingMode != 'NO_GST' && p.taxPercent > 0) ...[
                    const SizedBox(height: AppSizes.lg),
                    _GstBreakdownSection(
                      sellingPrice: p.sellingPrice,
                      taxPercent: p.taxPercent,
                      pricingMode: p.pricingMode,
                      currencyFormat: currencyFormat,
                    ),
                  ],
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
                  ..._buildCustomFieldSections(),
                  _DetailSection(
                    title: l10n.productsDetailsSection,
                    rows: [
                      if (p.hsnCode != null)
                        _DetailRow(l10n.productsHsnCode, p.hsnCode!),
                      _DetailRow(l10n.productsUnit, AppUnits.label(p.unit)),
                      if (p.category != null)
                        _DetailRow(l10n.productsCategory, p.category!.name),
                      _DetailRow(
                        l10n.productsCreated,
                        DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(p.createdAt.toLocal()),
                      ),
                      _DetailRow(
                        l10n.productsLastUpdated,
                        DateFormat(
                          'dd MMM yyyy, hh:mm a',
                        ).format(p.updatedAt.toLocal()),
                      ),
                      _DetailRow(
                        l10n.productsStatus,
                        p.isActive
                            ? l10n.productsActive
                            : l10n.productsInactive,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.lg),
                  _ReviewsSummarySection(
                    summary: _reviewSummary,
                    isLoading: _isReviewSummaryLoading,
                    onSeeAll: _openAllReviews,
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

class _ProductDetailSkeleton extends StatelessWidget {
  const _ProductDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        AppShimmerBox(width: double.infinity, height: 260, radius: 0),
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
              AppCard(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmerBox(
                          width: AppSizes.avatarMd,
                          height: AppSizes.avatarMd,
                          radius: AppSizes.radiusMd,
                        ),
                        const SizedBox(width: AppSizes.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppShimmerLine(
                                widthFactor: 0.35,
                                height: 10,
                              ),
                              const SizedBox(height: 6),
                              const AppShimmerLine(
                                widthFactor: 0.8,
                                height: 16,
                              ),
                              const SizedBox(height: 6),
                              AppShimmerBox(
                                width: 90,
                                height: 22,
                                radius: AppSizes.radiusSm,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    Row(
                      children: [
                        AppShimmerBox(
                          width: 70,
                          height: 22,
                          radius: AppSizes.radiusSm,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        AppShimmerBox(
                          width: 100,
                          height: 22,
                          radius: AppSizes.radiusSm,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    Row(
                      children: [
                        AppShimmerBox(
                          width: 80,
                          height: 24,
                          radius: AppSizes.lg,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        AppShimmerBox(
                          width: 100,
                          height: 24,
                          radius: AppSizes.lg,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),

              AppCard(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.md,
                  AppSizes.md,
                  AppSizes.md,
                ),
                child: Row(
                  children: [
                    AppShimmerBox(
                      width: AppSizes.avatarXs,
                      height: AppSizes.avatarXs,
                      radius: AppSizes.radiusSm,
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          AppShimmerLine(widthFactor: 0.55, height: 14),
                          SizedBox(height: 5),
                          AppShimmerLine(widthFactor: 0.9, height: 11),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    AppShimmerBox(width: 44, height: 26, radius: AppSizes.lg),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),

              AppCard(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          AppShimmerLine(widthFactor: 0.5, height: 22),
                          SizedBox(height: 6),
                          AppShimmerLine(widthFactor: 0.7, height: 12),
                        ],
                      ),
                    ),
                    AppShimmerBox(
                      width: 80,
                      height: 24,
                      radius: AppSizes.radiusSm,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.xl),

              AppShimmerBox(width: 80, height: 12, radius: AppSizes.radiusSm),
              const SizedBox(height: AppSizes.sm),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: AppSizes.md,
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < 5; i++) ...[
                      if (i > 0) const AppDivider.flush(),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSizes.sm,
                        ),
                        child: Row(
                          children: [
                            AppShimmerBox(
                              width: 90,
                              height: 13,
                              radius: AppSizes.radiusSm,
                            ),
                            const Spacer(),
                            AppShimmerBox(
                              width: 60,
                              height: 13,
                              radius: AppSizes.radiusSm,
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _ProductHeaderCard extends StatelessWidget {
  const _ProductHeaderCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
                      const SizedBox(height: AppSizes.xs),
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
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AppStatusBadge(
                label: product.isActive
                    ? l10n.productsActive
                    : l10n.productsInactive,
                tone: product.isActive
                    ? AppStatusTone.success
                    : AppStatusTone.neutral,
                icon: product.isActive
                    ? AppIcons.checkCircleOutlineRounded
                    : AppIcons.pauseCircleOutlineRounded,
                dense: true,
              ),
              if (product.ratingAvg != null)
                AppStatusBadge(
                  label:
                      '${product.ratingAvg!.toStringAsFixed(1)} · ${product.ratingCount} ${product.ratingCount == 1 ? l10n.productsReviewSingular : l10n.productsReviewPlural}',
                  tone: AppStatusTone.neutral,
                  icon: AppIcons.starRounded,
                  dense: true,
                )
              else
                AppStatusBadge(
                  label: l10n.productsNoReviewsYet,
                  tone: AppStatusTone.neutral,
                  icon: AppIcons.starOutlineRounded,
                  dense: true,
                ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          _IdentifierRibbon(sku: product.sku, barcode: product.barcode),
          if (product.description != null &&
              product.description!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.md),
            Text(
              product.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SystemTagsRow extends StatelessWidget {
  const _SystemTagsRow({required this.tags});
  final List<String> tags;

  String _label(AppLocalizations l10n, String tag) => switch (tag) {
    'BESTSELLER' => l10n.productsTagBestseller,
    'EDITORS_PICK' => l10n.productsTagEditorsPick,
    'NEW_ARRIVAL' => l10n.productsTagNewArrival,
    'TRENDING' => l10n.productsTagTrending,
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
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.xs,
      children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sm,
              vertical: 3,
            ),
            decoration: ShapeDecoration(
              color: _palette(t).bg,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            child: Text(
              _label(l10n, t),
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
    final l10n = AppLocalizations.of(context);
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
              color: published ? AppColors.brandSoft : AppColors.surfaceTint,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            child: AppIcon(
              published
                  ? AppIcons.storefrontRounded
                  : AppIcons.visibilityOffOutlined,
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
                  published
                      ? l10n.productsListedTitle
                      : l10n.productsNotListedTitle,
                  style: theme.textTheme.bodyMedium?.bold,
                ),
                Text(
                  published
                      ? l10n.productsListedHint
                      : l10n.productsNotListedHint,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
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

class _SalesPerformanceCard extends StatelessWidget {
  const _SalesPerformanceCard({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.productsPerformance,
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
                  icon: AppIcons.sellRounded,
                  label: l10n.productsLifetimeSold,
                  value: '${product.totalSold}',
                ),
              ),
              Expanded(
                child: _PerformanceMetric(
                  icon: AppIcons.timelineRounded,
                  label: l10n.productsSold30d,
                  value: '${product.soldLast30d}',
                ),
              ),
              Expanded(
                child: _PerformanceMetric(
                  icon: AppIcons.starRounded,
                  label: l10n.productsReviewsLabel,
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
  final AppIconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(icon, size: 18, color: AppColors.muted),
        const SizedBox(height: AppSizes.xs),
        Text(value, style: theme.textTheme.titleMedium?.extraBold),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}

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
    final l10n = AppLocalizations.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.productsLastActivity,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          if (product.lastStockInAt != null)
            _LastActivityRow(
              icon: AppIcons.southWestRounded,
              tone: AppColors.success,
              label: l10n.productsStockedIn,
              ago: _ago(product.lastStockInAt!),
              subtitle: product.lastVendorName,
            ),
          if (product.lastStockInAt != null && product.lastStockOutAt != null)
            const SizedBox(height: AppSizes.sm),
          if (product.lastStockOutAt != null)
            _LastActivityRow(
              icon: AppIcons.northEastRounded,
              tone: AppColors.error,
              label: l10n.productsSold,
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
  final AppIconData icon;
  final Color tone;
  final String label;
  final String ago;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        AppIcon(icon, size: 18, color: tone),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.bodyMedium?.semibold),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
        Text(
          ago,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

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

  String _attrs(AppLocalizations l10n, Map<String, String> attrs) {
    if (attrs.isEmpty) return l10n.productsDefaultVariant;
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
    final l10n = AppLocalizations.of(context);
    final active = [...variants]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '${l10n.productsVariantsSection} (${active.length})',
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (axes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    AppSizes.md,
                    AppSizes.lg,
                    0,
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final a in axes)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tileBg(AppColors.brandSoft),
                            borderRadius: AppShapes.squircleRadius(
                              AppSizes.radiusFull,
                            ),
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
                                    padding: const EdgeInsets.only(
                                      right: AppSizes.sm,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSizes.xs,
                                        vertical: 1,
                                      ),
                                      decoration: ShapeDecoration(
                                        color: AppColors.brand,
                                        shape: AppShapes.squircle(
                                          AppSizes.radiusSm,
                                        ),
                                      ),
                                      child: Text(
                                        l10n.productsDefaultBadge,
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
                                    padding: const EdgeInsets.only(
                                      right: AppSizes.sm,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSizes.xs,
                                        vertical: 1,
                                      ),
                                      decoration: ShapeDecoration(
                                        color: AppColors.muted,
                                        shape: AppShapes.squircle(
                                          AppSizes.radiusSm,
                                        ),
                                      ),
                                      child: Text(
                                        l10n.productsInactiveBadge,
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
                                    _attrs(l10n, active[i].attributes),
                                    style: theme.textTheme.bodyMedium?.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSizes.xxs),
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
                            style: theme.textTheme.bodyMedium?.bold,
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

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '${l10n.productsHighlightsSection} (${items.length})',
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
                      Padding(
                        padding: const EdgeInsets.only(
                          top: 8,
                          right: AppSizes.sm,
                        ),
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
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.4,
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
    );
  }
}

class _ProductSpecsSection extends StatelessWidget {
  const _ProductSpecsSection({required this.groups});
  final List<SpecGroup> groups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: l10n.productsProductSpecs,
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
                              style: theme.textTheme.titleSmall?.extraBold,
                            ),
                          ),
                          if (groups[gi].tab != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceTint,
                                borderRadius: AppShapes.squircleRadius(
                                  AppSizes.radiusFull,
                                ),
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
                                  style: theme.textTheme.bodySmall?.semibold,
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

class _OffersSection extends StatelessWidget {
  const _OffersSection({required this.offers});
  final List<ProductOffer> offers;

  AppIconData _icon(String kind) => switch (kind) {
    'BANK' => AppIcons.accountBalanceRounded,
    'COUPON' => AppIcons.localOfferRounded,
    'EMI' => AppIcons.paymentsRounded,
    'EXCHANGE' => AppIcons.swapHorizRounded,
    _ => AppIcons.localOfferOutlined,
  };

  Color _tint(String kind) => switch (kind) {
    'BANK' => AppColors.accentIndigo,
    'COUPON' => AppColors.brand,
    'EMI' => AppColors.accentTeal,
    'EXCHANGE' => AppColors.accentAmber,
    _ => AppColors.muted,
  };

  void _copy(BuildContext context, String code) {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.productsCouponCopied),
        duration: AppDurations.snackbar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '${l10n.productsOffersSection} (${offers.length})',
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
                      AppIcon(
                        _icon(offers[i].kind),
                        size: 20,
                        color: _tint(offers[i].kind),
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              offers[i].headline,
                              style: theme.textTheme.bodyMedium?.bold,
                            ),
                            if (offers[i].detail != null &&
                                offers[i].detail!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  offers[i].detail!,
                                  style: theme.textTheme.bodySmall?.copyWith(
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
                                  onTap: () => _copy(context, offers[i].code!),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceTint,
                                      borderRadius: AppShapes.squircleRadius(
                                        AppSizes.radiusSm,
                                      ),
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
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                        ),
                                        const SizedBox(width: AppSizes.xs),
                                        AppIcon(
                                          AppIcons.copyRounded,
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

class _ContentBlocksSection extends StatelessWidget {
  const _ContentBlocksSection({required this.blocks});
  final List<ContentBlock> blocks;

  ({AppIconData icon, String label, String preview}) _summary(
    AppLocalizations l10n,
    ContentBlock b,
  ) {
    final d = b.data;
    return switch (b.kind) {
      'HERO' => (
        icon: AppIcons.imageRounded,
        label: l10n.productsBlockHero,
        preview: (d['headline'] as String?) ?? '',
      ),
      'FEATURE' => (
        icon: AppIcons.featuredPlayListRounded,
        label: '${l10n.productsBlockFeature} · ${d['side'] ?? 'LEFT'}',
        preview: (d['title'] as String?) ?? '',
      ),
      'COMPARISON' => (
        icon: AppIcons.compareArrowsRounded,
        label: l10n.productsBlockComparison,
        preview:
            '${(d['columns'] as List?)?.length ?? 0} ${l10n.productsColumnsUnit} · ${(d['rows'] as List?)?.length ?? 0} ${l10n.productsRowsUnit}',
      ),
      'GALLERY' => (
        icon: AppIcons.collectionsRounded,
        label: l10n.productsBlockGallery,
        preview:
            '${(d['images'] as List?)?.length ?? 0} ${l10n.productsImagesUnit}',
      ),
      'TEXT' => (
        icon: AppIcons.textSnippetRounded,
        label: l10n.productsBlockText,
        preview: ((d['markdown'] as String?) ?? '').split('\n').first,
      ),
      _ => (icon: AppIcons.widgetsRounded, label: b.kind, preview: ''),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '${l10n.productsRichContentSection} (${blocks.length})',
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int i = 0; i < blocks.length; i++) ...[
                if (i > 0) const AppDivider.flush(),
                Builder(
                  builder: (_) {
                    final s = _summary(l10n, blocks[i]);
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
                          AppIcon(s.icon, size: 18, color: AppColors.muted),
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
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TagsSection extends StatelessWidget {
  const _TagsSection({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: l10n.productsTagsSection,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.tileBg(AppColors.brandSoft),
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

  AppIconData get _icon {
    if (product.isOutOfStock) return AppIcons.errorOutlineRounded;
    if (product.isLowStock) return AppIcons.warningAmberRounded;
    return AppIcons.checkCircleOutlineRounded;
  }

  String _labelOf(AppLocalizations l10n) {
    if (product.isOutOfStock) return l10n.productsOutOfStock;
    if (product.isLowStock) return l10n.productsLowStock;
    return l10n.productsInStock;
  }

  String _formatQty(double qty) {
    return qty.truncateToDouble() == qty
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                  style: theme.textTheme.headlineSmall?.bold,
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  '${l10n.productsLowStockAlertAt} ${_formatQty(product.lowStockThreshold)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          AppStatusBadge(label: _labelOf(l10n), tone: _tone, icon: _icon),
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
    final l10n = AppLocalizations.of(context);
    final suppliers = _groupBySupplier(transactions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: l10n.productsSupplierPriceHistory.toUpperCase(),
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: _buildContent(context, theme, suppliers),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    List<MapEntry<String, List<StockTransaction>>> suppliers,
  ) {
    final l10n = AppLocalizations.of(context);
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
        l10n.productsError,
        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
      );
    }

    if (suppliers.isEmpty) {
      return Text(
        l10n.productsNoSupplierHistory,
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
    final l10n = AppLocalizations.of(context);
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
    final lastPolicy = _policyLabel(l10n, sorted.first.purchasePriceMode);
    final isVendor = sorted.first.vendorId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                supplierName.isEmpty
                    ? l10n.productsUnknownSupplier
                    : supplierName,
                style: theme.textTheme.titleSmall?.bold,
              ),
            ),
            if (isVendor)
              AppStatusBadge(
                label: l10n.productsVendor,
                icon: AppIcons.businessRounded,
                dense: true,
              ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        _SupplierMetricRow(
          label: l10n.productsLatestPrice,
          value: latestPrice == null ? '-' : currencyFormat.format(latestPrice),
        ),
        _SupplierMetricRow(
          label: l10n.productsAveragePrice,
          value: averagePrice == null
              ? '-'
              : currencyFormat.format(averagePrice),
        ),
        _SupplierMetricRow(
          label: l10n.productsTotalQuantityBought,
          value:
              '${totalQty % 1 == 0 ? totalQty.toInt() : totalQty.toStringAsFixed(2)} (${transactions.length} ${l10n.productsPurchasesUnit})',
        ),
        _SupplierMetricRow(
          label: l10n.productsLastStockIn,
          value: DateFormat(
            'dd MMM yyyy, hh:mm a',
          ).format(lastStockIn.toLocal()),
        ),
        _SupplierMetricRow(label: l10n.productsPolicy, value: lastPolicy),
        const SizedBox(height: AppSizes.sm),
        Text(
          l10n.productsRecentBuys,
          style: theme.textTheme.labelMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSizes.xs),
        ...sorted.take(5).map((tx) {
          final date = DateFormat('dd MMM yyyy').format(tx.createdAt.toLocal());
          final qty = tx.quantity % 1 == 0
              ? tx.quantity.toInt().toString()
              : tx.quantity.toStringAsFixed(2);
          final price = tx.unitPrice == null
              ? '-'
              : currencyFormat.format(tx.unitPrice);
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
                  '${l10n.productsQtyLabel}: $qty',
                  style: theme.textTheme.bodySmall?.medium,
                ),
                const SizedBox(width: AppSizes.md),
                Text(price, style: theme.textTheme.bodySmall?.semibold),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _policyLabel(AppLocalizations l10n, String? mode) {
    if (mode == 'WEIGHTED_AVERAGE') return l10n.productsWeightedAverage;
    if (mode == 'USE_LATEST') return l10n.productsUseLatestPrice;
    if (mode == 'KEEP_CURRENT') return l10n.productsKeepCurrentPrice;
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
          Text(value, style: theme.textTheme.bodySmall?.semibold),
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
                            const SizedBox(height: AppSizes.xxs),
                            Text(
                              rows[i].value,
                              style: theme.textTheme.bodyMedium?.semibold,
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
                            Expanded(
                              child: Text(
                                rows[i].value,
                                textAlign: TextAlign.right,
                                style: theme.textTheme.bodyMedium?.semibold,
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

  final bool stack;
}

class _StockActionBar extends StatelessWidget {
  const _StockActionBar({required this.onStockIn, required this.onStockOut});

  final VoidCallback onStockIn;
  final VoidCallback onStockOut;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            AppColors.canvas,
            AppColors.canvas,
            AppColors.canvas.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.md,
            AppSizes.lg,
            AppSizes.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: _StockPill(
                  label: l10n.productsStockIn,
                  icon: AppIcons.addRounded,
                  onTap: onStockIn,
                  frosted: true,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: _StockPill(
                  label: l10n.productsStockOut,
                  icon: AppIcons.removeRounded,
                  onTap: onStockOut,
                  frosted: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.frosted,
  });

  final String label;
  final AppIconData icon;
  final VoidCallback onTap;
  final bool frosted;

  static const double _height = 52;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = frosted ? AppColors.black : AppColors.onInverse;

    final shape = AppShapes.squircle(
      AppSizes.radiusFull,
      side: frosted ? BorderSide(color: AppColors.hairline) : BorderSide.none,
    );

    final content = SizedBox(
      height: _height,
      child: Material(
        color: frosted
            ? AppColors.surface.withValues(alpha: 0.55)
            : AppColors.inverseSurface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          splashColor: fg.withValues(alpha: 0.06),
          highlightColor: fg.withValues(alpha: 0.04),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(icon, size: AppSizes.iconMd, color: fg),
                const SizedBox(width: AppSizes.sm),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: fg),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!frosted) return content;
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: content,
        ),
      ),
    );
  }
}

class _IdentifierRibbon extends StatelessWidget {
  const _IdentifierRibbon({required this.sku, required this.barcode});

  final String sku;
  final String? barcode;

  void _copy(BuildContext context, String value, String label) {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label ${l10n.productsCopiedSuffix}'),
        duration: AppDurations.snackbar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Wrap(
      spacing: AppSizes.sm,
      runSpacing: AppSizes.xs,
      children: [
        _IdentifierChip(
          icon: AppIcons.tagRounded,
          label: l10n.productsSku,
          value: sku,
          onTap: () => _copy(context, sku, l10n.productsSku),
        ),
        if (barcode != null && barcode!.isNotEmpty)
          _IdentifierChip(
            icon: AppIcons.qrCode2Rounded,
            label: l10n.productsBarcode,
            value: barcode!,
            onTap: () => _copy(context, barcode!, l10n.productsBarcode),
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

  final AppIconData icon;
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
              AppIcon(icon, size: AppSizes.iconSm - 2, color: AppColors.muted),
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
              AppIcon(AppIcons.copyRounded, size: 12, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingDraftsCard extends StatelessWidget {
  const _PendingDraftsCard({
    required this.drafts,
    required this.productUnit,
    required this.onTap,
  });

  final List<Invoice> drafts;
  final String productUnit;
  final void Function(String invoiceId) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                  child: AppIcon(
                    AppIcons.hourglassTopRounded,
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
                        '${l10n.productsPendingDrafts} (${drafts.length})',
                        style: theme.textTheme.titleSmall?.bold,
                      ),
                      Text(
                        l10n.productsPendingDraftsHint,
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
    final l10n = AppLocalizations.of(context);
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
              : l10n.productsCustomer)
        : (invoice.vendorName ?? l10n.productsVendor);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            AppIcon(
              isSale ? AppIcons.northEastRounded : AppIcons.southWestRounded,
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
                    style: theme.textTheme.bodyMedium?.semibold,
                  ),
                  Text(
                    '${isSale ? l10n.productsSale : l10n.productsPurchase} · $counterparty',
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
            AppIcon(
              AppIcons.chevronRightRounded,
              size: 18,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRate(double n) {
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

class _GstBreakdownSection extends StatelessWidget {
  const _GstBreakdownSection({
    required this.sellingPrice,
    required this.taxPercent,
    required this.pricingMode,
    required this.currencyFormat,
  });

  final double sellingPrice;
  final double taxPercent;
  final String pricingMode;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final inclusive = pricingMode == 'TAX_INCLUSIVE';
    final b = inclusive
        ? gstFromInclusive(sellingPrice, taxPercent)
        : gstFromExclusive(sellingPrice, taxPercent);
    final half = taxPercent / 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: l10n.productsPriceGstBreakdown,
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
              _GstRow(
                label: l10n.productsTaxableValue,
                hint: l10n.productsPriceBeforeGst,
                value: currencyFormat.format(b.taxable),
              ),
              _GstRow(
                label: 'CGST @ ${_formatRate(half)}%',
                value: currencyFormat.format(b.cgst),
              ),
              _GstRow(
                label: 'SGST @ ${_formatRate(half)}%',
                value: currencyFormat.format(b.sgst),
              ),
              _GstRow(
                label: '${l10n.productsTotalGst} @ ${_formatRate(taxPercent)}%',
                value: currencyFormat.format(b.gst),
                strong: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.xs),
                child: AppDivider.flush(),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      inclusive
                          ? l10n.productsSellingPriceInclGst
                          : l10n.productsTotalPayableExclGst,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    currencyFormat.format(b.totalPayable),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                inclusive
                    ? l10n.productsGstExplainer
                    : l10n.productsGstExplainerExclusive,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GstRow extends StatelessWidget {
  const _GstRow({
    required this.label,
    required this.value,
    this.hint,
    this.strong = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: strong ? AppColors.black : AppColors.muted,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
                ),
                children: hint == null
                    ? null
                    : [
                        TextSpan(
                          text: '  ·  $hint',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ],
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewsSummarySection extends StatelessWidget {
  const _ReviewsSummarySection({
    required this.summary,
    required this.isLoading,
    required this.onSeeAll,
  });

  final ReviewSummary? summary;
  final bool isLoading;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final s = summary;
    final count = s?.ratingCount ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: l10n.productsReviewsSection,
          padding: const EdgeInsets.only(bottom: AppSizes.sm),
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: isLoading && s == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
                    child: CircularProgressIndicator(),
                  ),
                )
              : (s == null || count == 0)
              ? Text(
                  l10n.productsNoReviewsBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                )
              : _content(context, s, count),
        ),
      ],
    );
  }

  Widget _content(BuildContext context, ReviewSummary s, int count) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final avg = s.ratingAvg ?? 0;
    final total = count == 0 ? 1 : count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  avg.toStringAsFixed(1),
                  style: theme.textTheme.headlineMedium?.extraBold,
                ),
                _StarRow(rating: avg, size: 16),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  '$count ${count == 1 ? l10n.productsRatingSingular : l10n.productsRatingPlural}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                if (s.verifiedCount > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppIcon(
                        AppIcons.verifiedRounded,
                        size: 13,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${s.verifiedCount} ${l10n.productsVerified}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(width: AppSizes.lg),
            Expanded(
              child: Column(
                children: [
                  for (int star = 5; star >= 1; star--)
                    _HistogramBar(
                      star: star,
                      count: s.histogram[star] ?? 0,
                      total: total,
                    ),
                ],
              ),
            ),
          ],
        ),
        if (s.recent.isNotEmpty) ...[
          const SizedBox(height: AppSizes.md),
          const AppDivider.flush(),
          const SizedBox(height: AppSizes.md),
          for (int i = 0; i < s.recent.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSizes.md),
            _RecentReviewTile(review: s.recent[i]),
          ],
        ],
        const SizedBox(height: AppSizes.md),
        Align(
          alignment: Alignment.centerLeft,
          child: AppButton.ghost(
            label: l10n.productsSeeAllReviews,
            icon: AppIcons.reviewsOutlined,
            onPressed: onSeeAll,
          ),
        ),
      ],
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating, this.size = 16});
  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating >= i + 1;
        final half = !filled && rating >= i + 0.5;
        return AppIcon(
          filled
              ? AppIcons.starRounded
              : half
              ? AppIcons.starHalfRounded
              : AppIcons.starOutlineRounded,
          size: size,
          color: filled || half ? AppColors.accentAmber : AppColors.disabled,
        );
      }),
    );
  }
}

class _HistogramBar extends StatelessWidget {
  const _HistogramBar({
    required this.star,
    required this.count,
    required this.total,
  });
  final int star;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final frac = total == 0 ? 0.0 : count / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$star★',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 6,
                backgroundColor: AppColors.surfaceTint,
                valueColor: AlwaysStoppedAnimation(AppColors.accentAmber),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          SizedBox(
            width: 26,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentReviewTile extends StatelessWidget {
  const _RecentReviewTile({required this.review});
  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StarRow(rating: review.rating.toDouble(), size: 14),
            if (review.title != null && review.title!.isNotEmpty) ...[
              const SizedBox(width: AppSizes.sm),
              Flexible(
                child: Text(
                  review.title!,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.bold,
                ),
              ),
            ],
          ],
        ),
        if (review.body != null && review.body!.isNotEmpty) ...[
          const SizedBox(height: AppSizes.xxs),
          Text(review.body!, style: theme.textTheme.bodySmall),
        ],
        const SizedBox(height: AppSizes.xxs),
        Text(
          review.userName ?? l10n.productsCustomer,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ],
    );
  }
}
