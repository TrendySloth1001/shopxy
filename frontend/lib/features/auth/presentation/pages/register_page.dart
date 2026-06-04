import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/profile/presentation/pages/legal_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/validation/auth_validators.dart';
import 'package:shopxy/shared/widgets/glass_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _shopName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  // DPDP §6 consent gate — both must be ticked before submit enables.
  // Stored in widget state because they are throw-away UI flags, not
  // persisted data.
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  String? _error;

  bool get _canSubmit => _acceptedTerms && _acceptedPrivacy && !_isLoading;

  @override
  void dispose() {
    _name.dispose();
    _shopName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms || !_acceptedPrivacy) {
      setState(
        () => _error =
            'Please accept the Terms of Service and Privacy Policy to continue.',
      );
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().register(
            _name.text.trim(),
            _email.text.trim(),
            _password.text,
            shopName: _shopName.text.trim(),
          );
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

    return GlassPage(
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
              controller: _shopName,
              decoration: const InputDecoration(
                labelText: 'Shop name',
                helperText:
                    'Shown to customers in the marketplace. You can rename it later.',
                prefixIcon: Icon(Icons.storefront_outlined),
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
              validator: AuthValidators.password,
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
            _ConsentCheckbox(
              value: _acceptedTerms,
              onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
              label: 'I accept the',
              linkLabel: 'Terms of Service',
              onLinkTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegalPage.terms()),
              ),
            ),
            _ConsentCheckbox(
              value: _acceptedPrivacy,
              onChanged: (v) => setState(() => _acceptedPrivacy = v ?? false),
              label: 'I accept the',
              linkLabel: 'Privacy Policy',
              onLinkTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LegalPage.privacy()),
              ),
            ),
            const SizedBox(height: AppSizes.md),
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
        // Submit stays disabled until both DPDP consent boxes are
        // ticked — passing null is what GlassActionPanel treats as
        // "disabled" so we don't need a separate flag.
        onPrimary: _canSubmit ? _submit : null,
        primaryLoading: _isLoading,
      ),
    );
  }
}

/// Compact consent row used twice on the register page (terms +
/// privacy). Renders a leading checkbox, an inline label, and a
/// [TextButton] that opens the matching [LegalPage]. Kept private to
/// this file because no other surface in the merchant app currently
/// needs the same layout.
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.xs,
                  ),
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
