import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shopxy/features/parties/presentation/widgets/party_picker.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/quotations/data/datasources/quotations_remote_data_source.dart';
import 'package:shopxy/features/quotations/domain/entities/quotation.dart';
import 'package:shopxy/features/quotations/presentation/widgets/quote_line_thumb.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

/// Pricing & profit calculator — a multi-product quote builder. Add products,
/// set quantities and per-product GST + discount, plus an overall discount,
/// with a ₹/% switch. GST, totals, cost, profit and margin recompute live. It's
/// the foundation for quotations. A faithful port of merchant-web's
/// `CalculatorSuite`.
class CalculatorView extends StatefulWidget {
  const CalculatorView({super.key});

  @override
  State<CalculatorView> createState() => _CalculatorViewState();
}

enum _Unit { pct, amt }

/// A calculator basket line: the product plus its editable price/qty/GST/disc
/// text fields (mirrors the web `Line` type).
class _CalcLine {
  _CalcLine({
    required this.product,
    required String price,
    required String qty,
    required String rate,
    required String disc,
  }) : priceCtrl = TextEditingController(text: price),
       qtyCtrl = TextEditingController(text: qty),
       rateCtrl = TextEditingController(text: rate),
       discCtrl = TextEditingController(text: disc);

  final Product product;
  final TextEditingController priceCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController discCtrl;

  void dispose() {
    priceCtrl.dispose();
    qtyCtrl.dispose();
    rateCtrl.dispose();
    discCtrl.dispose();
  }

  factory _CalcLine.from(Product p) => _CalcLine(
    product: p,
    price: p.sellingPrice > 0 ? _plain(p.sellingPrice) : '',
    qty: '1',
    rate: _plain(p.taxPercent),
    disc: '',
  );
}

double _num(String s) => double.tryParse(s) ?? 0;
double _round2(double n) => (n * 100).round() / 100;

/// A discount value (% of a base, or a flat ₹ capped at the base).
double _discountOf(double base, String value, _Unit unit) {
  final v = _num(value) < 0 ? 0.0 : _num(value);
  return unit == _Unit.pct
      ? (base * (v > 100 ? 100 : v)) / 100
      : (v > base ? base : v);
}

/// Split a tax-inclusive price into its taxable value and GST components.
({double taxable, double gst}) _gstFromInclusive(double gross, double rate) {
  final r = rate < 0 ? 0.0 : rate;
  final taxable = r > 0 ? (gross * 100) / (100 + r) : gross;
  return (taxable: taxable, gst: gross - taxable);
}

