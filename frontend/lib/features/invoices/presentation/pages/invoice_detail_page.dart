import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
import 'package:shopxy/features/invoices/presentation/pages/issue_note_page.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/glass_widgets.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class InvoiceDetailPage extends StatefulWidget {
  const InvoiceDetailPage({super.key, required this.invoiceId});
  final String invoiceId;

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  bool _archiving = false;

  Invoice? _invoice;
  bool _isLoading = true;
  bool _isDownloading = false;
  List<Payment> _payments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final ds = context.read<InvoicesRemoteDataSource>();
    final paymentsDs = context.read<PaymentsRemoteDataSource>();
    try {
      final invoice = await ds.getInvoiceById(widget.invoiceId);
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

  double get _paidTotal =>
      _payments.fold<double>(0, (sum, p) => sum + p.amount);

  double _outstanding(Invoice invoice) {
    final out = invoice.total - _paidTotal;
    return out > 0 ? out : 0;
  }

  String _paymentModeLabel(AppLocalizations l10n, Payment p) {
    switch (p.mode) {
      case 'OTHER':
        return p.note ?? l10n.invoicesPaymentModeOnline;
      case 'CASH':
        return l10n.invoicesPaymentModeCash;
      case 'UPI':
        return 'UPI';
      case 'NEFT':
        return 'NEFT';
      case 'RTGS':
        return 'RTGS';
      case 'CHEQUE':
        return l10n.invoicesPaymentModeCheque;
      case 'CARD':
        return l10n.invoicesPaymentModeCard;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  static String _safePdfFilename(String invoiceNo) {
    final sanitized = invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return '$sanitized.pdf';
  }

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
        ShareParams(files: [XFile(file.path)], text: 'Invoice $invoiceNo'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

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
        SnackBar(
          content: Text(
            AppLocalizations.of(context).invoicesCouldNotOpenWhatsApp,
          ),
        ),
      );
    }
  }

  static String? _normalizeIndianPhone(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;
    if (digits.startsWith('91') && digits.length >= 12) return digits;
    if (digits.length == 10) return '91$digits';
    if (digits.length >= 11) return digits;
    return null;
  }

  Future<void> _convertToInvoice() async {
    final invoice = _invoice;
    if (invoice == null) return;
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.invoicesConvertTitle),
        content: Text(l10n.invoicesConvertBody(invoice.invoiceNo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.invoicesCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.invoicesConvert),
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
      invoicesProvider.loadInvoices(refresh: true);
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => InvoiceDetailPage(invoiceId: created.id),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _issueNote() async {
    final invoice = _invoice;
    if (invoice == null) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => IssueNotePage(invoice: invoice)),
    );
  }

  Future<void> _setArchived(Invoice invoice, bool archived) async {
    final l10n = AppLocalizations.of(context);
    if (archived) {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: l10n.actionArchive,
        message: l10n.invoicesArchiveConfirmBody(invoice.invoiceNo),
        confirmLabel: l10n.actionArchive,
      );
      if (!confirmed || !mounted) return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _archiving = true);
    try {
      await context.read<InvoicesProvider>().setArchived(invoice.id, archived);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            archived
                ? l10n.documentArchivedNamed(invoice.invoiceNo)
                : l10n.documentRestoredNamed(invoice.invoiceNo),
          ),
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _archiving = false);
      messenger.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _openEdit() async {
    final invoice = _invoice;
    if (invoice == null || !invoice.isDraft) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CreateInvoicePage(existing: invoice)),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _updateStatus(String status) async {
    final l10n = AppLocalizations.of(context);
    final provider = context.read<InvoicesProvider>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = await provider.updateStatus(widget.invoiceId, status);
      if (!mounted) return;
      setState(() => _invoice = updated);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            status == 'CONFIRMED'
                ? l10n.invoicesConfirmedNamed(updated.invoiceNo)
                : l10n.invoicesCancelledNamed(updated.invoiceNo),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _confirmAndCancel() async {
    final invoice = _invoice;
    if (invoice == null) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.invoicesCancelInvoice),
        content: Text(l10n.invoicesCancelConfirmBody(invoice.invoiceNo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.invoicesKeepDraft),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.invoicesCancelInvoice),
          ),
        ],
      ),
    );
    if (ok == true) await _updateStatus('CANCELLED');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const _InvoiceDetailSkeleton();
    }

    if (_invoice == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: FloatingAppBar(),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Center(child: Text(l10n.invoicesErrorTitle)),
        ),
      );
    }

    final invoice = _invoice!;
    final df = DateFormat('dd MMM yyyy, hh:mm a');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: invoice.invoiceNo,
        actions: [
          if (!_isDownloading) ...[
            if (invoice.isDraft)
              IconButton(
                icon: const AppIcon(AppIcons.editOutlined),
                tooltip: l10n.invoicesEdit,
                onPressed: _openEdit,
              ),
            IconButton(
              icon: const AppIcon(AppIcons.shareRounded),
              tooltip: l10n.invoicesShare,
              onPressed: _sharePdf,
            ),
            IconButton(
              icon: const AppIcon(AppIcons.downloadRounded),
              tooltip: l10n.invoicesDownloadTooltip,
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
          if (!_isDownloading && (invoice.isArchived || !invoice.isConfirmed))
            IconButton(
              icon: AppIcon(
                invoice.isArchived
                    ? AppIcons.unarchiveRounded
                    : AppIcons.archiveAddRounded,
              ),
              tooltip: invoice.isArchived
                  ? l10n.actionRestore
                  : l10n.actionArchive,
              onPressed: _archiving
                  ? null
                  : () => _setArchived(invoice, !invoice.isArchived),
            ),
        ],
      ),
      bottomNavigationBar: invoice.isDraft ? _buildDraftActionBar(l10n) : null,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SizedBox(height: FloatingAppBar.contentTopInset(context)),
          GlassHero.line(
            kind: LineArt.invoice,
            height: AppSizes.heroHeightMd,
            illustrationSize: AppSizes.productImageSize,
            accent: invoice.isCancelled ? AppColors.error : AppColors.brand,
          ),
          Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            invoice.invoiceNo,
                            style: theme.textTheme.headlineSmall?.bold,
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
                          label: _documentTypeLabel(l10n, invoice.documentType),
                          tone: AppStatusTone.neutral,
                          dense: true,
                        ),
                        if (invoice.igstAmount + invoice.cgstAmount + invoice.sgstAmount > 0)
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
                          ? l10n.invoicesSaleInvoice
                          : l10n.invoicesPurchaseInvoice,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    Text(
                      df.format(invoice.invoiceDate.toLocal()),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    _InfoRow(
                      label: invoice.isSale
                          ? l10n.invoicesCustomer
                          : l10n.invoicesVendor,
                      value: invoice.partyName,
                    ),
                    if (invoice.isSale) ...[
                      if (invoice.customerPhone != null)
                        _InfoRow(
                          label: l10n.invoicesPhone,
                          value: invoice.customerPhone!,
                        ),
                      if (invoice.customerGstin != null)
                        _InfoRow(
                          label: l10n.invoicesGstin,
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
                      ).isNotEmpty)
                        _InfoRow(
                          label: l10n.invoicesAddress,
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
                          label: l10n.invoicesVendor,
                          value: invoice.vendor!.name,
                        ),
                      if (invoice.vendorGstin != null)
                        _InfoRow(
                          label: l10n.invoicesGstin,
                          value: invoice.vendorGstin!,
                        ),
                      if (_addressLine(
                        invoice.vendorAddress,
                        invoice.vendorCity,
                        invoice.vendorState,
                        invoice.vendorPinCode,
                      ).isNotEmpty)
                        _InfoRow(
                          label: l10n.invoicesAddress,
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
                  title: l10n.invoicesInvoiceItems.toUpperCase(),
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
                    _TotalRow(
                      label: l10n.invoicesSubtotal,
                      value: invoice.subtotal,
                    ),
                    if (invoice.igstAmount == 0 &&
                        invoice.cgstAmount == 0 &&
                        invoice.sgstAmount == 0)
                      _TotalRow(
                        label: l10n.invoicesTaxAmount,
                        value: invoice.taxAmount,
                      )
                    else if (invoice.isInterstate)
                      _TotalRow(label: 'IGST', value: invoice.igstAmount)
                    else ...[
                      _TotalRow(label: 'CGST', value: invoice.cgstAmount),
                      _TotalRow(label: 'SGST', value: invoice.sgstAmount),
                    ],
                    if (invoice.cessAmount > 0)
                      _TotalRow(
                        label: l10n.invoicesCess,
                        value: invoice.cessAmount,
                      ),
                    if (invoice.discount > 0)
                      _TotalRow(
                        label: l10n.invoicesDiscount,
                        value: -invoice.discount,
                      ),
                    if (invoice.roundOff != 0)
                      _TotalRow(
                        label: l10n.invoicesRoundOff,
                        value: invoice.roundOff,
                      ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                      child: AppDivider.flush(),
                    ),
                    _TotalRow(
                      label: l10n.invoicesTotal,
                      value: invoice.total,
                      isHighlight: true,
                    ),
                    if (invoice.status == 'CONFIRMED') ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                        child: AppDivider.flush(),
                      ),
                      _TotalRow(
                        label: l10n.invoicesReceived,
                        value: _paidTotal,
                      ),
                      _TotalRow(
                        label: l10n.invoicesOutstanding,
                        value: _outstanding(invoice),
                        isHighlight: true,
                      ),
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
                if (invoice.status == 'CONFIRMED' && _payments.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.xxl),
                  AppSectionHeader(
                    title: l10n.invoicesPaymentsReceivedTitle.toUpperCase(),
                    padding: const EdgeInsets.only(bottom: AppSizes.md),
                  ),
                  _PaymentTimeline(
                    payments: _payments,
                    label: (p) => _paymentModeLabel(l10n, p),
                    dateFmt: df,
                  ),
                ],
                const SizedBox(height: AppSizes.lg),
                _ActionTile(
                  iconChild: FaIcon(
                    FontAwesomeIcons.whatsapp,
                    color: AppColors.white,
                    size: 22,
                  ),
                  iconBackground: AppColors.whatsapp,
                  title: l10n.invoicesSendViaWhatsApp,
                  subtitle:
                      invoice.customerPhone != null &&
                          invoice.customerPhone!.isNotEmpty
                      ? l10n.invoicesOpensChatWith(invoice.customerPhone!)
                      : l10n.invoicesPickChatToSend,
                  onTap: _shareViaWhatsApp,
                ),
                if ((invoice.documentType == 'ESTIMATE' ||
                        invoice.documentType == 'PROFORMA') &&
                    invoice.status != 'CANCELLED') ...[
                  const SizedBox(height: AppSizes.sm),
                  _ActionTile(
                    iconChild: AppIcon(
                      AppIcons.swapHorizRounded,
                      color: AppColors.brand,
                      size: 20,
                    ),
                    iconBackground: AppColors.brand.withValues(alpha: 0.12),
                    title: l10n.invoicesConvertToInvoice,
                    subtitle: l10n.invoicesConvertTileSubtitle,
                    onTap: _isDownloading ? null : _convertToInvoice,
                  ),
                ],
                if (invoice.status == 'CONFIRMED' &&
                    (invoice.partyId != null || invoice.vendorId != null) &&
                    _outstanding(invoice) > 0.005) ...[
                  const SizedBox(height: AppSizes.sm),
                  _ActionTile(
                    iconChild: AppIcon(
                      AppIcons.accountBalanceWalletRounded,
                      color: AppColors.success,
                      size: 20,
                    ),
                    iconBackground: AppColors.success.withValues(alpha: 0.14),
                    title: l10n.invoicesMarkAsPaid,
                    subtitle: invoice.type == 'SALE'
                        ? l10n.invoicesRecordReceiptSubtitle
                        : l10n.invoicesRecordPaymentSubtitle,
                    onTap: () async {
                      final isSale = invoice.type == 'SALE';
                      final created = await RecordPaymentSheet.show(
                        context,
                        type: isSale ? 'RECEIPT' : 'PAYMENT',
                        partyId: isSale ? invoice.partyId : null,
                        vendorId: isSale ? null : invoice.vendorId,
                        partyName: invoice.customerName,
                        vendorName: invoice.vendorName,
                        initialAmount: _outstanding(invoice),
                        lockedInvoiceId: invoice.id,
                        lockedInvoiceLabel: invoice.invoiceNo,
                      );
                      if (!context.mounted) return;
                      if (created != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.invoicesPaymentRecorded)),
                        );
                        _load();
                      }
                    },
                  ),
                ],
                if (invoice.status == 'CONFIRMED' &&
                    invoice.type == 'SALE' &&
                    (invoice.documentType == 'TAX_INVOICE' ||
                        invoice.documentType == 'BILL_OF_SUPPLY')) ...[
                  const SizedBox(height: AppSizes.sm),
                  _ActionTile(
                    iconChild: AppIcon(
                      AppIcons.differenceRounded,
                      color: AppColors.brand,
                      size: 20,
                    ),
                    iconBackground: AppColors.brand.withValues(alpha: 0.12),
                    title: l10n.invoicesIssueNoteAction,
                    subtitle: l10n.invoicesIssueNoteActionSubtitle,
                    onTap: _isDownloading ? null : _issueNote,
                  ),
                ],
                if (invoice.note != null && invoice.note!.isNotEmpty) ...[
                  const SizedBox(height: AppSizes.lg),
                  const AppDivider.flush(),
                  const SizedBox(height: AppSizes.lg),
                  Text(
                    l10n.invoicesNote,
                    style: theme.textTheme.titleSmall?.bold,
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

  Widget _buildDraftActionBar(AppLocalizations l10n) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
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
                  label: l10n.invoicesCancelInvoice,
                  onPressed: _confirmAndCancel,
                  fullWidth: true,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                flex: 2,
                child: AppButton.primary(
                  label: l10n.invoicesConfirmInvoice,
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

  static String _addressLine(
    String? addr,
    String? city,
    String? state,
    String? pin,
  ) {
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

  static String _documentTypeLabel(AppLocalizations l10n, String docType) {
    switch (docType) {
      case 'TAX_INVOICE':
        return l10n.invoicesDocTaxInvoice.toUpperCase();
      case 'BILL_OF_SUPPLY':
        return l10n.invoicesDocBillOfSupply.toUpperCase();
      case 'CREDIT_NOTE':
        return l10n.invoicesDocCreditNote.toUpperCase();
      case 'DEBIT_NOTE':
        return l10n.invoicesDocDebitNote.toUpperCase();
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

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.iconChild,
    required this.iconBackground,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final Widget iconChild;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        side: BorderSide(color: AppColors.hairline),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                ),
                child: Center(child: iconChild),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.bodyMedium?.semibold),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSizes.xxs),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.sm),
              AppIcon(AppIcons.chevronRightRounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTimeline extends StatelessWidget {
  const _PaymentTimeline({
    required this.payments,
    required this.label,
    required this.dateFmt,
  });

  final List<Payment> payments;
  final String Function(Payment) label;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (int i = 0; i < payments.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.brand, width: 2),
                      ),
                    ),
                    if (i != payments.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: AppColors.brand.withValues(alpha: 0.35),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: i == payments.length - 1 ? 0 : AppSizes.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label(payments[i]),
                                style: theme.textTheme.bodyMedium?.semibold,
                              ),
                            ),
                            const SizedBox(width: AppSizes.sm),
                            Text(
                              '${AppStrings.currencySymbol}${payments[i].amount.toStringAsFixed(2)}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.xxs),
                        Text(
                          dateFmt.format(payments[i].paymentDate.toLocal()),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        if (payments[i].referenceNo.isNotEmpty)
                          Text(
                            payments[i].referenceNo,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InvoiceDetailSkeleton extends StatelessWidget {
  const _InvoiceDetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
            const AppShimmerBox(
              width: double.infinity,
              height: AppSizes.heroHeightMd,
              radius: 0,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.lg),
                children: const [
                  _SkeletonHeaderRow(),
                  SizedBox(height: AppSizes.sm),
                  _SkeletonBadgeRow(),
                  SizedBox(height: AppSizes.sm),
                  AppShimmerLine(widthFactor: 0.45, height: AppSizes.md),
                  SizedBox(height: AppSizes.xs),
                  AppShimmerLine(widthFactor: 0.55, height: AppSizes.sm),
                  SizedBox(height: AppSizes.lg),
                  _SkeletonInfoRow(labelFactor: 0.2, valueFactor: 0.55),
                  _SkeletonInfoRow(labelFactor: 0.15, valueFactor: 0.45),
                  _SkeletonInfoRow(labelFactor: 0.18, valueFactor: 0.6),
                  _SkeletonInfoRow(labelFactor: 0.22, valueFactor: 0.5),
                  SizedBox(height: AppSizes.lg),
                  AppShimmerLine(widthFactor: 0.35, height: AppSizes.md),
                  SizedBox(height: AppSizes.sm),
                  _SkeletonDivider(),
                  _SkeletonItemRow(),
                  _SkeletonDivider(),
                  _SkeletonItemRow(),
                  _SkeletonDivider(),
                  _SkeletonItemRow(),
                  SizedBox(height: AppSizes.md),
                  _SkeletonDivider(),
                  SizedBox(height: AppSizes.md),
                  _SkeletonTotalRow(labelFactor: 0.3, valueFactor: 0.25),
                  _SkeletonTotalRow(labelFactor: 0.25, valueFactor: 0.28),
                  _SkeletonTotalRow(labelFactor: 0.2, valueFactor: 0.22),
                  _SkeletonTotalRow(labelFactor: 0.22, valueFactor: 0.2),
                  SizedBox(height: AppSizes.xs),
                  _SkeletonDivider(),
                  SizedBox(height: AppSizes.xs),
                  _SkeletonTotalRow(
                    labelFactor: 0.2,
                    valueFactor: 0.3,
                    tall: true,
                  ),
                  SizedBox(height: AppSizes.huge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonHeaderRow extends StatelessWidget {
  const _SkeletonHeaderRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: AppShimmerLine(widthFactor: 0.65, height: AppSizes.xl)),
        SizedBox(width: AppSizes.md),
        AppShimmerBox(
          width: 72,
          height: AppSizes.xl,
          radius: AppSizes.radiusFull,
        ),
      ],
    );
  }
}

class _SkeletonBadgeRow extends StatelessWidget {
  const _SkeletonBadgeRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        AppShimmerBox(
          width: 90,
          height: AppSizes.lg,
          radius: AppSizes.radiusFull,
        ),
        SizedBox(width: AppSizes.xs),
        AppShimmerBox(
          width: 80,
          height: AppSizes.lg,
          radius: AppSizes.radiusFull,
        ),
      ],
    );
  }
}

