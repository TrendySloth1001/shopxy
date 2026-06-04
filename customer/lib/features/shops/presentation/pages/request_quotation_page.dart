import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/marketplace/data/datasources/marketplace_remote_data_source.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bottom_sheet.dart';
import 'package:shopxy_customer/shared/widgets/app_divider.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

/// Browse a *single linked shop's* catalogue, build a basket of what the
/// customer wants, and send it as a QUOTE REQUEST. The shop prices it and
/// sends back a quotation the customer can then accept (→ confirmed invoice).
/// This is the customer-initiated mirror of the merchant's quotation builder.
///
/// The catalogue is explorable by the merchant's own categories (chips
/// with live counts) on top of free-text search, so a customer can drill
/// into "what does this shop sell" instead of scrolling one long list.
class RequestQuotationPage extends StatefulWidget {
  const RequestQuotationPage({super.key, required this.shop});
  final LinkedShop shop;

  @override
  State<RequestQuotationPage> createState() => _RequestQuotationPageState();
}

class _RequestQuotationPageState extends State<RequestQuotationPage> {
  List<MarketplaceProduct> _products = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

  /// Selected category id, or null for "All".
  int? _categoryId;

  /// productId → (product, qty).
  final Map<int, ({MarketplaceProduct product, int qty})> _basket = {};

  /// Distinct categories present in this shop's catalogue, with a count
  /// of how many products fall under each. Sorted by name.
  List<({ProductCategoryRef cat, int count})> get _categories {
    final byId = <int, ({ProductCategoryRef cat, int count})>{};
    for (final p in _products) {
      final c = p.category;
      if (c == null) continue;
      final cur = byId[c.id];
      byId[c.id] = (cat: c, count: (cur?.count ?? 0) + 1);
    }
    final list = byId.values.toList()
      ..sort((a, b) => a.cat.name.toLowerCase().compareTo(b.cat.name.toLowerCase()));
    return list;
  }

  /// Catalogue filtered by the selected category AND the search box.
  List<MarketplaceProduct> get _visible {
    final q = _query.trim().toLowerCase();
    return _products.where((p) {
      if (_categoryId != null && p.category?.id != _categoryId) return false;
      if (q.isEmpty) return true;
      return p.name.toLowerCase().contains(q) ||
          p.sku.toLowerCase().contains(q);
    }).toList();
  }

