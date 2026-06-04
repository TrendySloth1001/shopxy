import 'package:shopxy_customer/shared/constants/app_strings.dart';

/// Single source of truth for the client-side credential rules, mirroring
/// the backend zod schema (min 8 chars, ≥1 letter, ≥1 digit). Centralised
/// here so the rule can't drift between the multiple forms that use it
/// (C-AUTH-3). Returns a localised error string, or null when valid.
class AuthValidators {
  const AuthValidators._();

  /// Password rule — keep in lockstep with the backend
  /// (`auth.controller` zod: `len≥8`, letter, digit).
  static String? password(String? v) {
    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
    if (v.length < 8) return AppStrings.passwordTooShort;
    if (!v.contains(RegExp(r'[A-Za-z]'))) return AppStrings.passwordNeedsLetter;
    if (!v.contains(RegExp(r'[0-9]'))) return AppStrings.passwordNeedsNumber;
    return null;
  }
}
