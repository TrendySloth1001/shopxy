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
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_card.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final ds = context.read<InvoicesRemoteDataSource>();
      final invoice = await ds.getInvoiceById(widget.invoiceId);
      if (mounted) {
        setState(() {
          _invoice = invoice;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadPdf() async {
    if (_invoice == null) return;
    setState(() => _isDownloading = true);
    final invoiceNo = _invoice!.invoiceNo;
    final ds = context.read<InvoicesRemoteDataSource>();
    try {
      final response = await ds.downloadPdf(widget.invoiceId);
      if (response.statusCode != 200) {
        throw Exception('Failed to generate PDF');
      }
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$invoiceNo.pdf');
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

  /// Downloads the PDF to the temp dir and pops the native share sheet.
  /// WhatsApp appears as a share target on both Android and iOS, so users
  /// effectively get a one-tap WhatsApp share — same flow handles email,
  /// Drive, etc. without extra integration code.
  Future<void> _sharePdf() async {
    if (_invoice == null) return;
    setState(() => _isDownloading = true);
    final invoiceNo = _invoice!.invoiceNo;
    final ds = context.read<InvoicesRemoteDataSource>();
    try {
      final response = await ds.downloadPdf(widget.invoiceId);
      if (response.statusCode != 200) {
        throw Exception('Failed to generate PDF');
      }
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$invoiceNo.pdf');
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          if (invoice.isDraft)
            IconButton(
              icon: const Icon(Icons.check_circle_outline_rounded),
              tooltip: AppStrings.confirmInvoice,
              onPressed: () => _updateStatus('CONFIRMED'),
            ),
          PopupMenuButton<String>(
            itemBuilder: (_) => [
              if (invoice.isDraft)
                const PopupMenuItem(
                  value: 'CANCELLED',
                  child: Text(AppStrings.cancelInvoice),
                ),
              if (!invoice.isConfirmed)
                const PopupMenuItem(
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
              } else {
                _updateStatus(v);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          GlassHero.line(
            kind: LineArt.invoice,
            height: 180,
            illustrationSize: 130,
            accent: invoice.isCancelled ? AppColors.error : AppColors.brand,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSizes.lg),
              children: [
          AppCard(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
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
                  runSpacing: 4,
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
          ),
          const SizedBox(height: AppSizes.md),
          AppSectionHeader(
            title: AppStrings.invoiceItems.toUpperCase(),
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < invoice.items.length; i++) ...[
                  if (i > 0) const AppDivider.flush(),
                  _ItemTile(item: invoice.items[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          AppCard(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
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
          ),
          const SizedBox(height: AppSizes.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(
                Icons.chat_rounded,
                color: Color(0xFF25D366),
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
          ),
          if (invoice.status == 'CONFIRMED' &&
              (invoice.partyId != null || invoice.vendorId != null)) ...[
            const SizedBox(height: AppSizes.md),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
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
            ),
          ],
          if (invoice.note != null && invoice.note!.isNotEmpty) ...[
            const SizedBox(height: AppSizes.md),
            AppCard(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.note,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Text(invoice.note!),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSizes.huge),
              ],
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(top: 4),
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
                const SizedBox(height: 2),
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
      padding: const EdgeInsets.symmetric(vertical: 3),
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