/// Plain number string: whole when integral, else up to 2dp (no grouping).
String _plain(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

class _CalculatorViewState extends State<CalculatorView> {
  final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  Timer? _searchDebounce;

  List<Product> _products = const [];
  bool _listLoading = true;
  bool _autoSeeded = false;

  final List<_CalcLine> _lines = [];
  bool _interState = false;
  _Unit _discUnit = _Unit.pct;
  final _overallCtrl = TextEditingController();

  // Quotation round-trip.
  Quotation? _quote;
  ({int id, String name, String? stateCode})? _party;
  bool _sending = false;
  String? _okMsg;
  String? _errMsg;

  @override
  void initState() {
    super.initState();
    _searchProducts('');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    _overallCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  ProductsRemoteDataSource get _productsDs =>
      context.read<ProductsRemoteDataSource>();
  QuotationsRemoteDataSource get _quotesDs =>
      context.read<QuotationsRemoteDataSource>();

  // ── product browser ────────────────────────────────────────────────────
  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AppDurations.searchDebounce, () {
      if (mounted) _searchProducts(v);
    });
  }

  Future<void> _searchProducts(String q) async {
    setState(() => _listLoading = true);
    try {
      final res = await _productsDs.getProducts(
        search: q.trim().isEmpty ? null : q.trim(),
        limit: 40,
      );
      if (!mounted) return;
      setState(() {
        _products = res.products;
        _listLoading = false;
      });
      _maybeSeedFirst();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _products = const [];
        _listLoading = false;
      });
    }
  }

  /// Seed the first product as a line the first time the list arrives (so the
  /// calculator isn't empty on open) — skipped once a quotation is loaded.
  Future<void> _maybeSeedFirst() async {
    if (_autoSeeded || _products.isEmpty || _lines.isNotEmpty) return;
    _autoSeeded = true;
    try {
      final full = await _productsDs.getProduct(_products.first.id);
      if (!mounted || _lines.isNotEmpty) return;
      setState(() => _lines.add(_CalcLine.from(full)));
    } catch (_) {
      /* ignore */
    }
  }

  bool _has(int id) => _lines.any((l) => l.product.id == id);

  Future<void> _toggleLine(Product p) async {
    if (_has(p.id)) {
      setState(() {
        final idx = _lines.indexWhere((l) => l.product.id == p.id);
        if (idx >= 0) _lines.removeAt(idx).dispose();
      });
      return;
    }
    try {
      final full = await _productsDs.getProduct(p.id);
      if (!mounted || _has(full.id)) return;
      setState(() => _lines.add(_CalcLine.from(full)));
    } catch (_) {
      /* ignore */
    }
  }

  // ── quotation round-trip ───────────────────────────────────────────────
  Future<void> _importQuotation(Quotation q) async {
    // Each quotation line is ex-GST (unit price + tax on top). Convert to the
    // calculator's GST-inclusive basis so the grand total ties to the quote.
    final built = <_CalcLine>[];
    for (final it in q.items) {
      try {
        final full = await _productsDs.getProduct(it.productId);
        final incl = 1 + (it.taxPercent) / 100;
        built.add(
          _CalcLine(
            product: full,
            price: _plain(_round2(it.unitPrice * incl)),
            qty: _plain(it.quantity <= 0 ? 1 : it.quantity),
            rate: _plain(it.taxPercent),
            disc: it.discount > 0 ? _plain(_round2(it.discount * incl)) : '',
          ),
        );
      } catch (_) {
        /* skip lines whose product is gone */
      }
    }
    if (!mounted) return;
    setState(() {
      for (final l in _lines) {
        l.dispose();
      }
      _lines
        ..clear()
        ..addAll(built);
      _discUnit = _Unit.amt; // quotation discounts are ₹ amounts
      _overallCtrl.text = '';
      _quote = q;
      _party = q.partyId != null
          ? (id: q.partyId!, name: q.partyName, stateCode: null)
          : null;
      _noteCtrl.text = q.note ?? '';
      _okMsg = null;
      _errMsg = null;
    });
  }

  Future<void> _loadQuotationById(int id) async {
    try {
      await _importQuotation(await _quotesDs.get(id));
    } catch (e) {
      if (mounted) setState(() => _errMsg = friendlyError(e));
    }
  }

  void _resetQuote() {
    setState(() {
      _quote = null;
      _party = null;
      _noteCtrl.text = '';
      _okMsg = null;
      _errMsg = null;
    });
  }

  /// Convert the inclusive basket into ex-GST quotation lines (the overall
  /// discount is distributed across lines pro-rata, so the quote total matches).
  List<Map<String, dynamic>> _buildItems() {
    final computed = _lines.map((l) {
      final price = _num(l.priceCtrl.text).clamp(0, double.infinity).toDouble();
      final qty = _num(l.qtyCtrl.text).clamp(0, double.infinity).toDouble();
      final rate = _num(l.rateCtrl.text).clamp(0, 100).toDouble();
      final grossInclLine = price * qty;
      final lineDiscIncl = _discountOf(
        grossInclLine,
        l.discCtrl.text,
        _discUnit,
      );
      return (
        line: l,
        price: price,
        qty: qty,
        rate: rate,
        grossInclLine: grossInclLine,
        lineDiscIncl: lineDiscIncl,
        netIncl: grossInclLine - lineDiscIncl,
      );
    }).toList();
    final after = computed.fold<double>(0, (s, c) => s + c.netIncl);
    final overallIncl = _discountOf(after, _overallCtrl.text, _discUnit);
    return [
      for (final c in computed)
        if (c.qty > 0 && c.price > 0)
          () {
            final share = after > 0 ? overallIncl * (c.netIncl / after) : 0.0;
            final totalDiscIncl = (c.lineDiscIncl + share) > c.grossInclLine
                ? c.grossInclLine
                : (c.lineDiscIncl + share);
            final factor = 100 / (100 + c.rate);
            return <String, dynamic>{
              'productId': c.line.product.id,
              'name': c.line.product.name,
              if (c.line.product.sku.isNotEmpty) 'sku': c.line.product.sku,
              'quantity': c.qty,
              'unitPrice': _round2(c.price * factor),
              'taxPercent': c.rate,
              'discount': _round2(totalDiscIncl * factor),
              if (c.line.product.primaryImageUrl != null)
                'imageUrl': c.line.product.primaryImageUrl,
            };
          }(),
    ];
  }

  /// Save the basket as a quotation (the PDF is rendered server-side from a
  /// saved quote, so download and send both go through this). Returns the quote.
  Future<Quotation?> _persistQuote() async {
    final l10n = AppLocalizations.of(context);
    final items = _buildItems();
    if (items.isEmpty) {
      setState(() => _errMsg = l10n.reportsCalcAddOneProduct);
      return null;
    }
    final requested = _quote?.status == 'REQUESTED';
    if (!requested && _party == null) {
      setState(() => _errMsg = l10n.reportsCalcChooseCustomerFirst);
      return null;
    }
    setState(() {
      _sending = true;
      _okMsg = null;
      _errMsg = null;
    });
    try {
      final trimmedNote = _noteCtrl.text.trim();
      final saved = requested && _quote != null
          ? await _quotesDs.respond(
              _quote!.id,
              items: items,
              note: trimmedNote.isEmpty ? null : trimmedNote,
              placeOfSupplyStateCode: _quote!.placeOfSupplyStateCode,
            )
          : await _quotesDs.create(
              partyId: _party!.id,
              items: items,
              note: trimmedNote.isEmpty ? null : trimmedNote,
              placeOfSupplyStateCode: _party!.stateCode,
            );
      if (mounted) setState(() => _quote = saved);
      return saved;
    } catch (e) {
      if (mounted) setState(() => _errMsg = friendlyError(e));
      return null;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final saved = await _persistQuote();
    if (saved != null && mounted) {
      setState(
        () => _okMsg = l10n.reportsCalcQuoteSent(
          saved.quotationNo,
          saved.partyName,
        ),
      );
    }
  }

  Future<void> _download() async {
    final saved = _quote ?? await _persistQuote();
    if (saved == null) return;
    try {
      final res = await _quotesDs.downloadPdf(saved.id);
      if (res.statusCode != 200) throw Exception('Failed to generate PDF');
      final dir = await getTemporaryDirectory();
      final safe = saved.quotationNo.replaceAll(
        RegExp(r'[^A-Za-z0-9_.-]'),
        '_',
      );
      final file = File('${dir.path}/quotation-$safe.pdf');
      await file.writeAsBytes(res.bodyBytes);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/pdf')]),
      );
    } catch (e) {
      if (mounted) setState(() => _errMsg = friendlyError(e));
    }
  }

  Future<void> _pickParty() async {
    final p = await showPartyPicker(context);
    if (p != null && mounted) {
      setState(() => _party = (id: p.id, name: p.name, stateCode: p.stateCode));
    }
  }

  Future<void> _pickQuotation() async {
    final picked = await showModalBottomSheet<Quotation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surface,
      builder: (_) => const _QuotationPickerSheet(),
    );
    if (picked != null) await _loadQuotationById(picked.id);
  }

  // ── aggregate maths (mirrors the web reducer) ───────────────────────────
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    double grossIncl = 0,
        lineDiscTotal = 0,
        taxAfterLines = 0,
        gstAfterLines = 0;
    double totalCost = 0, totalQty = 0;
    for (final l in _lines) {
      final price = _num(l.priceCtrl.text).clamp(0, double.infinity).toDouble();
      final q = _num(l.qtyCtrl.text).clamp(0, double.infinity).toDouble();
      final rate = _num(l.rateCtrl.text).clamp(0, 100).toDouble();
      final bk = _gstFromInclusive(price, rate);
      final grossLine = price * q;
      final lineDisc = _discountOf(grossLine, l.discCtrl.text, _discUnit);
      final net = grossLine - lineDisc;
      final f = grossLine > 0 ? net / grossLine : 0;
      grossIncl += grossLine;
      lineDiscTotal += lineDisc;
      taxAfterLines += bk.taxable * q * f;
      gstAfterLines += bk.gst * q * f;
      totalCost += l.product.purchasePrice * q;
      totalQty += q;
    }
    final afterLines = grossIncl - lineDiscTotal;
    final overallDisc = _discountOf(afterLines, _overallCtrl.text, _discUnit);
    final grandTotal = afterLines - overallDisc;
    final g = afterLines > 0 ? grandTotal / afterLines : 0;
    final finalTaxable = taxAfterLines * g;
    final finalGst = gstAfterLines * g;
    final cgst = _interState ? 0.0 : finalGst / 2;
    final igst = _interState ? finalGst : 0.0;
    final totalProfit = grandTotal - totalCost;
    final margin = grandTotal > 0 ? (totalProfit / grandTotal) * 100 : 0.0;
    final markup = totalCost > 0 ? (totalProfit / totalCost) * 100 : 0.0;
    final totalDisc = lineDiscTotal + overallDisc;
    final profitTone = totalProfit < 0
        ? AppColors.error
        : totalProfit > 0
        ? AppColors.success
        : AppColors.black;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.huge,
      ),
      children: [
        Text(l10n.reportsCalcTitle, style: theme.textTheme.titleLarge?.bold),
        const SizedBox(height: AppSizes.xs),
        Text(
          l10n.reportsCalcIntro,
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSizes.lg),

        // ── Line items ───────────────────────────────────────────────────
        if (_lines.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: AppSizes.xl),
            decoration: ShapeDecoration(
              shape: AppShapes.squircle(
                AppSizes.radiusMd,
                side: BorderSide(color: AppColors.hairline),
              ),
            ),
            child: Text(
              l10n.reportsCalcNoProductsYet,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          )
        else
          for (final l in _lines)
            _LineRow(
              key: ValueKey(l.product.id),
              line: l,
              unit: _discUnit,
              money: _money,
              onChanged: () => setState(() {}),
              onRemove: () => _toggleLine(l.product),
            ),

        const SizedBox(height: AppSizes.lg),

        // ── Controls ─────────────────────────────────────────────────────
        Wrap(
          spacing: AppSizes.xl,
          runSpacing: AppSizes.md,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _ChoiceField(
              label: l10n.reportsCalcSupply,
              value: _interState ? 'inter' : 'intra',
              options: [
                ('intra', l10n.reportsCalcWithinState),
                ('inter', l10n.reportsCalcInterState),
              ],
              onChanged: (v) => setState(() => _interState = v == 'inter'),
            ),
            _ChoiceField(
              label: l10n.reportsCalcDiscountIn,
              value: _discUnit == _Unit.pct ? 'pct' : 'amt',
              options: const [('pct', '%'), ('amt', '₹')],
              onChanged: (v) => setState(
                () => _discUnit = v == 'pct' ? _Unit.pct : _Unit.amt,
              ),
            ),
            SizedBox(
              width: 128,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.reportsCalcOverallDiscount,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  _NumField(
                    controller: _overallCtrl,
                    onChanged: (_) => setState(() {}),
                    prefix: _discUnit == _Unit.amt ? '₹' : null,
                    suffix: _discUnit == _Unit.pct ? '%' : null,
                    hint: '0',
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Calculation ──────────────────────────────────────────────────
        const SizedBox(height: AppSizes.xl),
        Divider(height: 1, color: AppColors.hairline),
        const SizedBox(height: AppSizes.xl),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.reportsCalcGrandTotalInclGst,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.subtle,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _money.format(grandTotal),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    (_lines.length == 1
                            ? l10n.reportsCalcProductCountOne(
                                '${_lines.length}',
                              )
                            : l10n.reportsCalcProductCountOther(
                                '${_lines.length}',
                              )) +
                        l10n.reportsCalcQtySummary(_plain(totalQty)) +
                        (totalDisc > 0
                            ? l10n.reportsCalcDiscOff(_money.format(totalDisc))
                            : ""),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.subtle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        Wrap(
          spacing: AppSizes.xl,
          runSpacing: AppSizes.md,
          children: [
            _Kpi(
              label: l10n.reportsCalcProfit,
              value: _money.format(totalProfit),
              tone: profitTone,
            ),
            _Kpi(
              label: l10n.reportsCalcMargin,
              value: _fmtPct(margin),
              tone: profitTone,
            ),
            _Kpi(label: 'GST', value: _money.format(finalGst)),
          ],
        ),
        const SizedBox(height: AppSizes.xl),

        _Block(
          label: l10n.reportsCalcBlockTotal,
          rows: [
            _R(
              l10n.reportsCalcGrossSubtotal,
              _money.format(grossIncl),
              hint: l10n.reportsCalcHintInclGst,
            ),
            if (lineDiscTotal > 0)
              _R(
                l10n.reportsCalcLineDiscounts,
                '− ${_money.format(lineDiscTotal)}',
                tone: AppColors.success,
              ),
            if (overallDisc > 0)
              _R(
                l10n.reportsCalcOverallDiscount,
                '− ${_money.format(overallDisc)}',
                tone: AppColors.success,
              ),
            _R.total(l10n.reportsCalcGrandTotalRow, _money.format(grandTotal)),
          ],
        ),
        const SizedBox(height: AppSizes.xl),
        _Block(
          label: _interState
              ? l10n.reportsCalcBlockGstInterState
              : l10n.reportsCalcBlockGstWithinState,
          rows: [
            _R(
              l10n.reportsCalcSubtotal,
              _money.format(finalTaxable),
              hint: l10n.reportsCalcHintTaxableExGst,
            ),
            if (_interState)
              _R('IGST', _money.format(igst))
            else ...[
              _R('CGST', _money.format(cgst)),
              _R('SGST', _money.format(cgst)),
            ],
            _R.total(l10n.reportsCalcGstTotal, _money.format(finalGst)),
          ],
        ),
        const SizedBox(height: AppSizes.xl),
        _Block(
          label: l10n.reportsCalcBlockProfit,
          rows: [
            _R(l10n.reportsCalcCostOfGoods, _money.format(totalCost)),
            _R(
              l10n.reportsCalcRevenue,
              _money.format(grandTotal),
              hint: l10n.reportsCalcHintInclGst,
            ),
            _R(
              l10n.reportsCalcProfit,
              _money.format(totalProfit),
              strong: true,
              tone: profitTone,
            ),
            _R(
              l10n.reportsCalcMarkup,
              _fmtPct(markup),
              hint: l10n.reportsCalcHintReturnOnCost,
            ),
            _R.total(
              l10n.reportsCalcProfitMargin,
              _fmtPct(margin),
              tone: profitTone,
            ),
          ],
        ),

        // ── Quotation round-trip ─────────────────────────────────────────
        const SizedBox(height: AppSizes.xxl),
        Divider(height: 1, color: AppColors.hairline),
        const SizedBox(height: AppSizes.lg),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                l10n.reportsCalcQuotation,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.subtle,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            if (_quote != null)
              Flexible(
                child: Text(
                  '${_quote!.quotationNo} · ${_statusLabel(context, _quote!.status)}',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _sending ? null : _pickQuotation,
              icon: const AppIcon(
                AppIcons.descriptionOutlined,
                size: AppSizes.iconSm,
              ),
              label: Text(l10n.reportsCalcLoadQuotation),
            ),
            if (_quote?.status != 'REQUESTED')
              OutlinedButton.icon(
                onPressed: _sending ? null : _pickParty,
                icon: const AppIcon(
                  AppIcons.personAddAlt1Outlined,
                  size: AppSizes.iconSm,
                ),
                label: Text(_party?.name ?? l10n.reportsCalcChooseCustomer),
              ),
            OutlinedButton.icon(
              onPressed: (_sending || _lines.isEmpty) ? null : _download,
              icon: const AppIcon(
                AppIcons.downloadRounded,
                size: AppSizes.iconSm,
              ),
              label: Text(l10n.reportsCalcDownload),
            ),
            FilledButton.icon(
              onPressed: (_sending || _lines.isEmpty) ? null : _send,
              icon: _sending
                  ? const SizedBox(
                      width: AppSizes.iconSm,
                      height: AppSizes.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppIcon(AppIcons.sendRounded, size: AppSizes.iconSm),
              label: Text(
                _sending
                    ? l10n.reportsCalcSending
                    : _quote?.status == 'REQUESTED'
                    ? l10n.reportsCalcPriceAndSend
                    : l10n.reportsCalcSendQuotation,
              ),
            ),
            if (_quote != null)
              TextButton(
                onPressed: _sending ? null : _resetQuote,
                child: Text(l10n.reportsCalcNew),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: l10n.reportsCalcNoteLabel,
            hintText: l10n.reportsCalcNoteHint,
            border: OutlineInputBorder(
              borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
            ),
          ),
        ),
        if (_okMsg != null || _errMsg != null) ...[
          const SizedBox(height: AppSizes.sm),
          Text(
            _errMsg ?? _okMsg!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: _errMsg != null ? AppColors.error : AppColors.success,
            ),
          ),
        ],
        const SizedBox(height: AppSizes.sm),
        Text(
          l10n.reportsCalcQuoteNote,
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.subtle),
        ),

        // ── Product browser ──────────────────────────────────────────────
        const SizedBox(height: AppSizes.xxl),
        Divider(height: 1, color: AppColors.hairline),
        const SizedBox(height: AppSizes.lg),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.reportsCalcYourProducts,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.subtle,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            if (_lines.isNotEmpty)
              Text(
                l10n.reportsCalcAddedCount('${_lines.length}'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.subtle,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        AppSearchBar(
          hint: l10n.reportsCalcSearchByNameOrSku,
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          // _onSearchChanged runs its own debounce.
          debounce: Duration.zero,
        ),
        const SizedBox(height: AppSizes.md),
        if (_listLoading && _products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
            child: Center(
              child: Text(
                l10n.reportsCalcLoadingProducts,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.subtle,
                ),
              ),
            ),
          )
        else if (_products.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
            child: Center(
              child: Text(
                l10n.reportsCalcNoProductsFound,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ),
          )
        else
          for (final p in _products)
            _ProductTile(
              product: p,
              money: _money,
              added: _has(p.id),
              onToggle: () => _toggleLine(p),
            ),
      ],
    );
  }
}

/// One editable basket line. Phone layout: product + inline price on the first
/// row; GST / qty / discount + line total on the second.
class _LineRow extends StatelessWidget {
  const _LineRow({
    super.key,
    required this.line,
    required this.unit,
    required this.money,
    required this.onChanged,
    required this.onRemove,
  });
  final _CalcLine line;
  final _Unit unit;
  final NumberFormat money;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final price = _num(
      line.priceCtrl.text,
    ).clamp(0, double.infinity).toDouble();
    final qty = _num(line.qtyCtrl.text).clamp(0, double.infinity).toDouble();
    final gross = price * qty;
    final net = gross - _discountOf(gross, line.discCtrl.text, unit);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              QuoteLineThumb(imageUrl: line.product.primaryImageUrl),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Row(
                      children: [
                        SizedBox(
                          width: 110,
                          child: _NumField(
                            controller: line.priceCtrl,
                            onChanged: (_) => onChanged(),
                            prefix: '₹',
                            dense: true,
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          l10n.reportsCalcEach,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.subtle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const AppIcon(
                  AppIcons.closeRounded,
                  size: AppSizes.iconMd,
                ),
                color: AppColors.subtle,
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
                tooltip: l10n.reportsCalcRemoveProduct(line.product.name),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniField(
                label: 'GST',
                child: _NumField(
                  controller: line.rateCtrl,
                  onChanged: (_) => onChanged(),
                  suffix: '%',
                  dense: true,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              _MiniField(
                label: l10n.reportsCalcQty,
                child: _NumField(
                  controller: line.qtyCtrl,
                  onChanged: (_) => onChanged(),
                  dense: true,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              _MiniField(
                label: l10n.reportsCalcDisc,
                child: _NumField(
                  controller: line.discCtrl,
                  onChanged: (_) => onChanged(),
                  prefix: unit == _Unit.amt ? '₹' : null,
                  suffix: unit == _Unit.pct ? '%' : null,
                  dense: true,
                ),
              ),
              const Spacer(),
              Text(
                money.format(net),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.subtle,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        SizedBox(width: 64, child: child),
      ],
    );
  }
}

/// Compact numeric text field with optional leading ₹ / trailing % affix.
class _NumField extends StatelessWidget {
  const _NumField({
    required this.controller,
    required this.onChanged,
    this.prefix,
    this.suffix,
    this.hint,
    this.dense = false,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? prefix;
  final String? suffix;
  final String? hint;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      decoration: InputDecoration(
        prefixText: prefix,
        suffixText: suffix,
        hintText: hint,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: dense ? AppSizes.sm : AppSizes.md,
        ),
        border: OutlineInputBorder(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
        ),
      ),
    );
  }
}

/// Labelled segmented pills (Supply / Discount unit).
class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });
  final String label;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: AppSizes.xs),
        Wrap(
          spacing: AppSizes.xs,
          children: [
            for (final o in options)
              _Pill(
                label: o.$2,
                selected: value == o.$1,
                onTap: () => onChanged(o.$1),
              ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.inverseSurface : AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusButton,
        side: BorderSide(
          color: selected ? AppColors.inverseSurface : AppColors.hairline,
        ),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusButton),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? AppColors.onInverse : AppColors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, this.tone});
  final String label;
  final String value;
  final Color? tone;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.subtle,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSizes.xs),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            color: tone ?? AppColors.black,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// A labelled block of key/value rows with a ruled total footer.
class _Block extends StatelessWidget {
  const _Block({required this.label, required this.rows});
  final String label;
  final List<_R> rows;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.subtle,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        for (final r in rows) r,
      ],
    );
  }
}

