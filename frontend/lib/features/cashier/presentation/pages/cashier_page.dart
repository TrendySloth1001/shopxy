import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/cashier/data/cashier_remote_data_source.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

/// Cashier control center: open/close a till shift, manage the cash drawer,
/// reconcile (X/Z report), and process returns. Reaches /me/cashier over HTTP.
class CashierPage extends StatefulWidget {
  const CashierPage({super.key});

  @override
  State<CashierPage> createState() => _CashierPageState();
}

String _money(num? v) => '₹${(v ?? 0).toStringAsFixed(2)}';
double _d(Object? v) => v is num ? v.toDouble() : 0;
int _i(Object? v) => v is num ? v.toInt() : 0;

/// Parse a money text field, ignoring everything that isn't the number itself —
/// the ₹ sign, thousands separators, spaces and stray characters — keeping only
/// digits and the decimal point (e.g. '₹1,200.50' → 1200.5). Returns null when
/// there's no parseable amount. Mirrors merchant-web `parseAmount`.
double? _parseAmount(String raw) {
  final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty || cleaned == '.') return null;
  return double.tryParse(cleaned);
}

class _CashierPageState extends State<CashierPage> {
  late final CashierRemoteDataSource _ds;
  bool _loading = true;
  bool _busy = false;
  Map<String, dynamic>? _shift;
  Map<String, dynamic>? _report;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ds = CashierRemoteDataSource(context.read<ApiClient>());
    _load();
    // Tick the shift timer every second while a shift is open.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _open) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _ds.current();
      if (!mounted) return;
      setState(() {
        _shift = res['shift'] as Map<String, dynamic>?;
        _report = res['report'] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(e);
    }
  }

  void _toast(Object e) {
    if (!mounted) return;
    final msg = e.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() => _busy = true);
    try {
      await fn();
    } catch (e) {
      _toast(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _open => _shift != null && _shift!['status'] == 'OPEN';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.cashierTitle,
        actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const SafeArea(
              top: true,
              bottom: false,
              child: Center(child: CircularProgressIndicator()),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    AppSizes.lg,
                    AppSizes.lg + FloatingAppBar.contentTopInset(context),
                    AppSizes.lg,
                    AppSizes.lg),
                children: [
                  if (_open) ...[
                    _ShiftOwnerBanner(shift: _shift!),
                    const SizedBox(height: AppSizes.lg),
                    if (_report != null) _ReportCard(report: _report!),
                    const SizedBox(height: AppSizes.lg),
                    _CashDrawerCard(busy: _busy, onRecord: (t, a, r) => _run(() async {
                          final rep = await _ds.cashMovement(t, a, r);
                          if (mounted) setState(() => _report = rep);
                        })),
                    const SizedBox(height: AppSizes.lg),
                    _ReturnsCard(ds: _ds, busy: _busy, onChanged: _load, run: _run),
                    const SizedBox(height: AppSizes.lg),
                    _CloseShiftCard(
                      expected: _d(_report?['cash']?['expected']),
                      busy: _busy,
                      onClose: (counted, note) => _run(() async {
                        final rep = await _ds.closeShift(counted, note);
                        if (!mounted) return;
                        final variance = _d(rep['cash']?['variance']);
                        _toast(l10n.cashierShiftClosedVariance(_money(variance)));
                        await _load();
                      }),
                    ),
                  ] else
                    _OpenShiftForm(busy: _busy, onOpen: (f) => _run(() async {
                          await _ds.openShift(f);
                          await _load();
                        })),
                  const SizedBox(height: AppSizes.lg),
                  _ShiftHistoryCard(ds: _ds),
                ],
              ),
            ),
    );
  }
}

String _elapsed(Object? openedAt) {
  final start = DateTime.tryParse(openedAt?.toString() ?? '');
  if (start == null) return '00:00:00';
  final d = DateTime.now().difference(start);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

class _ShiftOwnerBanner extends StatelessWidget {
  const _ShiftOwnerBanner({required this.shift});
  final Map<String, dynamic> shift;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = (shift['openedByName'] as String?) ?? l10n.cashierRoleCashier;
    final email = shift['openedByEmail'] as String?;
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.tileBg(AppColors.brandSoft),
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          Icon(Icons.account_circle_outlined, color: AppColors.brand),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                if (email != null) Text(email, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          Row(children: [
            Icon(Icons.timer_outlined, size: AppSizes.iconSm, color: AppColors.muted),
            const SizedBox(width: AppSizes.xs),
            Text(_elapsed(shift['openedAt']), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [])),
          ]),
        ],
      ),
    );
  }
}

