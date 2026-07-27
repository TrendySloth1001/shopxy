import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/data/models/hsn_dto.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// HSN/SAC classification field.
///
/// The merchant answers one question — *what is this product?* — and the GST
/// rate follows. There is no rate input here; the GST field on the page is a
/// readout of whatever this resolves to.
///
/// Three ways in, in the order merchants actually reach for them:
///
///  1. **Suggested from the product name.** They never touch this field —
///     they name the product, we propose codes, they tap one.
///  2. **Search**, by code or by word, including their own saved shortcuts and
///     the Hindi and transliterated aliases ("kameez", "chappal", "sariya").
///  3. **Typing a code directly**, for merchants who know theirs by heart.
///
/// Every candidate shows its **chapter → heading breadcrumb** and definition,
/// because a four-digit code alone can't tell anyone that chapter 62 is woven
/// and 61 is knitted — the most common apparel misclassification there is.
///
/// `onResolved(null)` means the code has no rate on file. The caller must leave
/// the rate as it was rather than zeroing it: a silent 0% is an under-charged
/// invoice.
///
/// Suggestions render inline beneath the field rather than in an overlay: this
/// lives inside a scrollable bottom-sheet editor, where a floating popover
/// would clip against the sheet's bounds.
class HsnCodeField extends StatefulWidget {
  const HsnCodeField({
    super.key,
    required this.controller,
    required this.dataSource,
    required this.onResolved,
    required this.productName,
    this.price,
    this.onChanged,
  });

  final TextEditingController controller;
  final ProductsRemoteDataSource dataSource;

  /// Called with the master's answer whenever the entered code changes, or with
  /// null when the code has no rate on file.
  final ValueChanged<HsnResolution?> onResolved;

  /// Drives the "suggested for this product" row, and is the label offered when
  /// saving a shortcut. Empty disables both.
  final String productName;

  /// Selling price, so a threshold slab resolves to the rate this product will
  /// actually bill at rather than the headline one.
  final double? price;

  /// Fired alongside typing so the page can mark the form dirty.
  final VoidCallback? onChanged;

  @override
  State<HsnCodeField> createState() => _HsnCodeFieldState();
}

class _HsnCodeFieldState extends State<HsnCodeField> {
  /// Shortest real HSN heading. Below this, resolving is noise.
  static const _minCodeLength = 4;
  static const _searchDebounce = Duration(milliseconds: 300);
  /// Longer than search: a product name is typed in full rather than probed
  /// character by character, and each call may cost a semantic lookup.
  static const _suggestDebounce = Duration(milliseconds: 600);

  Timer? _searchTimer;
  Timer? _suggestTimer;
  Timer? _priceTimer;

  List<HsnMatch> _suggestions = const [];
  List<HsnSuggestion> _nameSuggestions = const [];
  bool _loading = false;
  HsnMatch? _chosen;
  bool _savedShortcut = false;

  /// Latest-wins guard: a slow response for "620" must not overwrite the list
  /// for "62052", nor a stale rate overwrite a newer one.
  int _seq = 0;

