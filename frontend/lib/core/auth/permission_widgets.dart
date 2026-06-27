import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Hybrid-gating UX primitives.
///
///   • Things a staffer can't *view* → not rendered (callers just omit
///     them; use [NoAccessView] for a whole screen/tab they reached but
///     can't see).
///   • Things they can view but can't *manage* → shown but locked:
///     greyed, a small padlock, and a tap surfaces [showLockedHint]
///     ("Ask an owner for access") instead of doing the action.

/// Floating snackbar explaining a locked control. [what] names the thing,
/// e.g. showLockedHint(context, 'edit products').
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
            Icon(Icons.lock_outline_rounded,
                size: 18, color: AppColors.white),
            const SizedBox(width: AppSizes.sm),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
}

/// Wraps any interactive [child] (button, FAB, tile). When [allowed] is
/// false the child is greyed + non-interactive, with a padlock badge, and
/// a tap shows the locked hint. Use for can-view-can't-manage actions.
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
          Opacity(
            opacity: 0.45,
            child: IgnorePointer(child: child),
          ),
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
                child: Icon(Icons.lock_rounded,
                    size: 10, color: AppColors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// AppBar action that re-checks the caller's permissions on demand:
/// refetches /auth/me (so role/permission changes the owner made show
/// up) and reloads the page's own data via [onReload]. The gated widgets
/// re-evaluate reactively and any newly-allowed section mounts fresh.
///
/// Rate-limited via AuthProvider.manualRefresh (a global cooldown), so
/// it can't be used to spam the server; a tap during cooldown just
/// surfaces a "try again in Ns" hint instead of hitting the network.
class AccessReloadButton extends StatefulWidget {
  const AccessReloadButton({super.key, this.onReload, this.tooltip = 'Refresh'});

  /// Optional page-data reloader (e.g. `() => provider.load()`), run
  /// after the permission re-check.
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
        ..showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Just refreshed — try again in ${cooling.inSeconds + 1}s'),
        ));
      return;
    }
    setState(() => _busy = true);
    try {
      await auth.manualRefresh(); // re-check role + permissions
      await widget.onReload?.call(); // reload this page's data
    } catch (_) {
      // Permission re-check / reload is best-effort; ignore transient errors.
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
          : const Icon(Icons.refresh_rounded),
    );
  }
}

/// An AppBar-style icon action that locks (greys + padlock + hint) when
/// [allowed] is false instead of disappearing.
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
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final String? what;

  @override
  Widget build(BuildContext context) {
    if (allowed) {
      return IconButton(icon: Icon(icon), tooltip: tooltip, onPressed: onPressed);
    }
    return IconButton(
      tooltip: 'Locked — ask an owner',
      onPressed: () => showLockedHint(context, what),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: AppColors.subtle),
          Positioned(
            right: -3,
            bottom: -3,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                color: AppColors.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded,
                  size: 9, color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen placeholder for a tab/screen the staffer reached but isn't
/// permitted to view (used for the fixed bottom-nav tabs, which stay put
/// rather than disappearing).
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
              child: Icon(Icons.lock_outline_rounded,
                  size: 30, color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.lg),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSizes.xs),
            Text(
              message ?? 'You don\'t have access to this section. Ask an '
                  'owner to grant it from Team & roles.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
