import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// Settings section: appearance & language preferences
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsPreferences;

  /// No description provided for @settingsPreferencesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Currency, theme and language.'**
  String get settingsPreferencesSubtitle;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how ShopXY looks on this device.'**
  String get themeSubtitle;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeBeige.
  ///
  /// In en, this message translates to:
  /// **'Beige'**
  String get themeBeige;

  /// No description provided for @themeRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get themeRose;

  /// No description provided for @themeSage.
  ///
  /// In en, this message translates to:
  /// **'Sage'**
  String get themeSage;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeOled.
  ///
  /// In en, this message translates to:
  /// **'OLED'**
  String get themeOled;

  /// No description provided for @themeMidnight.
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get themeMidnight;

  /// No description provided for @themeNord.
  ///
  /// In en, this message translates to:
  /// **'Nord'**
  String get themeNord;

  /// No description provided for @themeLightDesc.
  ///
  /// In en, this message translates to:
  /// **'Warm canvas, dark text (default).'**
  String get themeLightDesc;

  /// No description provided for @themeBeigeDesc.
  ///
  /// In en, this message translates to:
  /// **'Soft sepia paper — warm, low glare.'**
  String get themeBeigeDesc;

  /// No description provided for @themeRoseDesc.
  ///
  /// In en, this message translates to:
  /// **'Warm blush — soft and easy on the eye.'**
  String get themeRoseDesc;

  /// No description provided for @themeSageDesc.
  ///
  /// In en, this message translates to:
  /// **'Cool mint-green — calm and quiet.'**
  String get themeSageDesc;

  /// No description provided for @themeDarkDesc.
  ///
  /// In en, this message translates to:
  /// **'Deep slate surfaces, easy on the eyes.'**
  String get themeDarkDesc;

  /// No description provided for @themeOledDesc.
  ///
  /// In en, this message translates to:
  /// **'True black — best for OLED displays.'**
  String get themeOledDesc;

  /// No description provided for @themeMidnightDesc.
  ///
  /// In en, this message translates to:
  /// **'Deep navy — indigo-tinted dark.'**
  String get themeMidnightDesc;

  /// No description provided for @themeNordDesc.
  ///
  /// In en, this message translates to:
  /// **'Muted arctic blue-grey — soft dark.'**
  String get themeNordDesc;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language.'**
  String get languageSubtitle;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get commonSignOut;

  /// No description provided for @noShopTitle.
  ///
  /// In en, this message translates to:
  /// **'No shop linked yet'**
  String get noShopTitle;

  /// No description provided for @noShopBody.
  ///
  /// In en, this message translates to:
  /// **'Ask a shop owner to invite you to their team, then sign in again to accept.'**
  String get noShopBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
