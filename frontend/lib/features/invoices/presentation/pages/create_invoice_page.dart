import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/parties/presentation/widgets/party_picker.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/pages/qr_scanner_page.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor.dart';
import 'package:shopxy/features/vendors/presentation/widgets/vendor_picker.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/indian.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/glass_widgets.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/constants/app_durations.dart';

class CreateInvoicePage extends StatefulWidget {
  /// [existing] turns this page into an edit form. Pre-fills every
  /// control from the invoice and routes the save action through PATCH
  /// instead of POST. Only DRAFT invoices should be passed in — the
  /// backend rejects anything else.
  const CreateInvoicePage({super.key, this.existing});

  final Invoice? existing;

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  // Heuristic unsaved-changes guard. Flipped true by the customer/name
  // and note listeners, or whenever an item is added/removed. Not exact —
  // intentional, see PopScope wiring below.
  bool _dirty = false;

  String _type = 'SALE';
  Vendor? _selectedVendor;
  Party? _selectedParty;
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerGstin = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _note = TextEditingController();

  // Tax-invoice vs bill-of-supply toggle, only meaningful for SALE.
  // PURCHASE always falls back to TAX_INVOICE on the wire.
  String _documentType = 'TAX_INVOICE';

  // GST tax convention. Default false = EXCLUSIVE: unit prices are pre-tax and
  // GST is added on top (the existing merchant manual-invoice behaviour — never
  // change this silently). When true = INCLUSIVE (matches the backend
  // `isPriceInclusive` flag and the marketplace "inclusive of all taxes" path):
  // the entered unit price ALREADY contains tax and the engine backs it out, so
  // the displayed tax isn't double-added.
  bool _isPriceInclusive = false;

  // Walk-in place-of-supply (used when no party is selected on a SALE).
  // Defaults to the shop's own state code once auth has loaded, which
  // gives the intrastate split out of the box.
  String? _walkInStateCode;

  final List<InvoiceItemDraft> _items = [];

  // product search
  List<Product> _productResults = [];
  bool _isSearchingProducts = false;
  final _productSearch = TextEditingController();
  Timer? _searchDebounce;

  void _markDirty() {
    // Trigger a rebuild so PopScope.canPop sees the flipped flag —
    // without setState the back gesture would still pop a dirty form
    // because canPop was computed from the prior build.
    if (!_dirty) {
      if (mounted) {
        setState(() => _dirty = true);
      } else {
        _dirty = true;
      }
    }
  }

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _customerName.addListener(_markDirty);
    _note.addListener(_markDirty);
    _discount.addListener(_markDirty);

    // Edit mode: rehydrate every control from the persisted invoice so
    // the user sees exactly what's on file before tweaking.
    final existing = widget.existing;
    if (existing != null) {
      _type = existing.type;
      _documentType = existing.documentType;
      _customerName.text = existing.customerName ?? '';
      _customerPhone.text = existing.customerPhone ?? '';
      _customerGstin.text = existing.customerGstin ?? '';
      _discount.text = existing.discount > 0
          ? existing.discount.toStringAsFixed(2)
          : '0';
      _note.text = existing.note ?? '';
      _walkInStateCode = existing.placeOfSupplyStateCode;
      // Reconstruct minimal Party/Vendor stubs from the invoice's address
      // snapshot. They're enough for the picker cards to render + for
      // IGST detection (state code drives that). If the user wants the
      // live row, they can tap "Change".
      if (existing.partyId != null && existing.isSale) {
        _selectedParty = _partyFromInvoiceSnapshot(existing);
      }
      if (existing.vendorId != null && existing.isPurchase) {
        _selectedVendor = _vendorFromInvoiceSnapshot(existing);
      }
      _items.addAll(existing.items.map(InvoiceItemDraft.fromInvoiceItem));
      // The form starts clean — user must touch something to mark dirty.
      _dirty = false;
    }

