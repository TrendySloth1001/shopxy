import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/pages/login_page.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

/// Heart toggle for product cards + detail pages. Animates the icon
/// crossfade when the saved-state flips. Optimistic — taps update
/// [WishlistProvider] immediately; failures roll back and surface a
/// snackbar.
///
/// Two variants:
///   * default — 32dp tap target with a soft circle background.
///     Use on cards/lists where the heart sits over imagery.
///   * `.flat` — no background, smaller hit area. Use in app bar
///     actions or inline rows.
class WishlistHeartButton extends StatelessWidget {
  const WishlistHeartButton({
    super.key,
    required this.productId,
    this.size = 32,
  }) : flat = false;

  const WishlistHeartButton.flat({super.key, required this.productId})
      : size = 40,
        flat = true;

  final int productId;
  final double size;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final saved = context.select<WishlistProvider, bool>(
      (p) => p.contains(productId),
    );
    final iconSize = flat ? 22.0 : size * 0.55;

    return Semantics(
      label: saved ? 'Remove from saved' : 'Save for later',
      button: true,
      child: GestureDetector(
        onTap: () => _onTap(context),
        child: AnimatedContainer(
          duration: AppDurations.short,
          curve: Curves.easeOut,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: flat
                ? Colors.transparent
                : (saved
                    ? AppColors.accentRoseSoft
                    : AppColors.white.withValues(alpha: 0.92)),
            shape: BoxShape.circle,
            border: flat
                ? null
                : Border.all(color: AppColors.hairline, width: 1),
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: AppDurations.short,
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey<bool>(saved),
              size: iconSize,
              color: saved ? AppColors.accentRose : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    // Guests can't save — backend requires auth. Prompt them to sign in
    // and replay the toggle after a successful login so the tap intent
    // is preserved instead of silently dropped.
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      final signedIn = await _promptSignIn(context);
      if (!context.mounted) return;
      if (signedIn != true || !auth.isAuthenticated) return;
      // Fall through and perform the toggle now that we're signed in.
    }
    final provider = context.read<WishlistProvider>();
    final wasSaved = provider.contains(productId);
    final ok = await provider.toggle(productId);
    if (!ok && context.mounted) {
      showAppSnackbar(
        context,
        message: provider.error ?? 'Could not update saved items',
        tone: AppSnackbarTone.error,
      );
      return;
    }
    if (context.mounted) {
      showAppSnackbar(
        context,
        message: wasSaved ? 'Removed from saved' : 'Added to saved',
        tone: wasSaved ? AppSnackbarTone.neutral : AppSnackbarTone.success,
      );
    }
  }

  Future<bool?> _promptSignIn(BuildContext context) {
    // Use the root navigator for the LoginPage push so we don't lose
    // the route when the bottom-sheet's local navigator dismisses.
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sign in to save items',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your saved items follow you across devices when you sign in.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () async {
                // Push login from the ROOT navigator first so the sheet
                // stays on screen during the login flow. Only pop the
                // sheet AFTER login returns. Pop with `true` only when
                // the user actually signed in, so the caller's
                // `auth.isAuthenticated` check sees the new state.
                await rootNavigator.push(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Sign in'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
