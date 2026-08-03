import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Fallback sign-in for Google-only accounts when Google itself isn't
/// reachable. Doesn't collect a TOTP code — an account with both a
/// recovery PIN and 2FA enabled hitting this exact path is a narrow edge
/// case not covered in this pass (mirrors merchant-web's same gap).
class RecoveryPinLoginPage extends StatefulWidget {
  const RecoveryPinLoginPage({super.key});

  @override
  State<RecoveryPinLoginPage> createState() => _RecoveryPinLoginPageState();
}

class _RecoveryPinLoginPageState extends State<RecoveryPinLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pin = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().loginWithRecoveryPin(
        _email.text.trim(),
        _pin.text,
      );
      // The root auth gate takes over from here once AuthProvider notifies.
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
        title: l10n.authRecoveryPinLoginTitle,
        subtitle: l10n.authRecoveryPinLoginSubtitle,
        footerPrompt: '',
        footerCta: l10n.authSignIn,
        onFooterTap: () => Navigator.of(context).pop(),
        children: [
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
            label: l10n.authRecoveryPinLabel,
            controller: _pin,
            obscure: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (v) {
              if (v == null || !RegExp(r'^\d{4,6}$').hasMatch(v)) {
                return l10n.authRecoveryPinInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSizes.xxl),
          AuthSubmitButton(
            label: l10n.authSignIn,
            loading: _isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
