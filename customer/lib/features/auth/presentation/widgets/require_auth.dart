import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/pages/login_page.dart';
import 'package:shopxy_customer/features/auth/presentation/pages/register_page.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_bottom_sheet.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

/// Single sign-in gate used by every guest-blocked action. The contract:
///
///   * If the user is already signed in, `action` runs immediately and
///     the future completes with `true`.
///   * Otherwise a bottom sheet appears explaining *why* sign-in is
///     needed (the `reason` string is the body — keep it short, e.g.
///     "to add items to your cart"). Two CTAs push either [LoginPage]
///     or [RegisterPage]; both auto-pop with `true` when auth succeeds.
///   * If the user dismisses the sheet or backs out of the auth pages,
///     the future completes with `false` and `action` is **not** run.
///
/// `action` is invoked from inside this helper rather than left to the
/// caller so a successful sign-in always runs exactly the work the
/// caller wanted gated — no risk of a forgotten "then add to cart"
/// follow-up. Pass `null` if you just want the sign-in prompt.
Future<bool> requireAuth(
  BuildContext context, {
  required String reason,
  VoidCallback? action,
}) async {
  final auth = context.read<AuthProvider>();
  if (auth.isAuthenticated) {
    action?.call();
    return true;
  }

  // Capture the root navigator *before* the sheet is shown so the
  // LoginPage push lands on the app-level nav, not on a transient
  // sheet/dialog navigator that disappears with the sheet.
  final rootNavigator = Navigator.of(context, rootNavigator: true);

  final mode = await _showSignInSheet(context, reason: reason);
  if (mode == null || !context.mounted) return false;

  final signedIn = await rootNavigator.push<bool>(
    MaterialPageRoute(
      builder: (_) => mode == _SignInChoice.register
          ? const RegisterPage()
          : const LoginPage(),
    ),
  );
  if (signedIn == true) {
    action?.call();
    return true;
  }
  return false;
}

/// Top-right "Skip" affordance for the Login + Register pages. Mirrors
/// the pattern Amazon/Flipkart use: the auth page is dismissible, but
/// before letting the user out we surface a short bottom sheet listing
/// what they'll miss without an account so the dismissal is informed.
///
/// On confirmation the auth page pops with `false`, which propagates
/// back through `requireAuth` so the caller's gated action does NOT
/// run. If the user backs out of the sheet they're returned to the
/// auth page to try again.
class SkipToGuestButton extends StatelessWidget {
  const SkipToGuestButton({super.key});

  Future<void> _onPressed(BuildContext context) async {
    final confirmed = await _showSkipSheet(context);
    if (confirmed == true && context.mounted) {
      Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => _onPressed(context),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.muted,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.xs,
        ),
        textStyle: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      child: const Text('Skip'),
    );
  }
}

Future<bool?> _showSkipSheet(BuildContext context) {
  return showAppBottomSheet<bool>(
    context,
    title: 'Continue without an account?',
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.sm,
          AppSizes.lg,
          AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'You can browse shops, search products and add items to '
              'your cart without signing in.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              "You'll need an account to:",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            const _SkipBullet(
              icon: AppIcons.localShippingOutlined,
              text: 'Place orders, track them and view invoices',
            ),
            const _SkipBullet(
              icon: AppIcons.favoriteBorderRounded,
              text: 'Save items to your wishlist',
            ),
            const _SkipBullet(
              icon: AppIcons.notificationsNoneRounded,
              text: 'Receive shop invitations and order updates',
            ),
            const _SkipBullet(
              icon: AppIcons.locationOnOutlined,
              text: 'Save delivery addresses for checkout',
            ),
            const SizedBox(height: AppSizes.lg),
            AppButton.primary(
              label: 'Continue browsing',
              fullWidth: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
            const SizedBox(height: AppSizes.sm),
            AppButton.secondary(
              label: 'Sign in instead',
              fullWidth: true,
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
          ],
        ),
      );
    },
  );
}

class _SkipBullet extends StatelessWidget {
  const _SkipBullet({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconMd, color: AppColors.muted),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.black,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SignInChoice { login, register }

Future<_SignInChoice?> _showSignInSheet(
  BuildContext context, {
  required String reason,
}) {
  return showAppBottomSheet<_SignInChoice>(
    context,
    title: 'Sign in to continue',
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.sm,
          AppSizes.lg,
          AppSizes.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              reason,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            AppButton.primary(
              label: 'Sign in',
              icon: AppIcons.loginRounded,
              fullWidth: true,
              onPressed: () =>
                  Navigator.of(ctx).pop(_SignInChoice.login),
            ),
            const SizedBox(height: AppSizes.sm),
            AppButton.secondary(
              label: 'Create account',
              fullWidth: true,
              onPressed: () =>
                  Navigator.of(ctx).pop(_SignInChoice.register),
            ),
          ],
        ),
      );
    },
  );
}