    // Seed the walk-in dropdown to the shop's own state so a fresh
    // SALE without a party defaults to intrastate CGST+SGST.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shopCode = context.read<AuthProvider>().user?.shopStateCode;
      if (shopCode != null && _walkInStateCode == null) {
        setState(() => _walkInStateCode = shopCode);
      }
    });
  }

  /// Build a stub [Party] from an invoice's snapshot. Used in edit mode
  /// so the SelectedPartyCard can render without an extra network call.
  /// The user can tap "Change" to swap in the live row from the picker.
  static Party _partyFromInvoiceSnapshot(Invoice inv) {
    return Party(
      id: inv.partyId!,
      name: inv.customerName ?? '—',
      phone: inv.customerPhone,
      gstin: inv.customerGstin,
      address: inv.customerAddress,
      city: inv.customerCity,
      state: inv.customerState,
      stateCode: inv.customerStateCode,
      pinCode: inv.customerPinCode,
      panNumber: inv.customerPanNumber,
      isActive: true,
      createdAt: inv.createdAt,
      updatedAt: inv.updatedAt,
    );
  }

  static Vendor _vendorFromInvoiceSnapshot(Invoice inv) {
    return Vendor(
      id: inv.vendorId!,
      name: inv.vendorName ?? inv.vendor?.name ?? '—',
      phone: inv.vendorPhone,
      gstin: inv.vendorGstin,
      address: inv.vendorAddress,
      city: inv.vendorCity,
      state: inv.vendorState,
      stateCode: inv.vendorStateCode,
      pinCode: inv.vendorPinCode,
      panNumber: inv.vendorPanNumber,
      isActive: true,
      createdAt: inv.createdAt,
      updatedAt: inv.updatedAt,
    );
  }

  @override
  void dispose() {
    _customerName.dispose();
    _customerPhone.dispose();
    _customerGstin.dispose();
    _discount.dispose();
    _note.dispose();
    _searchDebounce?.cancel();
    _productSearch.dispose();
    super.dispose();
  }

  // Sum of each line's taxable (qty*price − its own discount). Doubles as
  // the base over which the invoice-level discount is apportioned.
  double get _subtotal => _items.fold(0, (sum, i) => sum + i.subtotal);
  // Invoice-level discount, clamped to [0, subtotal] so the preview can't
  // go negative — matches the backend engine's clamp.
  double get _headerDiscount {
    final raw = double.tryParse(_discount.text) ?? 0;
    if (raw <= 0 || _subtotal <= 0) return 0;
    return raw > _subtotal ? _subtotal : raw;
  }
  // GST is charged on each line's taxable AFTER its proportional share of
  // the invoice-level discount (CGST Sec 15(3)). The backend apportions the
  // header discount into the lines before computing tax, so the preview
  // mirrors that or the shown total won't match the saved invoice.
  double get _totalTax {
    final base = _subtotal;
    final hd = _headerDiscount;
    if (base <= 0) return 0;
    var tax = 0.0;
    for (final i in _items) {
      final lineBase = i.subtotal; // qty*price − line discount
      final net = lineBase - hd * (lineBase / base);
      if (_isPriceInclusive) {
        // Inclusive: the net amount already contains tax — back it out so the
        // preview matches the backend and tax isn't double-added.
        final lineTaxable = net * 100 / (100 + i.taxPercent);
        tax += net - lineTaxable;
      } else {
        tax += net * i.taxPercent / 100;
      }
    }
    return tax;
  }
  // Net taxable after every discount. For inclusive pricing the tax already
  // sits inside the line amount, so taxable = net amount − tax.
  double get _taxableValue =>
      _isPriceInclusive ? _subtotal - _headerDiscount - _totalTax : _subtotal - _headerDiscount;
  // Exclusive: total = net taxable + tax. Inclusive: the net amount already
  // includes tax, so total = (subtotal − header discount) directly; written as
  // taxable + tax it reduces to the same number.
  double get _rawTotal => _taxableValue + _totalTax;
  // Indian invoices commonly round to the nearest rupee. We compute the
  // diff the same way the backend does so the UI matches the saved row.
  double get _roundedTotal => _rawTotal.roundToDouble();
  double get _roundOff => _roundedTotal - _rawTotal;
  double get _total => _roundedTotal;

  /// Counterparty state code for IGST-vs-CGST/SGST. SALE uses the
  /// selected party (or the walk-in picker); PURCHASE uses the vendor.
  /// Null if nothing is selected yet → defaults to intrastate.
  String? get _placeOfSupplyStateCode {
    if (_type == 'SALE') {
      return _selectedParty?.stateCode ?? _walkInStateCode;
    }
    return _selectedVendor?.stateCode;
  }

  /// True if the counterparty's state differs from the shop's. Mirrors
  /// backend `isInterstateSupply` — both halves must be present, else
  /// we treat it as intrastate to avoid mis-charging IGST.
  bool get _isInterstate {
    final shop = context.read<AuthProvider>().user?.shopStateCode;
    final pos = _placeOfSupplyStateCode;
    if (shop == null || pos == null) return false;
    return shop != pos;
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
    _markDirty();
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

  Future<void> _pickVendor() async {
    final picked = await showVendorPicker(context);
    if (picked != null && mounted) {
      setState(() => _selectedVendor = picked);
    }
  }

  void _clearVendor() => setState(() => _selectedVendor = null);

  /// Open the camera-based product scanner and append the picked product
  /// as a draft row. The scanner page handles "not found" itself: it lets
  /// the user create the product, then returns the fresh row.
  Future<void> _scanProduct() async {
    final picked = await Navigator.push<Product?>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (picked != null && mounted) _addItem(picked);
  }

  /// Saves the form. When [confirm] is true the backend (create path)
  /// or this method (edit path) immediately posts the stock movement
  /// too — saves the merchant a separate Confirm round-trip.
  ///
  /// Outcome routing:
  ///   - save-as-draft → pop true; list refreshes.
  ///   - save + confirm OK → pop true with a "confirmed" snackbar.
  ///   - save OK but confirm failed (insufficient stock) → push the
  ///     just-created draft's detail page so the merchant lands on the
  ///     row they need to fix, with a snackbar explaining why.
  Future<void> _save({required bool confirm}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.invoiceNeedsItems)),
      );
      return;
    }
    setState(() => _isSaving = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final provider = context.read<InvoicesProvider>();
      final itemsPayload = _items
          .map(
            (i) => {
              'productId': i.productId,
              'quantity': i.quantity,
              'unitPrice': i.unitPrice,
              'taxPercent': i.taxPercent,
              'discount': i.discount,
              // GST-5 — send the tax convention per line so the backend engine
              // computes the same total the preview shows. Defaults to false
              // (exclusive) so existing merchant manual invoices are unchanged.
              'isPriceInclusive': _isPriceInclusive,
            },
          )
          .toList();
      final docType = _type == 'SALE' ? _documentType : 'TAX_INVOICE';
      final existing = widget.existing;
      if (existing != null) {
        await provider.updateInvoice(
          id: existing.id,
          type: _type,
          vendorId: _selectedVendor?.id,
          partyId: _type == 'SALE' ? _selectedParty?.id : null,
          customerName: _customerName.text,
          customerPhone: _customerPhone.text,
          customerGstin: _customerGstin.text,
          discount: _headerDiscount > 0 ? _headerDiscount : null,
          note: _note.text.isNotEmpty ? _note.text : null,
          documentType: docType,
          placeOfSupplyStateCode: _placeOfSupplyStateCode,
          items: itemsPayload,
        );
        _dirty = false;
        if (confirm) {
          // Edit path runs confirm as a follow-up call so the create
          // and the status flip aren't double-coupled at the API level.
          try {
            await provider.updateStatus(existing.id, 'CONFIRMED');
            if (!mounted) return;
            messenger.showSnackBar(
              const SnackBar(content: Text('Invoice updated and confirmed')),
            );
          } catch (e) {
            if (!mounted) return;
            messenger.showSnackBar(
              SnackBar(content: Text(friendlyError(e))),
            );
          }
        } else if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Saved as draft')),
          );
        }
        if (mounted) navigator.pop(true);
        return;
      }

      final result = await provider.createInvoice(
        type: _type,
        vendorId: _selectedVendor?.id,
        partyId: _type == 'SALE' ? _selectedParty?.id : null,
        customerName: _customerName.text,
        customerPhone: _customerPhone.text,
        customerGstin: _customerGstin.text,
        discount: _headerDiscount > 0 ? _headerDiscount : null,
        note: _note.text.isNotEmpty ? _note.text : null,
        documentType: docType,
        placeOfSupplyStateCode: _placeOfSupplyStateCode,
        items: itemsPayload,
        confirm: confirm,
      );
      _dirty = false;
      if (!mounted) return;

      if (!confirm) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Saved as draft')),
        );
        navigator.pop(true);
        return;
      }
      if (result.confirmed) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Invoice ${result.invoice.invoiceNo} confirmed'),
          ),
        );
        navigator.pop(true);
        return;
      }
      // Auto-confirm failed — land the merchant on the draft so they
      // can address the underlying issue (usually insufficient stock).
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.confirmError ??
                'Saved as draft — confirm failed, please review.',
          ),
        ),
      );
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => InvoiceDetailPage(invoiceId: result.invoice.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
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

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Draft' : AppStrings.createInvoice),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          decoration: const BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : () => _save(confirm: false),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_isEditing ? 'Update draft' : 'Save as draft'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizes.huge),
                    side: const BorderSide(color: AppColors.hairline),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : () => _save(confirm: true),
                  icon: _isSaving
                      ? const SizedBox(
                          width: AppSizes.iconSm,
                          height: AppSizes.iconSm,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _isEditing ? 'Update & confirm' : 'Save & confirm',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    minimumSize: const Size.fromHeight(AppSizes.huge),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // Freeze inputs while saving — edits made mid-flight would be
      // silently dropped from the payload that's already on the wire.
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: Form(
        key: _formKey,
        child: Column(
          children: [
            GlassHero.line(
              kind: LineArt.receipt,
              height: AppSizes.heroHeightSm,
              illustrationSize: AppSizes.productImageSize,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.lg),
                children: [
            AppSectionHeader(
              title: AppStrings.invoiceType.toUpperCase(),
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
            ),
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
              // Type is immutable once an invoice exists — switching it
              // would change the number prefix (INV ↔ PUR) and stock
              // direction, so backend rejects it. Lock the toggle in
              // edit mode rather than silently failing on save.
              onSelectionChanged: _isEditing
                  ? null
                  : (v) => setState(() {
                        _type = v.first;
                        _selectedVendor = null;
                        _selectedParty = null;
                      }),
            ),
            const SizedBox(height: AppSizes.xxl),

            AppSectionHeader(
              title: (_type == 'SALE'
                      ? AppStrings.customerInfo
                      : AppStrings.vendorInfo)
                  .toUpperCase(),
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
            ),
            if (_type == 'PURCHASE') ...[
              if (_selectedVendor != null)
                _SelectedVendorCard(
                  vendor: _selectedVendor!,
                  onChange: _pickVendor,
                  onClear: _clearVendor,
                )
              else
                AppButton.secondary(
                  label: AppStrings.selectVendor,
                  icon: Icons.local_shipping_outlined,
                  onPressed: _pickVendor,
                  fullWidth: true,
                ),
            ] else ...[
              if (_selectedParty != null)
                _SelectedPartyCard(
                  party: _selectedParty!,
                  onChange: _pickParty,
                  onClear: _clearParty,
                )
              else ...[
                AppButton.secondary(
                  label: AppStrings.selectParty,
                  icon: Icons.person_search_rounded,
                  onPressed: _pickParty,
                  fullWidth: true,
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
                const SizedBox(height: AppSizes.md),
                // Walk-in place-of-supply picker. Drives the GST split
                // when no party is attached to the invoice.
                DropdownButtonFormField<String>(
                  initialValue: _walkInStateCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Place of supply (state)',
                    helperText: 'Buyer state — drives CGST/SGST vs IGST',
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('— Select —'),
                    ),
                    for (final s in IndianStates.all)
                      DropdownMenuItem<String>(
                        value: s.code,
                        child: Text('${s.code} — ${s.name}'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _walkInStateCode = v),
                ),
              ],
            ],

            const SizedBox(height: AppSizes.xxl),

            AppSectionHeader(
              title: AppStrings.invoiceItems.toUpperCase(),
              padding: const EdgeInsets.only(bottom: AppSizes.sm),
            ),

            // Product search + scan
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _productSearch,
                    decoration: InputDecoration(
                      labelText: AppStrings.searchToAddProduct,
                      prefixIcon: _isSearchingProducts
                          ? const Padding(
                              padding: EdgeInsets.all(AppSizes.md),
                              child: SizedBox(
                                width: AppSizes.iconSm,
                                height: AppSizes.iconSm,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : const Icon(Icons.search_rounded),
                    ),
                    onChanged: _onProductSearchChanged,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                IconButton.filledTonal(
                  tooltip: 'Scan barcode',
                  onPressed: _scanProduct,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                ),
              ],
            ),

            if (_productResults.isNotEmpty) ...[
              const SizedBox(height: AppSizes.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < _productResults.length; i++) ...[
                      if (i > 0) const AppDivider.flush(),
                      ListTile(
                        dense: true,
                        title: Text(_productResults[i].name),
                        subtitle: Text(_productResults[i].sku),
                        trailing: Text(
                          '${AppStrings.currencySymbol}${(_type == 'SALE' ? _productResults[i].sellingPrice : _productResults[i].purchasePrice).toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall,
                        ),
                        onTap: () => _addItem(_productResults[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSizes.md),

            if (_items.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Center(
                  child: Text(
                    AppStrings.noItemsYet,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...List.generate(
                _items.length,
                (i) => _ItemRow(
                  item: _items[i],
                  onRemove: () {
                    _markDirty();
                    setState(() => _items.removeAt(i));
                  },
                  onChanged: () {
                    _markDirty();
                    setState(() {});
                  },
                ),
              ),

            const SizedBox(height: AppSizes.xxl),

            if (_items.isNotEmpty) ...[
              AppSectionHeader(
                title: AppStrings.totals.toUpperCase(),
                padding: const EdgeInsets.only(bottom: AppSizes.sm),
              ),
              if (_type == 'SALE') ...[
                // Document-type toggle. Tax Invoice is the default; Bill of
                // Supply is for composition / nil-rated dealers; Estimate
                // creates an EST-prefixed quotation the user can later
                // convert via the detail page.
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'TAX_INVOICE',
                      label: Text('Tax Invoice'),
                    ),
                    ButtonSegment(
                      value: 'BILL_OF_SUPPLY',
                      label: Text('Bill of Supply'),
                    ),
                    ButtonSegment(
                      value: 'ESTIMATE',
                      label: Text('Estimate'),
                    ),
                  ],
                  selected: {_documentType},
                  onSelectionChanged: (v) =>
                      setState(() => _documentType = v.first),
                ),
                const SizedBox(height: AppSizes.md),
              ],
              // GST-5 — tax convention toggle. OFF (default) = unit prices are
              // pre-tax and GST is added on top (existing behaviour). ON = the
              // entered unit prices already include GST and the engine backs it
              // out, matching the marketplace "inclusive of all taxes" path.
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _isPriceInclusive,
                onChanged: (v) => setState(() => _isPriceInclusive = v),
                title: Text(
                  'Prices include GST',
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  _isPriceInclusive
                      ? 'Tax is backed out of the entered prices'
                      : 'GST is added on top of the entered prices',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ),
              _TotalRow(label: AppStrings.subtotal, value: _subtotal),
              // GST split: same formula as the backend — line.taxableValue =
              // qty*price − discount, line tax = taxableValue * rate / 100.
              // We sum across lines and either show one IGST row (interstate)
              // or split CGST/SGST 50/50 (intrastate).
              if (_isInterstate)
                _TotalRow(label: 'IGST', value: _totalTax)
              else ...[
                _TotalRow(label: 'CGST', value: _totalTax / 2),
                _TotalRow(label: 'SGST', value: _totalTax / 2),
              ],
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
              if (_roundOff != 0)
                _TotalRow(label: 'Round-off', value: _roundOff),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                child: AppDivider.flush(),
              ),
              _TotalRow(
                label: 'Grand Total',
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
          ],
        ),
        ),
      ),
      ),
    );
  }
}

class _SelectedVendorCard extends StatelessWidget {
  const _SelectedVendorCard({
    required this.vendor,
    required this.onChange,
    required this.onClear,
  });

  final Vendor vendor;
  final VoidCallback onChange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          AppMonogramAvatar(label: vendor.name),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vendor.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (vendor.phone != null)
                  Text(vendor.phone!, style: theme.textTheme.bodySmall),
                if (vendor.gstin != null)
                  Text(
                    'GSTIN: ${vendor.gstin}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: AppCard(
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
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.error,
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
    final labelStyle = isHighlight
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted);
    final valueStyle = isHighlight
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(
            '${AppStrings.currencySymbol}${value.toStringAsFixed(2)}',
            style: valueStyle,
          ),
        ],
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
    return AppCard(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          AppMonogramAvatar(label: party.name),
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
                      color: AppColors.muted,
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
    );
  }
}
