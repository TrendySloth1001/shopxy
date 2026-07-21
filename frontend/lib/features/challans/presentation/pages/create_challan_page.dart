import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/challans/domain/entities/challan.dart';
import 'package:shopxy/features/challans/presentation/providers/challans_provider.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/parties/presentation/widgets/party_picker.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/glass_widgets.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

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
  Timer? _searchDebounce;

  final List<ChallanItemDraft> _items = [];
  List<Product> _searchResults = [];
  bool _isSearching = false;
  bool _isSaving = false;
  Party? _selectedParty;
  // Heuristic unsaved-changes guard. Not exact — only watches the
  // party-name/note controllers plus item adds.
  bool _dirty = false;

  void _markDirty() {
    if (!_dirty) _dirty = true;
  }

  @override
  void initState() {
    super.initState();
    _partyName.addListener(_markDirty);
    _note.addListener(_markDirty);
  }

  @override
  void dispose() {
    _partyName.dispose();
    _partyPhone.dispose();
    _note.dispose();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
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
          ChallanItemDraft(
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

  Future<void> _pickParty() async {
    final picked = await showPartyPicker(context);
    if (picked != null && mounted) {
      setState(() {
        _selectedParty = picked;
        _partyName.text = picked.name;
        _partyPhone.text = picked.phone ?? '';
      });
    }
  }

  void _clearParty() {
    setState(() {
      _selectedParty = null;
      _partyName.clear();
      _partyPhone.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).challansAddAtLeastOne),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final provider = context.read<ChallansProvider>();
      await provider.createChallan(
        partyId: _selectedParty?.id,
        partyName: _selectedParty == null ? _partyName.text.trim() : null,
        partyPhone: _selectedParty == null && _partyPhone.text.trim().isNotEmpty
            ? _partyPhone.text.trim()
            : null,
        note: _note.text.trim().isNotEmpty ? _note.text.trim() : null,
        items: _items,
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
        title: Text(l10n.challansDiscardTitle),
        content: Text(l10n.challansDiscardMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.challansKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.challansDiscard),
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
          title: l10n.challansCreate,
          actions: [
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: AppSizes.iconMd,
                      height: AppSizes.iconMd,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.challansSubmit),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: Column(
              children: [
                SizedBox(height: FloatingAppBar.contentTopInset(context)),
                GlassHero.line(
                  kind: LineArt.deliveryNote,
                  height: AppSizes.heroHeightSm,
                  illustrationSize: AppSizes.productImageSize,
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    children: [
                      AppSectionHeader(
                        title: l10n.challansPartyInfo.toUpperCase(),
                        padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      ),
                      if (_selectedParty != null)
                        _SelectedPartyCard(
                          party: _selectedParty!,
                          onChange: _pickParty,
                          onClear: _clearParty,
                        )
                      else ...[
                        AppButton.secondary(
                          label: l10n.challansSelectParty,
                          icon: AppIcons.personSearchRounded,
                          onPressed: _pickParty,
                          fullWidth: true,
                        ),
                        const SizedBox(height: AppSizes.md),
                        TextFormField(
                          controller: _partyName,
                          decoration: InputDecoration(
                            labelText: l10n.challansPartyName,
                          ),
                          validator: (v) =>
                              _selectedParty == null &&
                                  (v == null || v.trim().isEmpty)
                              ? l10n.challansFieldRequired
                              : null,
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: AppSizes.md),
                        TextFormField(
                          controller: _partyPhone,
                          decoration: InputDecoration(
                            labelText: l10n.challansPhone,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _note,
                        decoration: InputDecoration(
                          labelText: l10n.challansNote,
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSizes.xxl),
                      AppSectionHeader(
                        title: l10n.challansAddProducts.toUpperCase(),
                        padding: const EdgeInsets.only(bottom: AppSizes.sm),
                      ),
                      Text(
                        l10n.challansNoPricesHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: AppSizes.md),
                      TextFormField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.challansSearchProducts,
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
                      const SizedBox(height: AppSizes.xl),
                      Row(
                        children: [
                          Expanded(
                            child: AppSectionHeader(
                              title: l10n.challansItemsHeader.toUpperCase(),
                              padding: const EdgeInsets.only(
                                bottom: AppSizes.sm,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: AppSizes.sm),
                            child: Text(
                              '${_items.length} ${l10n.challansItemsLabel}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_items.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(AppSizes.xl),
                          alignment: Alignment.center,
                          child: Text(
                            l10n.challansEmptyItems,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        )
                      else
                        ...List.generate(
                          _items.length,
                          (i) => _ItemRow(
                            item: _items[i],
                            onQtyChanged: (q) =>
                                setState(() => _items[i].quantity = q),
                            onDelete: () => setState(() => _items.removeAt(i)),
                          ),
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
    final qtyCtrl = TextEditingController(
      text: item.quantity.toStringAsFixed(
        item.quantity == item.quantity.truncateToDouble() ? 0 : 2,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: AppCard(
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
                    style: theme.textTheme.bodyMedium?.medium,
                  ),
                  Text(
                    item.productSku,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (v) {
                  final parsed = double.tryParse(v);
                  if (parsed != null && parsed > 0) onQtyChanged(parsed);
                },
              ),
            ),
            IconButton(
              icon: AppIcon(
                AppIcons.deleteOutlineRounded,
                color: AppColors.error,
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
                    'GSTIN: ${party.gstin}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
          TextButton(onPressed: onChange, child: Text(l10n.challansChange)),
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
