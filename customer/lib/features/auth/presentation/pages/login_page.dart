import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/pages/register_page.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/network_image_box.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_pill_button.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

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
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;

  late final AuthProvider _auth;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Pop with `true` the moment auth flips to signed-in — covers our own
  /// `_submit` succeeding AND a stacked [RegisterPage] finishing.
  void _onAuthChanged() {
    if (_auth.isAuthenticated && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().login(_email.text.trim(), _password.text);
    } catch (e) {
      if (mounted) {
        setState(() => _error = friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      heroImageUrl: HomeImg.unsplash('1483985988355-763728e1935b', w: 1000, h: 900),
      heroTagline: 'Pick up right where you left off.',
      title: AppStrings.welcomeBack,
      subtitle: AppStrings.loginSubtitle,
      showSkip: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AuthErrorBanner(message: _error!),
              const SizedBox(height: AppSizes.lg),
            ],
            AuthField(
              controller: _email,
              label: 'Email',
              icon: AppIcons.mailOutlineRounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return AppStrings.fieldRequired;
                if (!v.contains('@')) return AppStrings.invalidEmail;
                return null;
              },
            ),
            const SizedBox(height: AppSizes.md),
            AuthField(
              controller: _password,
              label: 'Password',
              icon: AppIcons.lockOutlineRounded,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) =>
                  v == null || v.isEmpty ? AppStrings.fieldRequired : null,
            ),
            const SizedBox(height: AppSizes.xl),
            AppPillButton(
              label: AppStrings.login,
              icon: AppIcons.arrowForwardRounded,
              loading: _isLoading,
              onPressed: _submit,
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.noAccount,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandStrong,
                    textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800),
                  ),
                  child: const Text(AppStrings.register),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
