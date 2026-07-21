import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:shopxy/features/payments/domain/entities/payment.dart';
import 'package:shopxy/features/payments/presentation/providers/payments_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/app_filter_pill.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Bottom-sheet form for recording a payment.
///
/// Reusable across the merchant app:
///   * For a party receipt: pass `type: 'RECEIPT'` + `partyId`.
///   * For a vendor payout: pass `type: 'PAYMENT'` + `vendorId`.
///
/// Optionally pre-allocates against a specific invoice (used by the
/// invoice detail page's "Mark as Paid" quick action) — when
/// [lockedInvoiceId] is set we skip the toggle entirely.
class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({
    super.key,
    required this.type,
    this.partyId,
    this.vendorId,
    this.partyName,
    this.vendorName,
    this.initialAmount,
    this.lockedInvoiceId,
    this.lockedInvoiceLabel,
  }) : assert(type == 'RECEIPT' || type == 'PAYMENT'),
       assert(
         (type == 'RECEIPT' && partyId != null) ||
             (type == 'PAYMENT' && vendorId != null),
         'RECEIPT requires partyId, PAYMENT requires vendorId',
       );

  final String type;
  final int? partyId;
  final int? vendorId;
  final String? partyName;
  final String? vendorName;
  final double? initialAmount;
  final int? lockedInvoiceId;
  final String? lockedInvoiceLabel;

  static Future<Payment?> show(
    BuildContext context, {
    required String type,
    int? partyId,
    int? vendorId,
    String? partyName,
    String? vendorName,
    double? initialAmount,
    int? lockedInvoiceId,
    String? lockedInvoiceLabel,
  }) {
    return showModalBottomSheet<Payment>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => RecordPaymentSheet(
        type: type,
        partyId: partyId,
        vendorId: vendorId,
        partyName: partyName,
        vendorName: vendorName,
        initialAmount: initialAmount,
        lockedInvoiceId: lockedInvoiceId,
        lockedInvoiceLabel: lockedInvoiceLabel,
      ),
    );
  }

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  static const _modes = <String>[
    'CASH',
    'UPI',
    'NEFT',
    'RTGS',
    'CHEQUE',
    'CARD',
  ];
  static final _dateFmt = DateFormat('d MMM y');

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  final _modeRefCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _mode = 'CASH';
  DateTime _date = DateTime.now();
  bool _allocate = false;
  int? _selectedInvoiceId;
  List<LedgerEntry> _openInvoices = const [];
  bool _loadingInvoices = false;
  // Shown inline inside the sheet. A snackbar via ScaffoldMessenger renders at
  // the screen bottom — behind this modal sheet — so save failures were
  // invisible; surface them here instead.
  String? _error;

  bool get _isReceipt => widget.type == 'RECEIPT';
  bool get _isLocked => widget.lockedInvoiceId != null;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.initialAmount != null
          ? widget.initialAmount!.toStringAsFixed(2)
          : '',
    );
    if (_isLocked) {
      _allocate = true;
      _selectedInvoiceId = widget.lockedInvoiceId;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _modeRefCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleAllocate(bool value) async {
    setState(() {
      _allocate = value;
      if (!value) _selectedInvoiceId = null;
    });
    if (value && _openInvoices.isEmpty && !_loadingInvoices) {
      setState(() => _loadingInvoices = true);
      try {
        final ds = context.read<PaymentsRemoteDataSource>();
        final ledger = _isReceipt
            ? await ds.getPartyLedger(widget.partyId!)
            : await ds.getVendorLedger(widget.vendorId!);
        // Surface every confirmed invoice as a candidate; we don't yet
        // pre-filter by paid/unpaid (server enforces over-allocation).
        final invoices = ledger.entries
            .where((e) => e.isInvoice)
            .toList()
            .reversed
            .toList();
        if (mounted) {
          setState(() {
            _openInvoices = invoices;
            _loadingInvoices = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loadingInvoices = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 5),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    final provider = context.read<PaymentsProvider>();
    try {
      final payment = await provider.create(
        type: widget.type,
        amount: amount,
        mode: _mode,
        modeReference: _modeRefCtrl.text.trim().isEmpty
            ? null
            : _modeRefCtrl.text.trim(),
        paymentDate: _date,
        partyId: _isReceipt ? widget.partyId : null,
        vendorId: _isReceipt ? null : widget.vendorId,
        invoiceId: _allocate ? _selectedInvoiceId : null,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(payment);
    } catch (e) {
      // Inline (not a snackbar) so the message is visible above the sheet.
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final counterpartyLabel = _isReceipt
        ? (widget.partyName ?? l10n.paymentsCounterpartyParty)
        : (widget.vendorName ?? l10n.paymentsCounterpartyVendor);

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isReceipt
                            ? l10n.paymentsRecordReceiptTitle
                            : l10n.paymentsRecordPaymentTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const AppIcon(AppIcons.closeRounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  _isReceipt
                      ? l10n.paymentsFromCounterparty(counterpartyLabel)
                      : l10n.paymentsToCounterparty(counterpartyLabel),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.paymentsAmountLabel,
                    prefixText: AppStrings.currencySymbol,
                  ),
                  validator: (v) {
                    final parsed = double.tryParse((v ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return l10n.paymentsAmountPositiveError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.md),
                Text(l10n.paymentsModeLabel, style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSizes.xs),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    // AppFilterPill sets the label colour directly, so the
                    // unselected label stays legible — unlike the themed
                    // ChoiceChip, whose state-aware label rendered light-on-
                    // light here.
                    for (final m in _modes)
                      AppFilterPill(
                        label: m,
                        selected: _mode == m,
                        onTap: () => setState(() => _mode = m),
                      ),
                  ],
                ),
                if (_mode != 'CASH') ...[
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _modeRefCtrl,
                    decoration: InputDecoration(
                      labelText: _mode == 'UPI'
                          ? l10n.paymentsUpiTransactionIdLabel
                          : _mode == 'CHEQUE'
                          ? l10n.paymentsChequeNumberLabel
                          : l10n.paymentsReferenceLabel,
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.md),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: AppShapes.squircleRadius(AppSizes.radiusInput),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.paymentsDateLabel,
                      suffixIcon: const AppIcon(AppIcons.calendarTodayOutlined),
                    ),
                    child: Text(_dateFmt.format(_date)),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                if (_isLocked) ...[
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: l10n.paymentsAllocatedToLabel,
                    ),
                    child: Text(
                      widget.lockedInvoiceLabel ?? l10n.paymentsInvoiceLabel,
                    ),
                  ),
                ] else ...[
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.paymentsAllocateToInvoiceTitle),
                    subtitle: Text(l10n.paymentsAllocateToInvoiceSubtitle),
                    value: _allocate,
                    onChanged: _toggleAllocate,
                  ),
                  if (_allocate) ...[
                    if (_loadingInvoices)
                      const Padding(
                        padding: EdgeInsets.all(AppSizes.sm),
                        child: LinearProgressIndicator(),
                      )
                    else if (_openInvoices.isEmpty)
                      Text(
                        l10n.paymentsNoInvoicesFound(counterpartyLabel),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        initialValue: _selectedInvoiceId,
                        decoration: InputDecoration(
                          labelText: l10n.paymentsInvoiceLabel,
                        ),
                        items: [
                          for (final inv in _openInvoices)
                            DropdownMenuItem(
                              value: inv.id,
                              child: Text(
                                '${inv.label} · '
                                '${AppStrings.currencySymbol}${inv.debit.toStringAsFixed(2)}',
                              ),
                            ),
                        ],
                        onChanged: (v) =>
                            setState(() => _selectedInvoiceId = v),
                        validator: (v) =>
                            v == null ? l10n.paymentsPickInvoiceError : null,
                      ),
                  ],
                ],
                const SizedBox(height: AppSizes.md),
                TextFormField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    labelText: l10n.paymentsNoteOptionalLabel,
                  ),
                  maxLines: 2,
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSizes.md),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppIcon(
                          AppIcons.errorOutlineRounded,
                          color: AppColors.error,
                          size: AppSizes.iconSm,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.lg),
                // Cancel + Save side by side so there's always an obvious way
                // out of the sheet (the top X alone was easy to miss).
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(l10n.commonCancel),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      flex: 2,
                      child: Consumer<PaymentsProvider>(
                        builder: (_, prov, _) {
                          return FilledButton(
                            onPressed: prov.isSubmitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: prov.isSubmitting
                                ? const SizedBox(
                                    width: AppSizes.iconMd,
                                    height: AppSizes.iconMd,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isReceipt
                                        ? l10n.paymentsSaveReceipt
                                        : l10n.paymentsSavePayment,
                                  ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
