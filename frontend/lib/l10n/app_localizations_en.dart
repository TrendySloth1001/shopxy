// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsPreferences => 'Preferences';

  @override
  String get settingsPreferencesSubtitle => 'Currency, theme and language.';

  @override
  String get theme => 'Theme';

  @override
  String get themeSubtitle => 'Choose how ShopXY looks on this device.';

  @override
  String get themeLight => 'Light';

  @override
  String get themeBeige => 'Beige';

  @override
  String get themeRose => 'Rose';

  @override
  String get themeSage => 'Sage';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeOled => 'OLED';

  @override
  String get themeMidnight => 'Midnight';

  @override
  String get themeNord => 'Nord';

  @override
  String get themeLightDesc => 'Warm canvas, dark text (default).';

  @override
  String get themeBeigeDesc => 'Soft sepia paper — warm, low glare.';

  @override
  String get themeRoseDesc => 'Warm blush — soft and easy on the eye.';

  @override
  String get themeSageDesc => 'Cool mint-green — calm and quiet.';

  @override
  String get themeDarkDesc => 'Deep slate surfaces, easy on the eyes.';

  @override
  String get themeOledDesc => 'True black — best for OLED displays.';

  @override
  String get themeMidnightDesc => 'Deep navy — indigo-tinted dark.';

  @override
  String get themeNordDesc => 'Muted arctic blue-grey — soft dark.';

  @override
  String get language => 'Language';

  @override
  String get languageSubtitle => 'Choose your preferred language.';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSignOut => 'Sign out';

  @override
  String get noShopTitle => 'No shop linked yet';

  @override
  String get noShopBody =>
      'Ask a shop owner to invite you to their team, then sign in again to accept.';
}
