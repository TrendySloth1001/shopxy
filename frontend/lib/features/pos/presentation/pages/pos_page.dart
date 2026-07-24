import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/cashier/data/cashier_remote_data_source.dart';
import 'package:shopxy/features/cashier/presentation/pages/cashier_page.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/payments/razorpay_checkout.dart';
import 'package:shopxy/features/pos/data/pos_models.dart';
import 'package:shopxy/features/pos/presentation/pos_sale_client.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

int _i(Object? v) => v is num ? v.toInt() : 0;
double _d(Object? v) => v is num ? v.toDouble() : 0;

String _elapsedSince(Object? openedAt) {
  final start = DateTime.tryParse(openedAt?.toString() ?? '');
  if (start == null) return '00:00:00';
  final d = DateTime.now().difference(start);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

/// Phone POS till: scan items into the shared cart, see it live (shared with the
/// web till), and check out to a GST bill. Reuses the same backend + the
/// scan-console WebSocket as the web till.
class PosPage extends StatefulWidget {
  const PosPage({super.key, this.kiosk = false});

  /// Kiosk mode (a Cashier-role login): the till is the whole app, so a log-out
  /// action is surfaced in the app bar.
  final bool kiosk;

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final MobileScannerController _controller = MobileScannerController();
  late final PosSaleClient _client;
  late final CashierRemoteDataSource _cashierDs;
  String? _lastCode;
  DateTime? _lastAt;
  bool _shownInvoice = false;
  Map<String, dynamic>? _shift;
  Timer? _ticker;

  bool get _shiftOpen => _shift != null && _shift!['status'] == 'OPEN';

  @override
  void initState() {
    super.initState();
    _client = PosSaleClient(context.read<ApiClient>())..addListener(_onChange);
    _client.start();
    _cashierDs = CashierRemoteDataSource(context.read<ApiClient>());
    _loadShift();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _shiftOpen) setState(() {});
    });
  }

  Future<void> _loadShift() async {
    try {
      final res = await _cashierDs.current();
      if (mounted) {
        setState(() => _shift = res['shift'] as Map<String, dynamic>?);
      }
    } catch (_) {
      /* the WS gate is the backstop */
    }
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    final inv = _client.checkoutInvoiceNo;
    if (inv != null && !_shownInvoice) {
      _shownInvoice = true;
      _controller.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) => _showReceipt(inv));
    } else if (inv == null && _client.isClosed && !_shownInvoice) {
      // Closed on another till (or voided) — show a terminal state too.
      _shownInvoice = true;
      _controller.stop();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showReceipt('completed on another till'),
      );
    }
    final unknown = _client.unknownCode;
    if (unknown != null && !_quickAddOpen) {
      _quickAddOpen = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showQuickAdd(unknown),
      );
    }
    // Online payment settled → terminal receipt.
    final paid = _client.onlinePaidAmount;
    if (paid != null && !_shownInvoice) {
      _shownInvoice = true;
      _controller.stop();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showReceipt('paid ₹${paid.toStringAsFixed(2)} online'),
      );
    }
  }

  bool _quickAddOpen = false;
  bool _payingOnline = false;

  /// Online tender: create an order, open Razorpay Checkout (UPI QR + cards),
  /// then settle. The pos.checkout event flips the till to paid; syncOnline is
  /// the webhook backstop.
  Future<void> _payOnline() async {
    if (_payingOnline) return;
    _payingOnline = true;
    try {
      final session = await _client.startOnline();
      if (session == null || !mounted) return; // error shown in the banner
      final clientParams = (session['clientParams'] as Map)
          .cast<String, dynamic>();
      final result = await RazorpayCheckout().open(clientParams: clientParams);
      if (!mounted) return;
      if (result.isSuccess) {
        await _client.syncOnline();
      } else {
        await _client.cancelOnline();
        if (result.outcome == RazorpayOutcome.failed && mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.message ?? l10n.posPaymentFailedRetry),
            ),
          );
        }
      }
    } finally {
      _payingOnline = false;
    }
  }

  Future<void> _showQuickAdd(String code) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final taxCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '1');
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${l10n.posNewItem} · $code'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: l10n.posName),
              ),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.posSellingPrice),
              ),
              TextField(
                controller: taxCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.posGstPercentOptional,
                ),
              ),
              TextField(
                controller: stockCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.posOnHand),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.posCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.posAdd),
          ),
        ],
      ),
    );
    _quickAddOpen = false;
    final price = double.tryParse(priceCtrl.text.trim());
    if (added == true &&
        nameCtrl.text.trim().isNotEmpty &&
        price != null &&
        price > 0) {
      await _client.quickAdd(
        code: code,
        name: nameCtrl.text.trim(),
        sellingPrice: price,
        taxPercent: double.tryParse(taxCtrl.text.trim()),
        openingStock: double.tryParse(stockCtrl.text.trim()),
      );
    } else {
      _client.clearUnknown();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _client.removeListener(_onChange);
    _client.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_shiftOpen) return; // gate: no scanning until a shift is open
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    final now = DateTime.now();
    if (code == _lastCode &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastCode = code;
    _lastAt = now;
    _client.scan(code);
  }

  Future<void> _showReceipt(String invoiceNo) async {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: AppIcon(
          AppIcons.checkCircleRounded,
          color: AppColors.success,
          size: AppSizes.iconHuge,
        ),
        title: Text(l10n.posSaleComplete),
        content: Text('${l10n.posInvoice} $invoiceNo'),
        actions: [
          if (_client.checkoutInvoiceId != null)
            TextButton.icon(
              onPressed: () => _printReceipt(
                _client.checkoutInvoiceId!,
                _client.checkoutInvoiceNo ?? 'receipt',
              ),
              icon: const AppIcon(AppIcons.printOutlined),
              label: Text(l10n.posPrint),
            ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // leave the till; reopen for a fresh sale
            },
            child: Text(l10n.posDone),
          ),
        ],
      ),
    );
  }

  /// Fetch the invoice PDF (authed) and open it in the device viewer (print/share).
  Future<void> _printReceipt(String invoiceId, String invoiceNo) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      final ds = context.read<InvoicesRemoteDataSource>();
      final response = await ds.downloadPdf(invoiceId);
      if (response.statusCode != 200) {
        throw Exception(l10n.posCouldNotGenerateReceipt);
      }
      final dir = await getApplicationDocumentsDirectory();
      final safe = invoiceNo.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final file = File('${dir.path}/$safe.pdf');
      await file.writeAsBytes(response.bodyBytes);
      await OpenFilex.open(file.path);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _editLineDiscount(SaleLine line) async {
    final l10n = AppLocalizations.of(context);
    final gross = line.unitPrice * line.quantity;
    final ctrl = TextEditingController(
      text: line.lineDiscount > 0 ? line.lineDiscount.toStringAsFixed(2) : '',
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.posDiscountMax(gross.toStringAsFixed(2)),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              children: [
                for (final pct in const [5, 10, 20])
                  ActionChip(
                    label: Text('$pct%'),
                    onPressed: () =>
                        ctrl.text = (gross * pct / 100).toStringAsFixed(2),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.posCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim()) ?? 0),
            child: Text(l10n.posApply),
          ),
        ],
      ),
    );
    if (amount != null && amount >= 0) {
      await _client.setLineDiscount(
        line.productId,
        amount > gross ? gross : amount,
      );
    }
  }

  Future<void> _editBillDiscount() async {
    final l10n = AppLocalizations.of(context);
    final current = _client.snapshot?.headerDiscount ?? 0;
    final ctrl = TextEditingController(
      text: current > 0 ? current.toStringAsFixed(2) : '',
    );
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.posBillDiscount),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.posDiscount,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.posCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim()) ?? 0),
            child: Text(l10n.posApply),
          ),
        ],
      ),
    );
    if (amount != null && amount >= 0) await _client.setHeaderDiscount(amount);
  }

  void _openCheckoutSheet() {
    final l10n = AppLocalizations.of(context);
    final total = _client.snapshot?.totals.total ?? 0;
    final cashCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppSizes.xl,
          right: AppSizes.xl,
          top: AppSizes.xl,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSizes.xl,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) {
            final theme = Theme.of(ctx);
            final received = double.tryParse(cashCtrl.text.trim());
            final change = received == null ? null : received - total;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${l10n.posCollect} ₹${total.toStringAsFixed(2)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.bold,
                ),
                const SizedBox(height: AppSizes.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.posCustomerOptional,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: l10n.posPhone,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                TextField(
                  controller: cashCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setSheet(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.posCashReceived,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (change != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSizes.sm),
                    child: Text(
                      '${l10n.posChangeDue}: ₹${(change < 0 ? 0 : change).toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: change < 0 ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSizes.md),
                FilledButton.icon(
                  onPressed: (received != null && received >= total)
                      ? () {
                          Navigator.pop(ctx);
                          _client.checkout(
                            'CASH',
                            customerName: nameCtrl.text.trim(),
                            customerPhone: phoneCtrl.text.trim(),
                          );
                        }
                      : null,
                  icon: const AppIcon(AppIcons.paymentsOutlined),
                  label: Text(l10n.posCashDone),
                ),
                const SizedBox(height: AppSizes.lg),
                Text(
                  l10n.posOtherTenders,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final m in const ['UPI', 'CARD', 'OTHER'])
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _client.checkout(
                            m,
                            customerName: nameCtrl.text.trim(),
                            customerPhone: phoneCtrl.text.trim(),
                          );
                        },
                        child: Text(m),
                      ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _payOnline();
                      },
                      icon: const AppIcon(AppIcons.smartphoneRounded),
                      label: Text(l10n.posOnline),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openSearch() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _ProductSearchSheet(client: _client),
      ),
    );
  }

  Future<void> _openHeldBills() async {
    final l10n = AppLocalizations.of(context);
    final bills = await _client.listOpen();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (ctx) => SafeArea(
        child: bills.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(AppSizes.xl),
                child: Text(l10n.posNoHeldBills, textAlign: TextAlign.center),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    child: Text(
                      l10n.posHeldBills,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final b in bills)
                    ListTile(
                      title: Text(
                        (b['customerName'] as String?) ??
                            '${l10n.posBill} #${b['id']}',
                      ),
                      subtitle: Text(l10n.posItemCount('${b['lineCount']}')),
                      trailing: const AppIcon(AppIcons.chevronRightRounded),
                      onTap: () {
                        Navigator.pop(ctx);
                        _client.recall(b['id'].toString());
                      },
                    ),
                ],
              ),
      ),
    );
  }

  /// Tap a line's quantity to type it directly (0 removes the line).
  Future<void> _editQty(SaleLine line) async {
    final l10n = AppLocalizations.of(context);
    final ctrl = TextEditingController(
      text: line.quantity.toStringAsFixed(line.quantity % 1 == 0 ? 0 : 2),
    );
    final qty = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: l10n.posQuantity,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, double.tryParse(v.trim())),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.posCancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(ctrl.text.trim())),
            child: Text(l10n.posSet),
          ),
        ],
      ),
    );
    if (qty != null && qty >= 0) await _client.setQty(line.productId, qty);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final snap = _client.snapshot;
    final lines = snap?.lines ?? const <SaleLine>[];
    final total = snap?.totals.total ?? 0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.posTitle,
        actions: [
          IconButton(
            tooltip: l10n.posFindItem,
            onPressed: _shiftOpen ? _openSearch : null,
            icon: const AppIcon(AppIcons.searchRounded),
          ),
          IconButton(
            tooltip: l10n.posCashierTooltip,
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CashierPage()))
                .then((_) => _loadShift()),
            icon: const AppIcon(AppIcons.calculateOutlined),
          ),
          IconButton(
            tooltip: l10n.posHold,
            onPressed: () => _client.holdAndNew(),
            icon: const AppIcon(AppIcons.pauseCircleOutlineRounded),
          ),
          IconButton(
            tooltip: l10n.posRecall,
            onPressed: _openHeldBills,
            icon: const AppIcon(AppIcons.restoreRounded),
          ),
          if (widget.kiosk)
            IconButton(
              tooltip: l10n.posLogOut,
              onPressed: () => context.read<AuthProvider>().logout(),
              icon: const AppIcon(AppIcons.logoutRounded),
            ),
          _StatusChip(status: _client.status),
        ],
      ),
      body: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          children: [
            if (_shiftOpen)
              Container(
                width: double.infinity,
                color: AppColors.tileBg(AppColors.brandSoft),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.lg,
                  vertical: AppSizes.sm,
                ),
                child: Row(
                  children: [
                    AppIcon(
                      AppIcons.accountCircleOutlined,
                      size: AppSizes.iconSm,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Expanded(
                      child: Text(
                        '${_shift!['openedByName'] ?? l10n.posCashier}'
                        '${_shift!['openedByEmail'] != null ? ' · ${_shift!['openedByEmail']}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.semibold,
                      ),
                    ),
                    AppIcon(
                      AppIcons.timerOutlined,
                      size: AppSizes.iconSm,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Text(
                      _elapsedSince(_shift!['openedAt']),
                      style: theme.textTheme.bodySmall?.bold,
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                color: AppColors.warningSoft,
                padding: const EdgeInsets.all(AppSizes.md),
                child: Row(
                  children: [
                    AppIcon(
                      AppIcons.lockOutlineRounded,
                      size: AppSizes.iconSm,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Expanded(
                      child: Text(
                        l10n.posOpenShiftToBill,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context)
                          .push(
                            MaterialPageRoute(
                              builder: (_) => const CashierPage(),
                            ),
                          )
                          .then((_) => _loadShift()),
                      child: Text(l10n.posOpenShift),
                    ),
                  ],
                ),
              ),
            SizedBox(
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: AppColors.canvas),
                  MobileScanner(controller: _controller, onDetect: _onDetect),
                  Center(
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: ShapeDecoration(
                        shape: AppShapes.squircle(
                          AppSizes.radiusLg,
                          side: BorderSide(color: AppColors.black, width: 3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_client.error != null)
              Container(
                width: double.infinity,
                color: AppColors.errorSoft,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.xl,
                  vertical: AppSizes.sm,
                ),
                child: Text(
                  _client.error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            Expanded(
              child: lines.isEmpty
                  ? Center(
                      child: Text(
                        l10n.posScanFirstItem,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      itemCount: lines.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: AppColors.hairline),
                      itemBuilder: (_, i) => _CartTile(
                        line: lines[i],
                        onInc: () => _client.setQty(
                          lines[i].productId,
                          lines[i].quantity + 1,
                        ),
                        onDec: () => _client.setQty(
                          lines[i].productId,
                          lines[i].quantity - 1,
                        ),
                        onRemove: () => _client.removeItem(lines[i].productId),
                        onTapQty: () => _editQty(lines[i]),
                        onDiscount: () => _editLineDiscount(lines[i]),
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.posTotal,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            '₹${total.toStringAsFixed(2)}',
                            style: theme.textTheme.titleLarge?.bold,
                          ),
                        ],
                      ),
                    ),
                    if (lines.isNotEmpty)
                      IconButton(
                        tooltip: l10n.posBillDiscount,
                        onPressed: _editBillDiscount,
                        icon: const AppIcon(AppIcons.percentRounded),
                      ),
                    FilledButton.icon(
                      onPressed: lines.isEmpty ? null : _openCheckoutSheet,
                      icon: const AppIcon(AppIcons.pointOfSaleRounded),
                      label: Text(l10n.posCheckout),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({
    required this.line,
    required this.onInc,
    required this.onDec,
    required this.onRemove,
    required this.onTapQty,
    required this.onDiscount,
  });
  final SaleLine line;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;
  final VoidCallback onTapQty;
  final VoidCallback onDiscount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.semibold,
              ),
              Text(
                '${line.sku} · ₹${line.unitPrice.toStringAsFixed(2)}${line.lineDiscount > 0 ? ' · −₹${line.lineDiscount.toStringAsFixed(2)}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onDiscount,
          tooltip: l10n.posLineDiscount,
          icon: AppIcon(
            AppIcons.percentRounded,
            color: line.lineDiscount > 0 ? AppColors.brand : AppColors.muted,
          ),
          iconSize: AppSizes.iconSm,
        ),
        IconButton(
          onPressed: onDec,
          icon: const AppIcon(AppIcons.removeCircleOutline),
          iconSize: AppSizes.iconMd,
        ),
        // Tap the quantity to type it directly.
        InkWell(
          onTap: onTapQty,
          borderRadius: BorderRadius.circular(AppSizes.radiusSm),
          child: Container(
            constraints: const BoxConstraints(minWidth: 36),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sm,
              vertical: 4,
            ),
            alignment: Alignment.center,
            child: Text(
              line.quantity.toStringAsFixed(line.quantity % 1 == 0 ? 0 : 2),
              style: theme.textTheme.titleSmall?.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: onInc,
          icon: const AppIcon(AppIcons.addCircleOutline),
          iconSize: AppSizes.iconMd,
        ),
        SizedBox(
          width: 72,
          child: Text(
            '₹${line.total.toStringAsFixed(2)}',
            textAlign: TextAlign.right,
            style: theme.textTheme.titleSmall?.bold,
          ),
        ),
        IconButton(
          onPressed: onRemove,
          icon: const AppIcon(AppIcons.closeRounded),
          iconSize: AppSizes.iconSm,
          color: AppColors.muted,
        ),
      ],
    );
  }
}

class _ProductSearchSheet extends StatefulWidget {
  const _ProductSearchSheet({required this.client});
  final PosSaleClient client;
  @override
  State<_ProductSearchSheet> createState() => _ProductSearchSheetState();
}

class _ProductSearchSheetState extends State<_ProductSearchSheet> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  int _seq = 0;
  List<Map<String, dynamic>> _results = const [];
  bool _searching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    final t = v.trim();
    if (t.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    final seq = ++_seq;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final r = await widget.client.searchProducts(t);
      if (mounted && seq == _seq) {
        setState(() {
          _results = r;
          _searching = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                labelText: l10n.posFindItemByNameSku,
                prefixIcon: const AppIcon(AppIcons.searchRounded),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: _searching && _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      child: Text(l10n.posSearching),
                    )
                  : _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      child: Text(l10n.posTypeToSearch),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (_, i) {
                        final p = _results[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${p['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${p['sku']} · ${l10n.posStock} ${_i(p['stock'])}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          trailing: Text(
                            '₹${_d(p['sellingPrice']).toStringAsFixed(2)}',
                            style: theme.textTheme.titleSmall?.bold,
                          ),
                          onTap: () {
                            widget.client.addItem(p['id'].toString());
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.posAddedItem('${p['name']}'),
                                ),
                                duration: const Duration(milliseconds: 700),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final PosConnStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    late final Color color;
    late final String label;
    switch (status) {
      case PosConnStatus.live:
        color = AppColors.success;
        label = l10n.posStatusLive;
      case PosConnStatus.connecting:
        color = AppColors.muted;
        label = l10n.posStatusConnecting;
      case PosConnStatus.reconnecting:
        color = AppColors.warning;
        label = l10n.posStatusReconnecting;
      case PosConnStatus.offline:
        color = AppColors.error;
        label = l10n.posStatusOffline;
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: AppSizes.lg),
        child: Row(
          children: [
            AppIcon(AppIcons.circle, size: 10, color: color),
            const SizedBox(width: AppSizes.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
