import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:shopxy_customer/features/addresses/domain/entities/user_address.dart';
import 'package:shopxy_customer/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

/// Create-only form for now (the AddressesPage list doesn't surface
/// an "edit" affordance yet; that's an iteration when product asks).
/// Pops with `true` on success so the caller can show a snackbar.
class EditAddressPage extends StatefulWidget {
  const EditAddressPage({super.key});

  @override
  State<EditAddressPage> createState() => _EditAddressPageState();
}

class _EditAddressPageState extends State<EditAddressPage> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _landmark = TextEditingController();
  bool _isDefault = true;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_label, _fullName, _phone, _line1, _line2, _city, _state, _pincode, _landmark]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final addr = await context.read<AddressesProvider>().create(
          UserAddressInput(
            label: _label.text.trim().isEmpty ? null : _label.text.trim(),
            fullName: _fullName.text.trim(),
            phone: _phone.text.trim(),
            line1: _line1.text.trim(),
            line2: _line2.text.trim().isEmpty ? null : _line2.text.trim(),
            city: _city.text.trim(),
            state: _state.text.trim(),
            pincode: _pincode.text.trim(),
            landmark: _landmark.text.trim().isEmpty ? null : _landmark.text.trim(),
            isDefault: _isDefault,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    if (addr == null) {
      showAppSnackbar(
        context,
        message: context.read<AddressesProvider>().error ?? 'Could not save address',
        tone: AppSnackbarTone.error,
      );
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.black,
        title: const Text('Add address'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.lg),
            children: [
              _field(controller: _label, label: 'Label (e.g. Home, Work)', required: false),
              _field(controller: _fullName, label: 'Full name'),
              _field(
                controller: _phone,
                label: 'Phone',
                keyboard: TextInputType.phone,
                validator: _phoneValidator,
              ),
              _field(controller: _line1, label: 'Address line 1'),
              _field(controller: _line2, label: 'Address line 2', required: false),
              Row(
                children: [
                  Expanded(child: _field(controller: _city, label: 'City')),
                  const SizedBox(width: AppSizes.md),
                  Expanded(child: _field(controller: _state, label: 'State')),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _pincode,
                      label: 'Pincode',
                      keyboard: TextInputType.number,
                      validator: _pincodeValidator,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(child: _field(controller: _landmark, label: 'Landmark', required: false)),
                ],
              ),
              SwitchListTile.adaptive(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: const Text('Set as default delivery address'),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: AppSizes.lg),
              AppButton.primary(
                label: 'Save address',
                onPressed: _saving ? null : _save,
                isLoading: _saving,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool required = true,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.md),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator ??
            (required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null),
      ),
    );
  }

  /// Indian pincode: 6 digits, first digit 1–9. PIN 000000 / 100000-with-
  /// leading-zero patterns are not valid PINs.
  static final RegExp _kPincodeRe = RegExp(r'^[1-9][0-9]{5}$');
  static String? _pincodeValidator(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Required';
    if (!_kPincodeRe.hasMatch(s)) return 'Enter a valid 6-digit pincode';
    return null;
  }

  /// Indian mobile: 10 digits starting 6/7/8/9. Strips a leading +91 or
  /// "91 " so the user can paste either form. Accepts dashes and spaces
  /// while typing (they're stripped before validation).
  static final RegExp _kPhoneRe = RegExp(r'^[6-9][0-9]{9}$');
  static String? _phoneValidator(String? v) {
    final raw = (v ?? '').trim().replaceAll(RegExp(r'[\s\-]'), '');
    final stripped = raw.startsWith('+91')
        ? raw.substring(3)
        : raw.startsWith('91') && raw.length == 12
            ? raw.substring(2)
            : raw;
    if (stripped.isEmpty) return 'Required';
    if (!_kPhoneRe.hasMatch(stripped)) return 'Enter a valid 10-digit mobile';
    return null;
  }
}
