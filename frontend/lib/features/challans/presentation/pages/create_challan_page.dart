import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/challans/domain/entities/challan.dart';
import 'package:shopxy/features/challans/presentation/providers/challans_provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';

class CreateChallanPage extends StatefulWidget {
  const CreateChallanPage({super.key});

  @override
  State<CreateChallanPage> createState() => _CreateChallanPageState();
}

class _CreateChallanPageState extends State<CreateChallanPage> {
  final _formKey = GlobalKey<FormState>();
  final _partyName = TextEditingController();
  final _partyPhone = TextEditingController();
  final _note = TextEditingController();
  final _searchCtrl = TextEditingController();

  final List<ChallanItemDraft> _items = [];
  List<Product> _searchResults = [];
  bool _isSearching = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _partyName.dispose();
    _partyPhone.dispose();
    _note.dispose();
    _searchCtrl.dispose();
    super.dispose();
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
    final existing = _items.indexWhere((i) => i.productId == p.id);
    if (existing >= 0) {
      setState(() => _items[existing].quantity += 1);
    } else {
      setState(() => _items.add(
            ChallanItemDraft(
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
        const SnackBar(content: Text(AppStrings.challanNoItems)),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final provider = context.read<ChallansProvider>();
      await provider.createChallan(
        partyName: _partyName.text.trim(),
        partyPhone: _partyPhone.text.trim().isNotEmpty ? _partyPhone.text.trim() : null,
        note: _note.text.trim().isNotEmpty ? _note.text.trim() : null,
        items: _items,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.createChallan),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.submit),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            // ── Party info ────────────────────────────────────────────
            _SectionHeader(title: AppStrings.challanPartyInfo),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _partyName,
              decoration: const InputDecoration(labelText: AppStrings.partyName),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? AppStrings.fieldRequired : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _partyPhone,
              decoration: const InputDecoration(labelText: AppStrings.phone),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: AppStrings.note),
              maxLines: 2,
            ),

            const SizedBox(height: AppSizes.xxl),

            // ── Add products ──────────────────────────────────────────
            _SectionHeader(title: AppStrings.challanAddProducts),
            const SizedBox(height: AppSizes.sm),
            Text(
              AppStrings.challanNoPricesHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: AppStrings.searchProducts,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(AppSizes.md),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: (v) => _searchProducts(v),
            ),
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: AppSizes.xs),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: _searchResults
                      .map(
                        (p) => ListTile(
                          dense: true,
                          title: Text(p.name),
                          subtitle: Text(p.sku),
                          trailing: const Icon(Icons.add_circle_outline_rounded),
                          onTap: () => _addProduct(p),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: AppSizes.xl),

            // ── Items list ────────────────────────────────────────────
            Row(
              children: [
                _SectionHeader(title: AppStrings.challanItems),
                const Spacer(),
                Text(
                  '${_items.length} ${AppStrings.items}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSizes.xl),
                alignment: Alignment.center,
                child: Text(
                  AppStrings.challanEmptyItems,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...List.generate(_items.length, (i) => _ItemRow(
                    item: _items[i],
                    onQtyChanged: (q) => setState(() => _items[i].quantity = q),
                    onDelete: () => setState(() => _items.removeAt(i)),
                  )),

            const SizedBox(height: AppSizes.huge),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onQtyChanged,
    required this.onDelete,
  });

  final ChallanItemDraft item;
  final ValueChanged<double> onQtyChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qtyCtrl = TextEditingController(text: item.quantity.toStringAsFixed(item.quantity == item.quantity.truncateToDouble() ? 0 : 2));

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
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
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    item.productSku,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.md),
            SizedBox(
              width: 72,
              child: TextFormField(
                controller: qtyCtrl,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: item.unit,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: AppSizes.xs,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null && parsed > 0) onQtyChanged(parsed);
                },
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}
