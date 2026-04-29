import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/parties/presentation/widgets/party_picker.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/vendors/data/datasources/vendors_remote_data_source.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';

class CreateInvoicePage extends StatefulWidget {
  const CreateInvoicePage({super.key});

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  String _type = 'SALE';
  Vendor? _selectedVendor;
  Party? _selectedParty;
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerGstin = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _note = TextEditingController();

  final List<InvoiceItemDraft> _items = [];

  // product search
  List<Product> _productResults = [];
  bool _isSearchingProducts = false;
  final _productSearch = TextEditingController();

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _customerGstin.dispose();
    _discount.dispose();
    _note.dispose();
    _productSearch.dispose();
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, i) => sum + i.subtotal);
  double get _totalTax => _items.fold(0, (sum, i) => sum + i.tax);
  double get _headerDiscount => double.tryParse(_discount.text) ?? 0;
  double get _total => _subtotal + _totalTax - _headerDiscount;

  Future<void> _searchProducts(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _productResults = []);
      return;
    }
    setState(() => _isSearchingProducts = true);
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      final result = await ds.getProducts(search: query, limit: 10);
      if (mounted) setState(() => _productResults = result.products);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _isSearchingProducts = false);
    }
  }

  void _addItem(Product product) {
    final existing = _items.indexWhere((i) => i.productId == product.id);
    if (existing >= 0) {
      setState(() => _items[existing].quantity += 1);
    } else {
      setState(() {
        _items.add(
          InvoiceItemDraft(
            productId: product.id,
            productName: product.name,
            productSku: product.sku,
            hsn: product.hsnCode,
            unit: product.unit,
            quantity: 1,
            unitPrice: _type == 'SALE'
                ? product.sellingPrice
                : product.purchasePrice,
            taxPercent: product.taxPercent,
          ),
        );
      });
    }
    _productSearch.clear();
    setState(() => _productResults = []);
  }

  Future<void> _pickParty() async {
    final picked = await showPartyPicker(context);
    if (picked != null && mounted) {
      setState(() {
        _selectedParty = picked;
        _customerName.text = picked.name;
        _customerPhone.text = picked.phone ?? '';
        _customerGstin.text = picked.gstin ?? '';
      });
    }
  }

  void _clearParty() {
    setState(() {
      _selectedParty = null;
      _customerName.clear();
      _customerPhone.clear();
      _customerGstin.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.invoiceNeedsItems)),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<InvoicesProvider>().createInvoice(
        type: _type,
        vendorId: _selectedVendor?.id,
        partyId: _type == 'SALE' ? _selectedParty?.id : null,
        customerName: _customerName.text,
        customerPhone: _customerPhone.text,
        customerGstin: _customerGstin.text,
        discount: _headerDiscount > 0 ? _headerDiscount : null,
        note: _note.text.isNotEmpty ? _note.text : null,
        items: _items
            .map(
              (i) => {
                'productId': i.productId,
                'quantity': i.quantity,
                'unitPrice': i.unitPrice,
                'taxPercent': i.taxPercent,
                'discount': i.discount,
              },
            )
            .toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
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
        title: const Text(AppStrings.createInvoice),
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
            // Type selector
            _SectionHeader(title: AppStrings.invoiceType),
            const SizedBox(height: AppSizes.md),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'SALE',
                  label: Text(AppStrings.saleInvoice),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: 'PURCHASE',
                  label: Text(AppStrings.purchaseInvoice),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (v) => setState(() {
                _type = v.first;
                _selectedVendor = null;
                _selectedParty = null;
              }),
            ),
            const SizedBox(height: AppSizes.xxl),

            // Party info
            _SectionHeader(
              title: _type == 'SALE'
                  ? AppStrings.customerInfo
                  : AppStrings.vendorInfo,
            ),
            const SizedBox(height: AppSizes.md),
            if (_type == 'PURCHASE') ...[
              _VendorSelector(
                selectedVendor: _selectedVendor,
                onSelected: (v) => setState(() => _selectedVendor = v),
              ),
            ] else ...[
              if (_selectedParty != null)
                _SelectedPartyCard(
                  party: _selectedParty!,
                  onChange: _pickParty,
                  onClear: _clearParty,
                )
              else ...[
                OutlinedButton.icon(
                  onPressed: _pickParty,
                  icon: const Icon(Icons.person_search_rounded),
                  label: const Text(AppStrings.selectParty),
                ),
                const SizedBox(height: AppSizes.md),
                TextFormField(
                  controller: _customerName,
                  decoration: const InputDecoration(
                    labelText: AppStrings.customerName,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSizes.md),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _customerPhone,
                        decoration: const InputDecoration(
                          labelText: AppStrings.phone,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: TextFormField(
                        controller: _customerGstin,
                        decoration: const InputDecoration(
                          labelText: AppStrings.gstin,
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                  ],
                ),
              ],
            ],

            const SizedBox(height: AppSizes.xxl),

            // Items
            _SectionHeader(title: AppStrings.invoiceItems),
            const SizedBox(height: AppSizes.md),

            // Product search
            TextField(
              controller: _productSearch,
              decoration: InputDecoration(
                labelText: AppStrings.searchToAddProduct,
                prefixIcon: _isSearchingProducts
                    ? const Padding(
                        padding: EdgeInsets.all(AppSizes.md),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search_rounded),
              ),
              onChanged: _searchProducts,
            ),

            if (_productResults.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              Card(
                child: Column(
                  children: _productResults
                      .map(
                        (p) => ListTile(
                          dense: true,
                          title: Text(p.name),
                          subtitle: Text(p.sku),
                          trailing: Text(
                            '${AppStrings.currencySymbol}${(_type == 'SALE' ? p.sellingPrice : p.purchasePrice).toStringAsFixed(2)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          onTap: () => _addItem(p),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],

            const SizedBox(height: AppSizes.md),

            if (_items.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Text(
                  AppStrings.noItemsYet,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...List.generate(
                _items.length,
                (i) => _ItemRow(
                  item: _items[i],
                  onRemove: () => setState(() => _items.removeAt(i)),
                  onChanged: () => setState(() {}),
                ),
              ),

            const SizedBox(height: AppSizes.xxl),

            // Totals
            if (_items.isNotEmpty) ...[
              _SectionHeader(title: AppStrings.totals),
              const SizedBox(height: AppSizes.md),
              _TotalRow(label: AppStrings.subtotal, value: _subtotal),
              _TotalRow(label: AppStrings.tax, value: _totalTax),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.discount,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextFormField(
                      controller: _discount,
                      textAlign: TextAlign.end,
                      decoration: InputDecoration(
                        prefixText: '${AppStrings.currencySymbol} ',
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const Divider(),
              _TotalRow(
                label: AppStrings.total,
                value: _total,
                isHighlight: true,
              ),
              const SizedBox(height: AppSizes.xxl),
            ],

            // Note
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: AppStrings.note),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSizes.huge),
          ],
        ),
      ),
    );
  }
}

class _VendorSelector extends StatefulWidget {
  const _VendorSelector({
    required this.selectedVendor,
    required this.onSelected,
  });
  final Vendor? selectedVendor;
  final ValueChanged<Vendor?> onSelected;

  @override
  State<_VendorSelector> createState() => _VendorSelectorState();
}

class _VendorSelectorState extends State<_VendorSelector> {
  List<Vendor> _vendors = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final ds = context.read<VendorsRemoteDataSource>();
      _vendors = await ds.getVendors();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LinearProgressIndicator();
    return DropdownButtonFormField<int?>(
      initialValue: widget.selectedVendor?.id,
      decoration: const InputDecoration(labelText: AppStrings.vendor),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text(AppStrings.noVendorSelected),
        ),
        ..._vendors.map(
          (v) => DropdownMenuItem(value: v.id, child: Text(v.name)),
        ),
      ],
      onChanged: (id) {
        if (id == null) {
          widget.onSelected(null);
        } else {
          final vendor = _vendors.firstWhere((v) => v.id == id);
          widget.onSelected(vendor);
        }
      },
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onRemove,
    required this.onChanged,
  });
  final InvoiceItemDraft item;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(item.productSku, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    color: theme.colorScheme.error,
                    size: AppSizes.iconMd,
                  ),
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Row(
              children: [
                _NumField(
                  label: AppStrings.quantity,
                  value: item.quantity,
                  onChanged: (v) {
                    item.quantity = v;
                    onChanged();
                  },
                ),
                const SizedBox(width: AppSizes.sm),
                _NumField(
                  label: AppStrings.unitPrice,
                  value: item.unitPrice,
                  prefix: AppStrings.currencySymbol,
                  onChanged: (v) {
                    item.unitPrice = v;
                    onChanged();
                  },
                ),
                const SizedBox(width: AppSizes.sm),
                _NumField(
                  label: '${AppStrings.tax} %',
                  value: item.taxPercent,
                  onChanged: (v) {
                    item.taxPercent = v;
                    onChanged();
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${AppStrings.total}: ${AppStrings.currencySymbol}${item.total.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.prefix,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextFormField(
        initialValue: value.toString(),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          prefixText: prefix != null ? '$prefix ' : null,
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });
  final String label;
  final double value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isHighlight
                ? theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  )
                : theme.textTheme.bodyMedium,
          ),
          Text(
            '${AppStrings.currencySymbol}${value.toStringAsFixed(2)}',
            style: isHighlight
                ? theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
          ),
        ],
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

class _SelectedPartyCard extends StatelessWidget {
  const _SelectedPartyCard({
    required this.party,
    required this.onChange,
    required this.onClear,
  });

  final Party party;
  final VoidCallback onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Text(
                party.name.characters.first.toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    party.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (party.phone != null)
                    Text(party.phone!, style: theme.textTheme.bodySmall),
                  if (party.gstin != null)
                    Text(
                      'GSTIN: ${party.gstin}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(onPressed: onChange, child: const Text('Change')),
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: onClear,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
