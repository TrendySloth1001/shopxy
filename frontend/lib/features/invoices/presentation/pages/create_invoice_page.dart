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

enum _PosSource {
  partyGstin,
  partyAddress,
  vendorGstin,
  vendorAddress,
  shopDefault,

  manual,
}

const double _actionBarButtonHeight = 54;

class CreateInvoicePage extends StatefulWidget {
  const CreateInvoicePage({super.key, this.existing});

  final Invoice? existing;

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _dirty = false;

  String _type = 'SALE';
  Vendor? _selectedVendor;
  Party? _selectedParty;
  final _customerName = TextEditingController();
  final _customerPhone = TextEditingController();
  final _customerGstin = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _note = TextEditingController();

  String _documentType = 'TAX_INVOICE';

  bool _isPriceInclusive = false;

  String? _posOverride;

  final List<InvoiceItemDraft> _items = [];

  void _onGstinChanged() {
    _markDirty();
    if (mounted) setState(() {});
  }

  void _markDirty() {
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
      if (existing.partyId != null && existing.isSale) {
        _selectedParty = _partyFromInvoiceSnapshot(existing);
      }
      if (existing.vendorId != null && existing.isPurchase) {
        _selectedVendor = _vendorFromInvoiceSnapshot(existing);
      }
      _items.addAll(existing.items.map(InvoiceItemDraft.fromInvoiceItem));
      _dirty = false;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<ProductCatalogue>().ensureLoaded());
    });
  }

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

  double get _subtotal => _items.fold(0, (sum, i) => sum + i.subtotal);
  double get _headerDiscount {
    final raw = double.tryParse(_discount.text) ?? 0;
    if (raw <= 0 || _subtotal <= 0) return 0;
    return raw > _subtotal ? _subtotal : raw;
  }

  double get _totalTax {
    final base = _subtotal;
    final hd = _headerDiscount;
    if (base <= 0) return 0;
    var tax = 0.0;
    for (final i in _items) {
      final lineBase = i.subtotal;
      final net = lineBase - hd * (lineBase / base);
      if (_isPriceInclusive) {
        final lineTaxable = net * 100 / (100 + i.taxPercent);
        tax += net - lineTaxable;
      } else {
        tax += net * i.taxPercent / 100;
      }
    }
    return tax;
  }

  double get _taxableValue => _isPriceInclusive
      ? _subtotal - _headerDiscount - _totalTax
      : _subtotal - _headerDiscount;
  double get _rawTotal => _taxableValue + _totalTax;
  double get _roundedTotal => _rawTotal.roundToDouble();
  double get _roundOff => _roundedTotal - _rawTotal;
  double get _total => _roundedTotal;

  ({String? code, _PosSource source}) get _placeOfSupply {
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

  bool get _canOverridePlaceOfSupply {
    if (_posOverride != null) return true;
    return _placeOfSupply.source == _PosSource.shopDefault;
  }

  String? get _placeOfSupplyStateCode => _placeOfSupply.code;

  bool get _isInterstate {
    final shop = context.read<AuthProvider>().user?.shopStateCode;
    final pos = _placeOfSupplyStateCode;
    if (shop == null || pos == null) return false;
    return shop != pos;
  }

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

  Future<void> _scanProduct() async {
    final picked = await Navigator.push<Product?>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (picked != null && mounted) _addItem(picked);
  }

  static const _namedRecipientThreshold = 50000;

  Future<({bool proceed, RecipientDetails? details})> _recipientGate() async {
    const carryOn = (proceed: true, details: null);
    if (_type != 'SALE') return carryOn;
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
        return (proceed: false, details: null);
      case RecipientSkipped():
        return (proceed: true, details: const RecipientDetails.acknowledgedMissing());
      case RecipientFilled(:final details, :final saveToParty):
        if (saveToParty && party != null) {
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
    }
  }

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

  Future<void> _save({required bool confirm}) async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.invoicesNeedsItems)));
      return;
    }

    final gate = await _recipientGate();
    if (!gate.proceed || !mounted) return;

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
        body: AbsorbPointer(
          absorbing: _isSaving,
          child: Form(
            key: _formKey,
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
                        AppCard(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.lg,
                            vertical: AppSizes.sm,
                          ),
                          child: Column(
                            children: [
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

  final bool canOverride;
  final VoidCallback onOverride;

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
