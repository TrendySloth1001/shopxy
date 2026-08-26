import 'package:shopxy/shared/constants/app_strings.dart';

class AuthValidators {
  const AuthValidators._();

  static String? password(String? v) {
    if (v == null || v.isEmpty) return AppStrings.fieldRequired;
    if (v.length < 10) return AppStrings.passwordTooShort;
    if (!v.contains(RegExp(r'[A-Za-z]'))) return AppStrings.passwordNeedsLetter;
    if (!v.contains(RegExp(r'[0-9]'))) return AppStrings.passwordNeedsNumber;
    return null;
  }
}
