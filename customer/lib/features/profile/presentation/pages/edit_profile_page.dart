import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/profile/data/datasources/avatar_remote_data_source.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/change_password_page.dart';
import 'package:shopxy_customer/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/widgets/app_text_field.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _phone = TextEditingController(text: user?.phoneNumber ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const AppIcon(AppIcons.cameraAltOutlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const AppIcon(AppIcons.photoLibraryOutlined),
              title: const Text('Pick from gallery'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            if (context.read<AuthProvider>().user?.avatarUrl != null)
              ListTile(
                leading: const AppIcon(
                  AppIcons.deleteOutline,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () => Navigator.of(ctx).pop(null),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (source == null) {
      final user = context.read<AuthProvider>().user;
      if (user?.avatarUrl == null) return;
      await _removePhoto();
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });
    try {
      final url = await context.read<AvatarRemoteDataSource>().upload(
        File(picked.path),
      );
      if (!mounted) return;
      await context.read<AuthProvider>().updateAvatar(url);
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'Photo updated',
        tone: AppSnackbarTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removePhoto() async {
    setState(() {
      _uploadingAvatar = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().updateAvatar(null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _save() async {
    final trimmedName = _name.text.trim();
    final trimmedPhone = _phone.text.trim();
    if (trimmedName.length < 2) {
      setState(() => _error = AppStrings.nameTooShort);
      return;
    }
    if (trimmedPhone.isNotEmpty &&
        !RegExp(r'^\+?[0-9\s\-]{7,20}$').hasMatch(trimmedPhone)) {
      setState(
        () => _error =
            'Phone number should be 7–15 digits with an optional + prefix.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthProvider>();
      if (trimmedName != (auth.user?.name ?? '')) {
        await auth.updateName(trimmedName);
      }
      final currentPhone = auth.user?.phoneNumber ?? '';
      if (trimmedPhone != currentPhone) {
        await auth.updatePhone(trimmedPhone);
      }
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'Profile updated',
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
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: 'Edit profile'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            Center(
              child: Stack(
                children: [
                  ProfileAvatar(
                    name: user?.name ?? '',
                    avatarUrl: user?.avatarUrl,
                    size: 96,
                    borderColor: AppColors.canvas,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: AppColors.brand,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _uploadingAvatar ? null : _changePhoto,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.sm),
                          child: _uploadingAvatar
                              ? const SizedBox(
                                  width: AppSizes.iconSm,
                                  height: AppSizes.iconSm,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.white,
                                  ),
                                )
                              : const AppIcon(
                                  AppIcons.cameraAltOutlined,
                                  color: AppColors.white,
                                  size: AppSizes.iconSm,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            AppTextField(
              controller: _name,
              label: AppStrings.fullName,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSizes.lg),
            AppTextField(
              controller: _email,
              label: AppStrings.email,
              enabled: false,
              helper: 'Contact support to change your email.',
            ),
            const SizedBox(height: AppSizes.lg),
            AppTextField(
              controller: _phone,
              label: 'Phone number',
              helper:
                  'Used for delivery updates. Include country code, '
                  'e.g. +91 98765 43210.',
              keyboardType: TextInputType.phone,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSizes.md),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
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
              icon: AppIcons.lockOutlineRounded,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