  /// Which code we last resolved from, so re-entering the same digits (or a
  /// rebuild) can't re-fire the fill and clobber a manual rate.
  String? _filledFor;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTyped);
    _scheduleSuggest();
  }

  @override
  void didUpdateWidget(HsnCodeField old) {
    super.didUpdateWidget(old);
    if (old.productName != widget.productName) _scheduleSuggest();
    // A price edit can cross a threshold the chosen code cares about. Without
    // this, raising a ₹2,400 shirt to ₹2,600 would leave it billing at 5% —
    // the rule would have been evaluated once and then forgotten.
    if (old.price != widget.price && _chosen?.rule != null) {
      _priceTimer?.cancel();
      _priceTimer = Timer(_searchDebounce, _reresolveForPrice);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTyped);
    _searchTimer?.cancel();
    _suggestTimer?.cancel();
    _priceTimer?.cancel();
    super.dispose();
  }

  void _scheduleSuggest() {
    _suggestTimer?.cancel();
    final name = widget.productName.trim();
    if (name.length < 3) {
      if (_nameSuggestions.isNotEmpty) setState(() => _nameSuggestions = const []);
      return;
    }
    _suggestTimer = Timer(_suggestDebounce, () async {
      final hits = await widget.dataSource.suggestHsn(name);
      if (mounted) setState(() => _nameSuggestions = hits);
    });
  }

  Future<void> _reresolveForPrice() async {
    final digits = normalizeHsnCode(widget.controller.text);
    if (digits.length < _minCodeLength) return;
    final hit = await widget.dataSource.resolveHsn(digits, price: widget.price);
    if (!mounted || hit == null) return;
    widget.onResolved(hit);
  }

  void _onTyped() {
    widget.onChanged?.call();
    _searchTimer?.cancel();
    final query = widget.controller.text.trim();
    if (query.isEmpty) {
      _filledFor = null;
      if (_suggestions.isNotEmpty || _loading || _chosen != null) {
        setState(() {
          _suggestions = const [];
          _loading = false;
          _chosen = null;
        });
      }
      return;
    }
    _searchTimer = Timer(_searchDebounce, () => _lookup(query));
  }

  Future<void> _lookup(String query) async {
    final mine = ++_seq;
    final digits = normalizeHsnCode(query);
    setState(() => _loading = true);

    final results = await widget.dataSource.searchHsn(query);
    final hit = digits.length >= _minCodeLength
        ? await widget.dataSource.resolveHsn(digits, price: widget.price)
        : null;
    if (!mounted || mine != _seq) return;

    setState(() {
      _suggestions = results;
      _loading = false;
    });
    if (digits.length >= _minCodeLength && _filledFor != digits) {
      _filledFor = digits;
      setState(() {
        _savedShortcut = false;
        _chosen = results.where((r) => r.code == digits).firstOrNull;
      });
      widget.onResolved(hit);
    }
  }

  Future<void> _pick(HsnMatch match) async {
    _seq++;
    widget.controller.text = match.code;
    _filledFor = match.code;
    setState(() {
      _suggestions = const [];
      _chosen = match;
      _savedShortcut = false;
    });
    final hit = await widget.dataSource.resolveHsn(match.code, price: widget.price);
    if (!mounted) return;
    widget.onResolved(hit);
  }

  Future<void> _saveShortcut() async {
    final name = widget.productName.trim();
    final code = normalizeHsnCode(widget.controller.text);
    if (name.isEmpty || code.length < _minCodeLength) return;
    final ok = await widget.dataSource.saveHsnShortcut(label: name, code: code);
    if (mounted && ok) setState(() => _savedShortcut = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final selectedCode = normalizeHsnCode(widget.controller.text);
    final showNameSuggestions =
        _nameSuggestions.isNotEmpty && selectedCode.length < _minCodeLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: widget.controller,
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            labelText: l10n.productsHsnCode,
            helperText: l10n.productsHsnCodeHelper,
            helperMaxLines: 2,
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(AppSizes.md),
                    child: SizedBox(
                      width: AppSizes.lg,
                      height: AppSizes.lg,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),

        // Proposed from the product name — the path where the merchant never
        // touches this field at all.
        if (showNameSuggestions) ...[
          const SizedBox(height: AppSizes.md),
          Text(
            l10n.productsHsnSuggestedFor,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSizes.sm),
          Wrap(
            spacing: AppSizes.sm,
            runSpacing: AppSizes.sm,
            children: [
              for (final s in _nameSuggestions.take(4))
                ActionChip(
                  avatar: s.via == 'SHORTCUT'
                      ? AppIcon(AppIcons.starRounded, size: AppSizes.iconSm, color: AppColors.brand)
                      : null,
                  label: Text('${s.name} · ${formatHsnRate(s.gstRate)}%'),
                  onPressed: () => _pick(s),
                ),
            ],
          ),
        ],

        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSizes.sm),
          Container(
            decoration: ShapeDecoration(
              color: AppColors.surface,
              shape: AppShapes.squircle(
                AppSizes.radiusMd,
                side: BorderSide(color: AppColors.hairline, width: 1),
              ),
            ),
            constraints: const BoxConstraints(maxHeight: 340),
            clipBehavior: Clip.antiAlias,
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: AppColors.hairline),
              itemBuilder: (context, i) =>
                  _SuggestionTile(match: _suggestions[i], onTap: _pick),
            ),
          ),
        ],

        // What was chosen: where it sits, what it means, where to go instead,
        // and a one-tap save to the merchant's own list.
        if (_chosen != null && _suggestions.isEmpty) ...[
          const SizedBox(height: AppSizes.md),
          _ChosenSummary(
            match: _chosen!,
            productName: widget.productName.trim(),
            saved: _savedShortcut,
            onSave: _saveShortcut,
            onPickAlternative: (code) => widget.controller.text = code,
          ),
        ],
      ],
    );
  }
}

/// One row in the search results — breadcrumb above, then name, code and rate,
/// then the definition that lets a merchant confirm they picked right.
class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.match, required this.onTap});
  final HsnMatch match;
  final ValueChanged<HsnMatch> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onTap(match),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (match.breadcrumb.isNotEmpty)
              Text(
                match.breadcrumb.map((b) => '${b.code} · ${b.name}').join('  ›  '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.subtle),
              ),
            const SizedBox(height: AppSizes.xxs),
            Row(
              children: [
                if (match.fromShortcut) ...[
                  AppIcon(AppIcons.starRounded, size: AppSizes.iconSm, color: AppColors.brand),
                  const SizedBox(width: AppSizes.xs),
                ],
                Expanded(
                  child: Text(
                    match.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Text(
                  match.code,
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(width: AppSizes.sm),
                Text(
                  '${formatHsnRate(match.gstRate)}%',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            if (match.definition != null && match.definition!.isNotEmpty) ...[
              const SizedBox(height: AppSizes.xxs),
              Text(
                match.definition!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The confirmed code, with the cross-references that catch a wrong pick before
/// it gets saved and repeated forever.
class _ChosenSummary extends StatelessWidget {
  const _ChosenSummary({
    required this.match,
    required this.productName,
    required this.saved,
    required this.onSave,
    required this.onPickAlternative,
  });

  final HsnMatch match;
  final String productName;
  final bool saved;
  final VoidCallback onSave;
  final ValueChanged<String> onPickAlternative;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.field,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (match.breadcrumb.isNotEmpty)
            Text(
              match.breadcrumb.map((b) => '${b.code} · ${b.name}').join('  ›  '),
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.subtle),
            ),
          if (match.definition != null && match.definition!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.xs),
            Text(
              match.definition!,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
          if (match.notHere.isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            Text(
              l10n.productsHsnNotThis,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.subtle),
            ),
            const SizedBox(height: AppSizes.xs),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.xs,
              children: [
                for (final n in match.notHere)
                  ActionChip(
                    label: Text('${n.name} · ${n.code}'),
                    onPressed: () => onPickAlternative(n.code),
                  ),
              ],
            ),
          ],
          if (productName.isNotEmpty) ...[
            const SizedBox(height: AppSizes.sm),
            TextButton.icon(
              onPressed: saved ? null : onSave,
              icon: AppIcon(AppIcons.starRounded, size: AppSizes.iconSm),
              label: Text(
                saved
                    ? l10n.productsHsnSaved
                    : l10n.productsHsnSaveShortcut(productName),
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
