import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/caution/presentation/providers/caution_provider.dart';
import 'package:shopxy/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:shopxy/features/payments/domain/entities/payment.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Bottom sheet for taking a caution deposit or refunding one.
///
///   * Deposit: `type: 'DEPOSIT'`.
///   * Refund:  `type: 'REFUND'` — capped at [currentBalance] so a deposit
///     can never be over-drawn (the server enforces this too).
///
/// Returns the new held balance on success, or null if dismissed.
class CautionSheet extends StatefulWidget {
  const CautionSheet({
    super.key,
    required this.type,
    required this.partyId,
    required this.partyName,
    required this.currentBalance,
  }) : assert(type == 'DEPOSIT' || type == 'REFUND');

  final String type;
  final int partyId;
  final String partyName;
  final double currentBalance;

  static Future<double?> show(
    BuildContext context, {
    required String type,
    required int partyId,
    required String partyName,
    required double currentBalance,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => CautionSheet(
        type: type,
        partyId: partyId,
        partyName: partyName,
        currentBalance: currentBalance,
      ),
    );
  }

  @override
  State<CautionSheet> createState() => _CautionSheetState();
}

class _CautionSheetState extends State<CautionSheet> {
  static const _modes = <String>['CASH', 'UPI', 'NEFT', 'RTGS', 'CHEQUE', 'CARD'];

  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _modeRefCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _mode = 'CASH';

  bool get _isRefund => widget.type == 'REFUND';

