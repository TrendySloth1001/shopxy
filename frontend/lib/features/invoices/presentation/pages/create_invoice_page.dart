import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/features/invoices/domain/entities/recipient_details.dart';
import 'package:shopxy/features/invoices/presentation/widgets/invoice_preview_sheet.dart';
import 'package:shopxy/features/invoices/presentation/widgets/recipient_details_sheet.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/parties/presentation/widgets/party_picker.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/pages/qr_scanner_page.dart';
import 'package:shopxy/features/products/presentation/widgets/product_picker.dart';
import 'package:shopxy/features/products/presentation/providers/product_catalogue.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor.dart';
import 'package:shopxy/features/vendors/presentation/widgets/vendor_picker.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/indian.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_filter_pill.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/glass_widgets.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

/// Where the derived place of supply came from. Shown under the read-only
/// row so the merchant can see WHY they're being charged IGST rather than
/// CGST+SGST — the one thing the old free-choice dropdown never told them.
enum _PosSource {
  partyGstin,
  partyAddress,
  vendorGstin,
  vendorAddress,
  shopDefault,

  /// The merchant picked the state themselves. Only offered when nothing on
  /// the counterparty says where they are — see [_CreateInvoicePageState._posOverride].
  manual,
}

/// Height of the sticky Save-as-draft / Save-&-confirm action buttons. Taller
/// than a stock button so the two labels stay on one line and the bar reads as
/// a deliberate footer.
const double _actionBarButtonHeight = 54;

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

  // Place of supply is no longer held in state — it's derived on every build
  // from the counterparty's GSTIN / address, falling back to the shop's own
  // state. See [_placeOfSupply].

  /// A state the merchant set by hand, overriding the shop-state fallback.
  ///
  /// Null in the ordinary case. Only settable when nothing on the
  /// counterparty implies a state (see [_canOverridePlaceOfSupply]) — the
  /// walk-in-from-another-state case, which would otherwise be billed as a
  /// local supply.
  String? _posOverride;

  final List<InvoiceItemDraft> _items = [];


  /// The place-of-supply row AND the CGST/SGST-vs-IGST split are both derived
  /// from this field, so it has to repaint on every keystroke. [_markDirty]
  /// alone won't do it — it only rebuilds the first time it's called.
  void _onGstinChanged() {
    _markDirty();
    if (mounted) setState(() {});
  }

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
    _customerGstin.addListener(_onGstinChanged);

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
      // `existing.placeOfSupplyStateCode` is deliberately not restored — it's
      // re-derived from the counterparty below, which is where it came from.
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Warm the catalogue while the merchant is still picking a customer, so
      // the product sheet opens on a list instead of a spinner.
      // No-op if another page loaded it already.
      unawaited(context.read<ProductCatalogue>().ensureLoaded());
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
  double get _taxableValue => _isPriceInclusive
      ? _subtotal - _headerDiscount - _totalTax
      : _subtotal - _headerDiscount;
  // Exclusive: total = net taxable + tax. Inclusive: the net amount already
  // includes tax, so total = (subtotal − header discount) directly; written as
  // taxable + tax it reduces to the same number.
  double get _rawTotal => _taxableValue + _totalTax;
  // Indian invoices commonly round to the nearest rupee. We compute the
  // diff the same way the backend does so the UI matches the saved row.
  double get _roundedTotal => _rawTotal.roundToDouble();
  double get _roundOff => _roundedTotal - _rawTotal;
  double get _total => _roundedTotal;

  /// Where this supply is deemed to take place, and why. Mirrors the backend's
  /// derivation (`invoices.service.ts` — GST-10 and the place-of-supply
  /// default) so the split shown here can't disagree with the one saved.
  ///
  /// Order: the counterparty's own state code → their GSTIN prefix → for a
  /// SALE, the shop's own state, because an unregistered walk-in with no
  /// address is a local supply.
  ({String? code, _PosSource source}) get _placeOfSupply {
    // A manual answer beats the shop-state guess, and is only reachable when
    // that guess was all we had (see [_canOverridePlaceOfSupply]).
    if (_posOverride != null) {
      return (code: _posOverride, source: _PosSource.manual);
    }
    if (_type == 'SALE') {
      final party = _selectedParty;
      if (party?.stateCode != null) {
        return (code: party!.stateCode, source: _PosSource.partyAddress);
      }
      final fromPartyGstin = IndianStates.stateCodeFromGstin(party?.gstin);
      if (fromPartyGstin != null) {
        return (code: fromPartyGstin, source: _PosSource.partyGstin);
      }
      final fromTypedGstin = IndianStates.stateCodeFromGstin(_customerGstin.text);
      if (fromTypedGstin != null) {
        return (code: fromTypedGstin, source: _PosSource.partyGstin);
      }
      return (code: _shopStateCode, source: _PosSource.shopDefault);
    }

    final vendor = _selectedVendor;
    if (vendor?.stateCode != null) {
      return (code: vendor!.stateCode, source: _PosSource.vendorAddress);
    }
    final fromVendorGstin = IndianStates.stateCodeFromGstin(vendor?.gstin);
    if (fromVendorGstin != null) {
      return (code: fromVendorGstin, source: _PosSource.vendorGstin);
    }
    return (code: _shopStateCode, source: _PosSource.shopDefault);
  }

  String? get _shopStateCode =>
      context.read<AuthProvider>().user?.shopStateCode;

  /// Ask for the state by hand. Only reachable via
  /// [_canOverridePlaceOfSupply], so it can never contradict a GSTIN.
  Future<void> _pickPlaceOfSupply() async {
    final l10n = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                0,
                AppSizes.lg,
                AppSizes.sm,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  l10n.invoicesPlaceOfSupply,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.semibold,
                ),
              ),
            ),
            const AppDivider.flush(),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: IndianStates.all.length,
                itemBuilder: (_, i) {
                  final state = IndianStates.all[i];
                  return ListTile(
                    title: Text('${state.code} — ${state.name}'),
                    onTap: () => Navigator.pop(sheetContext, state.code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() => _posOverride = chosen);
    _markDirty();
  }

  /// Whether the merchant may set the place of supply by hand.
  ///
  /// Only when nothing on the counterparty tells us where they are. A GSTIN
  /// or a saved address IS the answer — letting someone override those is
  /// exactly how tax ends up under the wrong head, which is what deriving
  /// the field was meant to prevent.
  ///
  /// The case this exists for: a walk-in with no GSTIN who is standing in
  /// another state. Without it that sale is silently billed as local.
  bool get _canOverridePlaceOfSupply {
    if (_posOverride != null) return true;
    return _placeOfSupply.source == _PosSource.shopDefault;
  }

  String? get _placeOfSupplyStateCode => _placeOfSupply.code;

  /// True if the counterparty's state differs from the shop's. Mirrors
  /// backend `isInterstateSupply` — both halves must be present, else
  /// we treat it as intrastate to avoid mis-charging IGST.
  bool get _isInterstate {
    final shop = context.read<AuthProvider>().user?.shopStateCode;
    final pos = _placeOfSupplyStateCode;
    if (shop == null || pos == null) return false;
    return shop != pos;
  }

  /// Opens the shared catalogue sheet. It calls back per tap rather than
  /// returning one product, so several lines can be added in one sitting.
  Future<void> _openProductPicker() {
    return showProductPicker(
      context,
      sale: _type == 'SALE',
      onAdd: _addItem,
    );
  }

  void _addItem(Product product) {
    _markDirty();
    final existing = _items.indexWhere((i) => i.productId == product.id);
    if (existing >= 0) {
      setState(() => _items[existing].quantity += 1);
    } else {
      setState(() {
        // The document-wide inclusive/exclusive switch can't represent mixed
        // per-line modes, so it's seeded from the FIRST product added — a
        // later product with a disagreeing pricingMode still bills correctly
        // per-line on the backend (which resolves per-product), just isn't
        // reflected in this preview toggle. Only seed once, on an empty cart.
        if (_items.isEmpty) {
          _isPriceInclusive = product.pricingMode == 'TAX_INCLUSIVE';
        }
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
            taxPercent:
                product.pricingMode == 'NO_GST' ? 0 : product.taxPercent,
          ),
        );
      });
    }
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

  /// The ₹50,000 named-recipient threshold in Rule 46(f). Mirrors `FIFTY_K`
  /// in `invoices.service.ts`.
  static const _namedRecipientThreshold = 50000;

  /// Checks the recipient is complete enough to issue, and if not, offers to
  /// complete it. Returns whether to carry on, plus anything the merchant
  /// filled in.
  ///
  /// This warns in MORE cases than the server blocks, on purpose. The server
  /// backfills `customerStateCode` from a recipient GSTIN and then counts a
  /// bare state code as an address, so a B2B invoice never actually trips its
  /// address branch however empty the customer's record is — it would happily
  /// issue a tax invoice with no postal address at all. The question worth
  /// asking the merchant is "do we know where this customer is?", not "will
  /// the server let this through?".
  Future<({bool proceed, RecipientDetails? details})> _recipientGate() async {
    const carryOn = (proceed: true, details: null);
    if (_type != 'SALE') return carryOn;
    // CREDIT/DEBIT notes inherit their recipient from the original invoice,
    // and ESTIMATE/PROFORMA are pre-supply offers Rule 46 doesn't govern.
    if (_documentType != 'TAX_INVOICE' && _documentType != 'BILL_OF_SUPPLY') {
      return carryOn;
    }

    final hasGstin = _customerGstin.text.trim().isNotEmpty;
    final RecipientRequirement? requirement = hasGstin
        ? RecipientRequirement.b2b
        : (_total >= _namedRecipientThreshold
              ? RecipientRequirement.highValue
              : null);
    if (requirement == null) return carryOn;

    final party = _selectedParty;
    bool filled(String? v) => (v ?? '').trim().isNotEmpty;
    final nameMissing = !filled(_customerName.text);
    // State code is deliberately NOT counted — see the note above. What's
    // being asked is whether a postal address exists.
    final addressMissing =
        !filled(party?.address) &&
        !filled(party?.city) &&
        !filled(party?.pinCode);
    if (!nameMissing && !addressMissing) return carryOn;

    final outcome = await showRecipientDetailsSheet(
      context,
      requirement: requirement,
      nameMissing: nameMissing,
      addressMissing: addressMissing,
      canSaveToParty: party != null,
      initialCity: party?.city,
      initialStateCode: party?.stateCode ?? _placeOfSupplyStateCode,
      initialPinCode: party?.pinCode,
    );

    switch (outcome) {
      case null:
        // Dismissed. Back to the form — skipping has to be chosen, never
        // fallen into.
        return (proceed: false, details: null);
      case RecipientSkipped():
        return (proceed: true, details: const RecipientDetails.acknowledgedMissing());
      case RecipientFilled(:final details, :final saveToParty):
        if (saveToParty && party != null) {
          // Best-effort: the invoice is the thing being saved, so a failure to
          // also update the customer record must not block it. The details
          // still travel on the invoice either way.
          await _saveDetailsToParty(party.id, details);
        }
        return (proceed: true, details: details);
    }
  }

  Future<void> _saveDetailsToParty(
    String partyId,
    RecipientDetails details,
  ) async {
    try {
      final ds = context.read<PartiesRemoteDataSource>();
      final updated = await ds.updateParty(partyId, {
        if (details.address != null) 'address': details.address,
        if (details.city != null) 'city': details.city,
        if (details.state != null) 'state': details.state,
        if (details.stateCode != null) 'stateCode': details.stateCode,
        if (details.pinCode != null) 'pinCode': details.pinCode,
      });
      if (mounted) setState(() => _selectedParty = updated);
    } catch (_) {
      // Swallowed on purpose — see the call site.
    }
  }

  /// Snapshot of what is about to be sent, for the pre-issue review. Built
  /// from the live form rather than re-read from anywhere, so it can't show
  /// something different from what gets saved.
  InvoicePreviewData _previewData() {
    final l10n = AppLocalizations.of(context);
    final isSale = _type == 'SALE';
    final party = _selectedParty;
    final vendor = _selectedVendor;

    final addressParts = isSale
        ? [party?.address, party?.city, party?.state, party?.pinCode]
        : [vendor?.address, vendor?.city, vendor?.state, vendor?.pinCode];
    final address = addressParts
        .where((p) => (p ?? '').trim().isNotEmpty)
        .join(', ');

    final pos = _placeOfSupply;
    final posName = IndianStates.stateNameFromCode(pos.code);

    String money(double v) =>
        '${AppStrings.currencySymbol}${v.toStringAsFixed(2)}';

    return InvoicePreviewData(
      documentTypeLabel: isSale ? _documentTypeLabel(_documentType) : _type,
      counterpartyLabel: isSale
          ? l10n.invoicesPreviewBillTo
          : l10n.invoicesPreviewFrom,
      counterpartyName: isSale
          ? (_customerName.text.trim().isNotEmpty
                ? _customerName.text.trim()
                : (party?.name ?? '—'))
          : (vendor?.name ?? '—'),
      counterpartyAddress: address.isEmpty ? null : address,
      placeOfSupply: pos.code == null
          ? null
          : '${pos.code}${posName != null ? ' — $posName' : ''}',
      supplyTypeLabel: _isInterstate
          ? l10n.invoicesSupplyInterState
          : l10n.invoicesSupplyIntraState,
      lines: [
        for (final i in _items)
          InvoicePreviewLine(
            name: i.productName,
            quantityLabel: '${_qtyLabel(i.quantity)} × ${money(i.unitPrice)}',
            amount: i.subtotal,
          ),
      ],
      totals: [
        InvoicePreviewTotal(l10n.invoicesSubtotal, money(_subtotal)),
        if (_headerDiscount > 0)
          InvoicePreviewTotal(
            l10n.invoicesDiscount,
            '- ${money(_headerDiscount)}',
          ),
        InvoicePreviewTotal(l10n.invoicesTax, money(_totalTax)),
        InvoicePreviewTotal(l10n.invoicesTotal, money(_total), emphasis: true),
      ],
    );
  }

  static String _qtyLabel(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(2);

  /// Same labels the document-type pills use, so the preview names the
  /// document exactly as the form did.
  String _documentTypeLabel(String value) {
    final l10n = AppLocalizations.of(context);
    return switch (value) {
      'TAX_INVOICE' => l10n.invoicesDocTaxInvoice,
      'BILL_OF_SUPPLY' => l10n.invoicesDocBillOfSupply,
      'ESTIMATE' => l10n.invoicesDocEstimate,
      'PROFORMA' => l10n.invoicesDocProforma,
      _ => value.replaceAll('_', ' '),
    };
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
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.invoicesNeedsItems)));
      return;
    }

    // Recipient completeness is checked HERE, before the request, because the
    // server's Rule 46(e)/(f) rejection is unactionable from this screen — the
    // merchant would just see "Recipient address is required" with nowhere to
    // put one.
    final gate = await _recipientGate();
    if (!gate.proceed || !mounted) return;

    // Confirming issues the document, posts the stock movement and burns an
    // invoice number. Saving a draft does none of that, so only the
    // irreversible path gets a review step.
    if (confirm) {
      final approved = await showInvoicePreviewSheet(context, _previewData());
      if (!approved || !mounted) return;
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
          recipient: gate.details,
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
              SnackBar(content: Text(l10n.invoicesUpdatedAndConfirmed)),
            );
          } catch (e) {
            if (!mounted) return;
            messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
          }
        } else if (mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.invoicesSavedAsDraft)),
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
        recipient: gate.details,
        items: itemsPayload,
        confirm: confirm,
      );
      _dirty = false;
      if (!mounted) return;

      if (!confirm) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.invoicesSavedAsDraft)),
        );
        navigator.pop(true);
        return;
      }
      if (result.confirmed) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.invoicesConfirmedNamed(result.invoice.invoiceNo),
            ),
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
            result.confirmError ?? l10n.invoicesSavedDraftConfirmFailed,
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
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.invoicesDiscardChangesTitle),
        content: Text(l10n.invoicesDiscardChangesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.invoicesKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.invoicesDiscard),
          ),
        ],
      ),
    );
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FloatingAppBar(
          title: _isEditing
              ? l10n.invoicesEditDraftTitle
              : l10n.invoicesCreateTitle,
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(AppSizes.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.hairline)),
            ),
            child: Row(
              children: [
                // Draft = secondary. No icon so the label always sits on one
                // line; the taller height keeps a comfortable tap target.
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : () => _save(confirm: false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        _actionBarButtonHeight,
                      ),
                      side: BorderSide(color: AppColors.hairline),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    child: Text(
                      _isEditing
                          ? l10n.invoicesUpdateDraft
                          : l10n.invoicesSaveAsDraft,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : () => _save(confirm: true),
                    icon: _isSaving
                        ? SizedBox(
                            width: AppSizes.iconSm,
                            height: AppSizes.iconSm,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onInverse,
                            ),
                          )
                        : const AppIcon(AppIcons.checkRounded),
                    label: Text(
                      _isEditing
                          ? l10n.invoicesUpdateAndConfirm
                          : l10n.invoicesSaveAndConfirm,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      minimumSize: const Size.fromHeight(
                        _actionBarButtonHeight,
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
            // Single scroll surface: the hero illustration scrolls away with the
            // form (it used to be pinned above a nested ListView). Content passes
            // behind the frosted app bar via extendBodyBehindAppBar.
            child: ListView(
              padding: EdgeInsets.zero,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                SizedBox(height: FloatingAppBar.contentTopInset(context)),
                GlassHero.line(
                  kind: LineArt.receipt,
                  height: AppSizes.heroHeightSm,
                  illustrationSize: AppSizes.productImageSize,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    AppSizes.lg,
                    AppSizes.lg,
                    AppSizes.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSectionHeader(
                        title: l10n.invoicesInvoiceType.toUpperCase(),
                        padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      ),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'SALE',
                            label: Text(l10n.invoicesSaleInvoice),
                            icon: const AppIcon(AppIcons.arrowUpwardRounded),
                          ),
                          ButtonSegment(
                            value: 'PURCHASE',
                            label: Text(l10n.invoicesPurchaseInvoice),
                            icon: const AppIcon(AppIcons.arrowDownwardRounded),
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
                        title:
                            (_type == 'SALE'
                                    ? l10n.invoicesCustomerInfo
                                    : l10n.invoicesVendorInfo)
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
                            label: l10n.invoicesSelectVendor,
                            icon: AppIcons.localShippingOutlined,
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
                            label: l10n.invoicesSelectParty,
                            icon: AppIcons.personSearchRounded,
                            onPressed: _pickParty,
                            fullWidth: true,
                          ),
                          const SizedBox(height: AppSizes.md),
                          TextFormField(
                            controller: _customerName,
                            decoration: InputDecoration(
                              labelText: l10n.invoicesCustomerName,
                            ),
                            textCapitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: AppSizes.md),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _customerPhone,
                                  decoration: InputDecoration(
                                    labelText: l10n.invoicesPhone,
                                  ),
                                  keyboardType: TextInputType.phone,
                                ),
                              ),
                              const SizedBox(width: AppSizes.md),
                              Expanded(
                                child: TextFormField(
                                  controller: _customerGstin,
                                  decoration: InputDecoration(
                                    labelText: l10n.invoicesGstin,
                                  ),
                                  textCapitalization:
                                      TextCapitalization.characters,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],

                      // Place of supply is DERIVED, never asked: the first two
                      // digits of a GSTIN are the holder's state code, so
                      // asking for it again invites a mismatch between what
                      // the merchant picked and what the number says. Shown
                      // read-only because it's the reason the tax below splits
                      // into CGST+SGST or IGST.
                      const SizedBox(height: AppSizes.md),
                      _PlaceOfSupplyRow(
                        placeOfSupply: _placeOfSupply,
                        isInterstate: _isInterstate,
                        canOverride: _canOverridePlaceOfSupply,
                        onOverride: _pickPlaceOfSupply,
                        onClearOverride: _posOverride == null
                            ? null
                            : () => setState(() => _posOverride = null),
                      ),

                      const SizedBox(height: AppSizes.xxl),

                      AppSectionHeader(
                        title: l10n.invoicesInvoiceItems.toUpperCase(),
                        padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      ),

                      // Opens the catalogue as a sheet rather than searching
                      // inline: the sheet browses the whole list without
                      // typing, and stays up across several taps so building
                      // a multi-line invoice doesn't reopen it per product.
                      Row(
                        children: [
                          Expanded(
                            child: AppCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.lg,
                                vertical: AppSizes.md,
                              ),
                              onTap: _openProductPicker,
                              child: Row(
                                children: [
                                  AppIcon(
                                    AppIcons.searchRounded,
                                    color: AppColors.muted,
                                    size: AppSizes.iconMd,
                                  ),
                                  const SizedBox(width: AppSizes.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.invoicesAddProducts,
                                          style: theme.textTheme.bodyMedium
                                              ?.semibold,
                                        ),
                                        Text(
                                          l10n.invoicesAddProductsHint,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: AppColors.muted,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  AppIcon(
                                    AppIcons.chevronRightRounded,
                                    color: AppColors.subtle,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          IconButton.filledTonal(
                            tooltip: l10n.invoicesScanBarcode,
                            onPressed: _scanProduct,
                            icon: const AppIcon(AppIcons.qrCodeScannerRounded),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSizes.md),

                      if (_items.isEmpty)
                        AppCard(
                          padding: const EdgeInsets.all(AppSizes.lg),
                          child: Center(
                            child: Text(
                              l10n.invoicesNoItemsYet,
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
                          title: l10n.invoicesTotals.toUpperCase(),
                          padding: const EdgeInsets.only(bottom: AppSizes.sm),
                        ),
                        if (_type == 'SALE') ...[
                          // Document-type toggle. Tax Invoice is the default; Bill of
                          // Supply is for composition / nil-rated dealers; Estimate and
                          // Proforma are pre-supply offers (both take the EST- series and
                          // convert into a real tax invoice via the detail page). Credit
                          // and debit notes are NOT here — they are Sec 34 adjustments
                          // raised against an existing invoice from its detail screen.
                          Wrap(
                            spacing: AppSizes.sm,
                            runSpacing: AppSizes.sm,
                            children: [
                              for (final (value, label) in <(String, String)>[
                                ('TAX_INVOICE', l10n.invoicesDocTaxInvoice),
                                (
                                  'BILL_OF_SUPPLY',
                                  l10n.invoicesDocBillOfSupply,
                                ),
                                ('ESTIMATE', l10n.invoicesDocEstimate),
                                ('PROFORMA', l10n.invoicesDocProforma),
                              ])
                                AppFilterPill(
                                  label: label,
                                  selected: _documentType == value,
                                  onTap: () =>
                                      setState(() => _documentType = value),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.md),
                        ],
                        // Money summary grouped on its own surface so the running total
                        // reads as a distinct panel, not more canvas rows. The tax-
                        // convention toggle lives here too — it directly drives the
                        // numbers below it.
                        AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.lg,
                            vertical: AppSizes.sm,
                          ),
                          child: Column(
                            children: [
                              // GST-5 — tax convention toggle. OFF (default) = unit
                              // prices are pre-tax and GST is added on top. ON = entered
                              // prices already include GST and the engine backs it out.
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                value: _isPriceInclusive,
                                onChanged: (v) =>
                                    setState(() => _isPriceInclusive = v),
                                title: Text(
                                  l10n.invoicesPricesIncludeGst,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                subtitle: Text(
                                  _isPriceInclusive
                                      ? l10n.invoicesPricesInclusiveHint
                                      : l10n.invoicesPricesExclusiveHint,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(bottom: AppSizes.sm),
                                child: AppDivider.flush(),
                              ),
                              _TotalRow(
                                label: l10n.invoicesSubtotal,
                                value: _subtotal,
                              ),
                              // GST split: same formula as the backend — line.taxableValue
                              // = qty*price − discount, line tax = taxableValue*rate/100.
                              // Sum across lines: one IGST row (interstate) or a 50/50
                              // CGST/SGST split (intrastate).
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
                                      l10n.invoicesDiscount,
                                      style: theme.textTheme.bodyMedium,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      controller: _discount,
                                      textAlign: TextAlign.end,
                                      decoration: InputDecoration(
                                        prefixText:
                                            '${AppStrings.currencySymbol} ',
                                        isDense: true,
                                        hintText: '0',
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (_) => setState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                              if (_roundOff != 0)
                                _TotalRow(
                                  label: l10n.invoicesRoundOff,
                                  value: _roundOff,
                                ),
                              const Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: AppSizes.sm,
                                ),
                                child: AppDivider.flush(),
                              ),
                              _TotalRow(
                                label: l10n.invoicesGrandTotal,
                                value: _total,
                                isHighlight: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.xxl),
                      ],

                      // Note
                      TextFormField(
                        controller: _note,
                        decoration: InputDecoration(
                          labelText: l10n.invoicesNote,
                        ),
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
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
    final l10n = AppLocalizations.of(context);
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
                Text(vendor.name, style: theme.textTheme.titleSmall?.semibold),
                if (vendor.phone != null)
                  Text(vendor.phone!, style: theme.textTheme.bodySmall),
                if (vendor.gstin != null)
                  Text(
                    '${l10n.invoicesGstin}: ${vendor.gstin}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: Text(l10n.invoicesChange)),
          IconButton(
            icon: const AppIcon(AppIcons.closeRounded),
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Read-only place-of-supply row. Styled as a disabled form field so it sits
/// in the same rhythm as the inputs above it, while making it obvious there's
/// nothing here to fill in.
class _PlaceOfSupplyRow extends StatelessWidget {
  const _PlaceOfSupplyRow({
    required this.placeOfSupply,
    required this.isInterstate,
    required this.canOverride,
    required this.onOverride,
    this.onClearOverride,
  });

  final ({String? code, _PosSource source}) placeOfSupply;
  final bool isInterstate;

  /// Whether to offer the manual picker at all — false whenever the
  /// counterparty's own GSTIN or address already answers the question.
  final bool canOverride;
  final VoidCallback onOverride;

  /// Non-null only while a manual answer is in force.
  final VoidCallback? onClearOverride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final code = placeOfSupply.code;
    final name = code == null
        ? null
        : IndianStates.all
              .where((s) => s.code == code)
              .map((s) => s.name)
              .firstOrNull;

    final helper = switch (placeOfSupply.source) {
      _PosSource.partyGstin => l10n.invoicesPlaceOfSupplyFromPartyGstin,
      _PosSource.partyAddress => l10n.invoicesPlaceOfSupplyFromPartyAddress,
      _PosSource.vendorGstin => l10n.invoicesPlaceOfSupplyFromVendorGstin,
      _PosSource.vendorAddress => l10n.invoicesPlaceOfSupplyFromVendorAddress,
      _PosSource.shopDefault => l10n.invoicesPlaceOfSupplyDefaultsToShop,
      _PosSource.manual => l10n.invoicesPlaceOfSupplySetManually,
    };

    return InputDecorator(
      decoration: InputDecoration(
        labelText: l10n.invoicesPlaceOfSupply,
        helperText: helper,
        helperMaxLines: 2,
        // A filled, non-focusable box reads as "computed for you" rather than
        // an input someone forgot to enable.
        filled: true,
        fillColor: AppColors.heroPanel,
        enabled: false,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              code == null
                  ? '—'
                  : name == null
                  ? code
                  : '$code — $name',
              style: theme.textTheme.bodyLarge?.semibold,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sm,
              vertical: 2,
            ),
            decoration: ShapeDecoration(
              color: isInterstate
                  ? AppColors.tileBg(AppColors.warningSoft)
                  : AppColors.tileBg(AppColors.infoSoft),
              shape: AppShapes.squircle(AppSizes.radiusFull),
            ),
            child: Text(
              isInterstate
                  ? l10n.invoicesSupplyInterState
                  : l10n.invoicesSupplyIntraState,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isInterstate ? AppColors.warning : AppColors.info,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          // Offered only when the shop's own state was a guess. A GSTIN or a
          // saved address IS the answer, and overriding those is how tax
          // lands under the wrong head.
          if (canOverride) ...[
            const SizedBox(width: AppSizes.xs),
            TextButton(
              onPressed: onClearOverride ?? onOverride,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                onClearOverride != null
                    ? l10n.invoicesPlaceOfSupplyReset
                    : l10n.invoicesPlaceOfSupplyChange,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.brandStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
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
    final l10n = AppLocalizations.of(context);
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
                        style: theme.textTheme.titleSmall?.semibold,
                      ),
                      Text(item.productSku, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: AppIcon(
                    AppIcons.closeRounded,
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
                  label: l10n.invoicesQuantity,
                  value: item.quantity,
                  onChanged: (v) {
                    item.quantity = v;
                    onChanged();
                  },
                ),
                const SizedBox(width: AppSizes.sm),
                _NumField(
                  label: l10n.invoicesUnitPrice,
                  value: item.unitPrice,
                  prefix: AppStrings.currencySymbol,
                  onChanged: (v) {
                    item.unitPrice = v;
                    onChanged();
                  },
                ),
                const SizedBox(width: AppSizes.sm),
                _NumField(
                  label: '${l10n.invoicesTax} %',
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
                '${l10n.invoicesTotal}: ${AppStrings.currencySymbol}${item.total.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.semibold,
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
        ? theme.textTheme.titleSmall?.bold
        : theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted);
    final valueStyle = isHighlight
        ? theme.textTheme.titleSmall?.bold
        : theme.textTheme.bodyMedium?.medium;
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
    final l10n = AppLocalizations.of(context);
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
                Text(party.name, style: theme.textTheme.titleSmall?.semibold),
                if (party.phone != null)
                  Text(party.phone!, style: theme.textTheme.bodySmall),
                if (party.gstin != null)
                  Text(
                    '${l10n.invoicesGstin}: ${party.gstin}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: Text(l10n.invoicesChange)),
          IconButton(
            icon: const AppIcon(AppIcons.closeRounded),
            onPressed: onClear,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
