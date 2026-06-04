import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/require_auth.dart';
import 'package:shopxy_customer/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
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
    this.size = AppSizes.iconXl,
  }) : flat = false;

  const WishlistHeartButton.flat({super.key, required this.productId})
      : size = AppSizes.iconHuge,
        flat = true;

  final int productId;
  final double size;
  final bool flat;

  @override
  Widget build(BuildContext context) {
    final saved = context.select<WishlistProvider, bool>(
      (p) => p.contains(productId),
    );
    final iconSize = flat ? AppSizes.iconMd : size * 0.55;

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
    final signedIn = await requireAuth(
      context,
      reason: 'Your saved items follow you across devices when you sign in.',
    );
    if (!signedIn || !context.mounted) return;

    final provider = context.read<WishlistProvider>();
    final wasSaved = provider.contains(productId);
    final ok = await provider.toggle(productId);
    if (!context.mounted) return;
    if (!ok) {
      showAppSnackbar(
        context,
        message: provider.error ?? 'Could not update saved items',
        tone: AppSnackbarTone.error,
      );
      return;
    }
    showAppSnackbar(
      context,
      message: wasSaved ? 'Removed from saved' : 'Added to saved',
      tone: wasSaved ? AppSnackbarTone.neutral : AppSnackbarTone.success,
    );
  }
}
