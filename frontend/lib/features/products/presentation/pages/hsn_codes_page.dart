import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/data/models/hsn_dto.dart';
import 'package:shopxy/features/products/presentation/widgets/hsn_code_field.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

/// "My HSN codes" — the merchant's own view of the two things they can save
/// against the shared tariff.
///
/// The product form asks *"save this as your code for X?"*, and without this
/// screen that was a one-way door: a saved shortcut silently won on every
/// future product with nowhere to see, correct, or remove it.
///
/// The two lists are deliberately different kinds of thing:
///
///  * **Saved codes** are classification only. They store no rate — the live
///    rate is joined on at read time — so they can never hold a merchant on a
///    slab the Council has since changed. Low stakes, freely editable.
///  * **Rate overrides** restate this shop's tax position on a code for the
///    whole catalogue. They need `shop:manage` (the backend enforces it),
///    demand a written reason, and delete softly, because they were the stated
///    basis for invoices already raised.
class HsnCodesPage extends StatefulWidget {
  const HsnCodesPage({super.key});

  @override
  State<HsnCodesPage> createState() => _HsnCodesPageState();
}

class _HsnCodesPageState extends State<HsnCodesPage> {
  List<HsnShortcut> _shortcuts = const [];
  List<HsnOverride> _overrides = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  ProductsRemoteDataSource get _ds => context.read<ProductsRemoteDataSource>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    // Overrides are fetched only when the role can see them: asking anyway
    // would 403 and turn a normal screen into an error for a cashier.
    final canSeeOverrides =
        context.read<AuthProvider>().user?.canView('shop') ?? false;
    setState(() => _loading = true);
    try {
      final shortcuts = await _ds.listHsnShortcuts();
      final overrides =
          canSeeOverrides ? await _ds.listHsnOverrides() : const <HsnOverride>[];
      if (!mounted) return;
      setState(() {
        _shortcuts = shortcuts;
        _overrides = overrides;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// `Exception: <text>` reads badly in a snackbar; the text alone is the
  /// backend's own message and is what the merchant needs.
  static String _message(Object e) =>
      e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

  /// Run a mutation, report it, and reload on success.
  Future<bool> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_message(e))),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().user;
    final canEditCodes = user?.canManage('products') ?? false;
    final canViewOverrides = user?.canView('shop') ?? false;
    final canEditOverrides = user?.canManage('shop') ?? false;
    final broken = _shortcuts.where((s) => s.needsAttention).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.hsnCodesTitle),
      body: _error != null
          ? _ErrorView(message: _error!, onRetry: _load, label: l10n.hsnRetry)
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.black,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.md + FloatingAppBar.contentTopInset(context),
                  AppSizes.lg,
                  AppSizes.xxl * 2,
                ),
                children: [
                  Text(l10n.hsnCodesSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                          )),
                  const SizedBox(height: AppSizes.xxl),

                  // ── Saved codes ──────────────────────────────────────────
                  _SectionHeading(title: l10n.hsnSavedHeading),
                  Text(l10n.hsnSavedBlurb,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          )),
                  if (broken > 0) ...[
                    const SizedBox(height: AppSizes.md),
                    _Banner(text: l10n.hsnSavedBrokenBanner(broken)),
                  ],
                  const SizedBox(height: AppSizes.md),
                  if (_loading && _shortcuts.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSizes.xxl),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_shortcuts.isEmpty)
                    EmptyState.line(
                      kind: LineArt.productTag,
                      title: l10n.hsnSavedEmptyTitle,
                      subtitle: l10n.hsnSavedEmptyHint,
                    )
                  else
                    for (final s in _shortcuts)
                      _ShortcutRow(
                        shortcut: s,
                        enabled: canEditCodes && !_busy,
                        onRepoint: () => _repoint(s),
                        onDelete: () =>
                            _run(() => _ds.deleteHsnShortcut(s.id)),
                      ),

                  // ── Rate overrides ───────────────────────────────────────
                  if (canViewOverrides) ...[
                    const SizedBox(height: AppSizes.xxl),
                    const Divider(height: 1),
                    const SizedBox(height: AppSizes.xxl),
                    _SectionHeading(
                      title: l10n.hsnOverridesHeading,
                      action: canEditOverrides
                          ? TextButton.icon(
                              onPressed: _busy ? null : _addOverride,
                              icon: const AppIcon(AppIcons.addRounded, size: 18),
                              label: Text(l10n.hsnOverridesAdd),
                            )
                          : null,
                    ),
                    Text(l10n.hsnOverridesBlurb,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            )),
                    const SizedBox(height: AppSizes.md),
                    if (_overrides.isEmpty)
                      Text(l10n.hsnOverridesEmpty,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.subtle,
                              ))
                    else
                      for (final o in _overrides)
                        _OverrideRow(
                          entry: o,
                          enabled: canEditOverrides && !_busy,
                          onDelete: () =>
                              _run(() => _ds.deleteHsnOverride(o.id)),
                        ),
                  ],
                ],
              ),
            ),
    );
  }

  /// Point a saved word at a different code. Saving is an upsert keyed on the
  /// merchant's own wording, so this moves the shortcut rather than duplicating
  /// it — and it is the only cure for `needsAttention`, because the successor
  /// to a retired code is a judgement call we must not make for them.
  Future<void> _repoint(HsnShortcut shortcut) async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.radiusDialog),
      builder: (_) => _CodePickerSheet(
        title: AppLocalizations.of(context).hsnRepointTitle(shortcut.label),
        blurb: AppLocalizations.of(context).hsnRepointBlurb,
        productName: shortcut.label,
        initialCode: shortcut.code,
        dataSource: _ds,
      ),
    );
    if (code == null || !mounted) return;
    await _run(() => _ds.saveHsnShortcut(label: shortcut.label, code: code));
  }

  Future<void> _addOverride() async {
    final result = await showModalBottomSheet<_OverrideDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.radiusDialog),
      builder: (_) => _OverrideSheet(dataSource: _ds),
    );
    if (result == null || !mounted) return;
    await _run(() => _ds.createHsnOverride(
          code: result.code,
          gstRate: result.gstRate,
          reason: result.reason,
        ));
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action});
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
              style: Theme.of(context).textTheme.titleMedium?.semibold),
        ),
        ?action,
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIcon(AppIcons.warningAmberRounded,
              size: 18, color: AppColors.warning),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.shortcut,
    required this.enabled,
    required this.onRepoint,
    required this.onDelete,
  });

  final HsnShortcut shortcut;
  final bool enabled;
  final VoidCallback onRepoint;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // The rate shown is joined live, never stored — so this is today's rate,
    // not the one that was in force when the shortcut was saved.
    final detail = [
      shortcut.code,
      ?shortcut.name,
      if (shortcut.gstRate != null) '${formatHsnRate(shortcut.gstRate!)}% GST',
      if (shortcut.useCount > 0) l10n.hsnSavedUsedCount(shortcut.useCount),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(shortcut.label,
                          style: theme.textTheme.bodyMedium?.semibold,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (shortcut.needsAttention) ...[
                      const SizedBox(width: AppSizes.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.sm, vertical: AppSizes.xxs),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius:
                              BorderRadius.circular(AppSizes.radiusFull),
                        ),
                        child: Text(l10n.hsnSavedBrokenBadge,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.warning)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(detail,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          TextButton(
            onPressed: enabled ? onRepoint : null,
            child: Text(l10n.hsnActionChangeCode),
          ),
          IconButton(
            onPressed: enabled ? onDelete : null,
            tooltip: l10n.hsnActionRemoveSaved,
            icon: const AppIcon(AppIcons.deleteOutline, size: 20),
          ),
        ],
      ),
    );
  }
}

