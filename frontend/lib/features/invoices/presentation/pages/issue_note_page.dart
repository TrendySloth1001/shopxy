import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_filter_pill.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class IssueNotePage extends StatefulWidget {
  const IssueNotePage({super.key, required this.invoice});

  final Invoice invoice;

  @override
  State<IssueNotePage> createState() => _IssueNotePageState();
}

class _NoteLineDraft {
  _NoteLineDraft(this.item)
    : include = false,
      qtyCtrl = TextEditingController(text: _trimQty(item.quantity)),
      priceCtrl = TextEditingController();

  final InvoiceItem item;
  bool include;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }

  static String _trimQty(double q) =>
      q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
}

class _IssueNotePageState extends State<IssueNotePage> {
  String _docType = 'CREDIT_NOTE';
  bool _restock = true;
  bool _submitting = false;
  final _reasonCtrl = TextEditingController();
  late final List<_NoteLineDraft> _lines = widget.invoice.items
      .map(_NoteLineDraft.new)
      .toList();

  bool get _isCredit => _docType == 'CREDIT_NOTE';

  @override
  void dispose() {
    _reasonCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  double get _approxTotal {
    var total = 0.0;
    for (final l in _lines) {
      if (!l.include) continue;
      final qty = double.tryParse(l.qtyCtrl.text.trim()) ?? 0;
      if (qty <= 0) continue;
      final unit = _isCredit
          ? l.item.unitPrice
          : (double.tryParse(l.priceCtrl.text.trim()) ?? 0);
      final line = qty * unit;
      total += line + line * l.item.taxPercent / 100;
    }
    return total;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final lines = <Map<String, dynamic>>[];
    for (final l in _lines) {
      if (!l.include) continue;
      final qty = double.tryParse(l.qtyCtrl.text.trim()) ?? 0;
      if (qty <= 0) continue;
      lines.add({
        'productId': l.item.productId,
        'quantity': qty,
        if (!_isCredit)
          'unitPrice': double.tryParse(l.priceCtrl.text.trim()) ?? 0,
      });
    }
    if (lines.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.invoicesNoteSelectLines)),
      );
      return;
    }

    setState(() => _submitting = true);
    final ds = context.read<InvoicesRemoteDataSource>();
    final invoicesProvider = context.read<InvoicesProvider>();
    try {
      final note = await ds.issueNote(
        widget.invoice.id,
        documentType: _docType,
        reason: _reasonCtrl.text.trim(),
        restock: _isCredit ? _restock : null,
        lines: lines,
      );
      invoicesProvider.loadInvoices(refresh: true);
      navigator.pop(true);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.invoicesNoteIssued(note.invoiceNo))),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.invoicesIssueNoteTitle),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          FloatingAppBar.contentTopInset(context) + AppSizes.sm,
          AppSizes.lg,
          AppSizes.huge * 2,
        ),
        children: [
          Text(
            l10n.invoicesNoteAgainst(widget.invoice.invoiceNo),
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSizes.md),
          Wrap(
            spacing: AppSizes.sm,
            children: [
              AppFilterPill(
                label: l10n.invoicesDocCreditNote,
                selected: _isCredit,
                onTap: () => setState(() => _docType = 'CREDIT_NOTE'),
              ),
              AppFilterPill(
                label: l10n.invoicesDocDebitNote,
                selected: !_isCredit,
                onTap: () => setState(() => _docType = 'DEBIT_NOTE'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(
            _isCredit
                ? l10n.invoicesCreditNoteExplainer
                : l10n.invoicesDebitNoteExplainer,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSizes.lg),
          AppSectionHeader(
            title: l10n.invoicesInvoiceItems.toUpperCase(),
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
          ),
          for (final line in _lines) _buildLineCard(line, theme, l10n),
          const SizedBox(height: AppSizes.md),
          if (_isCredit) ...[
            Material(
              color: AppColors.surface,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                side: BorderSide(color: AppColors.hairline),
              ),
              child: SwitchListTile.adaptive(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: AppSizes.xs,
                ),
                value: _restock,
                onChanged: (v) => setState(() => _restock = v),
                title: Text(l10n.invoicesNoteReturnToStock),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
          ],
          TextFormField(
            controller: _reasonCtrl,
            decoration: InputDecoration(labelText: l10n.invoicesNoteReason),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
          ),
          const SizedBox(height: AppSizes.lg),
          Text(
            l10n.invoicesNoteApproxTotal(
              '${AppStrings.currencySymbol}${_approxTotal.toStringAsFixed(2)}',
            ),
            style: theme.textTheme.titleMedium?.bold,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.sm,
            AppSizes.lg,
            AppSizes.md,
          ),
          child: SizedBox(
            height: AppSizes.huge,
            child: AppButton.primary(
              label: _isCredit
                  ? l10n.invoicesIssueCreditNote
                  : l10n.invoicesIssueDebitNote,
              onPressed: _submitting ? null : _submit,
              isLoading: _submitting,
              fullWidth: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLineCard(
    _NoteLineDraft line,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    final item = line.item;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Material(
        color: line.include ? AppColors.surface : AppColors.surfaceTint,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          side: BorderSide(
            color: line.include ? AppColors.brand : AppColors.hairline,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => line.include = !line.include),
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Row(
                  children: [
                    Checkbox(
                      value: line.include,
                      onChanged: (v) =>
                          setState(() => line.include = v ?? false),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: theme.textTheme.bodyMedium?.semibold,
                          ),
                          const SizedBox(height: AppSizes.xxs),
                          Text(
                            '${l10n.invoicesNoteSoldQty(_NoteLineDraft._trimQty(item.quantity))}'
                            ' · ${AppStrings.currencySymbol}${item.unitPrice.toStringAsFixed(2)}'
                            '${item.taxPercent > 0 ? ' · ${item.taxPercent.toStringAsFixed(0)}% GST' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (line.include)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.md,
                  0,
                  AppSizes.md,
                  AppSizes.md,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: TextFormField(
                        controller: line.qtyCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.invoicesQuantity,
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    if (!_isCredit) ...[
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: TextFormField(
                          controller: line.priceCtrl,
                          decoration: InputDecoration(
                            labelText: l10n.invoicesNoteExtraPerUnit,
                            prefixText: AppStrings.currencySymbol,
                            isDense: true,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