class _ShiftHistoryCard extends StatefulWidget {
  const _ShiftHistoryCard({required this.ds});
  final CashierRemoteDataSource ds;
  @override
  State<_ShiftHistoryCard> createState() => _ShiftHistoryCardState();
}

class _ShiftHistoryCardState extends State<_ShiftHistoryCard> {
  List<Map<String, dynamic>>? _shifts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await widget.ds.listShifts();
      if (mounted) setState(() => _shifts = s);
    } catch (_) {
      if (mounted) setState(() => _shifts = const []);
    }
  }

  Future<void> _view(int id) async {
    try {
      final rep = await widget.ds.shiftReport(id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (ctx, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(AppSizes.lg), children: [_ReportCard(report: rep)]),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _Card(
      title: l10n.cashierPastShiftsTitle,
      icon: Icons.history_rounded,
      child: _shifts == null
          ? Padding(padding: const EdgeInsets.symmetric(vertical: AppSizes.md), child: Text(l10n.cashierLoading))
          : _shifts!.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(vertical: AppSizes.md), child: Text(l10n.cashierNoShiftsYet))
              : Column(
                  children: [
                    for (final s in _shifts!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('${s['openedByName'] ?? l10n.cashierRoleCashier} · ${s['status']}', style: theme.textTheme.titleSmall),
                        subtitle: Text(
                          '${DateTime.tryParse(s['openedAt']?.toString() ?? '')?.toLocal().toString().split('.').first ?? ''}'
                          '${s['variance'] != null ? ' · ${l10n.cashierVarianceLabel(_money(_d(s['variance'])))}' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _view(_i(s['id'])),
                      ),
                  ],
                ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.icon});
  final String title;
  final Widget child;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, size: AppSizes.iconSm, color: AppColors.muted), const SizedBox(width: AppSizes.xs)],
            Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: AppSizes.md),
          child,
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(fontWeight: bold ? FontWeight.w700 : FontWeight.w400);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: bold ? AppColors.black : AppColors.muted)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});
  final Map<String, dynamic> report;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cash = (report['cash'] as Map?)?.cast<String, dynamic>() ?? {};
    final gst = (report['gst'] as Map?)?.cast<String, dynamic>() ?? {};
    final tenders = (report['tenders'] as List?) ?? const [];
    final returns = (report['returns'] as Map?)?.cast<String, dynamic>() ?? {};
    final sales = (report['sales'] as Map?)?.cast<String, dynamic>() ?? {};
    return _Card(
      title: l10n.cashierShiftReportTitle,
      icon: Icons.summarize_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.cashierSalesSummary('${_i(sales['count'])}', _money(_d(sales['gross']))),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          Divider(height: AppSizes.lg, color: AppColors.hairline),
          _KV(l10n.cashierOpeningFloat, _money(_d(cash['openingFloat']))),
          _KV(l10n.cashierCashSales, _money(_d(cash['cashSales']))),
          _KV(l10n.cashierPayIns, _money(_d(cash['payIns']))),
          _KV(l10n.cashierPayOuts, '− ${_money(_d(cash['payOuts']))}'),
          _KV(l10n.cashierDrops, '− ${_money(_d(cash['drops']))}'),
          _KV(l10n.cashierRefunds, '− ${_money(_d(cash['refunds']))}'),
          Divider(height: AppSizes.lg, color: AppColors.hairline),
          _KV(l10n.cashierExpectedInDrawer, _money(_d(cash['expected'])), bold: true),
          if (tenders.isNotEmpty) ...[
            Divider(height: AppSizes.lg, color: AppColors.hairline),
            for (final t in tenders.cast<Map>())
              _KV('${t['mode']} (${_i(t['count'])})', _money(_d(t['amount']))),
          ],
          Divider(height: AppSizes.lg, color: AppColors.hairline),
          _KV(l10n.cashierGstTaxable, _money(_d(gst['taxable']))),
          if (_d(gst['cgst']) > 0) _KV('CGST', _money(_d(gst['cgst']))),
          if (_d(gst['sgst']) > 0) _KV('SGST', _money(_d(gst['sgst']))),
          if (_d(gst['igst']) > 0) _KV('IGST', _money(_d(gst['igst']))),
          if (_i(returns['count']) > 0) ...[
            Divider(height: AppSizes.lg, color: AppColors.hairline),
            _KV(l10n.cashierReturnsCount('${_i(returns['count'])}'), '− ${_money(_d(returns['amount']))}'),
          ],
        ],
      ),
    );
  }
}