class _OverrideRow extends StatelessWidget {
  const _OverrideRow({
    required this.entry,
    required this.enabled,
    required this.onDelete,
  });

  /// Not named `override` — a field of that name shadows Dart's `@override`
  /// annotation for the whole class body.
  final HsnOverride entry;
  final bool enabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.code} · ${formatHsnRate(entry.gstRate)}%',
                  style: theme.textTheme.bodyMedium?.semibold,
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(entry.reason,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted)),
                if (entry.effectiveFrom != null)
                  Text(
                    l10n.hsnOverridesEffectiveFrom(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(entry.effectiveFrom!),
                    ),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.subtle),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: enabled ? onDelete : null,
            tooltip: l10n.hsnActionRemoveOverride,
            icon: const AppIcon(AppIcons.deleteOutline, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.label,
  });
  final String message;
  final VoidCallback onRetry;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSizes.lg),
            OutlinedButton(onPressed: onRetry, child: Text(label)),
          ],
        ),
      ),
    );
  }
}

/// Pick a code, and refuse to hand one back that has no rate on file — that is
/// exactly what got a broken shortcut here in the first place.
class _CodePickerSheet extends StatefulWidget {
  const _CodePickerSheet({
    required this.title,
    required this.blurb,
    required this.productName,
    required this.initialCode,
    required this.dataSource,
  });

