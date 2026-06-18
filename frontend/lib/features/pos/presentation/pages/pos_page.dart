import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/pos/data/pos_models.dart';
import 'package:shopxy/features/pos/presentation/pos_sale_client.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

const _tenderModes = ['CASH', 'UPI', 'CARD', 'OTHER'];

/// Phone POS till: scan items into the shared cart, see it live (shared with the
/// web till), and check out to a GST bill. Reuses the same backend + the
/// scan-console WebSocket as the web till.
class PosPage extends StatefulWidget {
  const PosPage({super.key});

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  final MobileScannerController _controller = MobileScannerController();
  late final PosSaleClient _client;
  String? _lastCode;
  DateTime? _lastAt;
  bool _shownInvoice = false;

  @override
  void initState() {
    super.initState();
    _client = PosSaleClient(context.read<ApiClient>())..addListener(_onChange);
    _client.start();
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _showReceipt('completed on another till'));
    }
    final unknown = _client.unknownCode;
    if (unknown != null && !_quickAddOpen) {
      _quickAddOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showQuickAdd(unknown));
    }
  }

  bool _quickAddOpen = false;

  Future<void> _showQuickAdd(String code) async {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final taxCtrl = TextEditingController();
    final stockCtrl = TextEditingController(text: '1');
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('New item · $code'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Selling price ₹')),
              TextField(controller: taxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'GST % (optional)')),
              TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'On hand')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    _quickAddOpen = false;
    final price = double.tryParse(priceCtrl.text.trim());
    if (added == true && nameCtrl.text.trim().isNotEmpty && price != null && price > 0) {
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
    _client.removeListener(_onChange);
    _client.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    final now = DateTime.now();
    if (code == _lastCode && _lastAt != null && now.difference(_lastAt!) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastCode = code;
    _lastAt = now;
    _client.scan(code);
  }

  Future<void> _showReceipt(String invoiceNo) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: AppSizes.iconHuge),
        title: const Text('Sale complete'),
        content: Text('Invoice $invoiceNo'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // leave the till; reopen for a fresh sale
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _openCheckoutSheet() {
    final total = _client.snapshot?.totals.total ?? 0;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.white,
      shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Collect ₹${total.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSizes.xs),
            Text('Choose tender mode', textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppColors.muted)),
            const SizedBox(height: AppSizes.xl),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              alignment: WrapAlignment.center,
              children: _tenderModes
                  .map((m) => FilledButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _client.checkout(m);
                        },
                        child: Text(m),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snap = _client.snapshot;
    final lines = snap?.lines ?? const <SaleLine>[];
    final total = snap?.totals.total ?? 0;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(title: const Text('Point of sale'), actions: [_StatusChip(status: _client.status)]),
      body: Column(
        children: [
          SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.black),
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: ShapeDecoration(
                      shape: AppShapes.squircle(AppSizes.radiusLg, side: const BorderSide(color: AppColors.white, width: 3)),
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
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl, vertical: AppSizes.sm),
              child: Text(_client.error!, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error)),
            ),
          Expanded(
            child: lines.isEmpty
                ? Center(child: Text('Scan the first item.', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted)))
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    itemCount: lines.length,
                    separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.hairline),
                    itemBuilder: (_, i) => _CartTile(
                      line: lines[i],
                      onInc: () => _client.setQty(lines[i].productId, lines[i].quantity + 1),
                      onDec: () => _client.setQty(lines[i].productId, lines[i].quantity - 1),
                      onRemove: () => _client.removeItem(lines[i].productId),
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
                        Text('Total', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                        Text('₹${total.toStringAsFixed(2)}', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: lines.isEmpty ? null : _openCheckoutSheet,
                    icon: const Icon(Icons.point_of_sale_rounded),
                    label: const Text('Checkout'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({required this.line, required this.onInc, required this.onDec, required this.onRemove});
  final SaleLine line;
  final VoidCallback onInc;
  final VoidCallback onDec;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              Text('${line.sku} · ₹${line.unitPrice.toStringAsFixed(2)}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted)),
            ],
          ),
        ),
        IconButton(onPressed: onDec, icon: const Icon(Icons.remove_circle_outline), iconSize: AppSizes.iconMd),
        Text(line.quantity.toStringAsFixed(line.quantity % 1 == 0 ? 0 : 2), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        IconButton(onPressed: onInc, icon: const Icon(Icons.add_circle_outline), iconSize: AppSizes.iconMd),
        SizedBox(
          width: 72,
          child: Text('₹${line.total.toStringAsFixed(2)}', textAlign: TextAlign.right, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        IconButton(onPressed: onRemove, icon: const Icon(Icons.close_rounded), iconSize: AppSizes.iconSm, color: AppColors.muted),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final PosConnStatus status;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;
    switch (status) {
      case PosConnStatus.live:
        color = AppColors.success;
        label = 'Live';
      case PosConnStatus.connecting:
        color = AppColors.muted;
        label = 'Connecting';
      case PosConnStatus.reconnecting:
        color = AppColors.warning;
        label = 'Reconnecting';
      case PosConnStatus.offline:
        color = AppColors.error;
        label = 'Offline';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: AppSizes.lg),
        child: Row(
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: AppSizes.xs),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