  @override
  void dispose() {
    _amountCtrl.dispose();
    _modeRefCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    final provider = context.read<CautionProvider>();
    try {
      final balance = await provider.record(
        partyId: widget.partyId,
        type: widget.type,
        amount: amount,
        mode: _mode,
        modeReference:
            _modeRefCtrl.text.trim().isEmpty ? null : _modeRefCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(balance);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

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
                        _isRefund ? 'Refund caution' : 'Add caution deposit',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  _isRefund
                      ? 'Back to ${widget.partyName} · held '
                          '${AppStrings.currencySymbol}${widget.currentBalance.toStringAsFixed(0)}'
                      : 'From ${widget.partyName}',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.lg),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: AppStrings.currencySymbol,
                  ),
                  validator: (v) {
                    final parsed = double.tryParse((v ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a positive amount';
                    }
                    if (_isRefund && parsed - widget.currentBalance > 0.005) {
                      return 'Cannot exceed held balance '
                          '(${AppStrings.currencySymbol}${widget.currentBalance.toStringAsFixed(0)})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.md),
                Text('Mode', style: theme.textTheme.labelLarge),
                const SizedBox(height: AppSizes.xs),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.xs,
                  children: [
                    for (final m in _modes)
                      ChoiceChip(
                        label: Text(m),
                        selected: _mode == m,
                        onSelected: (s) {
                          if (s) setState(() => _mode = m);
                        },
                      ),
                  ],
                ),
                if (_mode != 'CASH') ...[
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _modeRefCtrl,
                    decoration: InputDecoration(
                      labelText: _mode == 'UPI'
                          ? 'UPI transaction id'
                          : _mode == 'CHEQUE'
                              ? 'Cheque number'
                              : 'Reference',
                    ),
                  ),
                ],
                const SizedBox(height: AppSizes.md),
                TextFormField(
                  controller: _noteCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Note (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSizes.lg),
                SizedBox(
                  width: double.infinity,
                  child: Consumer<CautionProvider>(
                    builder: (_, prov, _) {
                      return FilledButton(
                        onPressed: prov.isSubmitting ? null : _submit,
                        child: prov.isSubmitting
                            ? const SizedBox(
                                width: AppSizes.xl,
                                height: AppSizes.xl,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_isRefund ? 'Refund' : 'Add deposit'),
                      );
                    },
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

/// Bottom sheet for forfeiting (keeping) part of a deposit on the party's
/// default. Capped at the held balance. The merchant picks the GST treatment
/// — a pure default penalty (no GST) vs forfeiture of a cancelled supply (GST
/// at the goods rate) — and is reminded the amount is taxable income.
class CautionForfeitSheet extends StatefulWidget {
  const CautionForfeitSheet({
    super.key,
    required this.partyId,
    required this.partyName,
    required this.currentBalance,
  });

  final int partyId;
  final String partyName;
  final double currentBalance;

  static Future<double?> show(
    BuildContext context, {
    required int partyId,
    required String partyName,
    required double currentBalance,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => CautionForfeitSheet(
        partyId: partyId,
        partyName: partyName,
        currentBalance: currentBalance,
      ),
    );
  }

  @override
  State<CautionForfeitSheet> createState() => _CautionForfeitSheetState();
}

class _CautionForfeitSheetState extends State<CautionForfeitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _taxRateCtrl = TextEditingController(text: '18');
  String _gstTreatment = 'NONE';

  @override
  void initState() {
    super.initState();
    // Default to forfeiting the whole held balance.
    _amountCtrl.text = widget.currentBalance.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _taxRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;
    final taxRate = _gstTreatment == 'SUPPLY'
        ? double.tryParse(_taxRateCtrl.text.trim())
        : null;

    final provider = context.read<CautionProvider>();
    try {
      final balance = await provider.forfeit(
        partyId: widget.partyId,
        amount: amount,
        gstTreatment: _gstTreatment,
        taxRate: taxRate,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(balance);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

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
                        'Forfeit caution',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  'Keep part of ${widget.partyName}’s deposit '
                  '(${AppStrings.currencySymbol}${widget.currentBalance.toStringAsFixed(0)} held) on default',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.lg),
                TextFormField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: AppStrings.currencySymbol,
                  ),
                  validator: (v) {
                    final parsed = double.tryParse((v ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a positive amount';
                    }
                    if (parsed - widget.currentBalance > 0.005) {
                      return 'Cannot exceed held balance '
                          '(${AppStrings.currencySymbol}${widget.currentBalance.toStringAsFixed(0)})';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSizes.md),
                Text('GST treatment', style: theme.textTheme.labelLarge),
                RadioGroup<String>(
                  groupValue: _gstTreatment,
                  onChanged: (v) => setState(() => _gstTreatment = v!),
                  child: const Column(
                    children: [
                      RadioListTile<String>(
                        value: 'NONE',
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Default penalty — no GST'),
                      ),
                      RadioListTile<String>(
                        value: 'SUPPLY',
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Cancelled supply — GST applies'),
                      ),
                    ],
                  ),
                ),
                if (_gstTreatment == 'SUPPLY') ...[
                  const SizedBox(height: AppSizes.sm),
                  TextFormField(
                    controller: _taxRateCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Goods GST rate (%)',
                      helperText:
                          'Forfeit is GST-inclusive — tax is carved out at this rate',
                      helperMaxLines: 2,
                    ),
                    validator: (v) {
                      if (_gstTreatment != 'SUPPLY') return null;
                      final parsed = double.tryParse((v ?? '').trim());
                      if (parsed == null || parsed < 0 || parsed > 100) {
                        return 'Enter the GST rate (0–100)';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: AppSizes.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: AppSizes.iconSm, color: AppColors.muted),
                    const SizedBox(width: AppSizes.xs),
                    Expanded(
                      child: Text(
                        'Forfeited deposits are taxable business income.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                TextFormField(
                  controller: _noteCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Note (optional)'),
                  maxLines: 2,
                ),
                const SizedBox(height: AppSizes.lg),
                SizedBox(
                  width: double.infinity,
                  child: Consumer<CautionProvider>(
                    builder: (_, prov, _) {
                      return FilledButton(
                        onPressed: prov.isSubmitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        child: prov.isSubmitting
                            ? const SizedBox(
                                width: AppSizes.xl,
                                height: AppSizes.xl,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Forfeit deposit'),
                      );
                    },
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

/// Bottom sheet for setting off caution against an open invoice. Loads the
/// party's invoices via the existing ledger endpoint (same source the payment
/// sheet uses) and caps the amount at both the held balance and the picked
/// invoice's value. Returns the new held balance on success.
class CautionAdjustSheet extends StatefulWidget {
  const CautionAdjustSheet({
    super.key,
    required this.partyId,
    required this.partyName,
    required this.currentBalance,
  });

  final int partyId;
  final String partyName;
  final double currentBalance;

  static Future<double?> show(
    BuildContext context, {
    required int partyId,
    required String partyName,
    required double currentBalance,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (_) => CautionAdjustSheet(
        partyId: partyId,
        partyName: partyName,
        currentBalance: currentBalance,
      ),
    );
  }

  @override
  State<CautionAdjustSheet> createState() => _CautionAdjustSheetState();
}

class _CautionAdjustSheetState extends State<CautionAdjustSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int? _selectedInvoiceId;
  List<LedgerEntry> _invoices = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    try {
      final ds = context.read<PaymentsRemoteDataSource>();
      final ledger = await ds.getPartyLedger(widget.partyId);
      final invoices =
          ledger.entries.where((e) => e.isInvoice).toList().reversed.toList();
      if (mounted) {
        setState(() {
          _invoices = invoices;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  LedgerEntry? get _selectedInvoice {
    for (final inv in _invoices) {
      if (inv.id == _selectedInvoiceId) return inv;
    }
    return null;
  }

  /// Set-off can't exceed the held balance or the invoice value.
  double get _cap {
    final inv = _selectedInvoice;
    final invoiceValue = inv?.debit ?? double.infinity;
    return widget.currentBalance < invoiceValue
        ? widget.currentBalance
        : invoiceValue;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0 || _selectedInvoiceId == null) return;

    final provider = context.read<CautionProvider>();
    try {
      final balance = await provider.adjust(
        partyId: widget.partyId,
        invoiceId: _selectedInvoiceId!,
        amount: amount,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(balance);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

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
                        'Set off caution',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Text(
                  'Apply ${widget.partyName}’s deposit '
                  '(${AppStrings.currencySymbol}${widget.currentBalance.toStringAsFixed(0)} held) '
                  'against an invoice',
                  style:
                      theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.lg),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSizes.sm),
                    child: LinearProgressIndicator(),
                  )
                else if (_invoices.isEmpty)
                  Text(
                    'No invoices found for ${widget.partyName}.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  )
                else ...[
                  DropdownButtonFormField<int>(
                    initialValue: _selectedInvoiceId,
                    decoration: const InputDecoration(labelText: 'Invoice'),
                    items: [
                      for (final inv in _invoices)
                        DropdownMenuItem(
                          value: inv.id,
                          child: Text(
                            '${inv.label} · '
                            '${AppStrings.currencySymbol}${inv.debit.toStringAsFixed(2)}',
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedInvoiceId = v;
                        // Default the amount to the most that can be applied.
                        final cap = _cap;
                        if (cap.isFinite) {
                          _amountCtrl.text = cap.toStringAsFixed(2);
                        }
                      });
                    },
                    validator: (v) => v == null ? 'Pick an invoice' : null,
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: AppStrings.currencySymbol,
                    ),
                    validator: (v) {
                      final parsed = double.tryParse((v ?? '').trim());
                      if (parsed == null || parsed <= 0) {
                        return 'Enter a positive amount';
                      }
                      if (parsed - _cap > 0.005) {
                        return 'Cannot exceed '
                            '${AppStrings.currencySymbol}${_cap.toStringAsFixed(0)}';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSizes.md),
                  TextFormField(
                    controller: _noteCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Note (optional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: AppSizes.lg),
                  SizedBox(
                    width: double.infinity,
                    child: Consumer<CautionProvider>(
                      builder: (_, prov, _) {
                        return FilledButton(
                          onPressed: prov.isSubmitting ? null : _submit,
                          child: prov.isSubmitting
                              ? const SizedBox(
                                  width: AppSizes.xl,
                                  height: AppSizes.xl,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Apply set-off'),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