  final String title;
  final String blurb;
  final String productName;
  final String initialCode;
  final ProductsRemoteDataSource dataSource;

  @override
  State<_CodePickerSheet> createState() => _CodePickerSheetState();
}

class _CodePickerSheetState extends State<_CodePickerSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialCode);
  HsnResolution? _resolved;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _SheetShell(
      title: widget.title,
      children: [
        Text(widget.blurb,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted)),
        const SizedBox(height: AppSizes.lg),
        HsnCodeField(
          controller: _controller,
          dataSource: widget.dataSource,
          productName: widget.productName,
          onResolved: (hit) => setState(() => _resolved = hit),
        ),
        const SizedBox(height: AppSizes.xl),
        FilledButton(
          onPressed: _resolved == null
              ? null
              : () => Navigator.pop(context, _resolved!.requestedCode),
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}

class _OverrideDraft {
  const _OverrideDraft({
    required this.code,
    required this.gstRate,
    required this.reason,
  });
  final String code;
  final double gstRate;
  final String reason;
}

/// Record a rate override.
///
/// The platform rate for the chosen code is resolved and shown as they type, so
/// the sheet states the departure plainly — "we say 5%, you are saying 18%" —
/// rather than letting a number be entered against nothing.
class _OverrideSheet extends StatefulWidget {
  const _OverrideSheet({required this.dataSource});
  final ProductsRemoteDataSource dataSource;

  @override
  State<_OverrideSheet> createState() => _OverrideSheetState();
}

class _OverrideSheetState extends State<_OverrideSheet> {
  final _code = TextEditingController();
  final _rate = TextEditingController();
  final _reason = TextEditingController();
  HsnResolution? _resolved;

  @override
  void dispose() {
    _code.dispose();
    _rate.dispose();
    _reason.dispose();
    super.dispose();
  }

  double? get _parsedRate {
    final v = double.tryParse(_rate.text.trim());
    if (v == null || v < 0 || v > 100) return null;
    return v;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rate = _parsedRate;
    final diverges =
        rate != null && _resolved != null && rate != _resolved!.gstRate;
    final ready = _resolved != null && rate != null && _reason.text.trim().length >= 3;

    return _SheetShell(
      title: l10n.hsnOverridesDialogTitle,
      children: [
        Text(l10n.hsnOverridesDialogBlurb,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.muted)),
        const SizedBox(height: AppSizes.lg),
        HsnCodeField(
          controller: _code,
          dataSource: widget.dataSource,
          productName: '',
          onResolved: (hit) => setState(() => _resolved = hit),
        ),
        if (_resolved != null) ...[
          const SizedBox(height: AppSizes.sm),
          Text(
            l10n.hsnOverridesPlatformRate(
                _resolved!.code, formatHsnRate(_resolved!.gstRate)),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: AppColors.subtle),
          ),
        ],
        const SizedBox(height: AppSizes.lg),
        TextField(
          controller: _rate,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l10n.hsnOverridesRateLabel),
          onChanged: (_) => setState(() {}),
        ),
        if (diverges) ...[
          const SizedBox(height: AppSizes.md),
          _Banner(
            text: l10n.hsnOverridesDiverges(
              _resolved!.code,
              formatHsnRate(rate),
              formatHsnRate(_resolved!.gstRate),
            ),
          ),
        ],
        const SizedBox(height: AppSizes.lg),
        TextField(
          controller: _reason,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: l10n.hsnOverridesReasonLabel,
            helperText: l10n.hsnOverridesReasonHelper,
            helperMaxLines: 3,
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSizes.xl),
        FilledButton(
          onPressed: !ready
              ? null
              : () => Navigator.pop(
                    context,
                    _OverrideDraft(
                      code: _resolved!.requestedCode,
                      gstRate: rate,
                      reason: _reason.text.trim(),
                    ),
                  ),
          child: Text(l10n.hsnOverridesConfirm),
        ),
      ],
    );
  }
}

/// Scroll-safe sheet body: the keyboard inset is added to the padding so the
/// reason field stays visible while it is being typed into.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSizes.lg,
        right: AppSizes.lg,
        top: AppSizes.lg,
        bottom: AppSizes.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleMedium?.semibold),
            const SizedBox(height: AppSizes.md),
            ...children,
          ],
        ),
      ),
    );
  }
}