class _OpenShiftForm extends StatefulWidget {
  const _OpenShiftForm({required this.busy, required this.onOpen});
  final bool busy;
  final void Function(double float) onOpen;
  @override
  State<_OpenShiftForm> createState() => _OpenShiftFormState();
}

class _OpenShiftFormState extends State<_OpenShiftForm> {
  final _ctrl = TextEditingController();
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: _Card(
        title: l10n.cashierOpenShiftTitle,
        icon: Icons.lock_open_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.cashierOpenShiftHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            const SizedBox(height: AppSizes.md),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: l10n.cashierOpeningFloatField, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: AppSizes.md),
            FilledButton.icon(
              onPressed: widget.busy ? null : () => widget.onOpen(_parseAmount(_ctrl.text) ?? 0),
              icon: const Icon(Icons.lock_open_rounded),
              label: Text(l10n.cashierOpenShiftButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashDrawerCard extends StatefulWidget {
  const _CashDrawerCard({required this.busy, required this.onRecord});
  final bool busy;
  final void Function(String type, double amount, String? reason) onRecord;
  @override
  State<_CashDrawerCard> createState() => _CashDrawerCardState();
}

class _CashDrawerCardState extends State<_CashDrawerCard> {
  String _type = 'PAY_IN';
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Card(
      title: l10n.cashierCashDrawerTitle,
      icon: Icons.savings_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(spacing: AppSizes.sm, children: [
            for (final t in [('PAY_IN', l10n.cashierPayIn), ('PAY_OUT', l10n.cashierPayOut), ('DROP', l10n.cashierDrop)])
              ChoiceChip(label: Text(t.$2), selected: _type == t.$1, onSelected: (_) => setState(() => _type = t.$1)),
          ]),
          const SizedBox(height: AppSizes.sm),
          TextField(controller: _amount, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: l10n.cashierAmountField, border: const OutlineInputBorder())),
          const SizedBox(height: AppSizes.sm),
          TextField(controller: _reason, decoration: InputDecoration(labelText: l10n.cashierReasonField, border: const OutlineInputBorder())),
          const SizedBox(height: AppSizes.sm),
          FilledButton(
            onPressed: widget.busy
                ? null
                : () {
                    final a = _parseAmount(_amount.text) ?? 0;
                    if (a <= 0) return;
                    widget.onRecord(_type, a, _reason.text.trim());
                    _amount.clear();
                    _reason.clear();
                  },
            child: Text(l10n.cashierRecordButton),
          ),
        ],
      ),
    );
  }
}

class _CloseShiftCard extends StatefulWidget {
  const _CloseShiftCard({required this.expected, required this.busy, required this.onClose});
  final double expected;
  final bool busy;
  final void Function(double counted, String? note) onClose;
  @override
  State<_CloseShiftCard> createState() => _CloseShiftCardState();
}

