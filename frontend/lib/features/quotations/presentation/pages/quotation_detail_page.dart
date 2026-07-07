import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shopxy/features/quotations/data/datasources/quotations_remote_data_source.dart';
import 'package:shopxy/features/quotations/domain/entities/quotation.dart';
import 'package:shopxy/features/quotations/presentation/pages/create_quotation_page.dart';
import 'package:shopxy/features/quotations/presentation/providers/quotations_provider.dart';
import 'package:shopxy/features/quotations/presentation/widgets/quote_line_thumb.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Merchant-side quotation detail: who it went to, status, line items, totals,
/// the invoice it spawned (if accepted), and a Cancel action while pending.
class QuotationDetailPage extends StatefulWidget {
  const QuotationDetailPage({super.key, required this.quotation});
  final Quotation quotation;

  @override
  State<QuotationDetailPage> createState() => _QuotationDetailPageState();
}

class _QuotationDetailPageState extends State<QuotationDetailPage> {
  final _currency = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final _dateFmt = DateFormat('d MMM y');
  late Quotation _q = widget.quotation;
  bool _busy = false;
  bool _downloading = false;

  Future<void> _sharePdf() async {
    setState(() => _downloading = true);
    final messenger = ScaffoldMessenger.of(context);
    final ds = context.read<QuotationsRemoteDataSource>();
    final filename = 'quotation-${_q.quotationNo.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_')}.pdf';
    try {
      final response = await ds.downloadPdf(_q.id);
      if (response.statusCode != 200) throw Exception('Failed to generate PDF');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
          text: 'Quotation ${_q.quotationNo}',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<QuotationsProvider>().cancel(_q.id);
      if (!mounted) return;
      setState(() {
        _busy = false;
        // Reflect the new status locally without refetching.
        _q = Quotation(
          id: _q.id,
          quotationNo: _q.quotationNo,
          status: 'CANCELLED',
          partyName: _q.partyName,
          subtotal: _q.subtotal,
          taxAmount: _q.taxAmount,
          total: _q.total,
          items: _q.items,
          createdAt: _q.createdAt,
          note: _q.note,
          declineNote: _q.declineNote,
          invoiceId: _q.invoiceId,
          invoiceNo: _q.invoiceNo,
        );
      });
      messenger.showSnackBar(
        SnackBar(content: Text('${_q.quotationNo} cancelled')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  /// Price the request in the builder; on success pop back to the list (which
  /// reloads), so the now-PENDING quote shows its new state.
  Future<void> _priceAndSend() async {
    final navigator = Navigator.of(context);
    final sent = await navigator.push<bool>(
      MaterialPageRoute(builder: (_) => CreateQuotationPage.respondTo(_q)),
    );
    if (sent == true && mounted) navigator.pop();
  }

  Future<void> _decline() async {
    final provider = context.read<QuotationsProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final ctrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline request'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            hintText: 'Shown to the customer',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Back')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (note == null) return;
    setState(() => _busy = true);
    try {
      await provider.declineRequest(_q.id,
          declineNote: note.isEmpty ? null : note);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _q = Quotation(
          id: _q.id,
          quotationNo: _q.quotationNo,
          status: 'DECLINED',
          partyName: _q.partyName,
          subtotal: _q.subtotal,
          taxAmount: _q.taxAmount,
          total: _q.total,
          items: _q.items,
          createdAt: _q.createdAt,
          note: _q.note,
          declineNote: note.isEmpty ? null : note,
          invoiceId: _q.invoiceId,
          invoiceNo: _q.invoiceNo,
        );
      });
      messenger.showSnackBar(const SnackBar(content: Text('Request declined')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  (Color, Color, String) _style(String status) {
    switch (status) {
      case 'REQUESTED':
        return (AppColors.brand, AppColors.brandSoft, 'New request');
      case 'PENDING':
        return (AppColors.warning, AppColors.warningSoft, 'Awaiting customer');
      case 'ACCEPTED':
        return (AppColors.success, AppColors.successSoft, 'Accepted');
      case 'DECLINED':
        return (AppColors.error, AppColors.errorSoft, 'Declined');
      case 'CANCELLED':
        return (AppColors.muted, AppColors.heroPanel, 'Cancelled');
      default:
        return (AppColors.muted, AppColors.heroPanel, status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (fg, _, label) = _style(_q.status);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: _q.quotationNo,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.sm),
            child: ActionChip(
              onPressed: _downloading ? null : _sharePdf,
              tooltip: 'Download or share this quote as PDF',
              backgroundColor: AppColors.tileBg(AppColors.brandSoft),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              avatar: _downloading
                  ? const SizedBox(
                      width: AppSizes.iconSm,
                      height: AppSizes.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.share_rounded,
                      size: AppSizes.iconSm, color: AppColors.brand),
              label: Text('Share',
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.brand, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.lg + FloatingAppBar.contentTopInset(context),
          AppSizes.lg,
          AppSizes.lg,
        ),
        children: [
          // Status + meta — flat, no box.
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: fg, fontWeight: FontWeight.w800)),
              const SizedBox(height: AppSizes.xs),
              Text(
                  _q.isRequested
                      ? 'From ${_q.partyName} · requested ${_dateFmt.format(_q.createdAt)}'
                      : 'To ${_q.partyName} · sent ${_dateFmt.format(_q.createdAt)}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted)),
              if (_q.status == 'ACCEPTED' && _q.invoiceNo != null) ...[
                const SizedBox(height: AppSizes.xs),
                Text('Invoice ${_q.invoiceNo} created',
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700)),
              ],
              if (_q.status == 'DECLINED' && _q.declineNote != null) ...[
                const SizedBox(height: AppSizes.xs),
                Text('Reason: ${_q.declineNote}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted)),
              ],
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          const AppDivider.flush(),
          const SizedBox(height: AppSizes.lg),
          _Label('Items (${_q.items.length})'),
          const SizedBox(height: AppSizes.xs),
          for (int i = 0; i < _q.items.length; i++) ...[
            if (i > 0) const AppDivider.flush(),
            _ItemRow(line: _q.items[i], currency: _currency),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: AppDivider.flush(),
          ),
          _totalRow('Subtotal', _currency.format(_q.subtotal), theme),
          _totalRow('GST', _currency.format(_q.taxAmount), theme),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
            child: AppDivider.flush(),
          ),
          _totalRow('Total', _currency.format(_q.total), theme, bold: true),
          if (_q.note != null && _q.note!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.lg),
            _Label(_q.isRequested ? "Customer's note" : 'Note'),
            const SizedBox(height: AppSizes.xs),
            Text(_q.note!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
      bottomNavigationBar: _q.isRequested
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : _decline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: BorderSide(color: AppColors.error),
                          padding:
                              const EdgeInsets.symmetric(vertical: AppSizes.lg),
                        ),
                        child: const Text('Decline'),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: _busy ? null : _priceAndSend,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          padding:
                              const EdgeInsets.symmetric(vertical: AppSizes.lg),
                        ),
                        child: Text('Price & send',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _q.isPending
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _cancel,
                    icon: _busy
                        ? const SizedBox(
                            width: AppSizes.iconSm,
                            height: AppSizes.iconSm,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.close_rounded, size: AppSizes.iconMd),
                    label: const Text('Cancel quotation'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSizes.lg),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _totalRow(String label, String value, ThemeData theme,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: bold ? null : AppColors.muted,
                  fontWeight: bold ? FontWeight.w800 : null)),
          Text(value,
              style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.line, required this.currency});
  final QuotationLine line;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qtyStr = line.quantity == line.quantity.roundToDouble()
        ? line.quantity.toStringAsFixed(0)
        : line.quantity.toStringAsFixed(2);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: Row(
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSizes.xs),
                Text(
                  '$qtyStr × ${currency.format(line.unitPrice)}'
                  '${line.taxPercent > 0 ? ' · ${line.taxPercent.toStringAsFixed(0)}% GST' : ''}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(currency.format(line.lineTotal),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.label);
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
