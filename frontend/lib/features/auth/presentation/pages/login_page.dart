import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/remembered_accounts.dart';
import 'package:shopxy/features/auth/presentation/pages/register_page.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/glass_widgets.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
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
      if (mounted) {
        setState(
          () => _error = friendlyError(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassPage(
      hero: GlassHero.image(asset: 'assets/login.png', height: 280),
      title: AppStrings.welcomeBack,
      subtitle: AppStrings.loginSubtitle,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _RememberedAccountsSection(),
            if (_error != null) ...[
              _AuthErrorBanner(message: _error!),
              const SizedBox(height: AppSizes.lg),
            ],
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: AppStrings.email,
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return AppStrings.fieldRequired;
                }
                if (!v.contains('@')) return AppStrings.invalidEmail;
                return null;
              },
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _password,
              decoration: InputDecoration(
                labelText: AppStrings.password,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  v == null || v.isEmpty ? AppStrings.fieldRequired : null,
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.noAccount,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  child: const Text(AppStrings.register),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: GlassActionPanel(
        primaryLabel: AppStrings.login,
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: _submit,
        primaryLoading: _isLoading,
      ),
    );
  }
}

/// Desktop/native one-tap return sign-in. Shows previously-used accounts;
/// tapping one resumes the session without a password. Hidden when empty.
class _RememberedAccountsSection extends StatefulWidget {
  const _RememberedAccountsSection();

  @override
  State<_RememberedAccountsSection> createState() => _RememberedAccountsSectionState();
}

class _RememberedAccountsSectionState extends State<_RememberedAccountsSection> {
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
      // On success the provider notifies and the auth gate swaps screens.
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
    final accounts = _accounts;
    if (accounts == null || accounts.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          _AuthErrorBanner(message: _error!),
          const SizedBox(height: AppSizes.lg),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Continue as',
            style: theme.textTheme.labelMedium?.copyWith(color: AppColors.muted),
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
        const SizedBox(height: AppSizes.md),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.hairline)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: Text(
                'or sign in',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.subtle),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.hairline)),
          ],
        ),
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
    final theme = Theme.of(context);
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
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
                      backgroundColor: AppColors.brandSoft,
                      child: Text(
                        _initials(account.name.isNotEmpty ? account.name : account.email),
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
                            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
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
                      const Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: busy ? null : onForget,
            icon: const Icon(Icons.close_rounded, size: AppSizes.iconSm, color: AppColors.muted),
            tooltip: 'Remove this account',
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

class _AuthErrorBanner extends StatelessWidget {
  const _AuthErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.error, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.error,
            size: AppSizes.iconSm,
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
