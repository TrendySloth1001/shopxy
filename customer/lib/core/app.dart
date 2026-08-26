import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/lifecycle/lifecycle_observer.dart';
import 'package:shopxy_customer/core/router/app_shell.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:shopxy_customer/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:shopxy_customer/features/home/presentation/services/tracking_service.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/theme/app_theme.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

class ShopxyCustomerApp extends StatelessWidget {
  const ShopxyCustomerApp({super.key, this.navigatorKey});

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

  static T? _maybeRead<T>(BuildContext context) {
    try {
      return Provider.of<T>(context, listen: false);
    } catch (_) {
      return null;
    }
  }
}

class _RootView extends StatelessWidget {
  const _RootView();

  @override
  Widget build(BuildContext context) {
    final authLoading = context.select<AuthProvider, bool>((a) => a.isLoading);
    final onboarding = context.watch<OnboardingController>();
    if (authLoading || !onboarding.loaded) return const _Splash();
    if (!onboarding.seen) return const OnboardingPage();
    return const CustomerShell();
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
              child: const AppIcon(
                AppIcons.storefrontRounded,
                size: AppSizes.iconXl,
                color: AppColors.white,
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            Text(
              AppStrings.appName,
              style: theme.textTheme.headlineSmall?.bold,
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
