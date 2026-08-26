import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

void showLockedHint(BuildContext context, [String? what]) {
  final msg = what == null
      ? 'You don\'t have access to do that. Ask an owner.'
      : 'You don\'t have access to $what. Ask an owner.';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            AppIcon(
              AppIcons.lockOutlineRounded,
              size: 18,
              color: AppColors.white,
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
}

class MaybeLocked extends StatelessWidget {
  const MaybeLocked({
    super.key,
    required this.allowed,
    required this.child,
    this.what,
    this.badge = true,
  });

  final bool allowed;
  final Widget child;
  final String? what;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    if (allowed) return child;
    return GestureDetector(
      onTap: () => showLockedHint(context, what),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(opacity: 0.45, child: IgnorePointer(child: child)),
          if (badge)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.muted,
                  shape: BoxShape.circle,
                ),
                child: AppIcon(
                  AppIcons.lockRounded,
                  size: 10,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AccessReloadButton extends StatefulWidget {
  const AccessReloadButton({
    super.key,
    this.onReload,
    this.tooltip = 'Refresh',
  });

  final Future<void> Function()? onReload;
  final String tooltip;

  @override
  State<AccessReloadButton> createState() => _AccessReloadButtonState();
}

class _AccessReloadButtonState extends State<AccessReloadButton> {
  bool _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    final auth = context.read<AuthProvider>();
    final cooling = auth.refreshCooldownRemaining;
    if (cooling > Duration.zero) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Just refreshed — try again in ${cooling.inSeconds + 1}s',
            ),
          ),
        );
      return;
    }
    setState(() => _busy = true);
    try {
      await auth.manualRefresh();
      await widget.onReload?.call();
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _busy ? null : _tap,
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const AppIcon(AppIcons.refreshRounded),
    );
  }
}

class LockedIconButton extends StatelessWidget {
  const LockedIconButton({
    super.key,
    required this.allowed,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.what,
  });

  final bool allowed;
  final AppIconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final String? what;

  @override
  Widget build(BuildContext context) {
    if (allowed) {
      return IconButton(
        icon: AppIcon(icon),
        tooltip: tooltip,
        onPressed: onPressed,
      );
    }
    return IconButton(
      tooltip: 'Locked — ask an owner',
      onPressed: () => showLockedHint(context, what),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          AppIcon(icon, color: AppColors.subtle),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: AppColors.muted,
                shape: BoxShape.circle,
              ),
              child: AppIcon(
                AppIcons.lockRounded,
                size: 9,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NoAccessView extends StatelessWidget {
  const NoAccessView({super.key, required this.title, this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusLg),
              ),
              alignment: Alignment.center,
              child: AppIcon(
                AppIcons.lockOutlineRounded,
                size: 30,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(title, style: theme.textTheme.titleMedium?.extraBold),
            const SizedBox(height: AppSizes.xs),
            Text(
              message ??
                  'You don\'t have access to this section. Ask an '
                      'owner to grant it from Team & roles.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
