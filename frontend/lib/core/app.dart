import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/core/prefs/locale_prefs.dart';
import 'package:shopxy/core/prefs/prefs_storage.dart';
import 'package:shopxy/core/prefs/theme_prefs.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/features/auth/presentation/pages/login_page.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy/features/notifications/domain/entities/invitation.dart';
import 'package:shopxy/features/shop/presentation/pages/join_request_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_palette.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_theme.dart';

class ShopxyApp extends StatelessWidget {
  const ShopxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The locale provider is created here (not in main.dart) so the i18n wiring
    // stays out of the shared bootstrap file. It loads asynchronously; until
    // then the app opens in English.
    return ChangeNotifierProvider<LocalePrefsProvider>(
      create: (_) => LocalePrefsProvider(appPrefsStorage)..load(),
      child: Consumer<LocalePrefsProvider>(
        builder: (context, localePrefs, _) {
          // Drive the whole app from the selected theme. Setting AppPalette.active
          // here (before the subtree builds) keeps the AppColors.* getters in sync
          // with the ThemeData we hand MaterialApp, so custom-painted widgets and
          // Material components agree.
          final themePrefs = context.watch<ThemePrefsProvider>();
          AppPalette.active = themePrefs.palette;

          return MaterialApp(
            title: AppStrings.appName,
            // Devanagari languages (Hindi) swap the base font to Noto Sans
            // Devanagari; English stays on Inter.
            theme: AppTheme.fromPalette(
              themePrefs.palette,
              devanagari: localePrefs.isDevanagari,
            ),
            themeMode: ThemeMode.light,
            debugShowCheckedModeBanner: false,
            locale: localePrefs.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isLoading) return const _SplashScreen();
    if (!auth.isAuthenticated) return const LoginPage();
    // A member (owner or staff) has a shopRole → straight into the app.
    // An authenticated account with no shopRole isn't on any team yet:
    // it's either an invited staffer who must accept first, or a stray
    // shopless account. The JoinGate sorts that out.
    if (auth.user?.shopRole != null) return const AppShell();
    return const _JoinGate();
  }
}

/// Decides what a membership-less authenticated account sees: the
/// join-request screen if they have a pending team invite, otherwise a
/// "no shop linked" dead-end with a way back out.
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

/// Fallback for an authenticated account with neither a shop nor a
/// pending invite — e.g. a staffer who was removed, or a stray account.
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
                Icon(Icons.storefront_outlined,
                    size: 48, color: AppColors.muted),
                const SizedBox(height: AppSizes.lg),
                Text(l10n.noShopTitle,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSizes.sm),
                Text(
                  l10n.noShopBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.muted),
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
            Container(
              width: 72,
              height: 72,
              decoration: ShapeDecoration(
                color: AppColors.inverseSurface,
                shape: AppShapes.squircle(AppSizes.radiusXl),
              ),
              child: Icon(
                Icons.inventory_2_rounded,
                size: AppSizes.iconXl,
                color: AppColors.onInverse,
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            Text(
              AppStrings.appName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
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
