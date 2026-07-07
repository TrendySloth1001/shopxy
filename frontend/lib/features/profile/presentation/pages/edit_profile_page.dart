import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/profile/presentation/pages/profile_page.dart'
    show ProfileAvatar;
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/indian.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

/// A field the caller can ask [EditProfilePage] to open focused on — lets
/// the completion meter deep-link straight to the field a user still needs
/// to fill instead of dumping them at the top of the form.
enum ProfileField {
  name,
  phone,
  shopName,
  shopAddress,
  shopCity,
  shopState,
  shopPinCode,
  shopGstin,
  shopPan,
  upiVpa,
  photo,
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, this.focusField});

  /// When set, the matching field is focused (and scrolled into view) once
  /// the form first lays out. `photo`/`shopState` have no text field, so
  /// they simply open the form at the top.
  final ProfileField? focusField;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

enum _PhotoAction { camera, gallery, remove }

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  // Shop details — every field is editable in this page; an empty string
  // is interpreted by the AuthProvider as "clear it on the server."
  late final TextEditingController _shopName;
  late final TextEditingController _shopAddress;
  late final TextEditingController _shopCity;
  late final TextEditingController _shopPinCode;
  late final TextEditingController _shopGstin;
  late final TextEditingController _shopPan;
  late final TextEditingController _upiVpa;
  String? _shopStateCode;
  bool _busy = false;
  bool _uploadingAvatar = false;

  /// Focus nodes for the text fields we can deep-link to. Requesting focus
  /// also makes Flutter scroll the field into view, so no scroll keys are
  /// needed. The dropdown (state) and avatar (photo) have no node.
  late final Map<ProfileField, FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phoneNumber ?? '');
    _shopName = TextEditingController(text: user?.shopName ?? '');
    _shopAddress = TextEditingController(text: user?.shopAddress ?? '');
    _shopCity = TextEditingController(text: user?.shopCity ?? '');
    _shopPinCode = TextEditingController(text: user?.shopPinCode ?? '');
    _shopGstin = TextEditingController(text: user?.shopGstin ?? '');
    _shopPan = TextEditingController(text: user?.shopPan ?? '');
    _upiVpa = TextEditingController(text: user?.upiVpa ?? '');
    _shopStateCode = user?.shopStateCode;

    _focusNodes = {
      for (final f in const [
        ProfileField.name,
        ProfileField.phone,
        ProfileField.shopName,
        ProfileField.shopAddress,
        ProfileField.shopCity,
        ProfileField.shopPinCode,
        ProfileField.shopGstin,
        ProfileField.shopPan,
        ProfileField.upiVpa,
      ])
        f: FocusNode(),
    };
    final target = widget.focusField;
    if (target != null && _focusNodes.containsKey(target)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNodes[target]!.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _shopName.dispose();
    _shopAddress.dispose();
    _shopCity.dispose();
    _shopPinCode.dispose();
    _shopGstin.dispose();
    _shopPan.dispose();
    _upiVpa.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final l10n = AppLocalizations.of(context);
    final user = context.read<AuthProvider>().user;
    final hasAvatar = user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty;
    final source = await showModalBottomSheet<_PhotoAction>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.profileTakePhoto),
              onTap: () => Navigator.of(ctx).pop(_PhotoAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.profilePickFromGallery),
              onTap: () => Navigator.of(ctx).pop(_PhotoAction.gallery),
            ),
            if (hasAvatar)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: AppColors.error),
                title: Text(l10n.profileRemovePhoto,
                    style: TextStyle(color: AppColors.error)),
                onTap: () => Navigator.of(ctx).pop(_PhotoAction.remove),
              ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source == _PhotoAction.remove) {
      await _setAvatar(null);
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source == _PhotoAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final url = await context
          .read<ShopProvider>()
          .uploadImage(File(picked.path));
      if (url == null) throw Exception('Upload failed');
      if (!mounted) return;
      await _setAvatar(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _setAvatar(String? url) async {
    try {
      await context.read<AuthProvider>().updateAvatar(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    // Diff each field against the stored value so we only PATCH what
    // actually changed. The provider treats `null` as "leave it alone"
    // and `''` as "clear it" — see updateProfile.
    String? diff(String current, String? stored) {
      final next = current.trim();
      final prev = stored ?? '';
      if (next == prev) return null;
      return next; // empty string → clear
    }

    final newName = _name.text.trim();
    final nameArg = newName == (user?.name ?? '') ? null : newName;

    // Phone: diff() gives null (unchanged) / '' (cleared) / value. The API
    // clears only when clearPhone is true, so map '' → clearPhone.
    final phoneDiff = diff(_phone.text, user?.phoneNumber);
    final clearPhone = phoneDiff == '';
    final phoneArg =
        (phoneDiff != null && phoneDiff.isNotEmpty) ? phoneDiff : null;

    final shopNameArg = diff(_shopName.text, user?.shopName);
    final shopAddressArg = diff(_shopAddress.text, user?.shopAddress);
    final shopCityArg = diff(_shopCity.text, user?.shopCity);
    final shopPinCodeArg = diff(_shopPinCode.text, user?.shopPinCode);
    final shopGstinArg = diff(_shopGstin.text.toUpperCase(), user?.shopGstin);
    final shopPanArg = diff(_shopPan.text.toUpperCase(), user?.shopPan);
    final upiArg = diff(_upiVpa.text, user?.upiVpa);

    // State pair must move together: if the code changed, send both
    // halves; if it didn't, send neither.
    String? shopStateArg;
    String? shopStateCodeArg;
    if (_shopStateCode != user?.shopStateCode) {
      shopStateCodeArg = _shopStateCode ?? '';
      shopStateArg = IndianStates.stateNameFromCode(_shopStateCode) ?? '';
    }

    final unchanged = nameArg == null &&
        phoneDiff == null &&
        shopNameArg == null &&
        shopAddressArg == null &&
        shopCityArg == null &&
        shopPinCodeArg == null &&
        shopGstinArg == null &&
        shopPanArg == null &&
        upiArg == null &&
        shopStateCodeArg == null;
    if (unchanged) {
      Navigator.pop(context);
      return;
    }

    setState(() => _busy = true);
    try {
      await auth.updateProfile(
        name: nameArg,
        phoneNumber: phoneArg,
        clearPhone: clearPhone,
        shopName: shopNameArg,
        shopAddress: shopAddressArg,
        shopCity: shopCityArg,
        shopState: shopStateArg,
        shopStateCode: shopStateCodeArg,
        shopPinCode: shopPinCodeArg,
        shopGstin: shopGstinArg,
        shopPan: shopPanArg,
        upiVpa: upiArg,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).profileProfileUpdated)),
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
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.profileEditProfile),
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
            Center(
              child: Stack(
                children: [
                  ProfileAvatar(
                    name: user?.name ?? '',
                    imageUrl: user?.avatarUrl,
                    size: 96,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: AppColors.inverseSurface,
                      shape: const CircleBorder(),
                      elevation: 1,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _uploadingAvatar ? null : _changePhoto,
                        child: Padding(
                          padding: const EdgeInsets.all(AppSizes.sm),
                          child: _uploadingAvatar
                              ? SizedBox(
                                  width: AppSizes.iconSm,
                                  height: AppSizes.iconSm,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.onInverse,
                                  ),
                                )
                              : Icon(
                                  Icons.camera_alt_outlined,
                                  color: AppColors.onInverse,
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
            TextFormField(
              controller: _name,
              focusNode: _focusNodes[ProfileField.name],
              decoration: InputDecoration(labelText: l10n.profileName),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 2) return l10n.profileNameMinLength;
                if (t.length > 80) return l10n.profileNameTooLong;
                return null;
              },
            ),
            const SizedBox(height: AppSizes.lg),
            TextFormField(
              controller: _phone,
              focusNode: _focusNodes[ProfileField.phone],
              decoration: InputDecoration(
                labelText: l10n.profileFieldPhone,
                hintText: '9876543210',
                prefixIcon: const Icon(Icons.call_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null; // phone is optional
                return IndianValidators.phone(v);
              },
            ),
            const SizedBox(height: AppSizes.lg),
            TextFormField(
              initialValue: user?.email ?? '',
              enabled: false,
              decoration: InputDecoration(
                labelText: l10n.profileEmail,
                helperText: l10n.profileEmailNotEditable,
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            Text(
              l10n.profileShopDetails,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              l10n.profileShopDetailsHint,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _shopName,
              focusNode: _focusNodes[ProfileField.shopName],
              decoration: InputDecoration(labelText: l10n.profileShopName),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _shopAddress,
              focusNode: _focusNodes[ProfileField.shopAddress],
              decoration: InputDecoration(labelText: l10n.profileShopAddress),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _shopCity,
                    focusNode: _focusNodes[ProfileField.shopCity],
                    decoration: InputDecoration(labelText: l10n.profileCity),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _shopPinCode,
                    focusNode: _focusNodes[ProfileField.shopPinCode],
                    decoration: InputDecoration(labelText: l10n.profilePinCode),
                    keyboardType: TextInputType.number,
                    validator: IndianValidators.pincode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            DropdownButtonFormField<String>(
              initialValue: _shopStateCode,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.profileState),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text(l10n.profileSelectPlaceholder),
                ),
                for (final s in IndianStates.all)
                  DropdownMenuItem<String>(
                    value: s.code,
                    child: Text('${s.code} — ${s.name}'),
                  ),
              ],
              onChanged: (v) => setState(() => _shopStateCode = v),
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _shopGstin,
                    focusNode: _focusNodes[ProfileField.shopGstin],
                    decoration: InputDecoration(labelText: l10n.profileGstin),
                    textCapitalization: TextCapitalization.characters,
                    validator: IndianValidators.gstin,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _shopPan,
                    focusNode: _focusNodes[ProfileField.shopPan],
                    decoration: InputDecoration(labelText: l10n.profilePan),
                    textCapitalization: TextCapitalization.characters,
                    validator: IndianValidators.pan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _upiVpa,
              focusNode: _focusNodes[ProfileField.upiVpa],
              decoration: InputDecoration(
                labelText: l10n.profileUpiId,
                hintText: 'shop@upi',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: IndianValidators.upiVpa,
            ),
            const SizedBox(height: AppSizes.xl),
            FilledButton(
              onPressed: _busy ? null : _save,
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
                  : Text(l10n.profileSave),
            ),
          ],
        ),
      ),
    );
  }
}
