import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/features/products/data/models/product_dto.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/app_units.dart';

class AddEditProductPage extends StatefulWidget {
  const AddEditProductPage({super.key, this.product});
  final Product? product;

  @override
  State<AddEditProductPage> createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends State<AddEditProductPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _hsnCode;
  late final TextEditingController _mrp;
  late final TextEditingController _sellingPrice;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _taxPercent;
  late final TextEditingController _stockQuantity;
  late final TextEditingController _lowStockThreshold;

  String _selectedUnit = 'PCS';
  int? _selectedCategoryId;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _sku = TextEditingController(text: p?.sku ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _hsnCode = TextEditingController(text: p?.hsnCode ?? '');
    _mrp = TextEditingController(text: p?.mrp.toStringAsFixed(2) ?? '');
    _sellingPrice = TextEditingController(text: p?.sellingPrice.toStringAsFixed(2) ?? '');
    _purchasePrice = TextEditingController(text: p?.purchasePrice.toStringAsFixed(2) ?? '');
    _taxPercent = TextEditingController(text: p?.taxPercent.toString() ?? '0');
    _stockQuantity = TextEditingController(text: p?.stockQuantity.toString() ?? '0');
    _lowStockThreshold = TextEditingController(text: p?.lowStockThreshold.toString() ?? '10');
    _selectedUnit = p?.unit ?? 'PCS';
    _selectedCategoryId = p?.categoryId;

    context.read<CategoriesProvider>().loadCategories();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _sku.dispose();
    _barcode.dispose();
    _hsnCode.dispose();
    _mrp.dispose();
    _sellingPrice.dispose();
    _purchasePrice.dispose();
    _taxPercent.dispose();
    _stockQuantity.dispose();
    _lowStockThreshold.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final provider = context.read<ProductsProvider>();

      if (isEditing) {
        final data = ProductDto.toUpdateJson(
          name: _name.text,
          description: _description.text,
          sku: _sku.text,
          barcode: _barcode.text.isNotEmpty ? _barcode.text : null,
          hsnCode: _hsnCode.text.isNotEmpty ? _hsnCode.text : null,
          mrp: double.parse(_mrp.text),
          sellingPrice: double.parse(_sellingPrice.text),
          purchasePrice: double.parse(_purchasePrice.text),
          taxPercent: double.tryParse(_taxPercent.text),
          lowStockThreshold: double.tryParse(_lowStockThreshold.text),
          unit: _selectedUnit,
          categoryId: _selectedCategoryId,
        );
        await provider.updateProduct(widget.product!.id, data);
      } else {
        await provider.createProduct(
          name: _name.text,
          sku: _sku.text,
          mrp: double.parse(_mrp.text),
          sellingPrice: double.parse(_sellingPrice.text),
          purchasePrice: double.parse(_purchasePrice.text),
          description: _description.text,
          barcode: _barcode.text.isNotEmpty ? _barcode.text : null,
          hsnCode: _hsnCode.text.isNotEmpty ? _hsnCode.text : null,
          taxPercent: double.tryParse(_taxPercent.text),
          stockQuantity: double.tryParse(_stockQuantity.text),
          lowStockThreshold: double.tryParse(_lowStockThreshold.text),
          unit: _selectedUnit,
          categoryId: _selectedCategoryId,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    return null;
  }

  String? _priceValidator(String? value) {
    if (value == null || value.trim().isEmpty) return AppStrings.fieldRequired;
    final n = double.tryParse(value);
    if (n == null) return AppStrings.invalidNumber;
    if (n < 0) return AppStrings.priceMustBePositive;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<CategoriesProvider>().categories;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? AppStrings.editProduct : AppStrings.addProduct),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.save),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            // Basic info section
            _SectionHeader(title: 'Basic Information'),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: AppStrings.productName),
              validator: _requiredValidator,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: AppStrings.description),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _sku,
                    decoration: const InputDecoration(labelText: AppStrings.sku),
                    validator: _requiredValidator,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _barcode,
                    decoration: const InputDecoration(labelText: AppStrings.barcode),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hsnCode,
                    decoration: const InputDecoration(labelText: AppStrings.hsnCode),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(labelText: AppStrings.category),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...categories.map(
                        (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.xxl),

            // Pricing section
            _SectionHeader(title: 'Pricing'),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _mrp,
                    decoration: InputDecoration(
                      labelText: AppStrings.mrp,
                      prefixText: '${AppStrings.currencySymbol} ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _priceValidator,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _sellingPrice,
                    decoration: InputDecoration(
                      labelText: AppStrings.sellingPrice,
                      prefixText: '${AppStrings.currencySymbol} ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _priceValidator,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchasePrice,
                    decoration: InputDecoration(
                      labelText: AppStrings.purchasePrice,
                      prefixText: '${AppStrings.currencySymbol} ',
                    ),
                    keyboardType: TextInputType.number,
                    validator: _priceValidator,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _taxPercent,
                    decoration: const InputDecoration(
                      labelText: AppStrings.taxPercent,
                      suffixText: '%',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.xxl),

            // Stock section
            _SectionHeader(title: 'Stock'),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                if (!isEditing)
                  Expanded(
                    child: TextFormField(
                      controller: _stockQuantity,
                      decoration: const InputDecoration(labelText: AppStrings.stockQuantity),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                if (!isEditing) const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _lowStockThreshold,
                    decoration: const InputDecoration(labelText: AppStrings.lowStockThreshold),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            DropdownButtonFormField<String>(
              initialValue: _selectedUnit,
              decoration: const InputDecoration(labelText: AppStrings.unit),
              items: AppUnits.all
                  .map((u) => DropdownMenuItem(value: u, child: Text('$u - ${AppUnits.label(u)}')))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedUnit = v);
              },
            ),

            const SizedBox(height: AppSizes.huge),
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
