import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/payments/presentation/widgets/record_payment_sheet.dart';
import 'package:shopxy/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:shopxy/features/payments/domain/entities/payment.dart';
import 'package:shopxy/features/invoices/presentation/pages/create_invoice_page.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/glass_widgets.dart';

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});
  final int invoiceId;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  Invoice? _invoice;
  bool _isLoading = true;
  bool _isDownloading = false;
  // Receipts recorded against this invoice (cash/UPI recorded by the merchant
  // AND platform-collected online/wallet receipts reconciled by the backend).
  // Drives the paid/outstanding summary + the payments list.
  List<Payment> _payments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Capture both data sources synchronously, before any await, so we never
    // touch `context` across an async gap.
    final ds = context.read<InvoicesRemoteDataSource>();
    final paymentsDs = context.read<PaymentsRemoteDataSource>();
    try {
      final invoice = await ds.getInvoiceById(widget.invoiceId);
      // Payments received against this invoice. Best-effort: a failure here
      // must not blank the invoice — fall back to an empty list so the page
      // still renders (the paid/outstanding summary just won't show).
      List<Payment> payments = const [];
      try {
        payments = await paymentsDs.listPayments(invoiceId: widget.invoiceId);
      } catch (_) {
        payments = const [];
      }
      if (mounted) {
        setState(() {
          _invoice = invoice;
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Sum of receipts recorded against this invoice.
  double get _paidTotal =>
      _payments.fold<double>(0, (sum, p) => sum + p.amount);

  /// Invoice total minus what's been received, floored at 0.
  double _outstanding(Invoice invoice) {
    final out = invoice.total - _paidTotal;
    return out > 0 ? out : 0;
  }

  /// Human label for a receipt's channel. Platform-collected receipts (online
  /// gateway / wallet) use mode OTHER; their note distinguishes which.
  String _paymentModeLabel(Payment p) {
    switch (p.mode) {
      case 'OTHER':
        return p.note ?? 'Online';
      case 'CASH':
        return 'Cash';
      case 'UPI':
        return 'UPI';
      case 'NEFT':
        return 'NEFT';
      case 'RTGS':
        return 'RTGS';
      case 'CHEQUE':
        return 'Cheque';
      case 'CARD':
        return 'Card';
      default:
        return p.mode;
    }
  }

  Future<void> _downloadPdf() async {
    if (_invoice == null) return;
    setState(() => _isDownloading = true);
    final filename = _safePdfFilename(_invoice!.invoiceNo);
    final ds = context.read<InvoicesRemoteDataSource>();
    try {
      final response = await ds.downloadPdf(widget.invoiceId);
      if (response.statusCode != 200) {
        throw Exception('Failed to generate PDF');
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// Invoice numbers can contain `/` (e.g. `PUR/26-27/00001`). Using
  /// that raw as a filename makes Dart try to create nested directories
  /// that don't exist — `PathNotFoundException`. Strip / replace anything
  /// the host filesystem might choke on.
  static String _safePdfFilename(String invoiceNo) {
    final sanitized = invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$sanitized.pdf';
  }

  /// Downloads the PDF to the temp dir and pops the native share sheet.
  /// WhatsApp appears as a share target on both Android and iOS, so users
  /// effectively get a one-tap WhatsApp share — same flow handles email,
  /// Drive, etc. without extra integration code.
  Future<void> _sharePdf() async {
    if (_invoice == null) return;
    setState(() => _isDownloading = true);
    final invoiceNo = _invoice!.invoiceNo;
    final filename = _safePdfFilename(invoiceNo);
    final ds = context.read<InvoicesRemoteDataSource>();
    try {
      final response = await ds.downloadPdf(widget.invoiceId);
      if (response.statusCode != 200) {
        throw Exception('Failed to generate PDF');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response.bodyBytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Invoice $invoiceNo',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// Open WhatsApp pre-filled with an invoice summary. If the invoice has
  /// a customer phone we deep-link to that chat directly; otherwise we
  /// fall back to the picker (`wa.me/?text=...`).
  Future<void> _shareViaWhatsApp() async {
    final invoice = _invoice;
    if (invoice == null) return;
    final text =
        'Invoice ${invoice.invoiceNo} — Total ${AppStrings.currencySymbol}${invoice.total.toStringAsFixed(2)}';
    final encoded = Uri.encodeComponent(text);
    final phone = _normalizeIndianPhone(invoice.customerPhone);
    final uri = phone != null
        ? Uri.parse('https://wa.me/$phone?text=$encoded')
        : Uri.parse('https://wa.me/?text=$encoded');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp')),
      );
    }
  }

  /// Strip non-digits and ensure a 91 (India) country prefix. Returns null
  /// when we can't make sense of the input — caller falls back to the
  /// generic WhatsApp share link.
  static String? _normalizeIndianPhone(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('91') && digits.length >= 12) return digits;
    if (digits.length == 10) return '91$digits';
    // Already has some other country code — trust the caller.
    if (digits.length >= 11) return digits;
    return null;
  }

  /// Convert this estimate/proforma into a real tax invoice. The backend
  /// mints a fresh invoice (new id, INV-prefixed number) from the source's
  /// items; we navigate to its detail page so the user can confirm/print.
  Future<void> _convertToInvoice() async {
    final invoice = _invoice;
    if (invoice == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Invoice?'),
        content: Text(
          'A new tax invoice will be created from ${invoice.invoiceNo}. '
          'The estimate stays on file unchanged.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Convert'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDownloading = true);
    final ds = context.read<InvoicesRemoteDataSource>();
    final invoicesProvider = context.read<InvoicesProvider>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final created = await ds.convertEstimate(invoice.id);
      // Refresh the parent list so the new INV row appears immediately.
      invoicesProvider.loadInvoices(refresh: true);
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => InvoiceDetailPage(invoiceId: created.id),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  /// Open the create form in edit mode for a DRAFT invoice. Once the user
  /// saves we reload the detail (totals + line items may have changed),
  /// so the page reflects the new state without a stale snapshot.
  Future<void> _openEdit() async {
    final invoice = _invoice;
    if (invoice == null || !invoice.isDraft) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateInvoicePage(existing: invoice),
      ),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _updateStatus(String status) async {
    final provider = context.read<InvoicesProvider>();
    try {
      final updated = await provider.updateStatus(widget.invoiceId, status);
      if (mounted) setState(() => _invoice = updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Cancelling a draft is destructive — it reverses any stock movement
  /// the draft would have posted on confirm. Gate it behind a dialog
  /// because the bottom bar puts the action one tap away.
  Future<void> _confirmAndCancel() async {
    final invoice = _invoice;
    if (invoice == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.cancelInvoice),
        content: Text(
          'Cancel ${invoice.invoiceNo}? No stock will be moved and the '
          'invoice will be marked as cancelled.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep draft'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(AppStrings.cancelInvoice),
          ),
        ],
      ),
    );
    if (ok == true) await _updateStatus('CANCELLED');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_invoice == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text(AppStrings.error)),
      );
    }

    final invoice = _invoice!;
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: Text(invoice.invoiceNo),
        actions: [
          if (!_isDownloading) ...[
            if (invoice.isDraft)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: _openEdit,
              ),
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share',
              onPressed: _sharePdf,
            ),
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: AppStrings.downloadInvoice,
              onPressed: _downloadPdf,
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(AppSizes.md),
              child: SizedBox(
                width: AppSizes.iconMd,
                height: AppSizes.iconMd,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          // Draft actions (Confirm / Cancel) live in the sticky bottom
          // bar so they're impossible to miss. The overflow menu is kept
          // for the only remaining secondary action: hard-delete a
          // not-yet-confirmed invoice.
          if (!invoice.isConfirmed)
            PopupMenuButton<String>(
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(AppStrings.delete),
                ),
              ],
              onSelected: (v) async {
                if (v == 'delete') {
                  await context
                      .read<InvoicesProvider>()
                      .deleteInvoice(invoice.id);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
      bottomNavigationBar: invoice.isDraft ? _buildDraftActionBar() : null,
      body: Column(
        children: [
          GlassHero.line(
            kind: LineArt.invoice,
            height: 180,
            illustrationSize: AppSizes.productImageSize,
            accent: invoice.isCancelled ? AppColors.error : AppColors.brand,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.lg),
              children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoice.invoiceNo,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AppStatusBadge(
                      label: invoice.status,
                      tone: _statusTone(invoice.status),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Wrap(
                  spacing: AppSizes.xs,
                  runSpacing: AppSizes.xs,
                  children: [
                    AppStatusBadge(
                      label: _documentTypeLabel(invoice.documentType),
                      tone: AppStatusTone.neutral,
                      dense: true,
                    ),
                    AppStatusBadge(
                      label: invoice.isInterstate ? 'IGST' : 'CGST+SGST',
                      tone: AppStatusTone.neutral,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  invoice.isSale
                      ? AppStrings.saleInvoice
                      : AppStrings.purchaseInvoice,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                Text(
                  df.format(invoice.invoiceDate),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                _InfoRow(
                  label: invoice.isSale
                      ? AppStrings.customer
                      : AppStrings.vendor,
                  value: invoice.partyName,
                ),
                if (invoice.isSale) ...[
                  if (invoice.customerPhone != null)
                    _InfoRow(
                      label: AppStrings.phone,
                      value: invoice.customerPhone!,
                    ),
                  if (invoice.customerGstin != null)
                    _InfoRow(
                      label: AppStrings.gstin,
                      value: invoice.customerGstin!,
                    ),
                  if (invoice.customerPanNumber != null)
                    _InfoRow(
                      label: 'PAN',
                      value: invoice.customerPanNumber!,
                    ),
                  if (_addressLine(
                    invoice.customerAddress,
                    invoice.customerCity,
                    invoice.customerState,
                    invoice.customerPinCode,
                  )
                      .isNotEmpty)
                    _InfoRow(
                      label: AppStrings.address,
                      value: _addressLine(
                        invoice.customerAddress,
                        invoice.customerCity,
                        invoice.customerState,
                        invoice.customerPinCode,
                      ),
                    ),
                ] else ...[
                  if (invoice.vendor?.name != null)
                    _InfoRow(
                      label: AppStrings.vendor,
                      value: invoice.vendor!.name,
                    ),
                  if (invoice.vendorGstin != null)
                    _InfoRow(
                      label: AppStrings.gstin,
                      value: invoice.vendorGstin!,
                    ),
                  if (_addressLine(
                    invoice.vendorAddress,
                    invoice.vendorCity,
                    invoice.vendorState,
                    invoice.vendorPinCode,
                  )
                      .isNotEmpty)
                    _InfoRow(
                      label: AppStrings.address,
                      value: _addressLine(
                        invoice.vendorAddress,
                        invoice.vendorCity,
                        invoice.vendorState,
                        invoice.vendorPinCode,
                      ),
                    ),
                ],
              ],
            ),
          const SizedBox(height: AppSizes.lg),
          const AppDivider.flush(),
          const SizedBox(height: AppSizes.lg),
          AppSectionHeader(
            title: AppStrings.invoiceItems.toUpperCase(),
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
          ),
          const AppDivider.flush(),
          for (int i = 0; i < invoice.items.length; i++) ...[
            if (i > 0) const AppDivider.flush(),
            _ItemTile(item: invoice.items[i]),
          ],
          const SizedBox(height: AppSizes.md),
          const AppDivider.flush(),
          const SizedBox(height: AppSizes.md),
          Column(
            children: [
                _TotalRow(label: AppStrings.subtotal, value: invoice.subtotal),
                // GST split mirrors how the invoice was saved. For older
                // rows without the split (igst/cgst/sgst all 0) we fall
                // back to the single taxAmount column.
                if (invoice.igstAmount == 0 &&
                    invoice.cgstAmount == 0 &&
                    invoice.sgstAmount == 0)
                  _TotalRow(label: AppStrings.taxAmount, value: invoice.taxAmount)
                else if (invoice.isInterstate)
                  _TotalRow(label: 'IGST', value: invoice.igstAmount)
                else ...[
                  _TotalRow(label: 'CGST', value: invoice.cgstAmount),
                  _TotalRow(label: 'SGST', value: invoice.sgstAmount),
                ],
                if (invoice.cessAmount > 0)
                  _TotalRow(label: 'Cess', value: invoice.cessAmount),
                if (invoice.discount > 0)
                  _TotalRow(label: AppStrings.discount, value: -invoice.discount),
                if (invoice.roundOff != 0)
                  _TotalRow(label: 'Round-off', value: invoice.roundOff),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                  child: AppDivider.flush(),
                ),
                _TotalRow(
                  label: AppStrings.total,
                  value: invoice.total,
                  isHighlight: true,
                ),
                // Payments received against this invoice — covers ALL channels:
                // cash/UPI recorded by the merchant AND online/wallet receipts
                // the backend reconciles from a customer's order payment. Shown
                // only once the invoice is a live liability (CONFIRMED).
                if (invoice.status == 'CONFIRMED') ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                    child: AppDivider.flush(),
                  ),
                  _TotalRow(label: 'Received', value: _paidTotal),
                  _TotalRow(
                    label: 'Outstanding',
                    value: _outstanding(invoice),
                    isHighlight: true,
                  ),
                  if (_payments.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.xs),
                    for (final p in _payments)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _paymentModeLabel(p),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${p.referenceNo} · ${df.format(p.paymentDate)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${AppStrings.currencySymbol}${p.amount.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
                // Payments received against this invoice — covers ALL channels:
                // cash/UPI recorded by the merchant AND online/wallet receipts
                // the backend reconciles from a customer's order payment. Shown
                // only once the invoice is a live liability (CONFIRMED).
                if (invoice.status == 'CONFIRMED') ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                    child: AppDivider.flush(),
                  ),
                  _TotalRow(label: 'Received', value: _paidTotal),
                  _TotalRow(
                    label: 'Outstanding',
                    value: _outstanding(invoice),
                    isHighlight: true,
                  ),
                  if (_payments.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.xs),
                    for (final p in _payments)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _paymentModeLabel(p),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${p.referenceNo} · ${df.format(p.paymentDate)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${AppStrings.currencySymbol}${p.amount.toStringAsFixed(2)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
                if (invoice.amountInWords != null &&
                    invoice.amountInWords!.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      invoice.amountInWords!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          const SizedBox(height: AppSizes.md),
          const AppDivider.flush(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.chat_rounded,
              color: AppColors.whatsapp,
            ),
            title: const Text('Send via WhatsApp'),
            subtitle: Text(
              invoice.customerPhone != null && invoice.customerPhone!.isNotEmpty
                  ? 'Opens chat with ${invoice.customerPhone}'
                  : 'Pick a chat to send to',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _shareViaWhatsApp,
          ),
          // Estimates / proformas get a one-tap "Convert to Invoice" tile.
          // Hidden once the source is cancelled — converting a cancelled
          // quotation makes no business sense and the backend would reject
          // it anyway.
          if ((invoice.documentType == 'ESTIMATE' ||
                  invoice.documentType == 'PROFORMA') &&
              invoice.status != 'CANCELLED') ...[
            const AppDivider.flush(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.brand,
              ),
              title: const Text('Convert to Invoice'),
              subtitle: Text(
                'Create a tax invoice from this estimate',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _isDownloading ? null : _convertToInvoice,
            ),
          ],
          if (invoice.status == 'CONFIRMED' &&
              (invoice.partyId != null || invoice.vendorId != null) &&
              _outstanding(invoice) > 0.005) ...[
            const AppDivider.flush(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.check_circle_outline_rounded,
                color: AppColors.success,
              ),
              title: const Text('Mark as Paid'),
              subtitle: Text(
                invoice.type == 'SALE'
                    ? 'Record a receipt for this invoice'
                    : 'Record a payment for this bill',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final isSale = invoice.type == 'SALE';
                final created = await RecordPaymentSheet.show(
                  context,
                  type: isSale ? 'RECEIPT' : 'PAYMENT',
                  partyId: isSale ? invoice.partyId : null,
                  vendorId: isSale ? null : invoice.vendorId,
                  partyName: invoice.customerName,
                  vendorName: invoice.vendorName,
                  initialAmount: invoice.total,
                  lockedInvoiceId: invoice.id,
                  lockedInvoiceLabel: invoice.invoiceNo,
                );
                if (!context.mounted) return;
                if (created != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Payment recorded')),
                  );
                }
              },
            ),
          ],
          if (invoice.note != null && invoice.note!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.lg),
            const AppDivider.flush(),
            const SizedBox(height: AppSizes.lg),
            Text(
              AppStrings.note,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(invoice.note!),
          ],
          const SizedBox(height: AppSizes.huge),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sticky bar shown only while the invoice is a DRAFT. Confirm posts
  /// the stock movement; Cancel is gated behind a dialog because it's
  /// destructive (no stock is moved and the row is marked cancelled).
  ///
  /// AppButton's inner [Center] expands unbounded in [bottomNavigationBar]
  /// — wrap each in a [SizedBox] with explicit height so they don't
  /// stretch to fill the screen.
  Widget _buildDraftActionBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.hairline, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: SizedBox(
          height: AppSizes.huge,
          child: Row(
            children: [
              Expanded(
                child: AppButton.secondary(
                  label: AppStrings.cancelInvoice,
                  onPressed: _confirmAndCancel,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                flex: 2,
                child: AppButton.primary(
                  label: AppStrings.confirmInvoice,
                  onPressed: () => _updateStatus('CONFIRMED'),
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compose a one-line "addr, city, state - pin" string, skipping empties.
  static String _addressLine(String? addr, String? city, String? state, String? pin) {
    final parts = <String>[];
    if (addr != null && addr.isNotEmpty) parts.add(addr);
    if (city != null && city.isNotEmpty) parts.add(city);
    if (state != null && state.isNotEmpty) {
      parts.add(pin != null && pin.isNotEmpty ? '$state - $pin' : state);
    } else if (pin != null && pin.isNotEmpty) {
      parts.add(pin);
    }
    return parts.join(', ');
  }

  static String _documentTypeLabel(String docType) {
    switch (docType) {
      case 'TAX_INVOICE':
        return 'TAX INVOICE';
      case 'BILL_OF_SUPPLY':
        return 'BILL OF SUPPLY';
      case 'CREDIT_NOTE':
        return 'CREDIT NOTE';
      case 'DEBIT_NOTE':
        return 'DEBIT NOTE';
      default:
        return docType.replaceAll('_', ' ');
    }
  }

  AppStatusTone _statusTone(String status) {
    switch (status) {
      case 'CONFIRMED':
        return AppStatusTone.success;
      case 'CANCELLED':
        return AppStatusTone.error;
      default:
        return AppStatusTone.neutral;
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.xs),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item});
  final InvoiceItem item;

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
                  item.productName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  '${item.quantity} ${item.unit} × ${AppStrings.currencySymbol}${item.unitPrice.toStringAsFixed(2)}'
                  '${item.taxPercent > 0 ? ' + ${item.taxPercent.toStringAsFixed(0)}% GST' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Text(
            '${AppStrings.currencySymbol}${item.total.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted);
    final valueStyle = isHighlight
        ? theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(
            '${value < 0 ? '-' : ''}${AppStrings.currencySymbol}${value.abs().toStringAsFixed(2)}',
            style: valueStyle,
          ),
        ],
      ),
    );
  }
}