class _R extends StatelessWidget {
  const _R(this.label, this.value, {this.hint, this.strong = false, this.tone})
    : isTotal = false;
  const _R.total(this.label, this.value, {this.tone})
    : hint = null,
      strong = true,
      isTotal = true;
  final String label;
  final String value;
  final String? hint;
  final bool strong;
  final bool isTotal;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style:
                    (isTotal
                            ? theme.textTheme.bodyLarge
                            : theme.textTheme.bodySmall)
                        ?.copyWith(
                          color: strong ? AppColors.black : AppColors.muted,
                        ),
                children: [
                  TextSpan(text: label),
                  if (hint != null)
                    TextSpan(
                      text: ' · $hint',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.subtle,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Text(
            value,
            style:
                (isTotal
                        ? theme.textTheme.titleMedium
                        : theme.textTheme.bodyMedium)
                    ?.copyWith(
                      color: tone ?? AppColors.black,
                      fontWeight: (isTotal || strong)
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
          ),
        ],
      ),
    );
    if (!isTotal) return row;
    return Container(
      margin: const EdgeInsets.only(top: AppSizes.xs),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: row,
    );
  }
}

/// A toggleable product tile in the browser (add / remove from the basket).
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.money,
    required this.added,
    required this.onToggle,
  });
  final Product product;
  final NumberFormat money;
  final bool added;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final low = product.isLowStock;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.xs),
      child: Material(
        color: added ? AppColors.brandSoft : AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(
            color: added ? AppColors.brandSoft : AppColors.hairline,
          ),
        ),
        child: InkWell(
          customBorder: AppShapes.squircle(AppSizes.radiusMd),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.sm),
            child: Row(
              children: [
                QuoteLineThumb(imageUrl: product.primaryImageUrl),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        product.sku,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.subtle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      money.format(product.sellingPrice),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '${_plain(product.stockQuantity)} ${product.unit}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: low ? AppColors.warning : AppColors.subtle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSizes.sm),
                Container(
                  width: AppSizes.iconLg,
                  height: AppSizes.iconLg,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: added ? AppColors.brand : AppColors.surface,
                    shape: AppShapes.squircle(
                      AppSizes.radiusFull,
                      side: BorderSide(
                        color: added ? AppColors.brand : AppColors.hairline,
                      ),
                    ),
                  ),
                  child: AppIcon(
                    added ? AppIcons.checkRounded : AppIcons.addRounded,
                    size: AppSizes.iconSm,
                    color: added ? AppColors.white : AppColors.subtle,
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

/// Bottom-sheet picker for loading a saved quotation into the calculator.
class _QuotationPickerSheet extends StatefulWidget {
  const _QuotationPickerSheet();
  @override
  State<_QuotationPickerSheet> createState() => _QuotationPickerSheetState();
}

class _QuotationPickerSheetState extends State<_QuotationPickerSheet> {
  final _money = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  final _searchCtrl = TextEditingController();
  List<Quotation> _all = const [];
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<QuotationsRemoteDataSource>().list();
      if (!mounted) return;
      setState(() {
        _all = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final q = _query.toLowerCase();
    final filtered = q.isEmpty
        ? _all
        : _all
              .where(
                (x) =>
                    x.quotationNo.toLowerCase().contains(q) ||
                    x.partyName.toLowerCase().contains(q),
              )
              .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          children: [
            const SizedBox(height: AppSizes.md),
            Container(
              width: AppSizes.handleWidth,
              height: AppSizes.handleHeight,
              decoration: ShapeDecoration(
                color: AppColors.hairline,
                shape: AppShapes.squircle(AppSizes.radiusFull),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Row(
                children: [
                  Text(
                    l10n.reportsCalcLoadQuotation,
                    style: theme.textTheme.titleMedium?.bold,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: l10n.reportsCalcSearchByNumberOrCustomer,
                  prefixIcon: const AppIcon(AppIcons.searchRounded),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        l10n.reportsCalcNoQuotationsYet,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: AppColors.hairline),
                      itemBuilder: (context, i) {
                        final x = filtered[i];
                        return ListTile(
                          title: Text(x.quotationNo),
                          subtitle: Text(
                            '${_statusLabel(context, x.status)} · ${x.partyName}',
                          ),
                          trailing: Text(
                            _money.format(x.total),
                            style: theme.textTheme.bodyMedium?.bold,
                          ),
                          onTap: () => Navigator.pop(context, x),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Percentage, trimmed to at most 2dp (no trailing zeros); "—" for non-finite.
String _fmtPct(double n) {
  if (!n.isFinite) return '—';
  final s = n.toStringAsFixed(2);
  final trimmed = s.contains('.')
      ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : s;
  return '$trimmed%';
}

String _statusLabel(BuildContext context, String status) {
  final l10n = AppLocalizations.of(context);
  return switch (status) {
    'REQUESTED' => l10n.reportsCalcStatusRequested,
    'PENDING' => l10n.reportsCalcStatusSent,
    'ACCEPTED' => l10n.reportsCalcStatusAccepted,
    'DECLINED' => l10n.reportsCalcStatusDeclined,
    'CANCELLED' => l10n.reportsCalcStatusCancelled,
    'EXPIRED' => l10n.reportsCalcStatusExpired,
    _ => status,
  };
}
