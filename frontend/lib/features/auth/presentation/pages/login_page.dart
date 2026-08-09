import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shopxy/core/auth/google_auth.dart';
import 'package:shopxy/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:shopxy/features/auth/presentation/pages/recovery_pin_login_page.dart';
import 'package:shopxy/features/auth/presentation/pages/register_page.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy/features/auth/presentation/widgets/remembered_accounts_sheet.dart';
import 'package:shopxy/features/profile/presentation/pages/legal_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // TODO SECURITY (SCRN-1): auth surface (credentials entered here). Enable
  // screenshot/recents-thumbnail protection (Android FLAG_SECURE / iOS
  // app-switcher blur) on entry and disable on exit. No cross-platform
  // package is a dependency yet — needs a package decision before wiring.
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(
        _email.text.trim(),
        _password.text,
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToRegister() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const RegisterPage()),
  );

  void _goToForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
    );
  }

  void _goToRecoveryPinLogin() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const RecoveryPinLoginPage()),
  );

  Future<void> _continueWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final idToken = await GoogleAuth.signInIdToken();
      // User cancelled the Google flow — not an error, just stop quietly.
      if (idToken == null) return;
      if (!mounted) return;
      // The root auth gate (app.dart) routes to the recovery-PIN setup
      // screen on its own once `needsRecoveryPinSetup` is true; no manual
      // navigation needed here.
      await context.read<AuthProvider>().loginWithGoogle(idToken);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: AuthScaffold(
        title: l10n.authWelcomeBack,
        subtitle: l10n.authLoginSubtitle,
        footerPrompt: l10n.authLoginFooterPrompt,
        footerCta: l10n.authCreateAccountCta,
        onFooterTap: _goToRegister,
        children: [
          // The two password-less ways in, stacked as a pair above the form.
          const RememberedAccountsButton(),
          if (GoogleAuth.isConfigured) GoogleButton(onTap: _continueWithGoogle),
          const SizedBox(height: AppSizes.lg),
          const AuthOrDivider(),
          const SizedBox(height: AppSizes.lg),
          if (_error != null) ...[
            AuthErrorBanner(message: _error!),
            const SizedBox(height: AppSizes.lg),
          ],
          AuthField(
            label: l10n.authEmail,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofocus: true,
            autocorrect: false,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.authFieldRequired;
              if (!v.contains('@')) return l10n.authInvalidEmail;
              return null;
            },
          ),
          const SizedBox(height: AppSizes.lg),
          AuthField(
            label: l10n.authPassword,
            controller: _password,
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (v) =>
                v == null || v.isEmpty ? l10n.authFieldRequired : null,
          ),
          const SizedBox(height: AppSizes.lg),
          AuthSubmitButton(
            label: l10n.authSignIn,
            loading: _isLoading,
            onPressed: _submit,
          ),
          const SizedBox(height: AppSizes.sm),
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : _goToForgotPassword,
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              child: Text(l10n.authForgotPassword, textAlign: TextAlign.center),
            ),
          ),
          if (GoogleAuth.isConfigured)
            Center(
              child: TextButton(
                onPressed: _isLoading ? null : _goToRecoveryPinLogin,
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: Text(
                  l10n.authUsePinInstead,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          const SizedBox(height: AppSizes.lg),
          const _LegalFooter(),
        ],
      ),
    );
  }
}

/// The pre-sign-in legal copy that mirrors merchant-web: a Terms / Privacy
/// acknowledgement, a contact-support line, and a compliance link. Stateful so
/// the inline-link tap recognizers are disposed properly.
class _LegalFooter extends StatefulWidget {
  const _LegalFooter();

  @override
  State<_LegalFooter> createState() => _LegalFooterState();
}

class _LegalFooterState extends State<_LegalFooter> {
  final _terms = TapGestureRecognizer();
  final _privacy = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    _terms.onTap = () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LegalPage.terms()),
    );
    _privacy.onTap = () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LegalPage.privacy()),
    );
  }

  @override
  void dispose() {
    _terms.dispose();
    _privacy.dispose();
    super.dispose();
  }

  Future<void> _support() async {
    final uri = Uri(scheme: 'mailto', path: 'support@shopxy.app');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: AppColors.muted);
    final subtle = theme.textTheme.bodySmall?.copyWith(color: AppColors.subtle);
    final link = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.black,
      decoration: TextDecoration.underline,
    );

    return Column(
      children: [
        Text.rich(
          TextSpan(
            style: muted,
            children: [
              TextSpan(text: l10n.authLegalAgreePrefix),
              TextSpan(
                text: l10n.authLegalTerms,
                style: link,
                recognizer: _terms,
              ),
              TextSpan(text: l10n.authLegalAcknowledgeMid),
              TextSpan(
                text: l10n.authLegalPrivacyPolicy,
                style: link,
                recognizer: _privacy,
              ),
              const TextSpan(text: '.'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.sm),
        GestureDetector(
          onTap: _support,
          child: Text.rich(
            TextSpan(
              style: subtle,
              children: [
                TextSpan(text: l10n.authTroubleSigningIn),
                TextSpan(
                  text: l10n.authContactSupport,
                  style: subtle?.copyWith(
                    color: AppColors.muted,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
