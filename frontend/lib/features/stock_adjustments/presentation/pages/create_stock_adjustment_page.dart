import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/stock_adjustments/data/datasources/stock_adjustments_remote_data_source.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/glass_widgets.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/constants/app_durations.dart';

const _kReasons = [
  (code: 'DAMAGE', label: 'Damaged', defaultDirection: 'OUT'),
  (code: 'EXPIRED', label: 'Expired', defaultDirection: 'OUT'),
  (code: 'SHRINKAGE', label: 'Shrinkage', defaultDirection: 'OUT'),
  (code: 'RECOUNT', label: 'Recount correction', defaultDirection: 'OUT'),
  (code: 'OPENING', label: 'Opening balance', defaultDirection: 'IN'),
];

class _ItemDraft {
  _ItemDraft({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.unit,
  });

  final int productId;
  final String productName;
  final String productSku;
  final String unit;
  double quantity = 1;
}

class CreateStockAdjustmentPage extends StatefulWidget {
  const CreateStockAdjustmentPage({super.key});

  @override
  State<CreateStockAdjustmentPage> createState() =>
      _CreateStockAdjustmentPageState();
}

class _CreateStockAdjustmentPageState extends State<CreateStockAdjustmentPage> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  String _reason = 'DAMAGE';
  String _direction = 'OUT';
  final List<_ItemDraft> _items = [];
  List<Product> _searchResults = const [];
  bool _isSearching = false;
  bool _isSaving = false;
  // Heuristic unsaved-changes guard. Watches the note controller and
  // item adds — not exact.
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) _dirty = true;
  }

  @override
  void initState() {
    super.initState();
    _note.addListener(_markDirty);
  }

  @override
  void dispose() {
    _note.dispose();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _pickReason(String code) {
    final spec = _kReasons.firstWhere((r) => r.code == code);
    setState(() {
      _reason = code;
      _direction = spec.defaultDirection;
    });
  }

  void _onProductSearchChanged(String value) {
    // Debounce — same pattern as OrdersInboxPage, so typing "sol" hits
    // the backend once instead of once per keystroke.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AppDurations.searchDebounce, () {
      if (!mounted) return;
      _searchProducts(value);
    });
  }

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _isSearching = true);
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      final result = await ds.getProducts(search: query, limit: 8);
      if (mounted) setState(() => _searchResults = result.products);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _addProduct(Product p) {
    _markDirty();
    final existing = _items.indexWhere((i) => i.productId == p.id);
    if (existing >= 0) {
      setState(() => _items[existing].quantity += 1);
    } else {
      setState(() => _items.add(
            _ItemDraft(
              productId: p.id,
              productName: p.name,
              productSku: p.sku,
              unit: p.unit,
            ),
          ));
    }
    _searchCtrl.clear();
    setState(() => _searchResults = []);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item to adjust.')),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final ds = context.read<StockAdjustmentsRemoteDataSource>();
      await ds.create(
        reasonCode: _reason,
        direction: _direction,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        items: _items
            .map((i) => (
                  productId: i.productId,
                  quantity: i.quantity,
                  unitCost: null,
                  note: null,
                ))
            .toList(),
      );
      _dirty = false;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your edits will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allowDirectionToggle = _reason == 'RECOUNT' || _reason == 'OPENING';

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('New stock adjustment'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: AppSizes.iconMd,
                    height: AppSizes.iconMd,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.submit),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            GlassHero.line(
              kind: LineArt.emptyClipboard,
              height: AppSizes.heroHeightSm,
              illustrationSize: AppSizes.productImageSize,
              accent: AppColors.warning,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.lg),
                children: [
            const AppSectionHeader(
              title: 'REASON',
              padding: EdgeInsets.only(bottom: AppSizes.sm),
            ),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.xs,
              children: _kReasons.map((r) {
                final selected = _reason == r.code;
                return ChoiceChip(
                  label: Text(r.label),
                  selected: selected,
                  onSelected: (_) => _pickReason(r.code),
                );
              }).toList(),
            ),
            if (allowDirectionToggle) ...[
              const SizedBox(height: AppSizes.md),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'IN', label: Text('Add stock')),
                  ButtonSegment(value: 'OUT', label: Text('Remove stock')),
                ],
                selected: {_direction},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _direction = v.first),
              ),
            ],
            const SizedBox(height: AppSizes.lg),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: AppStrings.note),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSizes.xxl),
            const AppSectionHeader(
              title: 'PRODUCTS',
              padding: EdgeInsets.only(bottom: AppSizes.sm),
            ),
            TextFormField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.searchProducts,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(AppSizes.md),
                        child: SizedBox(
                          width: AppSizes.iconSm,
                          height: AppSizes.iconSm,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _onProductSearchChanged,
            ),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: AppSizes.xs),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < _searchResults.length; i++) ...[
                      if (i > 0) const AppDivider.flush(),
                      ListTile(
                        dense: true,
                        title: Text(_searchResults[i].name),
                        subtitle: Text(_searchResults[i].sku),
                        trailing: const Icon(Icons.add_circle_outline_rounded),
                        onTap: () => _addProduct(_searchResults[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSizes.lg),
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSizes.xl),
                alignment: Alignment.center,
                child: Text(
                  'No products added yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < _items.length; i++) ...[
                      if (i > 0) const AppDivider.flush(),
                      _ItemRow(
                        item: _items[i],
                        onQuantityChanged: (q) => setState(() {
                          _items[i].quantity = q;
                        }),
                        onRemove: () => setState(() => _items.removeAt(i)),
                      ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: AppSizes.xxl),
            AppButton.primary(
              label: 'Post adjustment',
              icon: Icons.check_circle_outline_rounded,
              onPressed: _isSaving ? null : _save,
              isLoading: _isSaving,
              fullWidth: true,
              size: AppButtonSize.lg,
            ),
            const SizedBox(height: AppSizes.huge),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final _ItemDraft item;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.productSku,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          SizedBox(
            width: 88,
            child: TextFormField(
              initialValue: item.quantity % 1 == 0
                  ? item.quantity.toInt().toString()
                  : item.quantity.toStringAsFixed(2),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: AppSizes.sm,
                ),
                suffixText: item.unit,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                final q = double.tryParse(v);
                if (q != null && q > 0) onQuantityChanged(q);
              },
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(
              Icons.close_rounded,
              color: AppColors.error,
              size: AppSizes.iconMd,
            ),
          ),
        ],
      ),
    );
  }
}
