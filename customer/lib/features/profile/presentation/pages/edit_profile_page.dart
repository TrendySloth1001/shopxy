import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/change_password_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/widgets/app_text_field.dart';

/// Lets the user change their display name and reach the change-password
/// flow. Email stays read-only — backend doesn't expose an email-change
/// endpoint to the customer app yet.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _name;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: context.read<AuthProvider>().user?.name ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final trimmed = _name.text.trim();
    if (trimmed.length < 2) {
      setState(() => _error = AppStrings.nameTooShort);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().updateName(trimmed);
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'Profile updated',
        tone: AppSnackbarTone.success,
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: 'Edit profile'),
      body: SafeArea(
        child: ListView(
            padding: const EdgeInsets.all(AppSizes.lg),
            children: [
              AppTextField(
                controller: _name,
                label: AppStrings.fullName,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSizes.lg),
              AppTextField(
                controller: TextEditingController(text: user?.email ?? ''),
                label: AppStrings.email,
                enabled: false,
                helper: 'Contact support to change your email.',
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
                label: 'Save',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
              ),
              const SizedBox(height: AppSizes.lg),
              const Divider(color: AppColors.hairline),
              const SizedBox(height: AppSizes.md),
              AppButton.secondary(
                label: AppStrings.changePassword,
                icon: Icons.lock_outline_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ChangePasswordPage(),
                  ),
                ),
              ),
            ],
        ),
      ),
    );
  }
}
