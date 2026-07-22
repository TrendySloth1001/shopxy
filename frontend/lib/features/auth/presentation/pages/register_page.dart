import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/pages/otp_verify_page.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy/features/profile/presentation/pages/legal_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/validation/auth_validators.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // TODO SECURITY (SCRN-1): auth surface (credentials entered here). Enable
  // screenshot/recents-thumbnail protection (Android FLAG_SECURE / iOS
  // app-switcher blur) on entry and disable on exit. No cross-platform
  // package is a dependency yet — needs a package decision before wiring.
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _isLoading = false;
  // DPDP §6 consent gate — both must be ticked before submit enables.
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  String? _error;

  bool get _canSubmit => _acceptedTerms && _acceptedPrivacy && !_isLoading;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms || !_acceptedPrivacy) {
      final l10n = AppLocalizations.of(context);
      setState(() => _error = l10n.authAcceptTermsPrompt);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Shop name is collected in onboarding (name-your-shop) after signup —
      // mirrors merchant-web, which creates the owner shopless here.
      final result = await context.read<AuthProvider>().register(
        _name.text.trim(),
        _email.text.trim(),
        _password.text,
      );
      if (!mounted) return;
      switch (result) {
        case RegisterPending(:final email):
          // Verify the email before the account is created — collect the OTP.
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => OtpVerifyPage(email: email)),
          );
        case RegisterSignedIn():
          // OTP infra was down → account created + signed in directly. The auth
          // gate rebuilt underneath (→ onboarding); pop back to reveal it.
          Navigator.of(context).popUntil((r) => r.isFirst);
      }
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
        heroAsset: 'assets/register.png',
        title: l10n.authRegisterTitle,
        subtitle: l10n.authRegisterSubtitle,
        onSignIn: () => Navigator.pop(context),
        onCreateAccount: () {},
        footerPrompt: l10n.authRegisterFooterPrompt,
        footerCta: l10n.authSignIn,
        onFooterTap: () => Navigator.pop(context),
        children: [
          if (_error != null) ...[
            AuthErrorBanner(message: _error!),
            const SizedBox(height: AppSizes.lg),
          ],
          AuthField(
            label: l10n.authYourName,
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.authFieldRequired;
              if (v.trim().length < 2) return l10n.authNameTooShort;
              return null;
            },
          ),
          const SizedBox(height: AppSizes.lg),
          AuthField(
            label: l10n.authEmail,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.authFieldRequired;
              if (!v.contains('@') || !v.contains('.')) {
                return l10n.authInvalidEmail;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSizes.lg),
          AuthField(
            label: l10n.authPassword,
            controller: _password,
            obscure: true,
            helper: l10n.authPasswordHelper,
            textInputAction: TextInputAction.next,
            validator: AuthValidators.password,
          ),
          const SizedBox(height: AppSizes.lg),
          AuthField(
            label: l10n.authConfirmPassword,
            controller: _confirm,
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (v) {
              if (v == null || v.isEmpty) return l10n.authFieldRequired;
              if (v != _password.text) return l10n.authPasswordsDoNotMatch;
              return null;
            },
          ),
          const SizedBox(height: AppSizes.lg),
          _ConsentCheckbox(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
            label: l10n.authIAcceptThe,
            linkLabel: l10n.authTermsOfService,
            onLinkTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalPage.terms()),
            ),
          ),
          _ConsentCheckbox(
            value: _acceptedPrivacy,
            onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
            label: l10n.authIAcceptThe,
            linkLabel: l10n.authPrivacyPolicy,
            onLinkTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalPage.privacy()),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          AuthSubmitButton(
            label: l10n.authCreateAccount,
            loading: _isLoading,
            onPressed: _canSubmit ? _submit : null,
          ),
        ],
      ),
    );
  }
}

/// Compact consent row used twice (terms + privacy): a checkbox, an inline
/// label, and a link that opens the matching [LegalPage].
class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.label,
    required this.linkLabel,
    required this.onLinkTap,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final String linkLabel;
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(width: AppSizes.xs),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
              ),
              TextButton(
                onPressed: onLinkTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandStrong,
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(linkLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
