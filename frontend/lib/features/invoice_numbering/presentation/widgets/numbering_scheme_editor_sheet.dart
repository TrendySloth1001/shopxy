import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/invoice_numbering/domain/entities/numbering_scheme.dart';
import 'package:shopxy/features/invoice_numbering/presentation/providers/invoice_numbering_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// GSTIN/PAN-style code — letters, digits, `-_.` only. The separator is its
/// own field, not something merchants embed inside prefix/suffix.
final _codeRegex = RegExp(r'^[A-Za-z0-9\-_.]*$');

const _separators = ['/', '-', '.', ''];

Future<void> showNumberingSchemeEditorSheet(
  BuildContext context,
  String title,
  NumberingScheme scheme,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
    ),
    builder: (_) => _NumberingSchemeEditorSheet(title: title, scheme: scheme),
  );
}

class _NumberingSchemeEditorSheet extends StatefulWidget {
  const _NumberingSchemeEditorSheet({required this.title, required this.scheme});
  final String title;
  final NumberingScheme scheme;

  @override
  State<_NumberingSchemeEditorSheet> createState() =>
      _NumberingSchemeEditorSheetState();
}

class _NumberingSchemeEditorSheetState
    extends State<_NumberingSchemeEditorSheet> {
  late final TextEditingController _prefix;
  late final TextEditingController _suffix;
  late final TextEditingController _padding;
  late String _separator;
  late bool _resetYearly;
  bool _busy = false;
  String? _error;

  bool _showStartAt = false;
  final _startAt = TextEditingController();
  bool _startAtBusy = false;
  String? _startAtError;

  @override
  void initState() {
    super.initState();
    final s = widget.scheme;
    _prefix = TextEditingController(text: s.prefix);
    _suffix = TextEditingController(text: s.suffix);
    _padding = TextEditingController(text: s.padding.toString());
    _separator = s.separator;
    _resetYearly = s.resetYearly;
    for (final c in [_prefix, _suffix, _padding]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _prefix.dispose();
    _suffix.dispose();
    _padding.dispose();
    _startAt.dispose();
    super.dispose();
  }

  int get _paddingValue => int.tryParse(_padding.text) ?? widget.scheme.padding;

  String get _preview => formatDocNoPreview(
    prefix: _prefix.text,
    suffix: _suffix.text,
    separator: _separator,
    padding: _paddingValue.clamp(1, 8),
    resetYearly: _resetYearly,
    seq: widget.scheme.nextSeq,
    financialYear: widget.scheme.financialYear,
  );

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _error = null);
    final prefix = _prefix.text.trim();
    final suffix = _suffix.text.trim();
    final padding = int.tryParse(_padding.text.trim());
    if (prefix.length > 10 ||
        !_codeRegex.hasMatch(prefix) ||
        suffix.length > 10 ||
        !_codeRegex.hasMatch(suffix) ||
        padding == null ||
        padding < 1 ||
        padding > 8) {
      setState(() => _error = l10n.numberingErrorInvalid);
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<InvoiceNumberingProvider>().save(
        widget.scheme.series,
        {
          'prefix': prefix,
          'suffix': suffix,
          'separator': _separator,
          'padding': padding,
          'resetYearly': _resetYearly,
        },
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
      });
    }
  }

  Future<void> _setStartAt() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _startAtError = null);
    final n = int.tryParse(_startAt.text.trim());
    if (n == null || n <= 0) {
      setState(() => _startAtError = l10n.numberingErrorInvalidStartAt);
      return;
    }
    setState(() => _startAtBusy = true);
    try {
      await context.read<InvoiceNumberingProvider>().setNextNumber(
        widget.scheme.series,
        n,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _startAtBusy = false;
        _startAtError = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: AppSizes.lg,
          right: AppSizes.lg,
          top: AppSizes.md,
          bottom: AppSizes.lg + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: AppSizes.handleHeight,
                decoration: ShapeDecoration(
                  color: AppColors.hairline,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(
              widget.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.sm,
              ),
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.numberingPreviewLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xxs),
                  Text(
                    _preview,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.sm),
              Text(_error!, style: TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _prefix,
                    maxLength: 10,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l10n.numberingFieldPrefix,
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextField(
                    controller: _suffix,
                    maxLength: 10,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l10n.numberingFieldSuffix,
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              l10n.numberingFieldSeparator,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Wrap(
              spacing: AppSizes.sm,
              children: [
                for (final sep in _separators)
                  ChoiceChip(
                    label: Text(sep.isEmpty ? l10n.numberingFieldSeparatorNone : sep),
                    selected: _separator == sep,
                    onSelected: (_) => setState(() => _separator = sep),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            SizedBox(
              width: 120,
              child: TextField(
                controller: _padding,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.numberingFieldPadding),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              l10n.numberingFieldResetYearly,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Wrap(
              spacing: AppSizes.sm,
              children: [
                ChoiceChip(
                  label: Text(l10n.numberingResetYearlyOn),
                  selected: _resetYearly,
                  onSelected: (_) => setState(() => _resetYearly = true),
                ),
                ChoiceChip(
                  label: Text(l10n.numberingResetYearlyOff),
                  selected: !_resetYearly,
                  onSelected: (_) => setState(() => _resetYearly = false),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              l10n.numberingResetYearlyHelper,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.lg),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inverseSurface,
                foregroundColor: AppColors.onInverse,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              ),
              child: _busy
                  ? SizedBox(
                      height: AppSizes.xl,
                      width: AppSizes.xl,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onInverse,
                      ),
                    )
                  : Text(l10n.profileSave),
            ),
            const SizedBox(height: AppSizes.lg),
            const Divider(),
            const SizedBox(height: AppSizes.sm),
            InkWell(
              onTap: () => setState(() => _showStartAt = !_showStartAt),
              child: Row(
                children: [
                  AppIcon(
                    AppIcons.restoreRounded,
                    size: AppSizes.iconSm,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      l10n.numberingStartAtToggle,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_showStartAt) ...[
              const SizedBox(height: AppSizes.sm),
              Container(
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: ShapeDecoration(
                  color: AppColors.surface,
                  shape: AppShapes.squircle(
                    AppSizes.radiusMd,
                    side: BorderSide(color: AppColors.hairline),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.numberingStartAtHelper,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    if (_startAtError != null) ...[
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        _startAtError!,
                        style: TextStyle(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startAt,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: l10n.numberingStartAtLabel,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.sm),
                        FilledButton(
                          onPressed: _startAtBusy ? null : _setStartAt,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.inverseSurface,
                            foregroundColor: AppColors.onInverse,
                          ),
                          child: Text(
                            _startAtBusy ? '…' : l10n.numberingStartAtConfirm,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
