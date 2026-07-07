import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _showCurrent = false;
  bool _showNext = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateNext(AppLocalizations l10n, String? v) {
    final t = v ?? '';
    if (t.length < 8) return l10n.profilePasswordMinLength;
    if (!RegExp(r'[A-Za-z]').hasMatch(t)) return l10n.profilePasswordNeedsLetter;
    if (!RegExp(r'[0-9]').hasMatch(t)) return l10n.profilePasswordNeedsNumber;
    return null;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;
    if (_next.text != _confirm.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profilePasswordsDoNotMatch)),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthProvider>().changePassword(_current.text, _next.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profilePasswordChanged)),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.profileChangePassword),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.lg + FloatingAppBar.contentTopInset(context),
            AppSizes.lg,
            AppSizes.lg,
          ),
          children: [
            TextFormField(
              controller: _current,
              obscureText: !_showCurrent,
              decoration: InputDecoration(
                labelText: l10n.profileCurrentPassword,
                suffixIcon: IconButton(
                  icon: Icon(_showCurrent
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showCurrent = !_showCurrent),
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? l10n.profileRequired : null,
            ),
            const SizedBox(height: AppSizes.lg),
            TextFormField(
              controller: _next,
              obscureText: !_showNext,
              decoration: InputDecoration(
                labelText: l10n.profileNewPassword,
                helperText: l10n.profilePasswordHelper,
                suffixIcon: IconButton(
                  icon: Icon(_showNext
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => setState(() => _showNext = !_showNext),
                ),
              ),
              validator: (v) => _validateNext(l10n, v),
            ),
            const SizedBox(height: AppSizes.lg),
            TextFormField(
              controller: _confirm,
              obscureText: !_showNext,
              decoration: InputDecoration(
                  labelText: l10n.profileConfirmNewPassword),
              validator: (v) => (v ?? '').isEmpty ? l10n.profileRequired : null,
            ),
            const SizedBox(height: AppSizes.xl),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inverseSurface,
                foregroundColor: AppColors.onInverse,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              ),
              child: _busy
                  ? SizedBox(
                      height: AppSizes.xl,
                      width: AppSizes.xl,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.onInverse,
                      ),
                    )
                  : Text(l10n.profileChangePassword),
            ),
          ],
        ),
      ),
    );
  }
}
