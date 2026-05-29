import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/marketplace/data/datasources/marketplace_remote_data_source.dart';
import 'package:shopxy_customer/features/marketplace/domain/entities/marketplace_product.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bottom_sheet.dart';
import 'package:shopxy_customer/shared/widgets/app_divider.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

/// Browse a *single linked shop's* catalogue, build a basket of what the
/// customer wants, and send it as a QUOTE REQUEST. The shop prices it and
/// sends back a quotation the customer can then accept (→ confirmed invoice).
/// This is the customer-initiated mirror of the merchant's quotation builder.
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

  /// productId → (product, qty).
  final Map<int, ({MarketplaceProduct product, int qty})> _basket = {};

  /// Catalogue filtered by the search box (name or SKU, case-insensitive).
  List<MarketplaceProduct> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _products;
    return _products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.sku.toLowerCase().contains(q))
        .toList();
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
        padding: const EdgeInsets.fromLTRB(
            AppSizes.lg, 0, AppSizes.lg, AppSizes.lg),
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
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
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
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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
      appBar: AppBar(
        title: Text('Request a quote · ${widget.shop.shopName ?? widget.shop.name}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
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
                  : Column(
                      children: [
                        _SearchBar(
                          onChanged: (v) => setState(() => _query = v),
                        ),
                        const AppDivider.flush(),
                        Expanded(
                          child: Builder(builder: (_) {
                            final visible = _visible;
                            if (visible.isEmpty) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(AppSizes.xxl),
                                  child: Text('No products match your search.',
                                      style: TextStyle(color: AppColors.muted)),
                                ),
                              );
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                  0, AppSizes.sm, 0, 140),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) =>
                                  const AppDivider.flush(),
                              itemBuilder: (_, i) {
                                final p = visible[i];
                                return _ProductRow(
                                  product: p,
                                  qty: _basket[p.id]?.qty ?? 0,
                                  onChanged: (q) => _setQty(p, q),
                                );
                              },
                            );
                          }),
                        ),
                      ],
                    ),
      bottomNavigationBar: _BottomBar(
        itemCount: _itemCount,
        basketValue: _basketValue,
        onContinue: _continue,
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.qty,
    required this.onChanged,
  });
  final MarketplaceProduct product;
  final int qty;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = qty > 0;
    final img = product.images.isNotEmpty ? product.images.first : null;
    return Padding(
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
                const SizedBox(height: 2),
                Text(
                  '${AppStrings.currencySymbol}${product.sellingPrice.toStringAsFixed(0)} / ${product.unit}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
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
              child: const Text('Add',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            )
          else
            _Stepper(qty: qty, onChanged: onChanged),
        ],
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: AppColors.brand,
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(qty - 1),
        ),
        Text(
          '$qty',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: AppColors.brand,
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(qty + 1),
        ),
      ],
    );
  }
}

/// Product photo when available, brand-tinted box icon otherwise. Shared look
/// between the request list and the quote detail rows.
class _Thumb extends StatelessWidget {
  const _Thumb({required this.imageUrl});
  final String? imageUrl;
  static const double size = 44;

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
            size: 20, color: AppColors.brand),
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
          AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.sm),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search this shop’s catalogue',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
          filled: true,
          fillColor: AppColors.canvas,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            borderSide: BorderSide.none,
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
          AppSizes.lg, AppSizes.sm, AppSizes.lg, AppSizes.md,
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
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: AppShapes.squircle(AppSizes.radiusMd),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800),
                ),
                child: Text(hasItems ? 'Request quote' : 'Add items to request a quote'),
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
                  color: AppColors.error, size: 36),
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
