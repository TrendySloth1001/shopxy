import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

/// First-run "name your shop" step for a freshly-signed-up OWNER who has no
/// shop yet (the register form no longer collects the shop name — it's created
/// shopless, mirroring merchant-web). Creating the shop here gives the account
/// a ShopMember(OWNER) row, so the auth gate advances into the dashboard.
class OnboardingShopPage extends StatefulWidget {
  const OnboardingShopPage({super.key});

  @override
  State<OnboardingShopPage> createState() => _OnboardingShopPageState();
}

class _OnboardingShopPageState extends State<OnboardingShopPage> {
  final _formKey = GlobalKey<FormState>();
  final _shopName = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _shopName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final ok = await context.read<ShopProvider>().createFirstShop(
      _shopName.text.trim(),
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _isLoading = false;
        _error = context.read<ShopProvider>().error;
      });
      return;
    }
    // Shop created → refresh the session so shopRole populates; the root
    // auth gate then swaps this screen for the dashboard. This widget may be
    // disposed as a result, so guard any further state writes.
    await context.read<AuthProvider>().refreshUser();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.canvas,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.xxl,
                AppSizes.lg,
                AppSizes.xxl + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🏪', style: TextStyle(fontSize: 26)),
                        const SizedBox(width: AppSizes.sm),
                        Text(
                          'ShopXY',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.black,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.xxl),
                    Text(
                      l10n.onboardingShopTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      l10n.onboardingShopSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xxl),
                    if (_error != null) ...[
                      AuthErrorBanner(message: _error!),
                      const SizedBox(height: AppSizes.lg),
                    ],
                    AuthField(
                      label: l10n.authShopName,
                      controller: _shopName,
                      helper: l10n.authShopNameHelper,
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return l10n.authFieldRequired;
                        }
                        if (v.trim().length < 2) return l10n.authNameTooShort;
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSizes.xxl),
                    AuthSubmitButton(
                      label: l10n.onboardingShopCta,
                      loading: _isLoading,
                      onPressed: _isLoading ? null : _submit,
                    ),
                    const SizedBox(height: AppSizes.lg),
                    // Escape hatch — sign out if this isn't the account they meant.
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => context.read<AuthProvider>().logout(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.muted,
                      ),
                      child: Text(l10n.profileLogout),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