  static String? _firstImage(MarketplaceProduct p) =>
      p.images.isNotEmpty ? p.images.first : null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final slug = widget.shop.shopSlug;
    if (slug == null) {
      setState(() {
        _loading = false;
        _error = 'This shop has no catalogue to browse.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = context.read<MarketplaceRemoteDataSource>();
      final res = await ds.shopProducts(slug, limit: 100);
      if (!mounted) return;
      setState(() {
        _products = res.products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double get _basketValue => _basket.values
      .fold(0.0, (sum, e) => sum + e.product.sellingPrice * e.qty);

  int get _itemCount => _basket.values.fold(0, (sum, e) => sum + e.qty);

  void _setQty(MarketplaceProduct p, int qty) {
    setState(() {
      if (qty <= 0) {
        _basket.remove(p.id);
      } else {
        _basket[p.id] = (product: p, qty: qty);
      }
    });
  }

  List<Map<String, dynamic>> _itemsPayload() => _basket.values
      .map((e) => <String, dynamic>{
            'productId': e.product.id,
            'name': e.product.name,
            'sku': e.product.sku,
            'quantity': e.qty,
            'unitPrice': e.product.sellingPrice,
            'taxPercent': e.product.taxPercent,
            'imageUrl': _firstImage(e.product),
          })
      .toList();

  /// Open a read-rich preview of [p] (full gallery + details fetched on
  /// demand) so the customer can actually see what they're quoting, and
  /// add/adjust quantity from there.
  void _showProductPreview(MarketplaceProduct p) {
    showAppBottomSheet<void>(
      context,
      builder: (_) => _ProductPreviewSheet(
        base: p,
        initialQty: _basket[p.id]?.qty ?? 0,
        onQty: (q) => _setQty(p, q),
      ),
    );
  }

  Future<void> _continue() async {
    if (_basket.isEmpty) return;
    final note = await _confirmSheet();
    if (note == null || !mounted) return; // dismissed
    final prov = context.read<ShopsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await prov.requestQuotation(
        widget.shop,
        items: _itemsPayload(),
        note: note.isEmpty ? null : note,
      );
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: AppStrings.quoteRequestSent,
        tone: AppSnackbarTone.success,
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Returns the note string (possibly empty) on send, or null if dismissed.
  Future<String?> _confirmSheet() {
    final noteCtrl = TextEditingController();
    return showAppBottomSheet<String>(
      context,
      title: 'Send quote request',
      builder: (ctx) => Padding(
        padding:
            const EdgeInsets.fromLTRB(AppSizes.lg, 0, AppSizes.lg, AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_itemCount item(s) · ${AppStrings.currencySymbol}${_basketValue.toStringAsFixed(0)} (indicative). '
              'The shop will price it and send back a quotation you can accept.',
              style: Theme.of(ctx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted, height: 1.35),
            ),
            const SizedBox(height: AppSizes.lg),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Anything the shop should know',
                border: OutlineInputBorder(
                  borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(ctx).pop(noteCtrl.text.trim()),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
                  shape: AppShapes.squircle(AppSizes.radiusMd),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: const Text('Send request'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          'Request a quote · ${widget.shop.shopName ?? widget.shop.name}',
        ),
      ),
      body: _loading
          ? const _CatalogueSkeleton()
          : _error != null
              ? _ErrorView(err: _error!, onRetry: _load)
              : _products.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSizes.xxl),
                        child: Text(
                          'This shop has no products to browse yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
                    )
                  : _CatalogueBody(
                      categories: _categories,
                      categoryId: _categoryId,
                      visible: _visible,
                      basket: _basket,
                      onQuery: (v) => setState(() => _query = v),
                      onCategory: (id) => setState(() => _categoryId = id),
                      onQty: _setQty,
                      onView: _showProductPreview,
                    ),
      bottomNavigationBar: _BottomBar(
        itemCount: _itemCount,
        basketValue: _basketValue,
        onContinue: _continue,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Skeleton / shimmer loading state — mirrors the _CatalogueBody layout
// ---------------------------------------------------------------------------

/// Full-page skeleton shown while the catalogue is loading.
/// Renders a fake search bar, a chip rail, and 6 product-row skeletons.
class _CatalogueSkeleton extends StatelessWidget {
  const _CatalogueSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Fake search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.xs),
          child: AppShimmerBox(
            width: double.infinity,
            height: 44,
            radius: AppSizes.radiusMd,
          ),
        ),
        // Fake chip rail
        SizedBox(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.lg, vertical: AppSizes.sm),
            children: [
              AppShimmerBox(width: 56, height: 30, radius: AppSizes.radiusFull),
              const SizedBox(width: AppSizes.sm),
              AppShimmerBox(width: 72, height: 30, radius: AppSizes.radiusFull),
              const SizedBox(width: AppSizes.sm),
              AppShimmerBox(width: 64, height: 30, radius: AppSizes.radiusFull),
              const SizedBox(width: AppSizes.sm),
              AppShimmerBox(width: 80, height: 30, radius: AppSizes.radiusFull),
            ],
          ),
        ),
        const AppDivider.flush(),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, AppSizes.sm, 0, 140),
            itemCount: 6,
            separatorBuilder: (_, _) => const AppDivider.flush(),
            itemBuilder: (_, _) => const _SkeletonProductRow(),
          ),
        ),
      ],
    );
  }
}

/// One shimmer row that mirrors the real [_ProductRow] layout:
/// thumbnail box · name lines · price/unit lines · add-button placeholder.
class _SkeletonProductRow extends StatelessWidget {
  const _SkeletonProductRow();

