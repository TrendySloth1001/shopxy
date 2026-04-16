import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/stock/presentation/providers/stock_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

class StockBottomSheet extends StatefulWidget {
  const StockBottomSheet({
    super.key,
    required this.product,
    this.initialType = 'STOCK_IN',
  });

  final Product product;
  final String initialType;

  @override
  State<StockBottomSheet> createState() => _StockBottomSheetState();
}

class _StockBottomSheetState extends State<StockBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  final _quantity = TextEditingController();
  final _unitPrice = TextEditingController();
  final _note = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _quantity.dispose();
    _unitPrice.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await context.read<StockProvider>().addStock(
            productId: widget.product.id,
            type: _type,
            quantity: double.parse(_quantity.text),
            unitPrice: _unitPrice.text.isNotEmpty
                ? double.parse(_unitPrice.text)
                : null,
            note: _note.text.isNotEmpty ? _note.text : null,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.stockUpdated)),
        );
        Navigator.pop(context);
      }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppSizes.xl,
        right: AppSizes.xl,
        top: AppSizes.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: ShapeDecoration(
                  color: theme.colorScheme.outlineVariant,
                  shape: AppShapes.squircle(2),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.xl),

            Text(
              widget.product.name,
              style: theme.textTheme.titleMedium,
            ),
            Text(
              'Current stock: ${_formatQty(widget.product.stockQuantity)} ${widget.product.unit}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.xl),

            // Type selector
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'STOCK_IN',
                  label: Text(AppStrings.stockIn),
                  icon: Icon(Icons.add_rounded),
                ),
                ButtonSegment(
                  value: 'STOCK_OUT',
                  label: Text(AppStrings.stockOut),
                  icon: Icon(Icons.remove_rounded),
                ),
                ButtonSegment(
                  value: 'ADJUSTMENT',
                  label: Text(AppStrings.adjustment),
                  icon: Icon(Icons.swap_vert_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() => _type = v.first),
            ),
            const SizedBox(height: AppSizes.lg),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    decoration: const InputDecoration(labelText: AppStrings.quantity),
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    validator: (v) {
                      if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                      final n = double.tryParse(v);
                      if (n == null || n <= 0) return AppStrings.invalidNumber;
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _unitPrice,
                    decoration: InputDecoration(
                      labelText: AppStrings.unitPrice,
                      prefixText: '${AppStrings.currencySymbol} ',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),

            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: AppStrings.note),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSizes.xxl),

            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(AppStrings.confirm),
            ),
            const SizedBox(height: AppSizes.xl),
          ],
        ),
      ),
    );
  }

  String _formatQty(double qty) {
    return qty.truncateToDouble() == qty
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }
}
