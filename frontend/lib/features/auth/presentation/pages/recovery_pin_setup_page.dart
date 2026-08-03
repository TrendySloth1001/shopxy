import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Shown right after a Google sign-in creates (or first links) an account —
/// the root auth gate (`_AuthGate` in app.dart) routes here whenever
/// `AuthUser.needsRecoveryPinSetup` is true, ahead of shop onboarding.
/// Google accounts have no password, so this PIN is the only fallback if
/// Google itself is ever unreachable — mirrors WhatsApp's 2-step PIN: short,
/// numeric, chosen by the user (not a generated code to save). Mirrors
/// OnboardingShopPage's bare-Scaffold layout — this isn't a sign-in/register
/// toggle, so AuthScaffold doesn't fit.
class RecoveryPinSetupPage extends StatefulWidget {
  const RecoveryPinSetupPage({super.key});

  @override
  State<RecoveryPinSetupPage> createState() => _RecoveryPinSetupPageState();
}

class _RecoveryPinSetupPageState extends State<RecoveryPinSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    if (_pin.text != _confirmPin.text) {
      setState(() => _error = l10n.authRecoveryPinMismatch);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // The auth gate reads AuthUser.recoveryPinSetAt (refreshed by
      // setRecoveryPin itself), so no manual navigation is needed here —
      // it swaps this screen for onboarding/the shell on its own.
      await context.read<AuthProvider>().setRecoveryPin(_pin.text);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validatePin(String? v) {
    final l10n = AppLocalizations.of(context);
    if (v == null || !RegExp(r'^\d{4,6}$').hasMatch(v)) {
      return l10n.authRecoveryPinInvalid;
    }
    return null;
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
                      l10n.authRecoveryPinSetupTitle,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppColors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Text(
                      l10n.authRecoveryPinSetupSubtitle,
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
                      label: l10n.authRecoveryPinLabel,
                      controller: _pin,
                      obscure: true,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      validator: _validatePin,
                    ),
                    const SizedBox(height: AppSizes.lg),
                    AuthField(
                      label: l10n.authRecoveryPinConfirmLabel,
                      controller: _confirmPin,
                      obscure: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: _validatePin,
                    ),
                    const SizedBox(height: AppSizes.xxl),
                    AuthSubmitButton(
                      label: l10n.authRecoveryPinSave,
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