  static const double _thumbSize = AppSizes.productThumbSize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Thumbnail placeholder
          AppShimmerBox(
            width: _thumbSize,
            height: _thumbSize,
            radius: AppSizes.radiusSm,
          ),
          const SizedBox(width: AppSizes.md),
          // Text block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.8, height: 14),
                const SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.55, height: 12),
                const SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.4, height: 12),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // Add-button placeholder
          AppShimmerBox(
            width: 58,
            height: 32,
            radius: AppSizes.radiusFull,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Search + category chips + the filtered product list.
class _CatalogueBody extends StatelessWidget {
  const _CatalogueBody({
    required this.categories,
    required this.categoryId,
    required this.visible,
    required this.basket,
    required this.onQuery,
    required this.onCategory,
    required this.onQty,
    required this.onView,
  });

  final List<({ProductCategoryRef cat, int count})> categories;
  final int? categoryId;
  final List<MarketplaceProduct> visible;
  final Map<int, ({MarketplaceProduct product, int qty})> basket;
  final ValueChanged<String> onQuery;
  final ValueChanged<int?> onCategory;
  final void Function(MarketplaceProduct, int) onQty;
  final void Function(MarketplaceProduct) onView;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchBar(onChanged: onQuery),
        if (categories.isNotEmpty)
          _CategoryChips(
            categories: categories,
            selected: categoryId,
            onSelect: onCategory,
          ),
        const AppDivider.flush(),
        Expanded(
          child: visible.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSizes.xxl),
                    child: Text(
                      'No products match here.\nTry another category or search.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted, height: 1.4),
                    ),
                  ),
                )
              : ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(0, AppSizes.sm, 0, 140),
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => const AppDivider.flush(),
                  itemBuilder: (_, i) {
                    final p = visible[i];
                    return _ProductRow(
                      product: p,
                      qty: basket[p.id]?.qty ?? 0,
                      onChanged: (q) => onQty(p, q),
                      onView: () => onView(p),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Horizontal "All + each category" chip rail with live counts.
class _CategoryChips extends StatelessWidget {
  const _CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });
  final List<({ProductCategoryRef cat, int count})> categories;
  final int? selected;
  final ValueChanged<int?> onSelect;

  @override
  Widget build(BuildContext context) {
    final total = categories.fold<int>(0, (s, e) => s + e.count);
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg, vertical: AppSizes.sm),
        children: [
          _Chip(
            label: 'All',
            count: total,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final c in categories) ...[
            const SizedBox(width: AppSizes.sm),
            _Chip(
              label: c.cat.name,
              count: c.count,
              selected: selected == c.cat.id,
              onTap: () => onSelect(c.cat.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.white : AppColors.black;
    return Material(
      color: selected ? AppColors.black : AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: selected
            ? BorderSide.none
            : const BorderSide(color: AppColors.hairline, width: 1),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusFull),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md, vertical: AppSizes.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: fg, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: AppSizes.sm),
              Text(
                '$count',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: selected
                          ? AppColors.white.withValues(alpha: 0.7)
                          : AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.qty,
    required this.onChanged,
    required this.onView,
  });
  final MarketplaceProduct product;
  final int qty;
  final ValueChanged<int> onChanged;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = qty > 0;
    final img = product.images.isNotEmpty ? product.images.first : null;
    // Whole row taps through to the preview; the Add/stepper controls
    // sit on top and capture their own taps.
    return Material(
      color: selected ? AppColors.brand.withValues(alpha: 0.05) : AppColors.canvas,
      child: InkWell(
        onTap: onView,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
            children: [
              _Thumb(imageUrl: img),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSizes.xs),
                Row(
                  children: [
                    Text(
                      '${AppStrings.currencySymbol}${product.sellingPrice.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      ' / ${product.unit}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                    if (product.isDiscounted) ...[
                      const SizedBox(width: AppSizes.sm),
                      Text(
                        '${AppStrings.currencySymbol}${product.mrp.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.subtle,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          if (!selected)
            OutlinedButton(
              onPressed: () => onChanged(1),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brand,
                side: const BorderSide(color: AppColors.brand),
                shape: AppShapes.squircle(AppSizes.radiusFull),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: AppSizes.xs,
                ),
              ),
              child: Text('Add',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            )
          else
            _Stepper(qty: qty, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.qty, required this.onChanged});
  final int qty;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.brandSoft,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded),
            color: AppColors.brandStrong,
            iconSize: AppSizes.iconMd,
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(qty - 1),
          ),
          Text(
            '$qty',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800, color: AppColors.brandStrong),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            color: AppColors.brandStrong,
            iconSize: AppSizes.iconMd,
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(qty + 1),
          ),
        ],
      ),
    );
  }
}

/// Product photo when available, brand-tinted box icon otherwise.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});
  final String? imageUrl;
  static const double size = AppSizes.productThumbSize;

  @override
  Widget build(BuildContext context) {
    final raw = imageUrl ?? '';
    if (raw.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: ShapeDecoration(
          color: AppColors.brandSoft,
          shape: AppShapes.squircle(AppSizes.radiusSm),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.inventory_2_outlined,
            size: AppSizes.iconLg, color: AppColors.brand),
      );
    }
    return ClipPath(
      clipper: ShapeBorderClipper(
        shape: AppShapes.squircle(AppSizes.radiusSm),
      ),
      child: NetworkImageBox(
        url: resolveImageUrl(raw),
        width: size,
        height: size,
        placeholderColor: AppColors.brandSoft,
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.xs),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search this shop’s catalogue',
          prefixIcon: const Icon(Icons.search_rounded, size: AppSizes.iconMd),
          isDense: true,
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(
            borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
            borderSide: const BorderSide(color: AppColors.hairline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
            borderSide: const BorderSide(color: AppColors.hairline),
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.itemCount,
    required this.basketValue,
    required this.onContinue,
  });
  final int itemCount;
  final double basketValue;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasItems = itemCount > 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.sm,
          AppSizes.lg,
          AppSizes.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasItems)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$itemCount item(s) selected',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${AppStrings.currencySymbol}${basketValue.toStringAsFixed(0)} indicative',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: hasItems ? onContinue : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor: AppColors.hairline,
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
                  shape: AppShapes.squircle(AppSizes.radiusMd),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: Text(
                    hasItems ? 'Request quote' : 'Add items to request a quote'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.err, required this.onRetry});
  final String err;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: AppSizes.iconXl),
              const SizedBox(height: AppSizes.sm),
              Text(err, textAlign: TextAlign.center),
              const SizedBox(height: AppSizes.md),
              FilledButton(
                  onPressed: onRetry, child: const Text(AppStrings.retry)),
            ],
          ),
        ),
      );
}

