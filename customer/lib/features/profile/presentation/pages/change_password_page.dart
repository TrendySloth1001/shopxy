import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/widgets/app_text_field.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validateNew(String? v) {
    if (v == null || v.length < 8) return AppStrings.passwordTooShort;
    if (!RegExp(r'[A-Za-z]').hasMatch(v)) return AppStrings.passwordNeedsLetter;
    if (!RegExp(r'\d').hasMatch(v)) return AppStrings.passwordNeedsNumber;
    return null;
  }

  Future<void> _save() async {
    if (_current.text.isEmpty) {
      setState(() => _error = AppStrings.fieldRequired);
      return;
    }
    final newErr = _validateNew(_next.text);
    if (newErr != null) {
      setState(() => _error = newErr);
      return;
    }
    if (_next.text != _confirm.text) {
      setState(() => _error = AppStrings.passwordsDoNotMatch);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'Password changed',
        tone: AppSnackbarTone.success,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: AppStrings.changePassword),
      body: SafeArea(
        child: ListView(
            padding: const EdgeInsets.all(AppSizes.lg),
            children: [
              // AppTextField doesn't expose validators directly; for
              // launch this page leans on the inline `_save` check +
              // backend's password rules to surface errors after submit.
              AppTextField(
                controller: _current,
                label: AppStrings.currentPassword,
                obscureText: true,
              ),
              const SizedBox(height: AppSizes.lg),
              AppTextField(
                controller: _next,
                label: AppStrings.newPassword,
                obscureText: true,
                helper: AppStrings.passwordHint,
              ),
              const SizedBox(height: AppSizes.lg),
              AppTextField(
                controller: _confirm,
                label: AppStrings.confirmPassword,
                obscureText: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSizes.md),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSizes.xl),
              AppButton.primary(
                label: AppStrings.changePassword,
                onPressed: _saving ? null : _save,
                isLoading: _saving,
              ),
            ],
        ),
      ),
    );
  }
}
