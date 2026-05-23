import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/indian.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
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

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _name = TextEditingController(text: user?.name ?? '');
    _shopName = TextEditingController(text: user?.shopName ?? '');
    _shopAddress = TextEditingController(text: user?.shopAddress ?? '');
    _shopCity = TextEditingController(text: user?.shopCity ?? '');
    _shopPinCode = TextEditingController(text: user?.shopPinCode ?? '');
    _shopGstin = TextEditingController(text: user?.shopGstin ?? '');
    _shopPan = TextEditingController(text: user?.shopPan ?? '');
    _upiVpa = TextEditingController(text: user?.upiVpa ?? '');
    _shopStateCode = user?.shopStateCode;
  }

  @override
  void dispose() {
    _name.dispose();
    _shopName.dispose();
    _shopAddress.dispose();
    _shopCity.dispose();
    _shopPinCode.dispose();
    _shopGstin.dispose();
    _shopPan.dispose();
    _upiVpa.dispose();
    super.dispose();
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
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.editProfile)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSizes.lg),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.length < 2) return 'Name must be at least 2 characters';
                if (t.length > 80) return 'Name too long';
                return null;
              },
            ),
            const SizedBox(height: AppSizes.lg),
            TextFormField(
              initialValue: user?.email ?? '',
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                helperText: 'Email changes are not supported yet',
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            Text(
              'Shop details',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'These appear on invoices and PDFs. GSTIN must match the state.',
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _shopName,
              decoration: const InputDecoration(labelText: 'Shop name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _shopAddress,
              decoration: const InputDecoration(labelText: 'Shop address'),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSizes.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _shopCity,
                    decoration: const InputDecoration(labelText: 'City'),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _shopPinCode,
                    decoration: const InputDecoration(labelText: 'PIN code'),
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
              decoration: const InputDecoration(labelText: 'State'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('— Select —'),
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
                    decoration: const InputDecoration(labelText: 'GSTIN'),
                    textCapitalization: TextCapitalization.characters,
                    validator: IndianValidators.gstin,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: TextFormField(
                    controller: _shopPan,
                    decoration: const InputDecoration(labelText: 'PAN'),
                    textCapitalization: TextCapitalization.characters,
                    validator: IndianValidators.pan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            TextFormField(
              controller: _upiVpa,
              decoration: const InputDecoration(
                labelText: 'UPI ID',
                hintText: 'shop@upi',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: IndianValidators.upiVpa,
            ),
            const SizedBox(height: AppSizes.xl),
            FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.black,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
