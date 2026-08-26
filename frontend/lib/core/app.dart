import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/session_route_guard.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/core/network/offline/offline_banner.dart';
import 'package:shopxy/core/prefs/locale_prefs.dart';
import 'package:shopxy/core/prefs/prefs_storage.dart';
import 'package:shopxy/core/prefs/theme_prefs.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/features/auth/presentation/pages/login_page.dart';
import 'package:shopxy/features/auth/presentation/pages/recovery_pin_setup_page.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy/features/shop/presentation/pages/join_request_page.dart';
import 'package:shopxy/features/shop/presentation/pages/onboarding_shop_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_palette.dart';
import 'package:shopxy/shared/theme/app_theme.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

class ShopxyApp extends StatelessWidget {
  const ShopxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LocalePrefsProvider>(
      create: (_) => LocalePrefsProvider(appPrefsStorage)..load(),
      child: Consumer<LocalePrefsProvider>(
        builder: (context, localePrefs, _) {
          final themePrefs = context.watch<ThemePrefsProvider>();
          AppPalette.active = themePrefs.palette;

          return MaterialApp(
            title: AppStrings.appName,
            builder: (context, child) =>
                OfflineBannerHost(child: child ?? const SizedBox.shrink()),
            scrollBehavior: const _NoScrollbarBehavior(),
            theme: AppTheme.fromPalette(
              themePrefs.palette,
              devanagari: localePrefs.isDevanagari,
            ),
            themeMode: ThemeMode.light,
            debugShowCheckedModeBanner: false,
            locale: localePrefs.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const SessionRouteGuard(child: _AuthGate()),
          );
        },
      ),
    );
  }
}

class _NoScrollbarBehavior extends MaterialScrollBehavior {
  const _NoScrollbarBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isLoading) return const _SplashScreen();
    if (!auth.isAuthenticated) return const LoginPage();
    if (auth.user?.needsRecoveryPinSetup ?? false) {
      return const RecoveryPinSetupPage();
    }
    if (auth.user?.shopRole != null) return const AppShell();
    if (auth.user?.role == 'OWNER') return const OnboardingShopPage();
    return const _JoinGate();
  }
}

class _JoinGate extends StatefulWidget {
  const _JoinGate();

  @override
  State<_JoinGate> createState() => _JoinGateState();
}

class _JoinGateState extends State<_JoinGate> {
  bool _loading = true;
  Invitation? _invite;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ds = InvitationsRemoteDataSource(context.read<ApiClient>());
      final invites = await ds.incoming(status: 'PENDING');
      final team = invites.where((i) => i.isTeam && i.isPending).toList();
      if (!mounted) return;
      setState(() {
        _invite = team.isNotEmpty ? team.first : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _SplashScreen();
    final invite = _invite;
    if (invite != null) {
      return JoinRequestPage(
        invite: invite,
        onResolved: () => context.read<AuthProvider>().refreshUser(),
      );
    }
    return const _NoShopScreen();
  }
}

class _NoShopScreen extends StatelessWidget {
  const _NoShopScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppIcon(
                  AppIcons.storefrontOutlined,
                  size: 48,
                  color: AppColors.muted,
                ),
                const SizedBox(height: AppSizes.lg),
                Text(
                  l10n.noShopTitle,
                  style: theme.textTheme.titleLarge?.extraBold,
                ),
                const SizedBox(height: AppSizes.sm),
                Text(
                  l10n.noShopBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSizes.xl),
                FilledButton(
                  onPressed: () => context.read<AuthProvider>().logout(),
                  child: Text(l10n.commonSignOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/shopxy-icon.png', width: 72, height: 72),
            const SizedBox(height: AppSizes.xl),
            Text(
              AppStrings.appName,
              style: theme.textTheme.headlineSmall?.bold,
            ),
            const SizedBox(height: AppSizes.xxs),
            Text(
              AppStrings.appBy,
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.muted,
              ),
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
