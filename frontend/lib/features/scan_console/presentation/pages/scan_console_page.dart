import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/scan_console/presentation/scan_console_client.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Continuous "scan to console" mode. The phone holds a live WebSocket to the
/// shop room (role=scanner): every barcode/QR is pushed over the socket, the
/// backend resolves it and fans it to the web console, and acks it back. The
/// connection state + how many consoles are watching are shown up front so it's
/// obvious whether scans are actually reaching the server.
class ScanConsolePage extends StatefulWidget {
  const ScanConsolePage({super.key});

  @override
  State<ScanConsolePage> createState() => _ScanConsolePageState();
}

class _ScanConsolePageState extends State<ScanConsolePage> {
  final MobileScannerController _controller = MobileScannerController();
  late final ScanConsoleClient _client;

  String? _lastCode;
  DateTime? _lastAt;

  @override
  void initState() {
    super.initState();
    _client = ScanConsoleClient(context.read<ApiClient>())..addListener(_onChange);
    _client.start();
  }

  void _onChange() {
    if (mounted) setState(() {});
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
    _client.sendScan(code);
  }

  Future<void> _clear() async {
    try {
      await _client.clearConsole();
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
            onPressed: _client.recent.isEmpty ? null : _clear,
            icon: const Icon(Icons.delete_sweep_outlined, size: AppSizes.iconSm),
            label: const Text('Clear'),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 280,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: AppColors.black),
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Center(
                  child: Container(
                    width: 210,
                    height: 210,
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
          _ConnectionBanner(client: _client),
          Expanded(
            child: _client.recent.isEmpty
                ? Center(
                    child: Text(
                      'Point the camera at a product barcode or QR.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSizes.lg),
                    itemCount: _client.recent.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppColors.hairline),
                    itemBuilder: (_, i) => _FeedbackTile(item: _client.recent[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The "connection established on the phone end" surface.
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.client});
  final ScanConsoleClient client;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    late final Color bg;
    late final Color fg;
    late final IconData icon;
    late final String title;
    String? subtitle;

    switch (client.status) {
      case ScanConnStatus.connected:
        bg = AppColors.successSoft;
        fg = AppColors.success;
        icon = Icons.check_circle_rounded;
        title = 'Connection established';
        subtitle = client.consoles > 0
            ? '${client.consoles} console${client.consoles == 1 ? '' : 's'} watching · ${client.sentCount} sent'
            : 'Open the Scan console on the web to see scans live';
      case ScanConnStatus.connecting:
        bg = AppColors.surfaceTint;
        fg = AppColors.muted;
        icon = Icons.sync_rounded;
        title = 'Connecting…';
      case ScanConnStatus.reconnecting:
        bg = AppColors.warningSoft;
        fg = AppColors.warning;
        icon = Icons.sync_problem_rounded;
        title = 'Reconnecting…';
      case ScanConnStatus.error:
        bg = AppColors.errorSoft;
        fg = AppColors.error;
        icon = Icons.error_outline_rounded;
        title = 'Not connected';
        subtitle = client.error;
    }

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.xl,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconMd, color: fg),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(color: fg),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.item});
  final ScanFeedback item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = item.ok ? AppColors.success : AppColors.error;
    final soft = item.ok ? AppColors.successSoft : AppColors.errorSoft;
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
          item.ok ? Icons.check_rounded : Icons.close_rounded,
          color: color,
          size: AppSizes.iconMd,
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        item.subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
      ),
    );
  }
}
