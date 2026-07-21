import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/parties/presentation/widgets/party_picker.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/quotations/domain/entities/quotation.dart';
import 'package:shopxy/features/quotations/presentation/providers/quotations_provider.dart';
import 'package:shopxy/features/quotations/presentation/widgets/quote_line_thumb.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/core/icons/app_icons.dart';

/// Internal mutable bucket line.
class _Line {
  _Line({
    required this.productId,
    required this.name,
    required this.sku,
    required this.unitPrice,
    required this.taxPercent,
    this.imageUrl,
  }) {
    priceCtrl = TextEditingController(text: _fmtPrice(unitPrice));
  }
  final int productId;
  final String name;
  final String? sku;
  /// The quoted unit price — editable by the merchant in the builder.
  double unitPrice;
  final double taxPercent;
  final String? imageUrl;
  /// Backs the inline price field so the merchant can set their own quote
  /// price (the whole point of a quotation), seeded from the catalogue price.
  late final TextEditingController priceCtrl;
  int qty = 1;

  double get taxable => qty * unitPrice;
  double get lineTotal => taxable * (1 + taxPercent / 100);

  static String _fmtPrice(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

/// Merchant flow: browse the catalogue → add products to a bucket → pick a
/// linked customer → send a quotation. On the customer's acceptance it becomes
/// a confirmed invoice (handled server-side).
///
/// In *respond* mode ([respondTo] set) the merchant is pricing a customer's
/// quote request: the customer is fixed, lines are pre-filled from the request,
/// and sending calls `respond` (REQUESTED → PENDING) instead of `create`.
class CreateQuotationPage extends StatefulWidget {
  const CreateQuotationPage({super.key}) : respondTo = null;
  const CreateQuotationPage.respondTo(this.respondTo, {super.key});

  /// The customer-initiated request being priced, or null for a fresh quote.
  final Quotation? respondTo;

  @override
  State<CreateQuotationPage> createState() => _CreateQuotationPageState();
}

class _CreateQuotationPageState extends State<CreateQuotationPage> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;
  final _noteCtrl = TextEditingController();

  Party? _party;
  final List<_Line> _lines = [];
  List<Product> _results = const [];
  bool _searching = false;
  int _searchSeq = 0;

  bool get _isRespond => widget.respondTo != null;

  @override
  void initState() {
    super.initState();
    final req = widget.respondTo;
    if (req != null) {
      for (final l in req.items) {
        _lines.add(_Line(
          productId: l.productId,
          name: l.name,
          sku: l.sku,
          unitPrice: l.unitPrice,
          taxPercent: l.taxPercent,
          imageUrl: l.imageUrl,
        )..qty = l.quantity <= 0 ? 1 : l.quantity.round());
      }
      _noteCtrl.text = req.note ?? '';
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    for (final l in _lines) {
      l.priceCtrl.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _lines.fold(0, (s, l) => s + l.taxable);
  double get _tax => _lines.fold(0, (s, l) => s + l.taxable * l.taxPercent / 100);
  double get _total => _subtotal + _tax;

  void _onProductSearchChanged(String value) {
    // Debounce — same pattern as OrdersInboxPage, so typing "sol" hits
    // the backend once instead of once per keystroke.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AppDurations.searchDebounce, () {
      if (!mounted) return;
      _search(value);
    });
  }

  Future<void> _search(String q) async {
    final seq = ++_searchSeq;
    if (q.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final ds = context.read<ProductsRemoteDataSource>();
      final res = await ds.getProducts(search: q.trim(), limit: 8);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = res.products;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) return;
      setState(() => _searching = false);
    }
  }

  void _addProduct(Product p) {
    setState(() {
      final existing = _lines.where((l) => l.productId == p.id).toList();
      if (existing.isNotEmpty) {
        existing.first.qty += 1;
      } else {
        _lines.add(_Line(
          productId: p.id,
          name: p.name,
          sku: p.sku,
          unitPrice: p.sellingPrice,
          taxPercent: p.taxPercent,
          imageUrl: p.primaryImageUrl,
        ));
      }
      _searchCtrl.clear();
      _results = const [];
    });
  }

  Future<void> _pickParty() async {
    final p = await showPartyPicker(context);
    if (p != null && mounted) setState(() => _party = p);
  }

  Future<void> _send() async {
    if (_lines.isEmpty || (!_isRespond && _party == null)) return;
    final provider = context.read<QuotationsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final items = [
      for (final l in _lines)
        {
          'productId': l.productId,
          'name': l.name,
          if (l.sku != null) 'sku': l.sku,
          'quantity': l.qty,
          'unitPrice': l.unitPrice,
          'taxPercent': l.taxPercent,
          if (l.imageUrl != null) 'imageUrl': l.imageUrl,
        },
    ];
    try {
      final q = _isRespond
          ? await provider.respond(
              widget.respondTo!.id,
              items: items,
              note: _noteCtrl.text.trim(),
            )
          : await provider.create(
              partyId: _party!.id,
              placeOfSupplyStateCode: _party!.stateCode,
              note: _noteCtrl.text.trim(),
              items: items,
            );
      messenger.showSnackBar(
        SnackBar(content: Text('Quotation ${q.quotationNo} sent to ${q.partyName}')),
      );
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _lines.isNotEmpty && (_isRespond || _party != null);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
          title: _isRespond ? 'Price & send quote' : 'New quotation'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.lg + FloatingAppBar.contentTopInset(context),
          AppSizes.lg,
          AppSizes.lg,
        ),
        children: [
          // Customer selector (fixed when responding to a request).
          _SectionLabel('Customer'),
          const AppDivider.flush(),
          if (_isRespond)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              child: Row(
                children: [
                  Icon(AppIcons.personOutlineRounded,
                      color: AppColors.muted),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Text(
                      widget.respondTo!.partyName,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text('requested',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted)),
                ],
              ),
            )
          else
            InkWell(
              onTap: _pickParty,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                child: Row(
                  children: [
                    Icon(AppIcons.personOutlineRounded,
                        color: AppColors.muted),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Text(
                        _party?.name ?? 'Select a linked customer',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _party == null ? AppColors.muted : null,
                          fontWeight: _party == null ? null : FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(AppIcons.chevronRightRounded,
                        color: AppColors.muted),
                  ],
                ),
              ),
            ),
          const AppDivider.flush(),
          const SizedBox(height: AppSizes.lg),

          // Product search.
          _SectionLabel('Add products'),
          const SizedBox(height: AppSizes.xs),
          TextField(
            controller: _searchCtrl,
            onChanged: _onProductSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search your catalogue',
              prefixIcon: const Icon(AppIcons.searchRounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(AppSizes.md),
                      child: SizedBox(
                        width: AppSizes.iconSm,
                        height: AppSizes.iconSm,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
              ),
            ),
          ),
          if (_results.isNotEmpty)
            Column(
              children: [
                const AppDivider.flush(),
                for (int i = 0; i < _results.length; i++) ...[
                  if (i > 0) const AppDivider.flush(),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(_results[i].name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${_currency.format(_results[i].sellingPrice)} · ${_results[i].taxPercent.toStringAsFixed(0)}% GST · stock ${_results[i].stockQuantity.toStringAsFixed(0)}',
                    ),
                    trailing: Icon(AppIcons.addCircleOutlineRounded,
                        color: AppColors.brand),
                    onTap: () => _addProduct(_results[i]),
                  ),
                ],
                const AppDivider.flush(),
              ],
            ),
          const SizedBox(height: AppSizes.lg),

          // Bucket.
          _SectionLabel('Items (${_lines.length})'),
          const SizedBox(height: AppSizes.xs),
          if (_lines.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
              child: Text(
                'Search above and tap a product to add it.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            )
          else ...[
            const AppDivider.flush(),
            for (int i = 0; i < _lines.length; i++) ...[
              if (i > 0) const AppDivider.flush(),
              _lineRow(_lines[i], theme),
            ],
            const AppDivider.flush(),
          ],
          const SizedBox(height: AppSizes.lg),

          // Note.
          TextField(
            controller: _noteCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(
                borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),

          // Totals.
          if (_lines.isNotEmpty) ...[
            _totalRow('Subtotal', _subtotal, theme),
            _totalRow('GST', _tax, theme),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
              child: AppDivider.flush(),
            ),
            _totalRow('Total', _total, theme, bold: true),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Consumer<QuotationsProvider>(
            builder: (_, prov, _) => SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (canSend && !prov.isSubmitting) ? _send : null,
                child: prov.isSubmitting
                    ? const SizedBox(
                        width: AppSizes.iconMd,
                        height: AppSizes.iconMd,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(canSend
                        ? 'Send quotation · ${_currency.format(_total)}'
                        : _isRespond
                            ? 'Add items to send'
                            : 'Add a customer and items'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineRow(_Line line, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QuoteLineThumb(imageUrl: line.imageUrl),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSizes.xs),
                // Editable quote price — the merchant sets what they're
                // quoting, seeded from the catalogue price.
                Row(
                  children: [
                    SizedBox(
                      width: 104,
                      child: TextField(
                        controller: line.priceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (v) => setState(
                            () => line.unitPrice = double.tryParse(v) ?? 0),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          prefixText: '₹ ',
                          labelText: 'Rate',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.md, vertical: AppSizes.md),
                          border: OutlineInputBorder(
                            borderRadius:
                                AppShapes.squircleRadius(AppSizes.radiusSm),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        line.taxPercent > 0
                            ? '+${line.taxPercent.toStringAsFixed(0)}% GST'
                            : 'No GST',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(AppIcons.removeCircleOutlineRounded),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() {
                      if (line.qty > 1) {
                        line.qty -= 1;
                      } else {
                        line.priceCtrl.dispose();
                        _lines.remove(line);
                      }
                    }),
                  ),
                  Text('${line.qty}',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  IconButton(
                    icon: const Icon(AppIcons.addCircleOutlineRounded),
                    color: AppColors.brand,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => line.qty += 1),
                  ),
                ],
              ),
              Text(
                _currency.format(line.lineTotal),
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, ThemeData theme, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: bold ? FontWeight.w800 : null,
                color: bold ? null : AppColors.muted,
              )),
          Text(_currency.format(value),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
      );
}