/// In-context product preview opened from a catalogue row. Shows an
/// instant header from the list product, then fetches the full detail
/// (gallery, highlights, description) so the customer can actually see
/// the item, with an add-to-quote control wired back to the basket.
class _ProductPreviewSheet extends StatefulWidget {
  const _ProductPreviewSheet({
    required this.base,
    required this.initialQty,
    required this.onQty,
  });
  final MarketplaceProduct base;
  final int initialQty;
  final ValueChanged<int> onQty;

  @override
  State<_ProductPreviewSheet> createState() => _ProductPreviewSheetState();
}

class _ProductPreviewSheetState extends State<_ProductPreviewSheet> {
  MarketplaceProduct? _detail;
  bool _loading = true;
  late int _qty = widget.initialQty;

  MarketplaceProduct get _p => _detail ?? widget.base;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await context
          .read<MarketplaceRemoteDataSource>()
          .product(widget.base.id);
      if (mounted) {
        setState(() {
          _detail = d;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _set(int q) {
    setState(() => _qty = q < 0 ? 0 : q);
    widget.onQty(_qty);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _p;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Gallery(images: p.images),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.brand != null && p.brand!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSizes.xs),
                    child: Text(
                      p.brand!.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                Text(
                  p.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, height: 1.25),
                ),
                const SizedBox(height: AppSizes.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${AppStrings.currencySymbol}${p.sellingPrice.toStringAsFixed(0)}',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.xs),
                      child: Text('/ ${p.unit}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted)),
                    ),
                    if (p.isDiscounted) ...[
                      const SizedBox(width: AppSizes.sm),
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.xs),
                        child: Text(
                          '${AppStrings.currencySymbol}${p.mrp.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.subtle,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSizes.xs),
                        child: Text(
                          '${p.discountPct}% off',
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.brandStrong,
                              fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_loading)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.md),
                    child: Row(children: [
                      const SizedBox(
                          width: AppSizes.iconSm,
                          height: AppSizes.iconSm,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: AppSizes.sm),
                      Text('Loading details…',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted)),
                    ]),
                  ),
                if (p.highlights.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.md),
                  for (final h in p.highlights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSizes.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(
                                top: AppSizes.xs, right: AppSizes.sm),
                            child: Icon(Icons.check_circle_rounded,
                                size: AppSizes.iconSm, color: AppColors.brand),
                          ),
                          Expanded(
                            child: Text(h,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(height: 1.35)),
                          ),
                        ],
                      ),
                    ),
                ],
                if (p.description != null &&
                    p.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSizes.md),
                  Text(
                    p.description!.trim(),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: _qty == 0
                ? SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _set(1),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
                        shape: AppShapes.squircle(AppSizes.radiusMd),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      child: const Text('Add to quote'),
                    ),
                  )
                : Row(
                    children: [
                      _Stepper(qty: _qty, onChanged: _set),
                      const SizedBox(width: AppSizes.md),
                      Text(
                        '$_qty in your request',
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700, color: AppColors.muted),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Swipeable image gallery for the preview sheet. Falls back to a tinted
/// placeholder when the product has no images.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.images});
  final List<String> images;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _pc = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imgs = widget.images;
    if (imgs.isEmpty) {
      return Container(
        height: 200,
        color: AppColors.heroPanel,
        alignment: Alignment.center,
        child: const Icon(Icons.inventory_2_outlined,
            size: AppSizes.iconHuge, color: AppColors.brand),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _i = i),
            itemCount: imgs.length,
            itemBuilder: (_, i) => Container(
              color: AppColors.heroPanel,
              child: NetworkImageBox(
                url: resolveImageUrl(imgs[i]),
                fit: BoxFit.contain,
                placeholderColor: AppColors.heroPanel,
              ),
            ),
          ),
        ),
        if (imgs.length > 1) ...[
          const SizedBox(height: AppSizes.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < imgs.length; i++)
                AnimatedContainer(
                  duration: AppDurations.medium,
                  width: i == _i ? AppSizes.xl : AppSizes.sm,
                  height: AppSizes.sm,
                  margin: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
                  decoration: BoxDecoration(
                    color: i == _i ? AppColors.brand : AppColors.hairline,
                    borderRadius: AppShapes.squircleRadius(AppSizes.radiusFull),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
