import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/permission_widgets.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_icon_catalog.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/pages/add_edit_product_page.dart';
import 'package:shopxy/features/products/presentation/pages/product_detail_page.dart';
import 'package:shopxy/features/products/presentation/pages/qr_scanner_page.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/products/presentation/widgets/product_grid_card.dart';
import 'package:shopxy/features/products/presentation/widgets/product_list_tile.dart';
import 'package:shopxy/features/stock/presentation/widgets/stock_bottom_sheet.dart';
import 'package:shopxy/core/prefs/navigation_prefs.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_filter_pill.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Products listing — same chassis as the Parties and Vendors pages
/// (AppBar `+` action, [AppSearchBar] header, [ListView.separated]
/// with [AppDivider] rows). Extras specific to inventory: a scan
/// trailing in the search field, a filter strip for low-stock and
/// categories, and section headers grouping by category when the
/// user hasn't narrowed the list.
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _scrollHaptics;

  // Picker returns the chosen category's name so the chip can display
  // it without us having to fetch the full category list up-front
  // (which doesn't scale past a few hundred entries).
  String? _selectedCategoryName;

  /// Grid (card) view vs the vertical list. Grid is the default.
  bool _grid = true;

  /// This grid stays server-authoritative — its pagination, total count and
  /// low/out-of-stock filters are all computed there, and the cards read
  /// fields the light catalogue doesn't carry. So the fix here is the one it
  /// was missing: every other search in the app debounces, this one fired a
  /// request per character, meaning "sugar" cost five.
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollHaptics = ScrollBoundaryHaptics(_scrollCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProductsProvider>().loadProducts();
    });
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AppDurations.searchDebounce, () {
      if (!mounted) return;
      context.read<ProductsProvider>().setSearch(value);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollHaptics.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (product != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(productId: product.id),
        ),
      );
    }
  }

  Future<void> _openAddProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditProductPage()),
    );
    if (created == true && mounted) {
      context.read<ProductsProvider>().loadProducts();
    }
  }

  void _openProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(productId: product.id),
      ),
    );
  }

  /// Opens the StockBottomSheet for the given product pre-set to either
  /// STOCK_IN or STOCK_OUT — wired from the Slidable actions on each
  /// product row. On a successful post we kick a list reload so qty +
  /// stock state stay in sync.
  Future<void> _openStockSheet(Product product, String type) async {
    final draftId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => StockBottomSheet(product: product, initialType: type),
    );
    if (!mounted) return;
    if (draftId != null) {
      context.read<ProductsProvider>().loadProducts();
    }
  }

  void _scheduleLoadMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ProductsProvider>();
      if (!provider.isLoading && provider.hasMore) {
        provider.loadProducts(loadMore: true);
      }
    });
  }

  Future<void> _openCategoryPicker(ProductsProvider provider) async {
    final result = await CategoryPickerSheet.show(
      context,
      currentSelectionId: provider.categoryFilter,
    );
    if (result == null || !mounted) return;
    setState(() => _selectedCategoryName = result.categoryName);
    provider.setCategoryFilter(result.categoryId);
  }

  /// Compose (`section header`, `product rows...`) entries.
  ///
  /// Section headers are only meaningful when the *full* result set is
  /// already on-screen (small shop, single page). Once the list is
  /// paginated, a category's products can span pages and the header
  /// would repeat (or worse, mislead). Same when a single category is
  /// already selected: the header is just redundant noise.
  ///
  /// In the no-grouping case the category lives on each tile, so the
  /// row still tells the user what bucket it belongs to.
  List<_ListItem> _buildItems(ProductsProvider provider) {
    final items = <_ListItem>[];
    final canGroup =
        provider.categoryFilter == null &&
        provider.search.isEmpty &&
        !provider.hasMore;

    if (!canGroup) {
      for (final p in provider.products) {
        items.add(_ListItem.product(p));
      }
      return items;
    }

    final buckets = <String, List<Product>>{};
    // Remember the first iconName seen per group label so the section
    // header can render the picked glyph alongside the title.
    final groupIcons = <String, String?>{};
    for (final p in provider.products) {
      final group = p.category?.name ?? AppStrings.uncategorised;
      buckets.putIfAbsent(group, () => []).add(p);
      groupIcons.putIfAbsent(group, () => p.category?.iconName);
    }
    final groupNames = buckets.keys.toList()
      ..sort((a, b) {
        if (a == AppStrings.uncategorised) return 1;
        if (b == AppStrings.uncategorised) return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    for (final name in groupNames) {
      items.add(_ListItem.header(name, iconName: groupIcons[name]));
      for (final p in buckets[name]!) {
        items.add(_ListItem.product(p));
      }
    }
    return items;
  }

  /// Grid view: a continuous 2-column masonry of all products (flat, no
  /// category headers — grouping wastes columns when sections are small;
  /// the category filter covers narrowing). Cards vary in height with their
  /// content, so the masonry tiles them without gaps.
  Widget _buildGrid({required ProductsProvider provider}) {
    final products = provider.products;
    return CustomScrollView(
      controller: _scrollCtrl,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.md,
            AppSizes.lg,
            AppSizes.md,
          ),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: AppSizes.md,
            crossAxisSpacing: AppSizes.md,
            childCount: products.length,
            itemBuilder: (context, i) => ProductGridCard(
              product: products[i],
              onTap: () => _openProductDetail(products[i]),
            ),
          ),
        ),
        if (provider.hasMore)
          SliverToBoxAdapter(
            child: Builder(
              builder: (context) {
                _scheduleLoadMore();
                return const Padding(
                  padding: EdgeInsets.all(AppSizes.lg),
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        // Clear the floating bottom nav so the last row isn't hidden behind it.
        SliverToBoxAdapter(
          child: SizedBox(
            height: FloatingBottomNav.contentBottomInset(context) + AppSizes.sm,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<ProductsProvider>();
    // select the exact gating slice → rebuilds only when one of these
    // flips, not on unrelated AuthProvider changes.
    final (canView, canWrite, canStock) = context
        .select<AuthProvider, (bool, bool, bool)>((a) {
          final u = a.user;
          return (
            u?.canViewProducts ?? false,
            u?.canWriteProducts ?? false,
            // Swipe-to-stock is an inventory action (stockists have it too).
            u?.canWriteStock ?? false,
          );
        });
    final hasFilter =
        provider.categoryFilter != null ||
        provider.lowStockOnly ||
        provider.outOfStockOnly;
    final isSearching = provider.search.isNotEmpty;
    final items = _buildItems(provider);
    // Hoisted out of the itemBuilder so we don't re-scan the whole
    // list for every row.
    final hasHeaders = items.any((e) => e.isHeader);
    final showCategoryOnRow = !hasHeaders && provider.categoryFilter == null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: l10n.productsTitle,
        actions: [
          IconButton(
            tooltip: _grid ? l10n.productsListView : l10n.productsGridView,
            icon: AppIcon(
              _grid ? AppIcons.viewListRounded : AppIcons.gridViewRounded,
            ),
            onPressed: () => setState(() => _grid = !_grid),
          ),
          AccessReloadButton(onReload: () => provider.loadProducts()),
          if (canView)
            LockedIconButton(
              allowed: canWrite,
              icon: AppIcons.addRounded,
              tooltip: l10n.productsAddProduct,
              what: 'add products',
              onPressed: _openAddProduct,
            ),
        ],
      ),
      body: !canView
          ? NoAccessView(title: l10n.productsHidden)
          : Column(
              children: [
                // Drop the fixed search/filter header below the floating app bar.
                SizedBox(height: FloatingAppBar.contentTopInset(context)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    AppSizes.md,
                    AppSizes.lg,
                    0,
                  ),
                  child: AppSearchBar(
                    hint: l10n.productsSearchHint,
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    trailing: _ScanAction(onTap: _openScanner),
                  ),
                ),
                AppFilterStrip(
                  children: [
                    AppFilterPill(
                      label: l10n.productsFilterAll,
                      selected: !hasFilter,
                      onTap: () {
                        if (provider.lowStockOnly) {
                          provider.setLowStockOnly(false);
                        }
                        if (provider.outOfStockOnly) {
                          provider.setOutOfStockOnly(false);
                        }
                        if (provider.categoryFilter != null) {
                          setState(() => _selectedCategoryName = null);
                          provider.setCategoryFilter(null);
                        }
                      },
                    ),
                    AppFilterPill(
                      label: l10n.productsLowStock,
                      icon: AppIcons.warningAmberRounded,
                      selected: provider.lowStockOnly,
                      accent: AppColors.warning,
                      onTap: () =>
                          provider.setLowStockOnly(!provider.lowStockOnly),
                    ),
                    AppFilterPill(
                      label: l10n.productsOutOfStock,
                      icon: AppIcons.removeCircleOutlineRounded,
                      selected: provider.outOfStockOnly,
                      accent: AppColors.error,
                      onTap: () =>
                          provider.setOutOfStockOnly(!provider.outOfStockOnly),
                    ),
                    // One picker chip replaces the per-category pill list.
                    // Stays a single fixed-width affordance regardless of
                    // how many categories the shop has — the searchable
                    // bottom sheet handles 10 or 10,000 the same way.
                    AppFilterPill(
                      label: provider.categoryFilter == null
                          ? l10n.productsCategoryPickerLabel
                          : (_selectedCategoryName ??
                                l10n.productsCategoryPickerLabel),
                      icon: AppIcons.folderOutlined,
                      trailingIcon: AppIcons.expandMoreRounded,
                      selected: provider.categoryFilter != null,
                      onTap: () => _openCategoryPicker(provider),
                    ),
                  ],
                ),
                Expanded(
                  child: provider.isLoading && provider.products.isEmpty
                      ? (_grid
                            ? const _ProductGridSkeleton()
                            : const _ProductListSkeleton())
                      : provider.error != null && provider.products.isEmpty
                      ? AppErrorView(onRetry: () => provider.loadProducts())
                      : provider.products.isEmpty
                      ? () {
                          // Low-stock or out-of-stock with zero
                          // results is good news, not "no matches" —
                          // show a positive confirmation instead of
                          // the generic empty-search state.
                          final isAllStockedUp =
                              (provider.lowStockOnly ||
                                  provider.outOfStockOnly) &&
                              provider.categoryFilter == null &&
                              !isSearching;
                          return EmptyState.line(
                            kind: LineArt.boxes,
                            title: isAllStockedUp
                                ? l10n.productsAllStockedUpTitle
                                : (hasFilter || isSearching)
                                ? l10n.productsNoMatches
                                : l10n.productsNoProducts,
                            subtitle: isAllStockedUp
                                ? l10n.productsAllStockedUpHint
                                : (hasFilter || isSearching)
                                ? l10n.productsNoMatchesHint
                                : l10n.productsNoProductsHint,
                            action: (hasFilter || isSearching || !canWrite)
                                ? null
                                : AppButton.primary(
                                    label: l10n.productsAddProduct,
                                    icon: AppIcons.addRounded,
                                    onPressed: _openAddProduct,
                                  ),
                          );
                        }()
                      : RefreshIndicator(
                          onRefresh: () => provider.loadProducts(),
                          color: AppColors.black,
                          backgroundColor: AppColors.surface,
                          child: _grid
                              ? _buildGrid(provider: provider)
                              : ListView.separated(
                                  controller: _scrollCtrl,
                                  padding: EdgeInsets.only(
                                    top: AppSizes.sm,
                                    bottom:
                                        FloatingBottomNav.contentBottomInset(
                                          context,
                                        ) +
                                        AppSizes.sm,
                                  ),
                                  itemCount:
                                      items.length + (provider.hasMore ? 1 : 0),
                                  separatorBuilder: (context, index) {
                                    // No divider before a section header
                                    // (the header carries enough vertical
                                    // space on its own).
                                    if (index + 1 >= items.length) {
                                      return const AppDivider();
                                    }
                                    final next = items[index + 1];
                                    if (next.isHeader) {
                                      return const SizedBox.shrink();
                                    }
                                    return const AppDivider();
                                  },
                                  itemBuilder: (context, index) {
                                    if (index >= items.length) {
                                      _scheduleLoadMore();
                                      return const Padding(
                                        padding: EdgeInsets.all(AppSizes.lg),
                                        child: Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                    }
                                    final item = items[index];
                                    return item.map(
                                      header: (label, iconName) =>
                                          _CategoryHeader(
                                            label: label,
                                            iconName: iconName,
                                            first: index == 0,
                                          ),
                                      product: (p) => Slidable(
                                        key: ValueKey('product_${p.id}'),
                                        // Swipe right (start) → Stock In.
                                        // Inventory action — hidden for roles
                                        // without inventory:write (e.g. Cashier).
                                        startActionPane: canStock
                                            ? ActionPane(
                                                motion: const StretchMotion(),
                                                extentRatio: 0.28,
                                                children: [
                                                  CustomSlidableAction(
                                                    onPressed: (_) =>
                                                        _openStockSheet(
                                                          p,
                                                          'STOCK_IN',
                                                        ),
                                                    backgroundColor:
                                                        AppColors.success,
                                                    foregroundColor:
                                                        AppColors.white,
                                                    padding: EdgeInsets.zero,
                                                    child: _StockActionLabel(
                                                      icon: AppIcons
                                                          .arrowDownwardRounded,
                                                      label: l10n
                                                          .productsStockInAction,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : null,
                                        // Swipe left (end) → Stock Out.
                                        endActionPane: canStock
                                            ? ActionPane(
                                                motion: const StretchMotion(),
                                                extentRatio: 0.28,
                                                children: [
                                                  CustomSlidableAction(
                                                    onPressed: (_) =>
                                                        _openStockSheet(
                                                          p,
                                                          'STOCK_OUT',
                                                        ),
                                                    backgroundColor:
                                                        AppColors.error,
                                                    foregroundColor:
                                                        AppColors.white,
                                                    padding: EdgeInsets.zero,
                                                    child: _StockActionLabel(
                                                      icon: AppIcons
                                                          .arrowUpwardRounded,
                                                      label: l10n
                                                          .productsStockOutAction,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : null,
                                        child: ProductListTile(
                                          product: p,
                                          showCategory: showCategoryOnRow,
                                          onTap: () => _openProductDetail(p),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
    );
  }
}

/// Discriminated union for items rendered in the products list.
class _ListItem {
  const _ListItem._(this._label, this._iconName, this._product);
  factory _ListItem.header(String label, {String? iconName}) =>
      _ListItem._(label, iconName, null);
  factory _ListItem.product(Product p) => _ListItem._(null, null, p);

  final String? _label;
  final String? _iconName;
  final Product? _product;

  bool get isHeader => _label != null;

  T map<T>({
    required T Function(String label, String? iconName) header,
    required T Function(Product product) product,
  }) {
    if (_label != null) return header(_label, _iconName);
    return product(_product!);
  }
}

/// Subtle section divider between groups of products. Echoes the
/// section-header eyebrows used elsewhere in the app (dashboard,
/// settings) so the visual language stays consistent.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.label,
    required this.first,
    this.iconName,
  });
  final String label;
  final bool first;
  final String? iconName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.lg,
        first ? AppSizes.sm : AppSizes.lg,
        AppSizes.lg,
        AppSizes.xs,
      ),
      child: Row(
        children: [
          AppIcon(
            resolveCategoryIcon(iconName),
            size: 14,
            color: AppColors.muted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-list skeleton shown while the initial product fetch is in
/// flight. Renders 6 placeholder rows that mirror the real
/// [ProductListTile] layout (thumbnail + name lines + SKU line +
/// price line + stock pill), separated by [AppDivider]s exactly as
/// the real list is. Density is read from [NavigationPrefsProvider]
/// so the skeleton matches whichever mode the user last chose.
class _ProductListSkeleton extends StatelessWidget {
  const _ProductListSkeleton();

  @override
  Widget build(BuildContext context) {
    final compact = context.watch<NavigationPrefsProvider>().isCompact;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      itemCount: 6,
      separatorBuilder: (context, index) => const AppDivider(),
      itemBuilder: (context, index) => _ProductRowSkeleton(compact: compact),
    );
  }
}

/// Grid-view loading skeleton — 6 placeholder cards mirroring
/// [ProductGridCard] (square image + name + price lines).
class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        AppSizes.md,
      ),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSizes.md,
        crossAxisSpacing: AppSizes.md,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (context, index) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AspectRatio(
            aspectRatio: 1,
            child: AppShimmerBox(
              width: double.infinity,
              height: double.infinity,
              radius: AppSizes.radiusLg,
            ),
          ),
          const SizedBox(height: AppSizes.sm),
          AppShimmerLine(widthFactor: 0.9),
          const SizedBox(height: AppSizes.xs),
          AppShimmerLine(widthFactor: 0.5),
        ],
      ),
    );
  }
}

/// One skeleton row. Mirrors [ProductListTile] for the given density.
class _ProductRowSkeleton extends StatelessWidget {
  const _ProductRowSkeleton({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final imageSide = compact ? AppSizes.avatarMd : 96.0;
    final vPad = compact ? AppSizes.sm : AppSizes.lg;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSizes.lg, vertical: vPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail placeholder
          AppShimmerBox(
            width: imageSide,
            height: imageSide,
            radius: AppSizes.radiusMd,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name — 1 line compact, 2 lines card
                AppShimmerLine(widthFactor: 0.75),
                if (!compact) ...[
                  const SizedBox(height: AppSizes.xs),
                  AppShimmerLine(widthFactor: 0.55),
                ],
                const SizedBox(height: AppSizes.xs),
                // SKU / identifier line — narrower
                AppShimmerLine(widthFactor: 0.45, height: AppSizes.sm),
                const SizedBox(height: AppSizes.sm),
                // Price line
                AppShimmerLine(widthFactor: 0.6),
                const SizedBox(height: AppSizes.xs),
                // Stock pill — fixed width rounded capsule
                AppShimmerBox(
                  width: 96,
                  height: AppSizes.lg,
                  radius: AppSizes.radiusFull,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Trailing scan icon for the search bar. Compact, hairline-divided
/// from the input so it reads as a peer affordance without breaking
/// the search bar's silhouette.
class _ScanAction extends StatelessWidget {
  const _ScanAction({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 1, height: AppSizes.iconLg, color: AppColors.hairline),
        const SizedBox(width: AppSizes.xs),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.xs),
            child: AppIcon(
              AppIcons.qrCodeScannerRounded,
              size: AppSizes.iconMd,
              color: AppColors.black,
            ),
          ),
        ),
      ],
    );
  }
}

/// Icon-over-label content for a stock [CustomSlidableAction] — replicates the
/// built-in [SlidableAction] layout, which only accepts a Material `IconData`
/// (incompatible with the app's SVG [AppIcon]).
class _StockActionLabel extends StatelessWidget {
  const _StockActionLabel({required this.icon, required this.label});

  final AppIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppIcon(icon, color: AppColors.white, size: 22),
        const SizedBox(height: AppSizes.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
