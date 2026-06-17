import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/scan_console/data/scan_console_remote_data_source.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Continuous "scan to console" mode. Every barcode/QR the merchant scans is
/// POSTed to the backend, which resolves it to a product and pushes it live to
/// the web Scan console. The phone is the publisher; the web is the live list.
///
/// The same code re-scanned after a short cooldown bumps its quantity on the
/// web (POS-style); tight bursts from consecutive camera frames are debounced.
class ScanConsolePage extends StatefulWidget {
  const ScanConsolePage({super.key});

  @override
  State<ScanConsolePage> createState() => _ScanConsolePageState();
}

class _ScanConsolePageState extends State<ScanConsolePage> {
  final MobileScannerController _controller = MobileScannerController();
  late final ScanConsoleRemoteDataSource _ds;

  final List<_Sent> _recent = [];
  int _sentCount = 0;
  String? _lastCode;
  DateTime? _lastAt;

  @override
  void initState() {
    super.initState();
    _ds = ScanConsoleRemoteDataSource(context.read<ApiClient>());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue;
    if (code == null || code.isEmpty) return;

    // Debounce a burst of identical frames; a deliberate re-scan after the
    // cooldown is allowed through so it bumps the quantity on the console.
    final now = DateTime.now();
    if (code == _lastCode &&
        _lastAt != null &&
        now.difference(_lastAt!) < const Duration(milliseconds: 1200)) {
      return;
    }
    _lastCode = code;
    _lastAt = now;
    unawaited(_send(code));
  }

  Future<void> _send(String code) async {
    try {
      final product = await _ds.pushScan(code);
      if (!mounted) return;
      setState(() {
        _recent.insert(
          0,
          _Sent(
            title: product?.name ?? code,
            subtitle: product != null ? product.sku : 'No match in this shop',
            ok: product != null,
            at: DateTime.now(),
          ),
        );
        if (product != null) _sentCount++;
        if (_recent.length > 30) _recent.removeLast();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Could not send scan: $e')),
        );
    }
  }

  Future<void> _clear() async {
    try {
      await _ds.clearConsole();
      if (!mounted) return;
      setState(() {
        _recent.clear();
        _sentCount = 0;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Scan to console'),
        actions: [
          TextButton.icon(
            onPressed: _recent.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_sweep_outlined, size: AppSizes.iconSm),
            label: const Text('Clear'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Scanner viewport.
          SizedBox(
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: AppColors.black),
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: ShapeDecoration(
                      shape: AppShapes.squircle(
                        AppSizes.radiusLg,
                        side: const BorderSide(color: AppColors.white, width: 3),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Status strip.
          Container(
            width: double.infinity,
            color: AppColors.brandSoft,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.xl,
              vertical: AppSizes.md,
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering_rounded,
                    size: AppSizes.iconMd, color: AppColors.brandStrong),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    _sentCount == 0
                        ? 'Open the Scan console on the web — scans appear there live.'
                        : '$_sentCount sent · live on the web Scan console',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.brandStrong),
                  ),
                ),
              ],
            ),
          ),
          // Recent sends (local feedback so the scanner sees confirmation too).
          Expanded(
            child: _recent.isEmpty
                ? Center(
                    child: Text(
                      'Point the camera at a product barcode or QR.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    itemCount: _recent.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.hairline),
                    itemBuilder: (_, i) => _SentTile(sent: _recent[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Sent {
  _Sent({
    required this.title,
    required this.subtitle,
    required this.ok,
    required this.at,
  });
  final String title;
  final String subtitle;
  final bool ok;
  final DateTime at;
}

class _SentTile extends StatelessWidget {
  const _SentTile({required this.sent});
  final _Sent sent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = sent.ok ? AppColors.success : AppColors.error;
    final soft = sent.ok ? AppColors.successSoft : AppColors.errorSoft;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: AppSizes.avatarMd,
        height: AppSizes.avatarMd,
        decoration: ShapeDecoration(
          color: soft,
          shape: AppShapes.squircle(AppSizes.radiusMd),
        ),
        child: Icon(
          sent.ok ? Icons.check_rounded : Icons.close_rounded,
          color: color,
          size: AppSizes.iconMd,
        ),
      ),
      title: Text(
        sent.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        sent.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
      ),
    );
  }
}
