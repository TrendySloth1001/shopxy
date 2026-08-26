import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/features/scan_console/presentation/scan_console_client.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class ScanConsolePage extends StatefulWidget {
  const ScanConsolePage({super.key});

  @override
  State<ScanConsolePage> createState() => _ScanConsolePageState();
}

class _ScanConsolePageState extends State<ScanConsolePage> {
  final MobileScannerController _controller = MobileScannerController();
  late final ScanConsoleClient _client;
  final _scrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _scrollHaptics;

  String? _lastCode;
  DateTime? _lastAt;

  @override
  void initState() {
    super.initState();
    _scrollHaptics = ScrollBoundaryHaptics(_scrollCtrl);
    _client = ScanConsoleClient(context.read<ApiClient>())
      ..addListener(_onChange);
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
    _scrollHaptics.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
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
    _client.sendScan(code);
  }

  Future<void> _clear() async {
    try {
      await _client.clearConsole();
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.scanConsoleClearFailed('$e'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(
        title: l10n.scanConsoleTitle,
        actions: [
          TextButton.icon(
            onPressed: _client.recent.isEmpty ? null : _clear,
            icon: const AppIcon(
              AppIcons.deleteSweepOutlined,
              size: AppSizes.iconSm,
            ),
            label: Text(l10n.scanConsoleClear),
          ),
        ],
      ),
      body: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: Column(
          children: [
            SizedBox(height: FloatingAppBar.contentTopInset(context)),
            SizedBox(
              height: 280,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: AppColors.inverseSurface),
                  MobileScanner(controller: _controller, onDetect: _onDetect),
                  Center(
                    child: Container(
                      width: 210,
                      height: 210,
                      decoration: ShapeDecoration(
                        shape: AppShapes.squircle(
                          AppSizes.radiusLg,
                          side: BorderSide(color: AppColors.white, width: 3),
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
                        l10n.scanConsoleEmpty,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(AppSizes.lg),
                      itemCount: _client.recent.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: AppColors.hairline),
                      itemBuilder: (_, i) =>
                          _FeedbackTile(item: _client.recent[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.client});
  final ScanConsoleClient client;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    late final Color bg;
    late final Color fg;
    late final AppIconData icon;
    late final String title;
    String? subtitle;

    switch (client.status) {
      case ScanConnStatus.connected:
        bg = AppColors.successSoft;
        fg = AppColors.success;
        icon = AppIcons.checkCircleRounded;
        title = l10n.scanConsoleConnected;
        subtitle = client.consoles > 0
            ? l10n.scanConsoleWatching(client.consoles, client.sentCount)
            : l10n.scanConsoleOpenWebHint;
      case ScanConnStatus.connecting:
        bg = AppColors.surfaceTint;
        fg = AppColors.muted;
        icon = AppIcons.syncRounded;
        title = l10n.scanConsoleConnecting;
      case ScanConnStatus.reconnecting:
        bg = AppColors.warningSoft;
        fg = AppColors.warning;
        icon = AppIcons.syncProblemRounded;
        title = l10n.scanConsoleReconnecting;
      case ScanConnStatus.error:
        bg = AppColors.errorSoft;
        fg = AppColors.error;
        icon = AppIcons.errorOutlineRounded;
        title = l10n.scanConsoleNotConnected;
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
          AppIcon(icon, size: AppSizes.iconMd, color: fg),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
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
        child: AppIcon(
          item.ok ? AppIcons.checkRounded : AppIcons.closeRounded,
          color: color,
          size: AppSizes.iconMd,
        ),
      ),
      title: Text(
        item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall?.semibold,
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