class _CloseShiftCardState extends State<_CloseShiftCard> {
  final _counted = TextEditingController();
  final _note = TextEditingController();
  @override
  void dispose() {
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final counted = _parseAmount(_counted.text);
    final variance = counted == null ? null : counted - widget.expected;
    return _Card(
      title: l10n.cashierCloseShiftTitle,
      icon: Icons.lock_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.cashierExpectedInDrawerValue(_money(widget.expected)),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
          const SizedBox(height: AppSizes.sm),
          TextField(
            controller: _counted,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.cashierCountedCashField, border: const OutlineInputBorder()),
          ),
          if (variance != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSizes.xs),
              child: Text(
                l10n.cashierVarianceValue(
                  '${variance >= 0 ? '+' : ''}${_money(variance)}',
                  variance == 0 ? l10n.cashierVarianceBalanced : variance > 0 ? l10n.cashierVarianceOver : l10n.cashierVarianceShort,
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: variance == 0 ? AppColors.success : AppColors.warning),
              ),
            ),
          const SizedBox(height: AppSizes.sm),
          TextField(controller: _note, decoration: InputDecoration(labelText: l10n.cashierNoteField, border: const OutlineInputBorder())),
          const SizedBox(height: AppSizes.sm),
          FilledButton.icon(
            onPressed: widget.busy || counted == null ? null : () => widget.onClose(counted, _note.text.trim()),
            icon: const Icon(Icons.lock_outline_rounded),
            label: Text(l10n.cashierCloseZReportButton),
          ),
        ],
      ),
    );
  }
}

class _ReturnsCard extends StatefulWidget {
  const _ReturnsCard({required this.ds, required this.busy, required this.onChanged, required this.run});
  final CashierRemoteDataSource ds;
  final bool busy;
  final Future<void> Function() onChanged;
  final Future<void> Function(Future<void> Function()) run;
  @override
  State<_ReturnsCard> createState() => _ReturnsCardState();
}

class _ReturnsCardState extends State<_ReturnsCard> {
  final _invoiceId = TextEditingController();
  Map<String, dynamic>? _returnable;
  final Map<int, TextEditingController> _qty = {};
  String _refundMode = 'CASH';

  @override
  void dispose() {
    _invoiceId.dispose();
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lines = (_returnable?['lines'] as List?)?.cast<Map>() ?? const [];
    return _Card(
      title: l10n.cashierReturnsTitle,
      icon: Icons.assignment_return_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _invoiceId,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.cashierOriginalInvoiceIdField, border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            OutlinedButton(
              onPressed: widget.busy
                  ? null
                  : () => widget.run(() async {
                        final id = int.tryParse(_invoiceId.text.trim());
                        if (id == null) return;
                        final r = await widget.ds.returnable(id);
                        if (!mounted) return;
                        setState(() {
                          _returnable = r;
                          _qty.clear();
                        });
                      }),
              child: Text(l10n.cashierLookUpButton),
            ),
          ]),
          if (_returnable != null) ...[
            const SizedBox(height: AppSizes.sm),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${l['name']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(l10n.cashierReturnableLine('${_i(l['returnableQty'])}', _money(_d(l['unitPrice']))),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                    ]),
                  ),
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: _qty.putIfAbsent(_i(l['productId']), () => TextEditingController()),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      enabled: _i(l['returnableQty']) > 0,
                      decoration: const InputDecoration(hintText: '0', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(vertical: 8)),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: AppSizes.sm),
            Wrap(spacing: AppSizes.sm, children: [
              for (final m in const ['CASH', 'UPI', 'CARD', 'OTHER'])
                ChoiceChip(label: Text(m), selected: _refundMode == m, onSelected: (_) => setState(() => _refundMode = m)),
            ]),
            const SizedBox(height: AppSizes.sm),
            FilledButton.icon(
              onPressed: widget.busy
                  ? null
                  : () => widget.run(() async {
                        final reqLines = <Map<String, dynamic>>[];
                        _qty.forEach((productId, ctrl) {
                          final q = double.tryParse(ctrl.text.trim()) ?? 0;
                          if (q > 0) reqLines.add({'productId': productId, 'quantity': q});
                        });
                        if (reqLines.isEmpty) throw Exception(l10n.cashierEnterQuantityError);
                        final messenger = ScaffoldMessenger.of(context);
                        final res = await widget.ds.processReturn(
                          originalInvoiceId: _i(_returnable!['invoiceId']),
                          refundMode: _refundMode,
                          lines: reqLines,
                        );
                        if (!mounted) return;
                        messenger.showSnackBar(SnackBar(
                            content: Text(l10n.cashierCreditNoteCreated('${res['creditNoteNo']}', _money(_d(res['refundAmount']))))));
                        setState(() => _returnable = null);
                        await widget.onChanged();
                      }),
              icon: const Icon(Icons.assignment_return_outlined),
              label: Text(l10n.cashierProcessReturnButton),
            ),
          ],
        ],
      ),
    );
  }
}
