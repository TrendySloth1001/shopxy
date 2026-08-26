import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static const _resendCooldown = 30;

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _codeSent = false;
  bool _isLoading = false;
  String? _error;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _otp.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _resendIn = _resendCooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = AppLocalizations.of(context).authInvalidEmail);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthRemoteDataSource>().forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _isLoading = false;
      });
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _reset() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_password.text != _confirm.text) {
      setState(() => _error = l10n.authResetMismatch);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthRemoteDataSource>().resetPassword(
        _email.text.trim(),
        _otp.text.trim(),
        _password.text,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.authResetDone)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: AuthScaffold(
        title: l10n.authResetTitle,
        subtitle: l10n.authResetSubtitle,
        headerIcon: AppIcons.lockOpenRounded,
        footerPrompt: l10n.authLoginFooterPrompt,
        footerCta: l10n.authSignIn,
        onFooterTap: () => Navigator.of(context).pop(),
        children: [
          const SizedBox(height: AppSizes.lg),
          if (_error != null) ...[
            AuthErrorBanner(message: _error!),
            const SizedBox(height: AppSizes.lg),
          ],
          if (_codeSent) ...[
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.tileBg(AppColors.infoSoft),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: Text(
                l10n.authResetSent(_email.text.trim()),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.black,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
          ],
          AuthField(
            label: l10n.authEmail,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofocus: !_codeSent,
            autocorrect: false,
            enabled: !_codeSent && !_isLoading,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return l10n.authFieldRequired;
              if (!v.contains('@')) return l10n.authInvalidEmail;
              return null;
            },
          ),
          const SizedBox(height: AppSizes.lg),
          if (!_codeSent)
            AuthSubmitButton(
              label: l10n.authResetSendCode,
              loading: _isLoading,
              onPressed: _sendCode,
            )
          else ...[
            AuthField(
              label: l10n.authResetCodeLabel,
              controller: _otp,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              autofocus: true,
              validator: (v) => (v == null || v.trim().length != 6)
                  ? l10n.authResetInvalidCode
                  : null,
            ),
            const SizedBox(height: AppSizes.lg),
            AuthField(
              label: l10n.authResetNewPassword,
              controller: _password,
              obscure: true,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  v == null || v.isEmpty ? l10n.authFieldRequired : null,
            ),
            const SizedBox(height: AppSizes.lg),
            AuthField(
              label: l10n.authResetConfirmPassword,
              controller: _confirm,
              obscure: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _reset(),
              validator: (v) =>
                  v == null || v.isEmpty ? l10n.authFieldRequired : null,
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppIcon(
                  AppIcons.warningAmberRounded,
                  size: AppSizes.iconSm,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    l10n.authResetSignOutWarning,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.lg),
            AuthSubmitButton(
              label: l10n.authResetSubmit,
              loading: _isLoading,
              onPressed: _reset,
            ),
            const SizedBox(height: AppSizes.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  l10n.otpNoCodePrompt,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                TextButton(
                  onPressed: (_resendIn > 0 || _isLoading) ? null : _sendCode,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brandStrong,
                    disabledForegroundColor: AppColors.subtle,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _resendIn > 0
                        ? l10n.otpResendIn(_resendIn)
                        : l10n.otpResend,
                  ),
                ),
              ],
            ),
            Center(
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () => setState(() {
                        _codeSent = false;
                        _otp.clear();
                        _password.clear();
                        _confirm.clear();
                        _error = null;
                      }),
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                child: Text(l10n.authResetChangeEmail),
              ),
            ),
          ],
          const SizedBox(height: AppSizes.lg),
        ],
      ),
    );
  }
}
