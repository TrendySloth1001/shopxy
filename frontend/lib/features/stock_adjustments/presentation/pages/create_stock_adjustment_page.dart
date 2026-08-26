import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/stock_adjustments/data/datasources/stock_adjustments_remote_data_source.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/glass_widgets.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

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

  final String productId;
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
      setState(
        () => _items.add(
          _ItemDraft(
            productId: p.id,
            productName: p.name,
            productSku: p.sku,
            unit: p.unit,
          ),
        ),
      );
    }
    _searchCtrl.clear();
    setState(() => _searchResults = []);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.stockAdjAddAtLeastOne)));
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
            .map(
              (i) => (
                productId: i.productId,
                quantity: i.quantity,
                unitCost: null,
                note: null,
              ),
            )
            .toList(),
      );
      _dirty = false;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
        title: Text(l10n.stockAdjDiscardTitle),
        content: Text(l10n.stockAdjDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.stockAdjKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.stockAdjDiscard),
          ),
        ],
      ),
    );
    return discard == true;
  }

  String _reasonLabel(AppLocalizations l10n, String code) {
    switch (code) {
      case 'DAMAGE':
        return l10n.stockAdjReasonDamage;
      case 'EXPIRED':
        return l10n.stockAdjReasonExpired;
      case 'SHRINKAGE':
        return l10n.stockAdjReasonShrinkage;
      case 'RECOUNT':
        return l10n.stockAdjReasonRecount;
      case 'OPENING':
        return l10n.stockAdjReasonOpening;
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final allowDirectionToggle = _reason == 'RECOUNT' || _reason == 'OPENING';

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await _confirmDiscard();
        if (discard && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FloatingAppBar(title: l10n.stockAdjNewTitle),
        body: Form(
          key: _formKey,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(height: FloatingAppBar.contentTopInset(context)),
                GlassHero.line(
                  kind: LineArt.emptyClipboard,
                  height: AppSizes.heroHeightSm,
                  illustrationSize: AppSizes.productImageSize,
                  accent: AppColors.warning,
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSizes.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSectionHeader(
                        title: l10n.stockAdjReasonSection,
                        padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      ),
                      Wrap(
                        spacing: AppSizes.sm,
                        runSpacing: AppSizes.xs,
                        children: _kReasons.map((r) {
                          final selected = _reason == r.code;
                          return ChoiceChip(
                            label: Text(_reasonLabel(l10n, r.code)),
                            selected: selected,
                            onSelected: (_) => _pickReason(r.code),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSizes.md),
                      if (allowDirectionToggle)
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                              value: 'IN',
                              label: Text(l10n.stockAdjAddStock),
                            ),
                            ButtonSegment(
                              value: 'OUT',
                              label: Text(l10n.stockAdjRemoveStock),
                            ),
                          ],
                          selected: {_direction},
                          showSelectedIcon: false,
                          onSelectionChanged: (v) =>
                              setState(() => _direction = v.first),
                        )
                      else
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _DirectionHint(
                            direction: _direction,
                            l10n: l10n,
                          ),
                        ),
                      const SizedBox(height: AppSizes.lg),
                      TextFormField(
                        controller: _note,
                        decoration: InputDecoration(
                          labelText: l10n.stockAdjNote,
                        ),
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: AppSizes.xxl),
                      AppSectionHeader(
                        title: l10n.stockAdjProductsSection,
                        padding: const EdgeInsets.only(bottom: AppSizes.sm),
                        trailing: _items.isEmpty
                            ? null
                            : Text(
                                '${_items.length} ${_items.length == 1 ? l10n.stockAdjItemSingular : l10n.stockAdjItemPlural}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                      ),
                      TextFormField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.stockAdjSearchProducts,
                          prefixIcon: const AppIcon(AppIcons.searchRounded),
                          suffixIcon: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(AppSizes.md),
                                  child: SizedBox(
                                    width: AppSizes.iconSm,
                                    height: AppSizes.iconSm,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
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
                              for (
                                int i = 0;
                                i < _searchResults.length;
                                i++
                              ) ...[
                                if (i > 0) const AppDivider.flush(),
                                ListTile(
                                  dense: true,
                                  title: Text(_searchResults[i].name),
                                  subtitle: Text(_searchResults[i].sku),
                                  trailing: const AppIcon(
                                    AppIcons.addCircleOutlineRounded,
                                  ),
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
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.lg,
                            vertical: AppSizes.xxl,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radiusLg,
                            ),
                            border: Border.all(color: AppColors.hairline),
                          ),
                          child: Column(
                            children: [
                              AppIcon(
                                AppIcons.inventory2Rounded,
                                size: AppSizes.iconXl,
                                color: AppColors.subtle,
                              ),
                              const SizedBox(height: AppSizes.sm),
                              Text(
                                l10n.stockAdjNoProductsAdded,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.semibold,
                              ),
                              const SizedBox(height: AppSizes.xxs),
                              Text(
                                l10n.stockAdjSearchToAdd,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
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
                                  onRemove: () =>
                                      setState(() => _items.removeAt(i)),
                                ),
                              ],
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSizes.xxl),
                      AppButton.primary(
                        label: l10n.stockAdjPostAdjustment,
                        icon: AppIcons.checkCircleOutlineRounded,
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
      ),
    );
  }
}

class _DirectionHint extends StatelessWidget {
  const _DirectionHint({required this.direction, required this.l10n});

  final String direction;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIn = direction == 'IN';
    final accent = isIn ? AppColors.success : AppColors.error;
    final tint = isIn ? AppColors.successSoft : AppColors.errorSoft;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(
            isIn
                ? AppIcons.arrowUpwardRounded
                : AppIcons.arrowDownwardRounded,
            size: AppSizes.iconSm,
            color: accent,
          ),
          const SizedBox(width: AppSizes.xs),
          Text(
            isIn ? l10n.stockAdjAddsStock : l10n.stockAdjReducesStock,
            style: theme.textTheme.labelMedium?.copyWith(color: accent),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatefulWidget {
  const _ItemRow({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
  });

  final _ItemDraft item;
  final ValueChanged<double> onQuantityChanged;
  final VoidCallback onRemove;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _qty;

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: _format(widget.item.quantity));
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  static String _format(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(2);

  void _step(double delta) {
    final raw = widget.item.quantity + delta;
    final next = raw < 1 ? 1.0 : raw;
    _qty.text = _format(next);
    widget.onQuantityChanged(next);
  }

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
                  widget.item.productName,
                  style: theme.textTheme.bodyMedium?.semibold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.item.productSku,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          _StepButton(
            icon: AppIcons.removeRounded,
            onTap: () => _step(-1),
          ),
          SizedBox(
            width: AppSizes.massive + AppSizes.sm,
            child: TextFormField(
              controller: _qty,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.xs,
                  vertical: AppSizes.sm,
                ),
                suffixText: widget.item.unit,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (v) {
                final q = double.tryParse(v);
                if (q != null && q > 0) widget.onQuantityChanged(q);
              },
            ),
          ),
          _StepButton(icon: AppIcons.addRounded, onTap: () => _step(1)),
          IconButton(
            onPressed: widget.onRemove,
            icon: AppIcon(
              AppIcons.closeRounded,
              color: AppColors.error,
              size: AppSizes.iconMd,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final AppIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: AppSizes.iconLg,
      child: Container(
        width: AppSizes.iconXl,
        height: AppSizes.iconXl,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          border: Border.all(color: AppColors.hairline),
        ),
        alignment: Alignment.center,
        child: AppIcon(icon, size: AppSizes.iconSm, color: AppColors.black),
      ),
    );
  }
}
