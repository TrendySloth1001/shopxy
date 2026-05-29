import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/require_auth.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/glass_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
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
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// Pop with `true` on successful auth so the LoginPage below us — and
  /// in turn the original `requireAuth` caller — sees the success.
  void _onAuthChanged() {
    if (_auth.isAuthenticated && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context
          .read<AuthProvider>()
          .register(_name.text.trim(), _email.text.trim(), _password.text);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Top-right Skip overlay — same treatment as LoginPage. See
    // SkipToGuestButton for why the confirmation sheet is here.
    return Stack(
      children: [
        GlassPage(
      hero: GlassHero.image(asset: 'assets/register.png', height: 260),
      navButton: GlassNavButton(
        onPressed: () => Navigator.pop(context),
      ),
      title: AppStrings.registerTitle,
      subtitle: AppStrings.registerSubtitle,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              _AuthErrorBanner(message: _error!),
              const SizedBox(height: AppSizes.lg),
            ],
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: AppStrings.fullName,
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return AppStrings.fieldRequired;
                if (v.trim().length < 2) return AppStrings.nameTooShort;
                return null;
              },
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: AppStrings.email,
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return AppStrings.fieldRequired;
                if (!v.contains('@') || !v.contains('.')) return AppStrings.invalidEmail;
                return null;
              },
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _password,
              decoration: InputDecoration(
                labelText: AppStrings.password,
                helperText: AppStrings.passwordHint,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              obscureText: _obscurePass,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                if (v.length < 8) return AppStrings.passwordTooShort;
                if (!v.contains(RegExp(r'[A-Za-z]'))) return AppStrings.passwordNeedsLetter;
                if (!v.contains(RegExp(r'[0-9]'))) return AppStrings.passwordNeedsNumber;
                return null;
              },
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _confirm,
              decoration: InputDecoration(
                labelText: AppStrings.confirmPassword,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                if (v != _password.text) return AppStrings.passwordsDoNotMatch;
                return null;
              },
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.haveAccount,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(AppStrings.login),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: GlassActionPanel(
        primaryLabel: AppStrings.createAccount,
        primaryIcon: Icons.arrow_forward_rounded,
        onPrimary: _submit,
        primaryLoading: _isLoading,
      ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + AppSizes.sm,
          right: AppSizes.sm,
          child: const SkipToGuestButton(),
        ),
      ],
    );
  }
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