class _SkeletonInfoRow extends StatelessWidget {
  const _SkeletonInfoRow({
    required this.labelFactor,
    required this.valueFactor,
  });
  final double labelFactor;
  final double valueFactor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.xs),
      child: Row(
        children: [
          Flexible(
            flex: 2,
            child: AppShimmerLine(
              widthFactor: labelFactor,
              height: AppSizes.md,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Flexible(
            flex: 5,
            child: AppShimmerLine(
              widthFactor: valueFactor,
              height: AppSizes.md,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonItemRow extends StatelessWidget {
  const _SkeletonItemRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppShimmerLine(widthFactor: 0.7, height: AppSizes.md),
                SizedBox(height: AppSizes.xs),
                AppShimmerLine(widthFactor: 0.5, height: AppSizes.sm),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          AppShimmerBox(
            width: AppSizes.massive,
            height: AppSizes.md,
            radius: AppSizes.radiusSm,
          ),
        ],
      ),
    );
  }
}

class _SkeletonTotalRow extends StatelessWidget {
  const _SkeletonTotalRow({
    required this.labelFactor,
    required this.valueFactor,
    this.tall = false,
  });
  final double labelFactor;
  final double valueFactor;
  final bool tall;

  @override
  Widget build(BuildContext context) {
    final h = tall ? AppSizes.lg : AppSizes.md;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppShimmerLine(widthFactor: labelFactor, height: h),
          AppShimmerLine(widthFactor: valueFactor, height: h),
        ],
      ),
    );
  }
}

class _SkeletonDivider extends StatelessWidget {
  const _SkeletonDivider();

  @override
  Widget build(BuildContext context) {
    return const AppShimmerBox(width: double.infinity, height: 1, radius: 0);
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodySmall?.medium),
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
                  style: theme.textTheme.bodyMedium?.medium,
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  '${item.quantity.truncateToDouble() == item.quantity ? item.quantity.toInt() : item.quantity.toStringAsFixed(2)} ${item.unit} × ${AppStrings.currencySymbol}${item.unitPrice.toStringAsFixed(2)}'
                  '${item.taxPercent > 0 ? ' + ${item.taxPercent.toStringAsFixed(0)}% GST' : ''}'
                  '${item.hsn != null && item.hsn!.isNotEmpty ? ' · HSN ${item.hsn}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Text(
            '${AppStrings.currencySymbol}${item.total.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.semibold,
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
        ? theme.textTheme.titleSmall?.bold
        : theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted);
    final valueStyle = isHighlight
        ? theme.textTheme.titleSmall?.bold
        : theme.textTheme.bodyMedium?.medium;
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
