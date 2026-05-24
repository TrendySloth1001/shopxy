import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Multi-select product picker scoped to the caller's shop catalogue.
/// Pre-checks the IDs the merchant already linked to the slide and
/// returns the new selection back to the editor. Search is debounced
/// 250ms to avoid hammering /products while the merchant types.
class MerchantProductPickerPage extends StatefulWidget {
  const MerchantProductPickerPage({
    super.key,
    required this.alreadySelected,
  });
  final Set<int> alreadySelected;

  static Future<List<Product>?> show(
    BuildContext context, {
    required Set<int> alreadySelected,
  }) {
    return Navigator.of(context).push<List<Product>>(
      MaterialPageRoute(
        builder: (_) =>
            MerchantProductPickerPage(alreadySelected: alreadySelected),
      ),
    );
  }

  @override
  State<MerchantProductPickerPage> createState() =>
      _MerchantProductPickerPageState();
}

class _MerchantProductPickerPageState extends State<MerchantProductPickerPage> {
  final _searchCtrl = TextEditingController();
  final Set<int> _selectedIds = {};
  final Map<int, Product> _selectedProducts = {};
  List<Product> _results = const [];
  Timer? _debounce;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.alreadySelected);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetch('');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      final res = await ds.getProducts(search: q, limit: 50);
      if (!mounted) return;
      setState(() {
        _results = res.products;
        // Make sure any already-selected products we haven't seen in
        // search results still have their data cached for the chip row
        // at the top.
        for (final p in res.products) {
          if (_selectedIds.contains(p.id)) {
            _selectedProducts[p.id] = p;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _fetch(value));
  }

  void _toggle(Product p) {
    setState(() {
      if (_selectedIds.contains(p.id)) {
        _selectedIds.remove(p.id);
        _selectedProducts.remove(p.id);
      } else {
        _selectedIds.add(p.id);
        _selectedProducts[p.id] = p;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Pick products'),
        actions: [
          TextButton(
            onPressed: _selectedIds.isEmpty
                ? null
                : () {
                    // Return ONLY the freshly-toggled products that the
                    // editor doesn't already know about. The editor
                    // merges these with its existing list, preserving
                    // any discount % the merchant already set.
                    final added = _selectedProducts.values
                        .where((p) => !widget.alreadySelected.contains(p.id))
                        .toList();
                    Navigator.of(context).pop(added);
                  },
            child: Text(
              'Add ${_selectedIds.length - widget.alreadySelected.length}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.sm,
              AppSizes.lg,
              AppSizes.sm,
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              decoration: const InputDecoration(
                hintText: 'Search by name or SKU',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: _loading && _results.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.xl),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? const Center(
                            child: Text('No products match.'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              AppSizes.lg,
                              0,
                              AppSizes.lg,
                              96,
                            ),
                            itemCount: _results.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppSizes.xs),
                            itemBuilder: (_, i) {
                              final p = _results[i];
                              final selected = _selectedIds.contains(p.id);
                              return _ProductRow(
                                product: p,
                                selected: selected,
                                onTap: () => _toggle(p),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.selected,
    required this.onTap,
  });
  final Product product;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final img = product.images.isNotEmpty ? product.images.first.url : null;
    return Material(
      color: selected ? AppColors.brandSoft : AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: BorderSide(
          color: selected ? AppColors.brand : AppColors.hairline,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.sm),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: AppColors.heroPanel,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                child: img == null
                    ? const Icon(Icons.image_outlined,
                        color: AppColors.muted, size: 20)
                    : Image.network(
                        resolveImageUrl(img),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'SKU ${product.sku} • ₹${product.sellingPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AppColors.brand : AppColors.subtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
