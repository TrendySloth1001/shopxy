import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/require_auth.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/validation/auth_validators.dart';
import 'package:shopxy_customer/shared/widgets/app_pill_button.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/info_pages.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

/// Multi-step, onboarding-style registration. One question per screen
/// (name → email → password) with a progress bar, so signing up feels
/// like a guided flow rather than a wall of fields. Preserves the auth
/// contract: pops `true` the moment registration succeeds.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const _stepCount = 3;

  // TODO SECURITY (SCRN-1): auth surface (credentials entered here). Enable
  // screenshot/recents-thumbnail protection (Android FLAG_SECURE / iOS
  // app-switcher blur) on entry and disable on exit. No cross-platform
  // package is a dependency yet — needs a package decision before wiring.
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  int _step = 0;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;

  /// Explicit, affirmative DPDP consent — false until the user ticks the box
  /// on the final step. Submit is gated on this; it is never assumed.
  /// (DPDP Act 2023 s.6 — consent must be specific, informed, unambiguous.)
  bool _consentAccepted = false;

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

  void _onAuthChanged() {
    if (_auth.isAuthenticated && mounted) Navigator.of(context).pop(true);
  }

  bool get _isLast => _step == _stepCount - 1;

  void _back() {
    if (_step > 0) {
      setState(() {
        _step--;
        _error = null;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _continue() async {
    // Only the current step's fields are mounted, so this validates just
    // what's on screen.
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isLast) {
      setState(() {
        _step++;
        _error = null;
      });
      return;
    }
    if (!_consentAccepted) {
      setState(
        () => _error =
            'Please accept the Terms of Service and Privacy Policy to continue.',
      );
      return;
    }
    await _submit();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().register(
        _name.text.trim(),
        _email.text.trim(),
        _password.text,
        acceptedTerms: _consentAccepted,
        acceptedPrivacy: _consentAccepted,
      );
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
    return PopScope(
      // Back goes a step at a time; only pops the page from step 0.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  AppSizes.sm,
                  AppSizes.sm,
                  AppSizes.md,
                ),
                child: Row(
                  children: [
                    _CircleBack(onTap: _back),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: _StepProgress(step: _step, total: _stepCount),
                    ),
                    const SizedBox(width: AppSizes.md),
                    const SkipToGuestButton(),
                  ],
                ),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: AnimatedSwitcher(
                    duration: AppDurations.long,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.08, 0),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: SingleChildScrollView(
                      key: ValueKey(_step),
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.xl,
                        AppSizes.xl,
                        AppSizes.xl,
                        AppSizes.lg,
                      ),
                      child: _buildStep(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.xl,
                  0,
                  AppSizes.xl,
                  AppSizes.md,
                ),
                child: Column(
                  children: [
                    if (_error != null) ...[
                      AuthErrorBanner(message: _error!),
                      const SizedBox(height: AppSizes.md),
                    ],
                    AppPillButton(
                      label: _isLast ? AppStrings.createAccount : 'Continue',
                      icon: _isLast ? null : AppIcons.arrowForwardRounded,
                      loading: _isLoading,
                      onPressed: _continue,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppStrings.haveAccount,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.brandStrong,
                            textStyle: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          child: const Text(AppStrings.login),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _StepShell(
          stepLabel: 'STEP 1 OF $_stepCount',
          title: 'First, what should\nwe call you?',
          subtitle: "We'll use this on your orders and messages from shops.",
          fields: [
            AuthField(
              controller: _name,
              label: AppStrings.fullName,
              icon: AppIcons.personOutlineRounded,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _continue(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return AppStrings.fieldRequired;
                }
                if (v.trim().length < 2) return AppStrings.nameTooShort;
                return null;
              },
            ),
          ],
        );
      case 1:
        return _StepShell(
          stepLabel: 'STEP 2 OF $_stepCount',
          title: "What's your\nemail address?",
          subtitle: "You'll use it to sign in and get order updates.",
          fields: [
            AuthField(
              controller: _email,
              label: AppStrings.email,
              icon: AppIcons.mailOutlineRounded,
              autofocus: true,
              autocorrect: false,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _continue(),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return AppStrings.fieldRequired;
                }
                if (!v.contains('@') || !v.contains('.')) {
                  return AppStrings.invalidEmail;
                }
                return null;
              },
            ),
          ],
        );
      default:
        return _StepShell(
          stepLabel: 'STEP 3 OF $_stepCount',
          title: 'Now secure it with\na password',
          subtitle: 'Almost there — pick something only you would know.',
          fields: [
            AuthField(
              controller: _password,
              label: AppStrings.password,
              icon: AppIcons.lockOutlineRounded,
              obscure: _obscurePass,
              onToggleObscure: () =>
                  setState(() => _obscurePass = !_obscurePass),
              autofocus: true,
              helper: AppStrings.passwordHint,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.password,
            ),
            const SizedBox(height: AppSizes.md),
            AuthField(
              controller: _confirm,
              label: AppStrings.confirmPassword,
              icon: AppIcons.lockOutlineRounded,
              obscure: _obscureConfirm,
              onToggleObscure: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _continue(),
              validator: (v) {
                if (v == null || v.isEmpty) return AppStrings.fieldRequired;
                if (v != _password.text) return AppStrings.passwordsDoNotMatch;
                return null;
              },
            ),
            const SizedBox(height: AppSizes.lg),
            _ConsentCheckbox(
              value: _consentAccepted,
              onChanged: (v) => setState(() {
                _consentAccepted = v;
                if (v) _error = null;
              }),
              onOpenTerms: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
              ),
              onOpenPrivacy: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
              ),
            ),
          ],
        );
    }
  }
}

