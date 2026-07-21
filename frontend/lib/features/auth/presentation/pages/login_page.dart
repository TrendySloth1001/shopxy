import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shopxy/core/auth/remembered_accounts.dart';
import 'package:shopxy/features/auth/presentation/pages/register_page.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy/features/profile/presentation/pages/legal_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';

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

  void _googleSoon() {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.authGoogleComingSoon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Form(
      key: _formKey,
      child: AuthScaffold(
        title: l10n.authWelcomeBack,
        subtitle: l10n.authLoginSubtitle,
        onSignIn: () {},
        onCreateAccount: _goToRegister,
        footerPrompt: l10n.authLoginFooterPrompt,
        footerCta: l10n.authCreateAccountCta,
        onFooterTap: _goToRegister,
        children: [
          const _RememberedAccountsSection(),
          GoogleButton(onTap: _googleSoon),
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
              TextSpan(text: l10n.authLegalTerms, style: link, recognizer: _terms),
              TextSpan(text: l10n.authLegalAcknowledgeMid),
              TextSpan(
                  text: l10n.authLegalPrivacyPolicy,
                  style: link,
                  recognizer: _privacy),
              TextSpan(text: l10n.authLegalCookieSuffix),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSizes.md),
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
        const SizedBox(height: AppSizes.md),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const LegalPage.terms()),
          ),
          child: Text(
            l10n.authComplianceLawsFormulas,
            style: subtle?.copyWith(
              color: AppColors.muted,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}

/// Desktop/native one-tap return sign-in. Shows previously-used accounts;
/// tapping one resumes the session without a password. Hidden when empty.
class _RememberedAccountsSection extends StatefulWidget {
  const _RememberedAccountsSection();

  @override
  State<_RememberedAccountsSection> createState() =>
      _RememberedAccountsSectionState();
}

class _RememberedAccountsSectionState
    extends State<_RememberedAccountsSection> {
  List<RememberedAccount>? _accounts;
  int? _busyId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<AuthProvider>().rememberedAccounts();
    if (mounted) setState(() => _accounts = list);
  }

  Future<void> _resume(int id) async {
    setState(() {
      _busyId = id;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().loginWithRemembered(id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busyId = null;
          _error = friendlyError(e);
        });
        await _load();
      }
    }
  }

  Future<void> _forget(int id) async {
    await context.read<AuthProvider>().forgetRemembered(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accounts = _accounts;
    if (accounts == null || accounts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          AuthErrorBanner(message: _error!),
          const SizedBox(height: AppSizes.lg),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.authContinueAs,
            style:
                theme.textTheme.labelMedium?.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        for (final a in accounts) ...[
          _AccountCard(
            account: a,
            busy: _busyId == a.id,
            onTap: () => _resume(a.id),
            onForget: () => _forget(a.id),
          ),
          const SizedBox(height: AppSizes.sm),
        ],
        const SizedBox(height: AppSizes.lg),
      ],
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.busy,
    required this.onTap,
    required this.onForget,
  });

  final RememberedAccount account;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onForget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: busy ? null : onTap,
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.tileBg(AppColors.brandSoft),
                      child: Text(
                        _initials(account.name.isNotEmpty
                            ? account.name
                            : account.email),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.brandStrong,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            account.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    if (busy)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(AppIcons.chevronRightRounded,
                          color: AppColors.subtle),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: busy ? null : onForget,
            icon: Icon(AppIcons.closeRounded,
                size: AppSizes.iconSm, color: AppColors.muted),
            tooltip: l10n.authRemoveThisAccount,
          ),
        ],
      ),
    );
  }
}

String _initials(String s) {
  final parts = s.trim().split(RegExp(r'\s+'));
  final a = parts.isNotEmpty && parts.first.isNotEmpty ? parts.first[0] : '';
  final b = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
  final out = (a + b).toUpperCase();
  return out.isEmpty ? '?' : out;
}
