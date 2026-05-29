import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/lifecycle/lifecycle_observer.dart';
import 'package:shopxy_customer/core/router/app_shell.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/home/presentation/services/tracking_service.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/theme/app_theme.dart';

class ShopxyCustomerApp extends StatelessWidget {
  const ShopxyCustomerApp({super.key, this.navigatorKey});

  /// Shared root navigator key — wired up by `main.dart` so the
  /// DeepLinkHandler can push routes from outside any BuildContext.
  /// Nullable so legacy entry points (tests) can build the app without
  /// a key.
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      home: LifecycleObserver(
        onResumed: () async {
          // Best-effort re-sync on foreground: drop any locally-queued
          // analytics events so a kill from now on doesn't lose them,
          // and pull a fresh cart snapshot (server may have removed
          // out-of-stock lines or changed prices).
          final tracking = _maybeRead<TrackingService>(context);
          if (tracking != null) {
            unawaited(tracking.flush());
          }
          final cart = _maybeRead<CartProvider>(context);
          final auth = _maybeRead<AuthProvider>(context);
          if (cart != null && auth != null && auth.isAuthenticated) {
            unawaited(cart.syncFromServer(mergeLocal: false));
          }
        },
        onPaused: () async {
          final tracking = _maybeRead<TrackingService>(context);
          if (tracking != null) {
            unawaited(tracking.flush());
          }
        },
        child: const _RootView(),
      ),
    );
  }

  /// Tolerant Provider.of lookup — returns null when the type isn't
  /// registered (mostly relevant for widget tests that only mount a
  /// subset of providers).
  static T? _maybeRead<T>(BuildContext context) {
    try {
      return Provider.of<T>(context, listen: false);
    } catch (_) {
      return null;
    }
  }
}

/// Boot gate: shows the splash only while the token-check is still in
/// flight. Once auth has settled — whether the user is signed in or a
/// guest — the customer shell takes over and individual screens decide
/// what to show for guests (sign-in CTAs, public content, etc.).
class _RootView extends StatelessWidget {
  const _RootView();

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthProvider, bool>((a) => a.isLoading);
    return isLoading ? const _Splash() : const CustomerShell();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: ShapeDecoration(
                color: AppColors.brand,
                shape: AppShapes.squircle(AppSizes.radiusXl),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: AppSizes.iconXl,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            Text(
              AppStrings.appName,
              style:
                  theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSizes.xxl),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