/// Affirmative, opt-in consent control shown on the final register step.
/// Off by default; the tappable links open the actual Terms / Privacy notice
/// so the consent is informed. (DPDP Act 2023 s.6.)
class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkStyle = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.brandStrong,
      fontWeight: FontWeight.w800,
    );
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: AppColors.muted,
      height: 1.4,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppSizes.iconLg,
          height: AppSizes.iconLg,
          child: Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AppColors.brand,
            shape: AppShapes.squircle(AppSizes.radiusSm),
          ),
        ),
        const SizedBox(width: AppSizes.sm),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSizes.xs),
            child: Text.rich(
              TextSpan(
                style: baseStyle,
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()..onTap = onOpenTerms,
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: linkStyle,
                    recognizer: TapGestureRecognizer()..onTap = onOpenPrivacy,
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared per-step body: step label, big question, subtitle, fields.
class _StepShell extends StatelessWidget {
  const _StepShell({
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.fields,
  });

  final String stepLabel;
  final String title;
  final String subtitle;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stepLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: AppColors.brand,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSizes.md),
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.muted,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSizes.xxl),
        ...fields,
      ],
    );
  }
}

/// Three-segment progress bar; fills up to (and including) the active step.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final filled = i <= step;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == total - 1 ? 0 : AppSizes.sm),
            child: AnimatedContainer(
              duration: AppDurations.medium,
              height: AppSizes.xs,
              decoration: BoxDecoration(
                color: filled ? AppColors.brand : AppColors.hairline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      }),
    );
  }
}

/// Small circular back button — lighter than the chunky GlassNavButton,
/// suited to a white form page.
class _CircleBack extends StatelessWidget {
  const _CircleBack({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: const BorderSide(color: AppColors.hairline, width: 0.8),
      ),
      child: InkWell(
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        onTap: onTap,
        child: const SizedBox(
          width: AppSizes.avatarSm,
          height: AppSizes.avatarSm,
          child: AppIcon(
            AppIcons.arrowBackRounded,
            color: AppColors.black,
            size: AppSizes.iconMd,
          ),
        ),
      ),
    );
  }
}
