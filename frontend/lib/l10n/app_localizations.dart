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

  /// No description provided for @offlineBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'No network — showing saved data'**
  String get offlineBannerMessage;

  /// No description provided for @offlineSyncingMessage.
  ///
  /// In en, this message translates to:
  /// **'Syncing {count} change(s)…'**
  String offlineSyncingMessage(int count);

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

  /// No description provided for @productsTitle.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productsTitle;

  /// No description provided for @productsSwitchToCardView.
  ///
  /// In en, this message translates to:
  /// **'Switch to card view'**
  String get productsSwitchToCardView;

  /// No description provided for @productsSwitchToCompactView.
  ///
  /// In en, this message translates to:
  /// **'Switch to compact view'**
  String get productsSwitchToCompactView;

  /// No description provided for @productsGridView.
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get productsGridView;

  /// No description provided for @productsListView.
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get productsListView;

  /// No description provided for @productsAddProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product'**
  String get productsAddProduct;

  /// No description provided for @productsHidden.
  ///
  /// In en, this message translates to:
  /// **'Products hidden'**
  String get productsHidden;

  /// No description provided for @productsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get productsSearchHint;

  /// No description provided for @productsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get productsFilterAll;

  /// No description provided for @productsLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get productsLowStock;

  /// No description provided for @productsOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get productsOutOfStock;

  /// No description provided for @productsCategoryPickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get productsCategoryPickerLabel;

  /// No description provided for @productsAllStockedUpTitle.
  ///
  /// In en, this message translates to:
  /// **'All stocked up'**
  String get productsAllStockedUpTitle;

  /// No description provided for @productsAllStockedUpHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing is running low right now. Nice work.'**
  String get productsAllStockedUpHint;

  /// No description provided for @productsNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get productsNoMatches;

  /// No description provided for @productsNoProducts.
  ///
  /// In en, this message translates to:
  /// **'No products found'**
  String get productsNoProducts;

  /// No description provided for @productsNoMatchesHint.
  ///
  /// In en, this message translates to:
  /// **'Try clearing filters or searching for something else.'**
  String get productsNoMatchesHint;

  /// No description provided for @productsNoProductsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first product'**
  String get productsNoProductsHint;

  /// No description provided for @productsStockInAction.
  ///
  /// In en, this message translates to:
  /// **'Stock in'**
  String get productsStockInAction;

  /// No description provided for @productsStockOutAction.
  ///
  /// In en, this message translates to:
  /// **'Stock out'**
  String get productsStockOutAction;

  /// No description provided for @productsNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get productsNotFoundTitle;

  /// No description provided for @productsNotFoundHint.
  ///
  /// In en, this message translates to:
  /// **'Add it now with the scanned code'**
  String get productsNotFoundHint;

  /// No description provided for @productsScanAgain.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get productsScanAgain;

  /// No description provided for @productsScanQr.
  ///
  /// In en, this message translates to:
  /// **'Scan QR / Barcode'**
  String get productsScanQr;

  /// No description provided for @productsScanHint.
  ///
  /// In en, this message translates to:
  /// **'Point camera at QR or barcode'**
  String get productsScanHint;

  /// No description provided for @productsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get productsLoading;

  /// No description provided for @productsSpecifications.
  ///
  /// In en, this message translates to:
  /// **'Specifications'**
  String get productsSpecifications;

  /// No description provided for @productsGenerateQr.
  ///
  /// In en, this message translates to:
  /// **'Generate QR Code'**
  String get productsGenerateQr;

  /// No description provided for @productsClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get productsClose;

  /// No description provided for @productsListedOnMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Listed on the marketplace.'**
  String get productsListedOnMarketplace;

  /// No description provided for @productsHiddenFromMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Hidden from the marketplace.'**
  String get productsHiddenFromMarketplace;

  /// No description provided for @productsCouldntUpdateVisibility.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update visibility'**
  String get productsCouldntUpdateVisibility;

  /// No description provided for @productsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get productsDelete;

  /// No description provided for @productsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this product?'**
  String get productsDeleteConfirm;

  /// No description provided for @productsDeleted.
  ///
  /// In en, this message translates to:
  /// **'Product deleted'**
  String get productsDeleted;

  /// No description provided for @productsError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get productsError;

  /// No description provided for @productsDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Product Details'**
  String get productsDetailsTitle;

  /// No description provided for @productsShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get productsShare;

  /// No description provided for @productsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get productsEdit;

  /// No description provided for @productsStockLedger.
  ///
  /// In en, this message translates to:
  /// **'Stock ledger'**
  String get productsStockLedger;

  /// No description provided for @productsStockLedgerHint.
  ///
  /// In en, this message translates to:
  /// **'Every movement with source documents'**
  String get productsStockLedgerHint;

  /// No description provided for @productsPricingSection.
  ///
  /// In en, this message translates to:
  /// **'PRICING'**
  String get productsPricingSection;

  /// No description provided for @productsMrp.
  ///
  /// In en, this message translates to:
  /// **'MRP'**
  String get productsMrp;

  /// No description provided for @productsSellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling Price'**
  String get productsSellingPrice;

  /// No description provided for @productsPurchasePrice.
  ///
  /// In en, this message translates to:
  /// **'Purchase Price'**
  String get productsPurchasePrice;

  /// No description provided for @productsTaxPercent.
  ///
  /// In en, this message translates to:
  /// **'Tax %'**
  String get productsTaxPercent;

  /// No description provided for @productsNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get productsNone;

  /// No description provided for @productsProfitMargin.
  ///
  /// In en, this message translates to:
  /// **'Profit Margin'**
  String get productsProfitMargin;

  /// No description provided for @productsDetailsSection.
  ///
  /// In en, this message translates to:
  /// **'DETAILS'**
  String get productsDetailsSection;

  /// No description provided for @productsHsnCode.
  ///
  /// In en, this message translates to:
  /// **'HSN Code'**
  String get productsHsnCode;

  /// No description provided for @productsUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get productsUnit;

  /// No description provided for @productsCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get productsCategory;

  /// No description provided for @productsCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get productsCreated;

  /// No description provided for @productsLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get productsLastUpdated;

  /// No description provided for @productsStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get productsStatus;

  /// No description provided for @productsActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get productsActive;

  /// No description provided for @productsInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get productsInactive;

  /// No description provided for @productsTagBestseller.
  ///
  /// In en, this message translates to:
  /// **'Bestseller'**
  String get productsTagBestseller;

  /// No description provided for @productsTagEditorsPick.
  ///
  /// In en, this message translates to:
  /// **'Editor\'s pick'**
  String get productsTagEditorsPick;

  /// No description provided for @productsTagNewArrival.
  ///
  /// In en, this message translates to:
  /// **'New arrival'**
  String get productsTagNewArrival;

  /// No description provided for @productsTagTrending.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get productsTagTrending;

  /// No description provided for @productsReviewSingular.
  ///
  /// In en, this message translates to:
  /// **'review'**
  String get productsReviewSingular;

  /// No description provided for @productsReviewPlural.
  ///
  /// In en, this message translates to:
  /// **'reviews'**
  String get productsReviewPlural;

  /// No description provided for @productsNoReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get productsNoReviewsYet;

  /// No description provided for @productsListedTitle.
  ///
  /// In en, this message translates to:
  /// **'Listed on marketplace'**
  String get productsListedTitle;

  /// No description provided for @productsNotListedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not listed'**
  String get productsNotListedTitle;

  /// No description provided for @productsListedHint.
  ///
  /// In en, this message translates to:
  /// **'Customers can find and buy this product.'**
  String get productsListedHint;

  /// No description provided for @productsNotListedHint.
  ///
  /// In en, this message translates to:
  /// **'Visible to you only. Flip to publish.'**
  String get productsNotListedHint;

  /// No description provided for @productsPerformance.
  ///
  /// In en, this message translates to:
  /// **'PERFORMANCE'**
  String get productsPerformance;

  /// No description provided for @productsLifetimeSold.
  ///
  /// In en, this message translates to:
  /// **'Lifetime sold'**
  String get productsLifetimeSold;

  /// No description provided for @productsSold30d.
  ///
  /// In en, this message translates to:
  /// **'Sold (30d)'**
  String get productsSold30d;

  /// No description provided for @productsReviewsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get productsReviewsLabel;

  /// No description provided for @productsLastActivity.
  ///
  /// In en, this message translates to:
  /// **'LAST ACTIVITY'**
  String get productsLastActivity;

  /// No description provided for @productsStockedIn.
  ///
  /// In en, this message translates to:
  /// **'Stocked in'**
  String get productsStockedIn;

  /// No description provided for @productsSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get productsSold;

  /// No description provided for @productsVariantsSection.
  ///
  /// In en, this message translates to:
  /// **'VARIANTS'**
  String get productsVariantsSection;

  /// No description provided for @productsDefaultVariant.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get productsDefaultVariant;

  /// No description provided for @productsDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get productsDefaultBadge;

  /// No description provided for @productsInactiveBadge.
  ///
  /// In en, this message translates to:
  /// **'INACTIVE'**
  String get productsInactiveBadge;

  /// No description provided for @productsHighlightsSection.
  ///
  /// In en, this message translates to:
  /// **'HIGHLIGHTS'**
  String get productsHighlightsSection;

  /// No description provided for @productsProductSpecs.
  ///
  /// In en, this message translates to:
  /// **'PRODUCT SPECS'**
  String get productsProductSpecs;

  /// No description provided for @productsCouponCopied.
  ///
  /// In en, this message translates to:
  /// **'Coupon code copied'**
  String get productsCouponCopied;

  /// No description provided for @productsOffersSection.
  ///
  /// In en, this message translates to:
  /// **'OFFERS'**
  String get productsOffersSection;

  /// No description provided for @productsBlockHero.
  ///
  /// In en, this message translates to:
  /// **'Hero'**
  String get productsBlockHero;

  /// No description provided for @productsBlockFeature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get productsBlockFeature;

  /// No description provided for @productsBlockComparison.
  ///
  /// In en, this message translates to:
  /// **'Comparison'**
  String get productsBlockComparison;

  /// No description provided for @productsBlockGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get productsBlockGallery;

  /// No description provided for @productsBlockText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get productsBlockText;

  /// No description provided for @productsColumnsUnit.
  ///
  /// In en, this message translates to:
  /// **'columns'**
  String get productsColumnsUnit;

  /// No description provided for @productsRowsUnit.
  ///
  /// In en, this message translates to:
  /// **'rows'**
  String get productsRowsUnit;

  /// No description provided for @productsImagesUnit.
  ///
  /// In en, this message translates to:
  /// **'images'**
  String get productsImagesUnit;

  /// No description provided for @productsRichContentSection.
  ///
  /// In en, this message translates to:
  /// **'RICH CONTENT'**
  String get productsRichContentSection;

  /// No description provided for @productsTagsSection.
  ///
  /// In en, this message translates to:
  /// **'TAGS'**
  String get productsTagsSection;

  /// No description provided for @productsLowStockAlertAt.
  ///
  /// In en, this message translates to:
  /// **'Low stock alert at'**
  String get productsLowStockAlertAt;

  /// No description provided for @productsInStock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get productsInStock;

  /// No description provided for @productsSupplierPriceHistory.
  ///
  /// In en, this message translates to:
  /// **'Supplier-wise Price History'**
  String get productsSupplierPriceHistory;

  /// No description provided for @productsNoSupplierHistory.
  ///
  /// In en, this message translates to:
  /// **'No supplier stock-in history yet'**
  String get productsNoSupplierHistory;

  /// No description provided for @productsUnknownSupplier.
  ///
  /// In en, this message translates to:
  /// **'Unknown Supplier'**
  String get productsUnknownSupplier;

  /// No description provided for @productsVendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get productsVendor;

  /// No description provided for @productsLatestPrice.
  ///
  /// In en, this message translates to:
  /// **'Latest Price'**
  String get productsLatestPrice;

  /// No description provided for @productsAveragePrice.
  ///
  /// In en, this message translates to:
  /// **'Average Price'**
  String get productsAveragePrice;

  /// No description provided for @productsTotalQuantityBought.
  ///
  /// In en, this message translates to:
  /// **'Total Bought'**
  String get productsTotalQuantityBought;

  /// No description provided for @productsPurchasesUnit.
  ///
  /// In en, this message translates to:
  /// **'purchases'**
  String get productsPurchasesUnit;

  /// No description provided for @productsLastStockIn.
  ///
  /// In en, this message translates to:
  /// **'Last Stock In'**
  String get productsLastStockIn;

  /// No description provided for @productsPolicy.
  ///
  /// In en, this message translates to:
  /// **'Policy'**
  String get productsPolicy;

  /// No description provided for @productsRecentBuys.
  ///
  /// In en, this message translates to:
  /// **'Recent Buys'**
  String get productsRecentBuys;

  /// No description provided for @productsQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get productsQtyLabel;

  /// No description provided for @productsWeightedAverage.
  ///
  /// In en, this message translates to:
  /// **'Weighted Avg'**
  String get productsWeightedAverage;

  /// No description provided for @productsUseLatestPrice.
  ///
  /// In en, this message translates to:
  /// **'Use Latest'**
  String get productsUseLatestPrice;

  /// No description provided for @productsKeepCurrentPrice.
  ///
  /// In en, this message translates to:
  /// **'Keep Current'**
  String get productsKeepCurrentPrice;

  /// No description provided for @productsStockIn.
  ///
  /// In en, this message translates to:
  /// **'Stock In'**
  String get productsStockIn;

  /// No description provided for @productsStockOut.
  ///
  /// In en, this message translates to:
  /// **'Stock Out'**
  String get productsStockOut;

  /// No description provided for @productsCopiedSuffix.
  ///
  /// In en, this message translates to:
  /// **'copied'**
  String get productsCopiedSuffix;

  /// No description provided for @productsSku.
  ///
  /// In en, this message translates to:
  /// **'SKU'**
  String get productsSku;

  /// No description provided for @productsBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get productsBarcode;

  /// No description provided for @productsPendingDrafts.
  ///
  /// In en, this message translates to:
  /// **'Pending drafts'**
  String get productsPendingDrafts;

  /// No description provided for @productsPendingDraftsHint.
  ///
  /// In en, this message translates to:
  /// **'Stock will move once these are confirmed.'**
  String get productsPendingDraftsHint;

  /// No description provided for @productsCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get productsCustomer;

  /// No description provided for @productsSale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get productsSale;

  /// No description provided for @productsPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get productsPurchase;

  /// No description provided for @productsPriceGstBreakdown.
  ///
  /// In en, this message translates to:
  /// **'PRICE & GST BREAKDOWN'**
  String get productsPriceGstBreakdown;

  /// No description provided for @productsTaxableValue.
  ///
  /// In en, this message translates to:
  /// **'Taxable value'**
  String get productsTaxableValue;

  /// No description provided for @productsPriceBeforeGst.
  ///
  /// In en, this message translates to:
  /// **'price before GST'**
  String get productsPriceBeforeGst;

  /// No description provided for @productsTotalGst.
  ///
  /// In en, this message translates to:
  /// **'Total GST'**
  String get productsTotalGst;

  /// No description provided for @productsSellingPriceInclGst.
  ///
  /// In en, this message translates to:
  /// **'Selling price (incl. GST)'**
  String get productsSellingPriceInclGst;

  /// No description provided for @productsGstExplainer.
  ///
  /// In en, this message translates to:
  /// **'Prices include GST. CGST + SGST shown for a sale within your state; a sale to another state is charged the same total as IGST.'**
  String get productsGstExplainer;

  /// No description provided for @productsReviewsSection.
  ///
  /// In en, this message translates to:
  /// **'REVIEWS'**
  String get productsReviewsSection;

  /// No description provided for @productsNoReviewsBody.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet. Verified buyers can rate this product after a confirmed purchase.'**
  String get productsNoReviewsBody;

  /// No description provided for @productsRatingSingular.
  ///
  /// In en, this message translates to:
  /// **'rating'**
  String get productsRatingSingular;

  /// No description provided for @productsRatingPlural.
  ///
  /// In en, this message translates to:
  /// **'ratings'**
  String get productsRatingPlural;

  /// No description provided for @productsVerified.
  ///
  /// In en, this message translates to:
  /// **'verified'**
  String get productsVerified;

  /// No description provided for @productsSeeAllReviews.
  ///
  /// In en, this message translates to:
  /// **'See all reviews'**
  String get productsSeeAllReviews;

  /// No description provided for @productsDuplicateWarning.
  ///
  /// In en, this message translates to:
  /// **'A product with that {label} already exists — saving will not merge'**
  String productsDuplicateWarning(Object label);

  /// No description provided for @productsBarcodeLower.
  ///
  /// In en, this message translates to:
  /// **'barcode'**
  String get productsBarcodeLower;

  /// No description provided for @productsDroppedBlocksPrefix.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get productsDroppedBlocksPrefix;

  /// No description provided for @productsMalformedBlockSingular.
  ///
  /// In en, this message translates to:
  /// **'malformed content block'**
  String get productsMalformedBlockSingular;

  /// No description provided for @productsMalformedBlockPlural.
  ///
  /// In en, this message translates to:
  /// **'malformed content blocks'**
  String get productsMalformedBlockPlural;

  /// No description provided for @productsFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get productsFieldRequired;

  /// No description provided for @productsInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get productsInvalidNumber;

  /// No description provided for @productsPriceMustBePositive.
  ///
  /// In en, this message translates to:
  /// **'Price must be greater than 0'**
  String get productsPriceMustBePositive;

  /// No description provided for @productsOcrApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied scan results'**
  String get productsOcrApplied;

  /// No description provided for @productsOcrNoDetails.
  ///
  /// In en, this message translates to:
  /// **'No product details found'**
  String get productsOcrNoDetails;

  /// No description provided for @productsOcrFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not read product details'**
  String get productsOcrFailed;

  /// No description provided for @productsImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is larger than 5 MB. Pick a smaller image or crop tighter.'**
  String get productsImageTooLarge;

  /// No description provided for @productsMaxImagesReached.
  ///
  /// In en, this message translates to:
  /// **'You can attach at most {count} images per product. Remove some to add more.'**
  String productsMaxImagesReached(Object count);

  /// No description provided for @productsSelectedButOnlyFit.
  ///
  /// In en, this message translates to:
  /// **'Selected {selected}, but only {remaining} more fit. Skipping the extras.'**
  String productsSelectedButOnlyFit(Object selected, Object remaining);

  /// No description provided for @productsFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'{name}: larger than 5 MB'**
  String productsFileTooLarge(Object name);

  /// No description provided for @productsUploadedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get productsUploadedPrefix;

  /// No description provided for @productsImageSingular.
  ///
  /// In en, this message translates to:
  /// **'image'**
  String get productsImageSingular;

  /// No description provided for @productsImagePlural.
  ///
  /// In en, this message translates to:
  /// **'images'**
  String get productsImagePlural;

  /// No description provided for @productsSkippedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get productsSkippedPrefix;

  /// No description provided for @productsInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid URL'**
  String get productsInvalidUrl;

  /// No description provided for @productsDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get productsDiscardTitle;

  /// No description provided for @productsDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Your edits will be lost.'**
  String get productsDiscardMessage;

  /// No description provided for @productsKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get productsKeepEditing;

  /// No description provided for @productsDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get productsDiscard;

  /// No description provided for @productsEditProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get productsEditProduct;

  /// No description provided for @productsReviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get productsReviews;

  /// No description provided for @productsScanLabel.
  ///
  /// In en, this message translates to:
  /// **'Scan label'**
  String get productsScanLabel;

  /// No description provided for @productsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get productsSave;

  /// No description provided for @productsSectionBasics.
  ///
  /// In en, this message translates to:
  /// **'THE BASICS'**
  String get productsSectionBasics;

  /// No description provided for @productsProductName.
  ///
  /// In en, this message translates to:
  /// **'Product Name'**
  String get productsProductName;

  /// No description provided for @productsNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Boult Astra TWS Earbuds'**
  String get productsNameHint;

  /// No description provided for @productsDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get productsDescription;

  /// No description provided for @productsDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'A line or two about what it is'**
  String get productsDescriptionHint;

  /// No description provided for @productsBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get productsBrand;

  /// No description provided for @productsBrandHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Boult — optional'**
  String get productsBrandHint;

  /// No description provided for @productsSectionPrice.
  ///
  /// In en, this message translates to:
  /// **'PRICE'**
  String get productsSectionPrice;

  /// No description provided for @productsSellingPriceLabel.
  ///
  /// In en, this message translates to:
  /// **'Selling price'**
  String get productsSellingPriceLabel;

  /// No description provided for @productsSellingPriceHelper.
  ///
  /// In en, this message translates to:
  /// **'What the customer pays'**
  String get productsSellingPriceHelper;

  /// No description provided for @productsMrpHelper.
  ///
  /// In en, this message translates to:
  /// **'Strike-through price'**
  String get productsMrpHelper;

  /// No description provided for @productsCostPrice.
  ///
  /// In en, this message translates to:
  /// **'Cost price'**
  String get productsCostPrice;

  /// No description provided for @productsCostPriceHelper.
  ///
  /// In en, this message translates to:
  /// **'What you pay'**
  String get productsCostPriceHelper;

  /// No description provided for @productsGst.
  ///
  /// In en, this message translates to:
  /// **'GST'**
  String get productsGst;

  /// No description provided for @productsOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get productsOptional;

  /// No description provided for @productsSectionIdentityStock.
  ///
  /// In en, this message translates to:
  /// **'IDENTITY & STOCK'**
  String get productsSectionIdentityStock;

  /// No description provided for @productsSkuHelper.
  ///
  /// In en, this message translates to:
  /// **'Your own product code — must be unique'**
  String get productsSkuHelper;

  /// No description provided for @productsOpeningStock.
  ///
  /// In en, this message translates to:
  /// **'Opening stock'**
  String get productsOpeningStock;

  /// No description provided for @productsSectionMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'MORE DETAILS'**
  String get productsSectionMoreDetails;

  /// No description provided for @productsMoreDetailsIntro.
  ///
  /// In en, this message translates to:
  /// **'All optional. Add as much as you like to make the product page richer — you can come back any time.'**
  String get productsMoreDetailsIntro;

  /// No description provided for @productsProductImages.
  ///
  /// In en, this message translates to:
  /// **'Product Images'**
  String get productsProductImages;

  /// No description provided for @productsPickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get productsPickFromGallery;

  /// No description provided for @productsTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get productsTakePhoto;

  /// No description provided for @productsGalleryEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Pick from gallery\" to select multiple images at once. Up to {count} per product.'**
  String productsGalleryEmptyHint(Object count);

  /// No description provided for @productsGalleryCountHint.
  ///
  /// In en, this message translates to:
  /// **'{count}/{max} images added.'**
  String productsGalleryCountHint(Object count, Object max);

  /// No description provided for @productsAddByImageLink.
  ///
  /// In en, this message translates to:
  /// **'Add by image link'**
  String get productsAddByImageLink;

  /// No description provided for @productsAddImageUrl.
  ///
  /// In en, this message translates to:
  /// **'Or paste image URL'**
  String get productsAddImageUrl;

  /// No description provided for @productsImageUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://...'**
  String get productsImageUrlHint;

  /// No description provided for @productsAddImage.
  ///
  /// In en, this message translates to:
  /// **'Add Image'**
  String get productsAddImage;

  /// No description provided for @productsHighlightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get productsHighlightsTitle;

  /// No description provided for @productsHighlightsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Short selling points shown up top'**
  String get productsHighlightsSubtitle;

  /// No description provided for @productsHighlightsIntro.
  ///
  /// In en, this message translates to:
  /// **'Short bullet points shown above the fold on the product page. Up to 8.'**
  String get productsHighlightsIntro;

  /// No description provided for @productsSpecificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Specifications'**
  String get productsSpecificationsTitle;

  /// No description provided for @productsSpecificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed spec sheet, grouped by section'**
  String get productsSpecificationsSubtitle;

  /// No description provided for @productsSpecificationsIntro.
  ///
  /// In en, this message translates to:
  /// **'Group attributes by section (e.g. \"Display\", \"Camera\"). Each row is a label and a value.'**
  String get productsSpecificationsIntro;

  /// No description provided for @productsOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get productsOffersTitle;

  /// No description provided for @productsOffersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Coupon, EMI or exchange offers'**
  String get productsOffersSubtitle;

  /// No description provided for @productsOffersIntro.
  ///
  /// In en, this message translates to:
  /// **'Bank, coupon, EMI or exchange offers shown beneath the price.'**
  String get productsOffersIntro;

  /// No description provided for @productsRichDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Rich product description'**
  String get productsRichDescriptionTitle;

  /// No description provided for @productsRichDescriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hero image, features, comparison, gallery'**
  String get productsRichDescriptionSubtitle;

  /// No description provided for @productsRichDescriptionShort.
  ///
  /// In en, this message translates to:
  /// **'Rich description'**
  String get productsRichDescriptionShort;

  /// No description provided for @productsRichDescriptionIntro.
  ///
  /// In en, this message translates to:
  /// **'Build the scrollable story on the product page. Add up to 8 blocks and drag them into order.'**
  String get productsRichDescriptionIntro;

  /// No description provided for @productsVariantsTitle.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get productsVariantsTitle;

  /// No description provided for @productsVariantsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Colours, sizes and other options'**
  String get productsVariantsSubtitle;

  /// No description provided for @productsVariantsIntro.
  ///
  /// In en, this message translates to:
  /// **'Optional. Declare axes (Colour, Size, …) and add one variant per combination. A single default variant is created automatically when you don\'t.'**
  String get productsVariantsIntro;

  /// No description provided for @productsTagsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get productsTagsTitle;

  /// No description provided for @productsTagsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keywords that help shoppers find this'**
  String get productsTagsSubtitle;

  /// No description provided for @productsTagsIntro.
  ///
  /// In en, this message translates to:
  /// **'Up to 20. Bestseller, Eco-friendly, etc.'**
  String get productsTagsIntro;

  /// No description provided for @productsMoreAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'More about this product'**
  String get productsMoreAboutTitle;

  /// No description provided for @productsMoreAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your shop\'s own custom fields'**
  String get productsMoreAboutSubtitle;

  /// No description provided for @productsMoreAboutIntro.
  ///
  /// In en, this message translates to:
  /// **'Shop-wide fields like Warranty, Model number or Material — define them once, reuse on every product.'**
  String get productsMoreAboutIntro;

  /// No description provided for @productsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get productsDone;

  /// No description provided for @productsBarcodeHelper.
  ///
  /// In en, this message translates to:
  /// **'The number under the striped code on the package'**
  String get productsBarcodeHelper;

  /// No description provided for @productsHsnCodeHelper.
  ///
  /// In en, this message translates to:
  /// **'Tax classification code for invoices'**
  String get productsHsnCodeHelper;

  /// No description provided for @productsHsnRateFrom.
  ///
  /// In en, this message translates to:
  /// **'GST rate from HSN {code}.'**
  String productsHsnRateFrom(String code);

  /// No description provided for @productsHsnRateFromHeading.
  ///
  /// In en, this message translates to:
  /// **'GST rate inferred from heading {code} — confirm it fits this item.'**
  String productsHsnRateFromHeading(String code);

  /// No description provided for @productsHsnRateUnknown.
  ///
  /// In en, this message translates to:
  /// **'No GST rate on file for this code. Check the code, or set the rate yourself.'**
  String get productsHsnRateUnknown;

  /// No description provided for @productsLowStockThreshold.
  ///
  /// In en, this message translates to:
  /// **'Low Stock Alert'**
  String get productsLowStockThreshold;

  /// No description provided for @productsLowStockThresholdHelper.
  ///
  /// In en, this message translates to:
  /// **'We\'ll flag the product once stock drops to this'**
  String get productsLowStockThresholdHelper;

  /// No description provided for @productsAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get productsAddTag;

  /// No description provided for @productsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get productsRemove;

  /// No description provided for @productsAddHighlightHint.
  ///
  /// In en, this message translates to:
  /// **'Add a highlight…'**
  String get productsAddHighlightHint;

  /// No description provided for @productsAddSpecGroup.
  ///
  /// In en, this message translates to:
  /// **'Add spec group'**
  String get productsAddSpecGroup;

  /// No description provided for @productsGroupTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Group title (e.g. Display)'**
  String get productsGroupTitleLabel;

  /// No description provided for @productsRemoveGroup.
  ///
  /// In en, this message translates to:
  /// **'Remove group'**
  String get productsRemoveGroup;

  /// No description provided for @productsTabLabel.
  ///
  /// In en, this message translates to:
  /// **'Tab (optional — e.g. Features & Specs)'**
  String get productsTabLabel;

  /// No description provided for @productsSpecLabelLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get productsSpecLabelLabel;

  /// No description provided for @productsSpecLabelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. In the box'**
  String get productsSpecLabelHint;

  /// No description provided for @productsRemoveRow.
  ///
  /// In en, this message translates to:
  /// **'Remove row'**
  String get productsRemoveRow;

  /// No description provided for @productsSpecValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get productsSpecValueLabel;

  /// No description provided for @productsSpecValueHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Earbuds, charging case, cable, manual'**
  String get productsSpecValueHint;

  /// No description provided for @productsAddRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get productsAddRow;

  /// No description provided for @productsBankOffersNote.
  ///
  /// In en, this message translates to:
  /// **'Bank offers are platform-wide and managed centrally. Customers will still see HDFC / ICICI / SBI etc. on this product\'s page if a platform offer is active.'**
  String get productsBankOffersNote;

  /// No description provided for @productsAddOffer.
  ///
  /// In en, this message translates to:
  /// **'Add offer'**
  String get productsAddOffer;

  /// No description provided for @productsOfferKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get productsOfferKind;

  /// No description provided for @productsOfferHeadline.
  ///
  /// In en, this message translates to:
  /// **'Headline'**
  String get productsOfferHeadline;

  /// No description provided for @productsOfferHeadlineHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. ₹2000 off with code WELCOME'**
  String get productsOfferHeadlineHint;

  /// No description provided for @productsOfferDetail.
  ///
  /// In en, this message translates to:
  /// **'Detail (optional)'**
  String get productsOfferDetail;

  /// No description provided for @productsOfferCode.
  ///
  /// In en, this message translates to:
  /// **'Code (optional)'**
  String get productsOfferCode;

  /// No description provided for @productsBlockHeroLabel.
  ///
  /// In en, this message translates to:
  /// **'Hero banner'**
  String get productsBlockHeroLabel;

  /// No description provided for @productsBlockHeroHint.
  ///
  /// In en, this message translates to:
  /// **'A big image with a headline'**
  String get productsBlockHeroHint;

  /// No description provided for @productsBlockFeatureLabel.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get productsBlockFeatureLabel;

  /// No description provided for @productsBlockFeatureHint.
  ///
  /// In en, this message translates to:
  /// **'Image beside a title + description'**
  String get productsBlockFeatureHint;

  /// No description provided for @productsBlockComparisonLabel.
  ///
  /// In en, this message translates to:
  /// **'Comparison table'**
  String get productsBlockComparisonLabel;

  /// No description provided for @productsBlockComparisonHint.
  ///
  /// In en, this message translates to:
  /// **'Compare this vs other options'**
  String get productsBlockComparisonHint;

  /// No description provided for @productsBlockGalleryLabel.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get productsBlockGalleryLabel;

  /// No description provided for @productsBlockGalleryHint.
  ///
  /// In en, this message translates to:
  /// **'A row of images with captions'**
  String get productsBlockGalleryHint;

  /// No description provided for @productsBlockTextLabel.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get productsBlockTextLabel;

  /// No description provided for @productsBlockTextHint.
  ///
  /// In en, this message translates to:
  /// **'A paragraph of rich text'**
  String get productsBlockTextHint;

  /// No description provided for @productsBlocksEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Build a rich product story shoppers scroll through — add a block to start.'**
  String get productsBlocksEmptyHint;

  /// No description provided for @productsBlockPosition.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String productsBlockPosition(Object index, Object total);

  /// No description provided for @productsMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get productsMoveUp;

  /// No description provided for @productsMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get productsMoveDown;

  /// No description provided for @productsBannerImage.
  ///
  /// In en, this message translates to:
  /// **'Banner image'**
  String get productsBannerImage;

  /// No description provided for @productsHeadline.
  ///
  /// In en, this message translates to:
  /// **'Headline'**
  String get productsHeadline;

  /// No description provided for @productsSubtext.
  ///
  /// In en, this message translates to:
  /// **'Subtext (optional)'**
  String get productsSubtext;

  /// No description provided for @productsFeatureImage.
  ///
  /// In en, this message translates to:
  /// **'Feature image'**
  String get productsFeatureImage;

  /// No description provided for @productsImageOnThe.
  ///
  /// In en, this message translates to:
  /// **'Image on the '**
  String get productsImageOnThe;

  /// No description provided for @productsSideLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get productsSideLeft;

  /// No description provided for @productsSideRight.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get productsSideRight;

  /// No description provided for @productsFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get productsFieldTitle;

  /// No description provided for @productsImageN.
  ///
  /// In en, this message translates to:
  /// **'Image {index}'**
  String productsImageN(Object index);

  /// No description provided for @productsCaption.
  ///
  /// In en, this message translates to:
  /// **'Caption (optional)'**
  String get productsCaption;

  /// No description provided for @productsAddImageAction.
  ///
  /// In en, this message translates to:
  /// **'Add image'**
  String get productsAddImageAction;

  /// No description provided for @productsComparisonIntro.
  ///
  /// In en, this message translates to:
  /// **'Name what you\'re comparing, then add a row for each feature and fill in a cell under every column.'**
  String get productsComparisonIntro;

  /// No description provided for @productsColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get productsColumns;

  /// No description provided for @productsColumnNName.
  ///
  /// In en, this message translates to:
  /// **'Column {index} name'**
  String productsColumnNName(Object index);

  /// No description provided for @productsThisProductHint.
  ///
  /// In en, this message translates to:
  /// **'This product'**
  String get productsThisProductHint;

  /// No description provided for @productsOtherCompetitorHint.
  ///
  /// In en, this message translates to:
  /// **'Other / competitor'**
  String get productsOtherCompetitorHint;

  /// No description provided for @productsRemoveColumn.
  ///
  /// In en, this message translates to:
  /// **'Remove column'**
  String get productsRemoveColumn;

  /// No description provided for @productsAddColumn.
  ///
  /// In en, this message translates to:
  /// **'Add column'**
  String get productsAddColumn;

  /// No description provided for @productsRows.
  ///
  /// In en, this message translates to:
  /// **'Rows'**
  String get productsRows;

  /// No description provided for @productsFeature.
  ///
  /// In en, this message translates to:
  /// **'Feature'**
  String get productsFeature;

  /// No description provided for @productsFeatureHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Battery life'**
  String get productsFeatureHint;

  /// No description provided for @productsColumnN.
  ///
  /// In en, this message translates to:
  /// **'Column {index}'**
  String productsColumnN(Object index);

  /// No description provided for @productsReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get productsReplace;

  /// No description provided for @productsUpload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get productsUpload;

  /// No description provided for @productsHideLinkField.
  ///
  /// In en, this message translates to:
  /// **'Hide link field'**
  String get productsHideLinkField;

  /// No description provided for @productsOrPasteLink.
  ///
  /// In en, this message translates to:
  /// **'or paste a link'**
  String get productsOrPasteLink;

  /// No description provided for @productsImageLinkUrl.
  ///
  /// In en, this message translates to:
  /// **'Image link (URL)'**
  String get productsImageLinkUrl;

  /// No description provided for @productsAxes.
  ///
  /// In en, this message translates to:
  /// **'Axes'**
  String get productsAxes;

  /// No description provided for @productsAddAxis.
  ///
  /// In en, this message translates to:
  /// **'Add axis (e.g. Colour, Size)'**
  String get productsAddAxis;

  /// No description provided for @productsVariantsLabel.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get productsVariantsLabel;

  /// No description provided for @productsAddVariant.
  ///
  /// In en, this message translates to:
  /// **'Add variant'**
  String get productsAddVariant;

  /// No description provided for @productsAxisNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Axis name (e.g. Colour)'**
  String get productsAxisNameLabel;

  /// No description provided for @productsValueN.
  ///
  /// In en, this message translates to:
  /// **'Value {index}'**
  String productsValueN(Object index);

  /// No description provided for @productsAddValue.
  ///
  /// In en, this message translates to:
  /// **'Add value'**
  String get productsAddValue;

  /// No description provided for @productsAxisFallback.
  ///
  /// In en, this message translates to:
  /// **'Axis'**
  String get productsAxisFallback;

  /// No description provided for @productsSellingShort.
  ///
  /// In en, this message translates to:
  /// **'Selling'**
  String get productsSellingShort;

  /// No description provided for @productsStockShort.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get productsStockShort;

  /// No description provided for @productsVariantImagesHint.
  ///
  /// In en, this message translates to:
  /// **'Add images for this exact variant — what colour it looks like, how it fits. Customers picking this option will see these instead of the product-level gallery.'**
  String get productsVariantImagesHint;

  /// No description provided for @productsAddVariantImage.
  ///
  /// In en, this message translates to:
  /// **'Add variant image'**
  String get productsAddVariantImage;

  /// No description provided for @productsFromGallery.
  ///
  /// In en, this message translates to:
  /// **'From gallery'**
  String get productsFromGallery;

  /// No description provided for @productsTakePhotoMenu.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get productsTakePhotoMenu;

  /// No description provided for @productsAddShort.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get productsAddShort;

  /// No description provided for @productsAddPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get productsAddPhotos;

  /// No description provided for @productsOutOfStockLabel.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get productsOutOfStockLabel;

  /// No description provided for @productsReorderAt.
  ///
  /// In en, this message translates to:
  /// **'reorder at'**
  String get productsReorderAt;

  /// No description provided for @productsInStockSuffix.
  ///
  /// In en, this message translates to:
  /// **'in stock'**
  String get productsInStockSuffix;

  /// No description provided for @productsOutSince.
  ///
  /// In en, this message translates to:
  /// **'Out since'**
  String get productsOutSince;

  /// No description provided for @productsLastIn.
  ///
  /// In en, this message translates to:
  /// **'Last in:'**
  String get productsLastIn;

  /// No description provided for @productsCostPrefix.
  ///
  /// In en, this message translates to:
  /// **'cost'**
  String get productsCostPrefix;

  /// No description provided for @productsAboveMrp.
  ///
  /// In en, this message translates to:
  /// **'above M.R.P.'**
  String get productsAboveMrp;

  /// No description provided for @ordersTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get ordersTitle;

  /// No description provided for @ordersNoAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Orders hidden'**
  String get ordersNoAccessTitle;

  /// No description provided for @ordersTabPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get ordersTabPending;

  /// No description provided for @ordersTabConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get ordersTabConfirmed;

  /// No description provided for @ordersTabRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get ordersTabRejected;

  /// No description provided for @ordersTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ordersTabAll;

  /// No description provided for @ordersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search customer, item or #id'**
  String get ordersSearchHint;

  /// No description provided for @ordersAnyDate.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get ordersAnyDate;

  /// No description provided for @ordersItemUnit.
  ///
  /// In en, this message translates to:
  /// **'item'**
  String get ordersItemUnit;

  /// No description provided for @ordersItemsUnit.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get ordersItemsUnit;

  /// No description provided for @ordersAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get ordersAllCaughtUp;

  /// No description provided for @ordersAllCaughtUpHint.
  ///
  /// In en, this message translates to:
  /// **'New orders will land here.'**
  String get ordersAllCaughtUpHint;

  /// No description provided for @ordersNoMatching.
  ///
  /// In en, this message translates to:
  /// **'No matching orders'**
  String get ordersNoMatching;

  /// No description provided for @ordersNoMatchingHint.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or date range.'**
  String get ordersNoMatchingHint;

  /// No description provided for @ordersNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No orders here yet'**
  String get ordersNoneYet;

  /// No description provided for @ordersNoneYetHint.
  ///
  /// In en, this message translates to:
  /// **'New orders will appear here when customers place them.'**
  String get ordersNoneYetHint;

  /// No description provided for @ordersError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get ordersError;

  /// No description provided for @ordersRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get ordersRetry;

  /// No description provided for @ordersDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String ordersDetailTitle(Object id);

  /// No description provided for @ordersActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share order summary'**
  String get ordersActionShare;

  /// No description provided for @ordersManageWhat.
  ///
  /// In en, this message translates to:
  /// **'manage orders'**
  String get ordersManageWhat;

  /// No description provided for @ordersDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get ordersDecline;

  /// No description provided for @ordersConfirmAndCreateInvoice.
  ///
  /// In en, this message translates to:
  /// **'Confirm & create invoice'**
  String get ordersConfirmAndCreateInvoice;

  /// No description provided for @ordersInvoiceCreated.
  ///
  /// In en, this message translates to:
  /// **'Invoice {no} created'**
  String ordersInvoiceCreated(Object no);

  /// No description provided for @ordersDeclinedToast.
  ///
  /// In en, this message translates to:
  /// **'Order declined'**
  String get ordersDeclinedToast;

  /// No description provided for @ordersShippingPosted.
  ///
  /// In en, this message translates to:
  /// **'Shipping update posted'**
  String get ordersShippingPosted;

  /// No description provided for @ordersStockPosted.
  ///
  /// In en, this message translates to:
  /// **'{name} stock posted'**
  String ordersStockPosted(Object name);

  /// No description provided for @ordersCouldNotOpenApp.
  ///
  /// In en, this message translates to:
  /// **'Could not open that app'**
  String get ordersCouldNotOpenApp;

  /// No description provided for @ordersWhatsappGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hi {name}, regarding your order #{id}.'**
  String ordersWhatsappGreeting(Object name, Object id);

  /// No description provided for @ordersEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String ordersEmailSubject(Object id);

  /// No description provided for @ordersShareHeader.
  ///
  /// In en, this message translates to:
  /// **'Order #{id} from {name}'**
  String ordersShareHeader(Object id, Object name);

  /// No description provided for @ordersJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get ordersJustNow;

  /// No description provided for @ordersMinAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String ordersMinAgo(Object n);

  /// No description provided for @ordersHrAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} hr ago'**
  String ordersHrAgo(Object n);

  /// No description provided for @ordersDayAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} days ago'**
  String ordersDayAgo(Object n);

  /// No description provided for @ordersSummaryItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get ordersSummaryItemsLabel;

  /// No description provided for @ordersSummaryQtyLabel.
  ///
  /// In en, this message translates to:
  /// **'Total qty'**
  String get ordersSummaryQtyLabel;

  /// No description provided for @ordersSummaryTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get ordersSummaryTotalLabel;

  /// No description provided for @ordersShortfallTitle.
  ///
  /// In en, this message translates to:
  /// **'{short} of {total} items short on stock'**
  String ordersShortfallTitle(Object short, Object total);

  /// No description provided for @ordersShortfallBody.
  ///
  /// In en, this message translates to:
  /// **'Restock now or decline — the invoice will fail to post otherwise.'**
  String get ordersShortfallBody;

  /// No description provided for @ordersRestock.
  ///
  /// In en, this message translates to:
  /// **'Restock'**
  String get ordersRestock;

  /// No description provided for @ordersLinkedParty.
  ///
  /// In en, this message translates to:
  /// **'Linked party'**
  String get ordersLinkedParty;

  /// No description provided for @ordersCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get ordersCall;

  /// No description provided for @ordersWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get ordersWhatsapp;

  /// No description provided for @ordersEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get ordersEmail;

  /// No description provided for @ordersCustomerNote.
  ///
  /// In en, this message translates to:
  /// **'Customer\'s note'**
  String get ordersCustomerNote;

  /// No description provided for @ordersJourneyPlaced.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get ordersJourneyPlaced;

  /// No description provided for @ordersJourneyDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get ordersJourneyDeclined;

  /// No description provided for @ordersJourneyCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get ordersJourneyCancelled;

  /// No description provided for @ordersJourneyConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get ordersJourneyConfirmed;

  /// No description provided for @ordersJourneyInvoiced.
  ///
  /// In en, this message translates to:
  /// **'Invoiced'**
  String get ordersJourneyInvoiced;

  /// No description provided for @ordersJourneyPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get ordersJourneyPaid;

  /// No description provided for @ordersInactiveProduct.
  ///
  /// In en, this message translates to:
  /// **'Inactive product'**
  String get ordersInactiveProduct;

  /// No description provided for @ordersStockUnknown.
  ///
  /// In en, this message translates to:
  /// **'Stock unknown'**
  String get ordersStockUnknown;

  /// No description provided for @ordersStockOk.
  ///
  /// In en, this message translates to:
  /// **'Asked {ask} · {have} {unit} in stock'**
  String ordersStockOk(Object ask, Object have, Object unit);

  /// No description provided for @ordersStockShort.
  ///
  /// In en, this message translates to:
  /// **'Asked {ask} · in stock {have} · short {short}'**
  String ordersStockShort(Object ask, Object have, Object short);

  /// No description provided for @ordersTotalsSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get ordersTotalsSubtotal;

  /// No description provided for @ordersTotalsTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get ordersTotalsTax;

  /// No description provided for @ordersTotalsDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get ordersTotalsDiscount;

  /// No description provided for @ordersTotalsTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get ordersTotalsTotal;

  /// No description provided for @ordersPartialFulfillFootnote.
  ///
  /// In en, this message translates to:
  /// **'Final invoice may differ if you partial-fulfill.'**
  String get ordersPartialFulfillFootnote;

  /// No description provided for @ordersOpenInvoice.
  ///
  /// In en, this message translates to:
  /// **'Open invoice {no}'**
  String ordersOpenInvoice(Object no);

  /// No description provided for @ordersConfirmShortfallTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock looks short — confirm anyway?'**
  String get ordersConfirmShortfallTitle;

  /// No description provided for @ordersConfirmOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm this order?'**
  String get ordersConfirmOrderTitle;

  /// No description provided for @ordersConfirmShortfallWarning.
  ///
  /// In en, this message translates to:
  /// **'Some items have less stock than the customer asked for. The draft invoice will fail to post when you try to confirm it.'**
  String get ordersConfirmShortfallWarning;

  /// No description provided for @ordersConfirmOrderBody.
  ///
  /// In en, this message translates to:
  /// **'This creates a draft sale invoice for the items. Stock will move once you confirm the invoice.'**
  String get ordersConfirmOrderBody;

  /// No description provided for @ordersNotYet.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get ordersNotYet;

  /// No description provided for @ordersConfirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm order'**
  String get ordersConfirmOrder;

  /// No description provided for @ordersDeclineReasonOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get ordersDeclineReasonOutOfStock;

  /// No description provided for @ordersDeclineReasonClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed today'**
  String get ordersDeclineReasonClosed;

  /// No description provided for @ordersDeclineReasonPriceChanged.
  ///
  /// In en, this message translates to:
  /// **'Price changed'**
  String get ordersDeclineReasonPriceChanged;

  /// No description provided for @ordersDeclineReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get ordersDeclineReasonOther;

  /// No description provided for @ordersDeclineOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Decline this order?'**
  String get ordersDeclineOrderTitle;

  /// No description provided for @ordersDeclineOrderBody.
  ///
  /// In en, this message translates to:
  /// **'The customer will be notified. You can leave a note explaining why.'**
  String get ordersDeclineOrderBody;

  /// No description provided for @ordersDeclineOrderNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get ordersDeclineOrderNoteHint;

  /// No description provided for @ordersKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep'**
  String get ordersKeep;

  /// No description provided for @ordersDeclineOrder.
  ///
  /// In en, this message translates to:
  /// **'Decline order'**
  String get ordersDeclineOrder;

  /// No description provided for @ordersShippingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Shipping updates'**
  String get ordersShippingUpdates;

  /// No description provided for @ordersUpdateShipping.
  ///
  /// In en, this message translates to:
  /// **'Update shipping'**
  String get ordersUpdateShipping;

  /// No description provided for @ordersNoShippingUpdates.
  ///
  /// In en, this message translates to:
  /// **'No shipping updates yet.'**
  String get ordersNoShippingUpdates;

  /// No description provided for @ordersMilestonePacked.
  ///
  /// In en, this message translates to:
  /// **'Packed'**
  String get ordersMilestonePacked;

  /// No description provided for @ordersMilestoneShipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get ordersMilestoneShipped;

  /// No description provided for @ordersMilestoneOutForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Out for delivery'**
  String get ordersMilestoneOutForDelivery;

  /// No description provided for @ordersMilestoneDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get ordersMilestoneDelivered;

  /// No description provided for @ordersMilestoneReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get ordersMilestoneReturned;

  /// No description provided for @ordersShippingSheetBody.
  ///
  /// In en, this message translates to:
  /// **'The customer sees these updates on their order. Marking Delivered starts their return window.'**
  String get ordersShippingSheetBody;

  /// No description provided for @ordersCourierHint.
  ///
  /// In en, this message translates to:
  /// **'Courier (optional), e.g. Delhivery'**
  String get ordersCourierHint;

  /// No description provided for @ordersAwbHint.
  ///
  /// In en, this message translates to:
  /// **'AWB / tracking number (optional)'**
  String get ordersAwbHint;

  /// No description provided for @ordersEtaHint.
  ///
  /// In en, this message translates to:
  /// **'ETA (optional)'**
  String get ordersEtaHint;

  /// No description provided for @ordersClearEta.
  ///
  /// In en, this message translates to:
  /// **'Clear ETA'**
  String get ordersClearEta;

  /// No description provided for @ordersNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get ordersNoteHint;

  /// No description provided for @ordersCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ordersCancel;

  /// No description provided for @ordersSaveUpdate.
  ///
  /// In en, this message translates to:
  /// **'Save update'**
  String get ordersSaveUpdate;

  /// No description provided for @ordersStockDraftPendingOne.
  ///
  /// In en, this message translates to:
  /// **'1 stock draft pending'**
  String get ordersStockDraftPendingOne;

  /// No description provided for @ordersStockDraftPendingMany.
  ///
  /// In en, this message translates to:
  /// **'{count} stock drafts pending'**
  String ordersStockDraftPendingMany(Object count);

  /// No description provided for @ordersStockDraftHint.
  ///
  /// In en, this message translates to:
  /// **'Confirm to post the stock — until then the shortfall stays.'**
  String get ordersStockDraftHint;

  /// No description provided for @ordersDraftInvoiceNo.
  ///
  /// In en, this message translates to:
  /// **'Draft invoice #{no}'**
  String ordersDraftInvoiceNo(Object no);

  /// No description provided for @ordersOpenDraft.
  ///
  /// In en, this message translates to:
  /// **'Open draft'**
  String get ordersOpenDraft;

  /// No description provided for @ordersConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get ordersConfirm;

  /// No description provided for @ordersHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get ordersHide;

  /// No description provided for @invoicesNavTitle.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get invoicesNavTitle;

  /// No description provided for @invoicesCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Invoice'**
  String get invoicesCreateTitle;

  /// No description provided for @invoicesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search invoice no, party, vendor'**
  String get invoicesSearchHint;

  /// No description provided for @invoicesFiltersTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get invoicesFiltersTooltip;

  /// No description provided for @invoicesFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get invoicesFilterAll;

  /// No description provided for @invoicesFilterSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get invoicesFilterSales;

  /// No description provided for @invoicesFilterPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get invoicesFilterPurchases;

  /// No description provided for @invoicesErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get invoicesErrorTitle;

  /// No description provided for @invoicesRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get invoicesRetry;

  /// No description provided for @invoicesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No invoices found'**
  String get invoicesEmptyTitle;

  /// No description provided for @invoicesEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create your first invoice to get started'**
  String get invoicesEmptyBody;

  /// No description provided for @invoicesGeneratingPdf.
  ///
  /// In en, this message translates to:
  /// **'Generating PDF...'**
  String get invoicesGeneratingPdf;

  /// No description provided for @invoicesItemUnit.
  ///
  /// In en, this message translates to:
  /// **'item'**
  String get invoicesItemUnit;

  /// No description provided for @invoicesItemsUnit.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get invoicesItemsUnit;

  /// No description provided for @invoicesDownloadTooltip.
  ///
  /// In en, this message translates to:
  /// **'Download Invoice'**
  String get invoicesDownloadTooltip;

  /// No description provided for @invoicesDocTaxInvoice.
  ///
  /// In en, this message translates to:
  /// **'Tax Invoice'**
  String get invoicesDocTaxInvoice;

  /// No description provided for @invoicesDocBillOfSupply.
  ///
  /// In en, this message translates to:
  /// **'Bill of Supply'**
  String get invoicesDocBillOfSupply;

  /// No description provided for @invoicesDocEstimate.
  ///
  /// In en, this message translates to:
  /// **'Estimate'**
  String get invoicesDocEstimate;

  /// No description provided for @invoicesDocProforma.
  ///
  /// In en, this message translates to:
  /// **'Proforma'**
  String get invoicesDocProforma;

  /// No description provided for @invoicesDocCreditNote.
  ///
  /// In en, this message translates to:
  /// **'Credit Note'**
  String get invoicesDocCreditNote;

  /// No description provided for @invoicesDocDebitNote.
  ///
  /// In en, this message translates to:
  /// **'Debit Note'**
  String get invoicesDocDebitNote;

  /// No description provided for @invoicesStatusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get invoicesStatusDraft;

  /// No description provided for @invoicesStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get invoicesStatusConfirmed;

  /// No description provided for @invoicesStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get invoicesStatusCancelled;

  /// No description provided for @invoicesFilterAllDocuments.
  ///
  /// In en, this message translates to:
  /// **'All documents'**
  String get invoicesFilterAllDocuments;

  /// No description provided for @invoicesFilterAnyStatus.
  ///
  /// In en, this message translates to:
  /// **'Any status'**
  String get invoicesFilterAnyStatus;

  /// No description provided for @invoicesFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get invoicesFiltersTitle;

  /// No description provided for @invoicesDocumentTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get invoicesDocumentTypeLabel;

  /// No description provided for @invoicesStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get invoicesStatusLabel;

  /// No description provided for @invoicesClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get invoicesClearAll;

  /// No description provided for @invoicesApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get invoicesApply;

  /// No description provided for @invoicesEditDraftTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Draft'**
  String get invoicesEditDraftTitle;

  /// No description provided for @invoicesSaveAsDraft.
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get invoicesSaveAsDraft;

  /// No description provided for @invoicesUpdateDraft.
  ///
  /// In en, this message translates to:
  /// **'Update draft'**
  String get invoicesUpdateDraft;

  /// No description provided for @invoicesSaveAndConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save & confirm'**
  String get invoicesSaveAndConfirm;

  /// No description provided for @invoicesUpdateAndConfirm.
  ///
  /// In en, this message translates to:
  /// **'Update & confirm'**
  String get invoicesUpdateAndConfirm;

  /// No description provided for @invoicesInvoiceType.
  ///
  /// In en, this message translates to:
  /// **'Invoice Type'**
  String get invoicesInvoiceType;

  /// No description provided for @invoicesSaleInvoice.
  ///
  /// In en, this message translates to:
  /// **'Sale Invoice'**
  String get invoicesSaleInvoice;

  /// No description provided for @invoicesPurchaseInvoice.
  ///
  /// In en, this message translates to:
  /// **'Purchase Invoice'**
  String get invoicesPurchaseInvoice;

  /// No description provided for @invoicesCustomerInfo.
  ///
  /// In en, this message translates to:
  /// **'Customer Information'**
  String get invoicesCustomerInfo;

  /// No description provided for @invoicesVendorInfo.
  ///
  /// In en, this message translates to:
  /// **'Vendor Information'**
  String get invoicesVendorInfo;

  /// No description provided for @invoicesSelectVendor.
  ///
  /// In en, this message translates to:
  /// **'Select vendor'**
  String get invoicesSelectVendor;

  /// No description provided for @invoicesSelectParty.
  ///
  /// In en, this message translates to:
  /// **'Select party'**
  String get invoicesSelectParty;

  /// No description provided for @invoicesCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get invoicesCustomerName;

  /// No description provided for @invoicesPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get invoicesPhone;

  /// No description provided for @invoicesGstin.
  ///
  /// In en, this message translates to:
  /// **'GSTIN'**
  String get invoicesGstin;

  /// No description provided for @invoicesPlaceOfSupply.
  ///
  /// In en, this message translates to:
  /// **'Place of supply (state)'**
  String get invoicesPlaceOfSupply;

  /// No description provided for @invoicesPlaceOfSupplyHelper.
  ///
  /// In en, this message translates to:
  /// **'Buyer state — drives CGST/SGST vs IGST'**
  String get invoicesPlaceOfSupplyHelper;

  /// No description provided for @invoicesSelectDash.
  ///
  /// In en, this message translates to:
  /// **'— Select —'**
  String get invoicesSelectDash;

  /// No description provided for @invoicesInvoiceItems.
  ///
  /// In en, this message translates to:
  /// **'Invoice Items'**
  String get invoicesInvoiceItems;

  /// No description provided for @invoicesSearchToAddProduct.
  ///
  /// In en, this message translates to:
  /// **'Search product to add'**
  String get invoicesSearchToAddProduct;

  /// No description provided for @invoicesScanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get invoicesScanBarcode;

  /// No description provided for @invoicesNoItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No items added yet'**
  String get invoicesNoItemsYet;

  /// No description provided for @invoicesTotals.
  ///
  /// In en, this message translates to:
  /// **'Totals'**
  String get invoicesTotals;

  /// No description provided for @invoicesPricesIncludeGst.
  ///
  /// In en, this message translates to:
  /// **'Prices include GST'**
  String get invoicesPricesIncludeGst;

  /// No description provided for @invoicesPricesInclusiveHint.
  ///
  /// In en, this message translates to:
  /// **'Tax is backed out of the entered prices'**
  String get invoicesPricesInclusiveHint;

  /// No description provided for @invoicesPricesExclusiveHint.
  ///
  /// In en, this message translates to:
  /// **'GST is added on top of the entered prices'**
  String get invoicesPricesExclusiveHint;

  /// No description provided for @invoicesSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get invoicesSubtotal;

  /// No description provided for @invoicesDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get invoicesDiscount;

  /// No description provided for @invoicesRoundOff.
  ///
  /// In en, this message translates to:
  /// **'Round-off'**
  String get invoicesRoundOff;

  /// No description provided for @invoicesGrandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get invoicesGrandTotal;

  /// No description provided for @invoicesNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get invoicesNote;

  /// No description provided for @invoicesChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get invoicesChange;

  /// No description provided for @invoicesQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get invoicesQuantity;

  /// No description provided for @invoicesUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit Price'**
  String get invoicesUnitPrice;

  /// No description provided for @invoicesTax.
  ///
  /// In en, this message translates to:
  /// **'Tax'**
  String get invoicesTax;

  /// No description provided for @invoicesTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get invoicesTotal;

  /// No description provided for @invoicesNeedsItems.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one item'**
  String get invoicesNeedsItems;

  /// No description provided for @invoicesUpdatedAndConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Invoice updated and confirmed'**
  String get invoicesUpdatedAndConfirmed;

  /// No description provided for @invoicesSavedAsDraft.
  ///
  /// In en, this message translates to:
  /// **'Saved as draft'**
  String get invoicesSavedAsDraft;

  /// No description provided for @invoicesConfirmedNamed.
  ///
  /// In en, this message translates to:
  /// **'{invoiceNo} confirmed'**
  String invoicesConfirmedNamed(Object invoiceNo);

  /// No description provided for @invoicesSavedDraftConfirmFailed.
  ///
  /// In en, this message translates to:
  /// **'Saved as draft — confirm failed, please review.'**
  String get invoicesSavedDraftConfirmFailed;

  /// No description provided for @invoicesDiscardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get invoicesDiscardChangesTitle;

  /// No description provided for @invoicesDiscardChangesBody.
  ///
  /// In en, this message translates to:
  /// **'Your edits will be lost.'**
  String get invoicesDiscardChangesBody;

  /// No description provided for @invoicesKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get invoicesKeepEditing;

  /// No description provided for @invoicesDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get invoicesDiscard;

  /// No description provided for @invoicesErrorTitle2Unused.
  ///
  /// In en, this message translates to:
  /// **'unused'**
  String get invoicesErrorTitle2Unused;

  /// No description provided for @invoicesPaymentModeOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get invoicesPaymentModeOnline;

  /// No description provided for @invoicesPaymentModeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get invoicesPaymentModeCash;

  /// No description provided for @invoicesPaymentModeCheque.
  ///
  /// In en, this message translates to:
  /// **'Cheque'**
  String get invoicesPaymentModeCheque;

  /// No description provided for @invoicesPaymentModeCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get invoicesPaymentModeCard;

  /// No description provided for @invoicesCouldNotOpenWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Could not open WhatsApp'**
  String get invoicesCouldNotOpenWhatsApp;

  /// No description provided for @invoicesConvertTitle.
  ///
  /// In en, this message translates to:
  /// **'Convert to Invoice?'**
  String get invoicesConvertTitle;

  /// No description provided for @invoicesConvertBody.
  ///
  /// In en, this message translates to:
  /// **'A new tax invoice will be created from {invoiceNo}. The estimate stays on file unchanged.'**
  String invoicesConvertBody(Object invoiceNo);

  /// No description provided for @invoicesCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get invoicesCancel;

  /// No description provided for @invoicesConvert.
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get invoicesConvert;

  /// No description provided for @invoicesCancelledNamed.
  ///
  /// In en, this message translates to:
  /// **'{invoiceNo} cancelled'**
  String invoicesCancelledNamed(Object invoiceNo);

  /// No description provided for @invoicesCancelInvoice.
  ///
  /// In en, this message translates to:
  /// **'Cancel Invoice'**
  String get invoicesCancelInvoice;

  /// No description provided for @invoicesCancelConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Cancel {invoiceNo}? No stock will be moved and the invoice will be marked as cancelled.'**
  String invoicesCancelConfirmBody(Object invoiceNo);

  /// No description provided for @invoicesKeepDraft.
  ///
  /// In en, this message translates to:
  /// **'Keep draft'**
  String get invoicesKeepDraft;

  /// No description provided for @invoicesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get invoicesEdit;

  /// No description provided for @invoicesShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get invoicesShare;

  /// No description provided for @invoicesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get invoicesDelete;

  /// No description provided for @invoicesDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Delete {invoiceNo}? This can\'t be undone.'**
  String invoicesDeleteConfirmBody(Object invoiceNo);

  /// No description provided for @invoicesDeletedNamed.
  ///
  /// In en, this message translates to:
  /// **'{invoiceNo} deleted'**
  String invoicesDeletedNamed(Object invoiceNo);

  /// No description provided for @invoicesCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get invoicesCustomer;

  /// No description provided for @invoicesVendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get invoicesVendor;

  /// No description provided for @invoicesAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get invoicesAddress;

  /// No description provided for @invoicesTaxAmount.
  ///
  /// In en, this message translates to:
  /// **'Tax Amount'**
  String get invoicesTaxAmount;

  /// No description provided for @invoicesCess.
  ///
  /// In en, this message translates to:
  /// **'Cess'**
  String get invoicesCess;

  /// No description provided for @invoicesReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get invoicesReceived;

  /// No description provided for @invoicesOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get invoicesOutstanding;

  /// No description provided for @invoicesPaymentsReceivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Payments received'**
  String get invoicesPaymentsReceivedTitle;

  /// No description provided for @invoicesSendViaWhatsApp.
  ///
  /// In en, this message translates to:
  /// **'Send via WhatsApp'**
  String get invoicesSendViaWhatsApp;

  /// No description provided for @invoicesOpensChatWith.
  ///
  /// In en, this message translates to:
  /// **'Opens chat with {phone}'**
  String invoicesOpensChatWith(Object phone);

  /// No description provided for @invoicesPickChatToSend.
  ///
  /// In en, this message translates to:
  /// **'Pick a chat to send to'**
  String get invoicesPickChatToSend;

  /// No description provided for @invoicesConvertToInvoice.
  ///
  /// In en, this message translates to:
  /// **'Convert to Invoice'**
  String get invoicesConvertToInvoice;

  /// No description provided for @invoicesConvertTileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a tax invoice from this estimate'**
  String get invoicesConvertTileSubtitle;

  /// No description provided for @invoicesMarkAsPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as Paid'**
  String get invoicesMarkAsPaid;

  /// No description provided for @invoicesRecordReceiptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record a receipt for this invoice'**
  String get invoicesRecordReceiptSubtitle;

  /// No description provided for @invoicesRecordPaymentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Record a payment for this bill'**
  String get invoicesRecordPaymentSubtitle;

  /// No description provided for @invoicesPaymentRecorded.
  ///
  /// In en, this message translates to:
  /// **'Payment recorded'**
  String get invoicesPaymentRecorded;

  /// No description provided for @invoicesConfirmInvoice.
  ///
  /// In en, this message translates to:
  /// **'Confirm Invoice'**
  String get invoicesConfirmInvoice;

  /// No description provided for @invoicesIssueNoteAction.
  ///
  /// In en, this message translates to:
  /// **'Issue credit / debit note'**
  String get invoicesIssueNoteAction;

  /// No description provided for @invoicesIssueNoteActionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust this confirmed sale with a credit or debit note'**
  String get invoicesIssueNoteActionSubtitle;

  /// No description provided for @invoicesIssueNoteTitle.
  ///
  /// In en, this message translates to:
  /// **'Issue note'**
  String get invoicesIssueNoteTitle;

  /// No description provided for @invoicesCreditNoteExplainer.
  ///
  /// In en, this message translates to:
  /// **'Reduces what the customer owes. Returned goods can be put back into stock.'**
  String get invoicesCreditNoteExplainer;

  /// No description provided for @invoicesDebitNoteExplainer.
  ///
  /// In en, this message translates to:
  /// **'Bills the customer an extra amount — e.g. correcting an undercharge.'**
  String get invoicesDebitNoteExplainer;

  /// No description provided for @invoicesNoteReturnToStock.
  ///
  /// In en, this message translates to:
  /// **'Return goods to stock'**
  String get invoicesNoteReturnToStock;

  /// No description provided for @invoicesNoteReason.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get invoicesNoteReason;

  /// No description provided for @invoicesNoteExtraPerUnit.
  ///
  /// In en, this message translates to:
  /// **'Extra per unit'**
  String get invoicesNoteExtraPerUnit;

  /// No description provided for @invoicesIssueCreditNote.
  ///
  /// In en, this message translates to:
  /// **'Issue credit note'**
  String get invoicesIssueCreditNote;

  /// No description provided for @invoicesIssueDebitNote.
  ///
  /// In en, this message translates to:
  /// **'Issue debit note'**
  String get invoicesIssueDebitNote;

  /// No description provided for @invoicesNoteSelectLines.
  ///
  /// In en, this message translates to:
  /// **'Add at least one line to the note'**
  String get invoicesNoteSelectLines;

  /// No description provided for @invoicesNoteSoldQty.
  ///
  /// In en, this message translates to:
  /// **'Sold {qty}'**
  String invoicesNoteSoldQty(Object qty);

  /// No description provided for @invoicesNoteIssued.
  ///
  /// In en, this message translates to:
  /// **'{noteNo} issued'**
  String invoicesNoteIssued(Object noteNo);

  /// No description provided for @invoicesNoteAgainst.
  ///
  /// In en, this message translates to:
  /// **'Against {invoiceNo}'**
  String invoicesNoteAgainst(Object invoiceNo);

  /// No description provided for @invoicesNoteApproxTotal.
  ///
  /// In en, this message translates to:
  /// **'Approx. total {amount}'**
  String invoicesNoteApproxTotal(Object amount);

  /// No description provided for @partiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Parties'**
  String get partiesTitle;

  /// No description provided for @partiesAddParty.
  ///
  /// In en, this message translates to:
  /// **'Add Party'**
  String get partiesAddParty;

  /// No description provided for @partiesEditParty.
  ///
  /// In en, this message translates to:
  /// **'Edit Party'**
  String get partiesEditParty;

  /// No description provided for @partiesDeleteParty.
  ///
  /// In en, this message translates to:
  /// **'Delete Party'**
  String get partiesDeleteParty;

  /// No description provided for @partiesDeletePartyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this party? \"{name}\"?'**
  String partiesDeletePartyConfirm(Object name);

  /// No description provided for @partiesPartyDeleted.
  ///
  /// In en, this message translates to:
  /// **'Party deleted successfully'**
  String get partiesPartyDeleted;

  /// No description provided for @partiesSearchParties.
  ///
  /// In en, this message translates to:
  /// **'Search parties...'**
  String get partiesSearchParties;

  /// No description provided for @partiesNoParties.
  ///
  /// In en, this message translates to:
  /// **'No parties found'**
  String get partiesNoParties;

  /// No description provided for @partiesNoPartiesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first party'**
  String get partiesNoPartiesHint;

  /// No description provided for @partiesSelectParty.
  ///
  /// In en, this message translates to:
  /// **'Select party'**
  String get partiesSelectParty;

  /// No description provided for @partiesNewParty.
  ///
  /// In en, this message translates to:
  /// **'New party'**
  String get partiesNewParty;

  /// No description provided for @partiesPartyName.
  ///
  /// In en, this message translates to:
  /// **'Party Name'**
  String get partiesPartyName;

  /// No description provided for @partiesContactName.
  ///
  /// In en, this message translates to:
  /// **'Contact Name'**
  String get partiesContactName;

  /// No description provided for @partiesPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get partiesPhone;

  /// No description provided for @partiesEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get partiesEmail;

  /// No description provided for @partiesGstin.
  ///
  /// In en, this message translates to:
  /// **'GSTIN'**
  String get partiesGstin;

  /// No description provided for @partiesAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get partiesAddress;

  /// No description provided for @partiesCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get partiesCity;

  /// No description provided for @partiesPinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get partiesPinCode;

  /// No description provided for @partiesState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get partiesState;

  /// No description provided for @partiesSelectPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'— Select —'**
  String get partiesSelectPlaceholder;

  /// No description provided for @partiesSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get partiesSave;

  /// No description provided for @partiesEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get partiesEdit;

  /// No description provided for @partiesDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get partiesDelete;

  /// No description provided for @partiesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get partiesConfirm;

  /// No description provided for @partiesFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get partiesFieldRequired;

  /// No description provided for @partiesPartyUpdated.
  ///
  /// In en, this message translates to:
  /// **'{name} updated'**
  String partiesPartyUpdated(Object name);

  /// No description provided for @partiesPartyAdded.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String partiesPartyAdded(Object name);

  /// No description provided for @partiesCancelInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel invitation'**
  String get partiesCancelInvitationTitle;

  /// No description provided for @partiesCancelInvitationBody.
  ///
  /// In en, this message translates to:
  /// **'Cancel this pending invitation? You can send a new one later.'**
  String get partiesCancelInvitationBody;

  /// No description provided for @partiesInvitationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Invitation cancelled'**
  String get partiesInvitationCancelled;

  /// No description provided for @partiesAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'Already linked'**
  String get partiesAlreadyLinked;

  /// No description provided for @partiesInviteToShopxy.
  ///
  /// In en, this message translates to:
  /// **'Invite to Shopxy'**
  String get partiesInviteToShopxy;

  /// No description provided for @partiesAddEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Add an email first'**
  String get partiesAddEmailFirst;

  /// No description provided for @partiesSentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to {email}'**
  String partiesSentTo(Object email);

  /// No description provided for @partiesGstinLabel.
  ///
  /// In en, this message translates to:
  /// **'GSTIN'**
  String get partiesGstinLabel;

  /// No description provided for @partiesChallansUnit.
  ///
  /// In en, this message translates to:
  /// **'challans'**
  String get partiesChallansUnit;

  /// No description provided for @partiesInvoicesUnit.
  ///
  /// In en, this message translates to:
  /// **'invoices'**
  String get partiesInvoicesUnit;

  /// No description provided for @partiesItemsUnit.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get partiesItemsUnit;

  /// No description provided for @partiesBillsUnit.
  ///
  /// In en, this message translates to:
  /// **'bills'**
  String get partiesBillsUnit;

  /// No description provided for @partiesInviteStatusInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get partiesInviteStatusInvited;

  /// No description provided for @partiesInviteStatusLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get partiesInviteStatusLinked;

  /// No description provided for @partiesInviteStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get partiesInviteStatusDeclined;

  /// No description provided for @partiesInviteStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get partiesInviteStatusCancelled;

  /// No description provided for @partiesInviteStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get partiesInviteStatusExpired;

  /// No description provided for @partiesPartyTitle.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get partiesPartyTitle;

  /// No description provided for @partiesRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get partiesRecordPayment;

  /// No description provided for @partiesLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get partiesLedger;

  /// No description provided for @partiesRecentInvoices.
  ///
  /// In en, this message translates to:
  /// **'Recent invoices'**
  String get partiesRecentInvoices;

  /// No description provided for @partiesRecentChallans.
  ///
  /// In en, this message translates to:
  /// **'Recent challans'**
  String get partiesRecentChallans;

  /// No description provided for @partiesNoActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity yet.'**
  String get partiesNoActivityYet;

  /// No description provided for @partiesNetBilled.
  ///
  /// In en, this message translates to:
  /// **'Net billed'**
  String get partiesNetBilled;

  /// No description provided for @partiesSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get partiesSales;

  /// No description provided for @partiesReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get partiesReturns;

  /// No description provided for @partiesBalance.
  ///
  /// In en, this message translates to:
  /// **'BALANCE'**
  String get partiesBalance;

  /// No description provided for @partiesBalanceShort.
  ///
  /// In en, this message translates to:
  /// **'Bal'**
  String get partiesBalanceShort;

  /// No description provided for @partiesNoOutstanding.
  ///
  /// In en, this message translates to:
  /// **'No outstanding'**
  String get partiesNoOutstanding;

  /// No description provided for @partiesOwesYou.
  ///
  /// In en, this message translates to:
  /// **'Owes you'**
  String get partiesOwesYou;

  /// No description provided for @partiesAdvanceCredit.
  ///
  /// In en, this message translates to:
  /// **'Advance / credit'**
  String get partiesAdvanceCredit;

  /// No description provided for @vendorsTitle.
  ///
  /// In en, this message translates to:
  /// **'Vendors'**
  String get vendorsTitle;

  /// No description provided for @vendorsAddVendor.
  ///
  /// In en, this message translates to:
  /// **'Add Vendor'**
  String get vendorsAddVendor;

  /// No description provided for @vendorsEditVendor.
  ///
  /// In en, this message translates to:
  /// **'Edit Vendor'**
  String get vendorsEditVendor;

  /// No description provided for @vendorsDeleteVendor.
  ///
  /// In en, this message translates to:
  /// **'Delete Vendor'**
  String get vendorsDeleteVendor;

  /// No description provided for @vendorsDeleteVendorConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this vendor?'**
  String get vendorsDeleteVendorConfirm;

  /// No description provided for @vendorsVendorDeleted.
  ///
  /// In en, this message translates to:
  /// **'Vendor deleted successfully'**
  String get vendorsVendorDeleted;

  /// No description provided for @vendorsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search vendors...'**
  String get vendorsSearchHint;

  /// No description provided for @vendorsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No vendors found'**
  String get vendorsEmptyTitle;

  /// No description provided for @vendorsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add your first vendor'**
  String get vendorsEmptyHint;

  /// No description provided for @vendorsVendorName.
  ///
  /// In en, this message translates to:
  /// **'Vendor Name'**
  String get vendorsVendorName;

  /// No description provided for @vendorsContactName.
  ///
  /// In en, this message translates to:
  /// **'Contact Name'**
  String get vendorsContactName;

  /// No description provided for @vendorsPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get vendorsPhone;

  /// No description provided for @vendorsEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get vendorsEmail;

  /// No description provided for @vendorsGstin.
  ///
  /// In en, this message translates to:
  /// **'GSTIN'**
  String get vendorsGstin;

  /// No description provided for @vendorsAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get vendorsAddress;

  /// No description provided for @vendorsCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get vendorsCity;

  /// No description provided for @vendorsPinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get vendorsPinCode;

  /// No description provided for @vendorsState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get vendorsState;

  /// No description provided for @vendorsStateSelect.
  ///
  /// In en, this message translates to:
  /// **'— Select —'**
  String get vendorsStateSelect;

  /// No description provided for @vendorsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get vendorsSave;

  /// No description provided for @vendorsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get vendorsDelete;

  /// No description provided for @vendorsEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get vendorsEdit;

  /// No description provided for @vendorsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get vendorsConfirm;

  /// No description provided for @vendorsFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get vendorsFieldRequired;

  /// No description provided for @vendorsSelectVendor.
  ///
  /// In en, this message translates to:
  /// **'Select vendor'**
  String get vendorsSelectVendor;

  /// No description provided for @vendorsNewVendor.
  ///
  /// In en, this message translates to:
  /// **'New vendor'**
  String get vendorsNewVendor;

  /// No description provided for @vendorsTxnsUnit.
  ///
  /// In en, this message translates to:
  /// **'txns'**
  String get vendorsTxnsUnit;

  /// No description provided for @vendorsInvoicesUnit.
  ///
  /// In en, this message translates to:
  /// **'invoices'**
  String get vendorsInvoicesUnit;

  /// No description provided for @vendorsCancelInviteTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel invitation'**
  String get vendorsCancelInviteTitle;

  /// No description provided for @vendorsCancelInviteMessage.
  ///
  /// In en, this message translates to:
  /// **'Cancel this pending invitation? You can send a new one later.'**
  String get vendorsCancelInviteMessage;

  /// No description provided for @vendorsInviteCancelled.
  ///
  /// In en, this message translates to:
  /// **'Invitation cancelled'**
  String get vendorsInviteCancelled;

  /// No description provided for @vendorsAlreadyLinked.
  ///
  /// In en, this message translates to:
  /// **'Already linked'**
  String get vendorsAlreadyLinked;

  /// No description provided for @vendorsInviteToShopxy.
  ///
  /// In en, this message translates to:
  /// **'Invite to Shopxy'**
  String get vendorsInviteToShopxy;

  /// No description provided for @vendorsAddEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Add an email first'**
  String get vendorsAddEmailFirst;

  /// No description provided for @vendorsCancelInvitation.
  ///
  /// In en, this message translates to:
  /// **'Cancel invitation'**
  String get vendorsCancelInvitation;

  /// No description provided for @vendorsSentTo.
  ///
  /// In en, this message translates to:
  /// **'Sent to'**
  String get vendorsSentTo;

  /// No description provided for @vendorsInviteStatusInvited.
  ///
  /// In en, this message translates to:
  /// **'Invited'**
  String get vendorsInviteStatusInvited;

  /// No description provided for @vendorsInviteStatusLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get vendorsInviteStatusLinked;

  /// No description provided for @vendorsInviteStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get vendorsInviteStatusDeclined;

  /// No description provided for @vendorsInviteStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get vendorsInviteStatusCancelled;

  /// No description provided for @vendorsInviteStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get vendorsInviteStatusExpired;

  /// No description provided for @vendorsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get vendorsDetailTitle;

  /// No description provided for @vendorsRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get vendorsRecordPayment;

  /// No description provided for @vendorsLedger.
  ///
  /// In en, this message translates to:
  /// **'Ledger'**
  String get vendorsLedger;

  /// No description provided for @vendorsRecentBills.
  ///
  /// In en, this message translates to:
  /// **'Recent bills'**
  String get vendorsRecentBills;

  /// No description provided for @vendorsRecentStockIn.
  ///
  /// In en, this message translates to:
  /// **'Recent stock-in'**
  String get vendorsRecentStockIn;

  /// No description provided for @vendorsNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity yet.'**
  String get vendorsNoActivity;

  /// No description provided for @vendorsLinked.
  ///
  /// In en, this message translates to:
  /// **'Linked'**
  String get vendorsLinked;

  /// No description provided for @vendorsNetPurchased.
  ///
  /// In en, this message translates to:
  /// **'Net purchased'**
  String get vendorsNetPurchased;

  /// No description provided for @vendorsBillsUnit.
  ///
  /// In en, this message translates to:
  /// **'bills'**
  String get vendorsBillsUnit;

  /// No description provided for @vendorsStockIns.
  ///
  /// In en, this message translates to:
  /// **'Stock-ins'**
  String get vendorsStockIns;

  /// No description provided for @vendorsLedgerRows.
  ///
  /// In en, this message translates to:
  /// **'Ledger rows'**
  String get vendorsLedgerRows;

  /// No description provided for @vendorsReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get vendorsReturns;

  /// No description provided for @vendorsItemUnit.
  ///
  /// In en, this message translates to:
  /// **'item'**
  String get vendorsItemUnit;

  /// No description provided for @vendorsItemsUnit.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get vendorsItemsUnit;

  /// No description provided for @vendorsNoOutstanding.
  ///
  /// In en, this message translates to:
  /// **'No outstanding'**
  String get vendorsNoOutstanding;

  /// No description provided for @vendorsYouOwe.
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get vendorsYouOwe;

  /// No description provided for @vendorsAdvanceWithVendor.
  ///
  /// In en, this message translates to:
  /// **'Advance with vendor'**
  String get vendorsAdvanceWithVendor;

  /// No description provided for @vendorsBalanceLabel.
  ///
  /// In en, this message translates to:
  /// **'BALANCE'**
  String get vendorsBalanceLabel;

  /// No description provided for @vendorsBalShort.
  ///
  /// In en, this message translates to:
  /// **'Bal'**
  String get vendorsBalShort;

  /// No description provided for @profileNavProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileNavProfile;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// No description provided for @profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditProfile;

  /// No description provided for @profileAppTagline.
  ///
  /// In en, this message translates to:
  /// **'Smart Inventory Management'**
  String get profileAppTagline;

  /// No description provided for @profileMemberSince.
  ///
  /// In en, this message translates to:
  /// **'Since'**
  String get profileMemberSince;

  /// No description provided for @profileManageBusiness.
  ///
  /// In en, this message translates to:
  /// **'Manage your business'**
  String get profileManageBusiness;

  /// No description provided for @profileNavCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get profileNavCategories;

  /// No description provided for @profileCategoriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Product categories and grouping'**
  String get profileCategoriesSubtitle;

  /// No description provided for @profileNavVendors.
  ///
  /// In en, this message translates to:
  /// **'Vendors'**
  String get profileNavVendors;

  /// No description provided for @profileVendorsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Suppliers you buy from'**
  String get profileVendorsSubtitle;

  /// No description provided for @profileNavParties.
  ///
  /// In en, this message translates to:
  /// **'Parties'**
  String get profileNavParties;

  /// No description provided for @profilePartiesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customers you sell to'**
  String get profilePartiesSubtitle;

  /// No description provided for @profileOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get profileOperations;

  /// No description provided for @profileNavInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get profileNavInvoices;

  /// No description provided for @profileInvoicesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sales, purchase and credit notes'**
  String get profileInvoicesSubtitle;

  /// No description provided for @profileNavChallans.
  ///
  /// In en, this message translates to:
  /// **'Challans'**
  String get profileNavChallans;

  /// No description provided for @profileChallansSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Delivery notes without prices'**
  String get profileChallansSubtitle;

  /// No description provided for @profileStockAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Stock adjustments'**
  String get profileStockAdjustments;

  /// No description provided for @profileStockAdjustmentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Damage, expiry, shrinkage corrections'**
  String get profileStockAdjustmentsSubtitle;

  /// No description provided for @profileReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get profileReports;

  /// No description provided for @profileReportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sales, purchases, GST and P&L'**
  String get profileReportsSubtitle;

  /// No description provided for @profileFinishShopSetup.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up your shop'**
  String get profileFinishShopSetup;

  /// No description provided for @profileFinishShopSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Add your shop name, GSTIN and state so invoices print correctly.'**
  String get profileFinishShopSetupBody;

  /// No description provided for @profilePersonalDetails.
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get profilePersonalDetails;

  /// No description provided for @profileNotAdded.
  ///
  /// In en, this message translates to:
  /// **'Not added'**
  String get profileNotAdded;

  /// No description provided for @profileCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get profileCopied;

  /// No description provided for @profileFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileFieldName;

  /// No description provided for @profileFieldPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get profileFieldPhoto;

  /// No description provided for @profileFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profileFieldPhone;

  /// No description provided for @profileFieldShopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get profileFieldShopName;

  /// No description provided for @profileFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileFieldAddress;

  /// No description provided for @profileFieldCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileFieldCity;

  /// No description provided for @profileFieldState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get profileFieldState;

  /// No description provided for @profileFieldStateCode.
  ///
  /// In en, this message translates to:
  /// **'State code'**
  String get profileFieldStateCode;

  /// No description provided for @profileFieldPinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get profileFieldPinCode;

  /// No description provided for @profileFieldGstin.
  ///
  /// In en, this message translates to:
  /// **'GSTIN'**
  String get profileFieldGstin;

  /// No description provided for @profileFieldPan.
  ///
  /// In en, this message translates to:
  /// **'PAN'**
  String get profileFieldPan;

  /// No description provided for @profileFieldUpiId.
  ///
  /// In en, this message translates to:
  /// **'UPI ID'**
  String get profileFieldUpiId;

  /// No description provided for @profileCompletionTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile complete'**
  String get profileCompletionTitle;

  /// No description provided for @profileCompletionDetailsAdded.
  ///
  /// In en, this message translates to:
  /// **'details added.'**
  String get profileCompletionDetailsAdded;

  /// No description provided for @profileCompleteIt.
  ///
  /// In en, this message translates to:
  /// **'Complete it'**
  String get profileCompleteIt;

  /// No description provided for @profileWhatsLeft.
  ///
  /// In en, this message translates to:
  /// **'WHAT\'S LEFT'**
  String get profileWhatsLeft;

  /// No description provided for @profileRoleOwner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get profileRoleOwner;

  /// No description provided for @profileRoleManager.
  ///
  /// In en, this message translates to:
  /// **'Manager'**
  String get profileRoleManager;

  /// No description provided for @profileRoleStockist.
  ///
  /// In en, this message translates to:
  /// **'Stockist'**
  String get profileRoleStockist;

  /// No description provided for @profileRoleCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get profileRoleCashier;

  /// No description provided for @profileRoleStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get profileRoleStaff;

  /// No description provided for @profileChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get profileChangePassword;

  /// No description provided for @profileCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get profileCurrentPassword;

  /// No description provided for @profileNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get profileNewPassword;

  /// No description provided for @profileConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get profileConfirmNewPassword;

  /// No description provided for @profilePasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'8+ chars, must include a letter and a number'**
  String get profilePasswordHelper;

  /// No description provided for @profilePasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Must be at least 8 characters'**
  String get profilePasswordMinLength;

  /// No description provided for @profilePasswordNeedsLetter.
  ///
  /// In en, this message translates to:
  /// **'Must contain a letter'**
  String get profilePasswordNeedsLetter;

  /// No description provided for @profilePasswordNeedsNumber.
  ///
  /// In en, this message translates to:
  /// **'Must contain a number'**
  String get profilePasswordNeedsNumber;

  /// No description provided for @profilePasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get profilePasswordsDoNotMatch;

  /// No description provided for @profilePasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Existing sessions revoked.'**
  String get profilePasswordChanged;

  /// No description provided for @profileRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get profileRequired;

  /// No description provided for @profilePrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get profilePrivacyPolicy;

  /// No description provided for @profileTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get profileTermsOfService;

  /// No description provided for @profilePrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'ShopXY is a Data Fiduciary under India\'s Digital Personal Data Protection Act, 2023 (DPDP). This notice explains what we collect, why, and the rights you have over your data.\n\nWhat we hold\nWe store the minimum data needed to run your shop: account credentials, your product/vendor/party records, invoices and payments you create, notification preferences, and consent timestamps. We do not sell your data and do not share it with third parties except as required to operate the service (hosting, error monitoring) or by Indian law.\n\nData localisation\nYour data is stored on servers located in India in line with applicable RBI / sector guidance. Backups are encrypted and held in the same jurisdiction.\n\nRetention\nFinancial records — invoices, payments and supporting ledgers — are retained for at least 8 financial years to comply with the Companies Act, 2013 (§128) and the GST Act (§36). Other personal data is retained only as long as your account is active or as required to provide the service.\n\nYour rights (DPDP §11 and §12)\nYou have the right to (a) access a copy of your personal data, (b) correct or update it, (c) withdraw consent and request erasure, and (d) nominate someone to act on your behalf. The Settings > Danger zone screen exposes \"Export my data\" (a downloadable JSON of every row tied to your account) and \"Delete account\" (immediate erasure for customer accounts; controlled erasure for shop-owner accounts whose books are still inside the 8-year retention window).\n\nConsent withdrawal\nYou may withdraw consent at any time by deleting your account or by emailing support@shopxy.app. Withdrawal does not apply retroactively to processing performed lawfully before withdrawal.\n\nGrievance redressal\nDPDP §13 requires a published grievance contact. Please reach our Grievance Officer at grievance@shopxy.app. We acknowledge within 48 hours and aim to resolve within one month; personal-data requests under the DPDP Act are addressed within 15 days. If unresolved, you may approach the Data Protection Board of India.\n'**
  String get profilePrivacyBody;

  /// No description provided for @profileTermsBody.
  ///
  /// In en, this message translates to:
  /// **'ShopXY is provided as-is for managing your shop\'s inventory, invoices, payments and customer relationships. By creating an account you agree to the terms below.\n\n1. Account integrity. Provide accurate information when registering and keep your password confidential — you are responsible for all activity under your account.\n\n2. Lawful use. Use the service only for legitimate business operations. No spam, no scraping, no attempts to compromise other accounts or to bypass billing.\n\n3. Compliance with Indian law. You will comply with all applicable tax, GST and commerce laws of India. ShopXY assists with documentation but does not constitute legal or tax advice.\n\n4. Data and consent. Your use of ShopXY is also governed by the Privacy Policy, which describes how we handle personal data under the DPDP Act, 2023 — including data localisation in India, an 8-year retention window for financial books (Companies Act §128 / GST §36), and your rights to access and delete your data via the in-app Settings screen.\n\n5. Service availability. We may schedule maintenance or update features. We will give reasonable notice for material changes.\n\n6. Termination. We may suspend accounts that violate these terms or that we reasonably suspect of fraudulent activity. You may close your account at any time via Settings > Delete account.\n\n7. Grievances. Questions, complaints or DPDP requests can be sent to grievance@shopxy.app. The Grievance Officer acknowledges within 48 hours and responds within one month.\n'**
  String get profileTermsBody;

  /// No description provided for @profileTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get profileTakePhoto;

  /// No description provided for @profilePickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick from gallery'**
  String get profilePickFromGallery;

  /// No description provided for @profileRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get profileRemovePhoto;

  /// No description provided for @profileProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileProfileUpdated;

  /// No description provided for @profileName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileName;

  /// No description provided for @profileNameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get profileNameMinLength;

  /// No description provided for @profileNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Name too long'**
  String get profileNameTooLong;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profileEmailNotEditable.
  ///
  /// In en, this message translates to:
  /// **'Email changes are not supported yet'**
  String get profileEmailNotEditable;

  /// No description provided for @profileShopDetails.
  ///
  /// In en, this message translates to:
  /// **'Shop details'**
  String get profileShopDetails;

  /// No description provided for @profileShopDetailsHint.
  ///
  /// In en, this message translates to:
  /// **'These appear on invoices and PDFs. GSTIN must match the state.'**
  String get profileShopDetailsHint;

  /// No description provided for @profileShopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get profileShopName;

  /// No description provided for @profileShopAddress.
  ///
  /// In en, this message translates to:
  /// **'Shop address'**
  String get profileShopAddress;

  /// No description provided for @profileCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get profileCity;

  /// No description provided for @profilePinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get profilePinCode;

  /// No description provided for @profileState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get profileState;

  /// No description provided for @profileSelectPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'— Select —'**
  String get profileSelectPlaceholder;

  /// No description provided for @profileGstin.
  ///
  /// In en, this message translates to:
  /// **'GSTIN'**
  String get profileGstin;

  /// No description provided for @profilePan.
  ///
  /// In en, this message translates to:
  /// **'PAN'**
  String get profilePan;

  /// No description provided for @profileUpiId.
  ///
  /// In en, this message translates to:
  /// **'UPI ID'**
  String get profileUpiId;

  /// No description provided for @profileSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSave;

  /// No description provided for @profileSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get profileSectionAccount;

  /// No description provided for @profileChangePasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update the password on your account'**
  String get profileChangePasswordSubtitle;

  /// No description provided for @profileSectionShopOperations.
  ///
  /// In en, this message translates to:
  /// **'SHOP OPERATIONS'**
  String get profileSectionShopOperations;

  /// No description provided for @profileShopOperations.
  ///
  /// In en, this message translates to:
  /// **'Shop operations'**
  String get profileShopOperations;

  /// No description provided for @profileShopOperationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hours, vacation mode, payouts, KYC, team'**
  String get profileShopOperationsSubtitle;

  /// No description provided for @profileSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get profileSectionAppearance;

  /// No description provided for @profileCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get profileCurrency;

  /// No description provided for @profileCurrencyIndianRupee.
  ///
  /// In en, this message translates to:
  /// **'Indian Rupee (₹)'**
  String get profileCurrencyIndianRupee;

  /// No description provided for @profileListDensity.
  ///
  /// In en, this message translates to:
  /// **'List density'**
  String get profileListDensity;

  /// No description provided for @profileListDensityCompactDesc.
  ///
  /// In en, this message translates to:
  /// **'Tighter rows — more products per screen.'**
  String get profileListDensityCompactDesc;

  /// No description provided for @profileListDensityComfortableDesc.
  ///
  /// In en, this message translates to:
  /// **'Comfortable spacing (default).'**
  String get profileListDensityComfortableDesc;

  /// No description provided for @profileDensityComfortable.
  ///
  /// In en, this message translates to:
  /// **'Comfortable'**
  String get profileDensityComfortable;

  /// No description provided for @profileDensityCompact.
  ///
  /// In en, this message translates to:
  /// **'Compact'**
  String get profileDensityCompact;

  /// No description provided for @profileNavigationStyle.
  ///
  /// In en, this message translates to:
  /// **'Navigation style'**
  String get profileNavigationStyle;

  /// No description provided for @profileNavigationStyleSidebarDesc.
  ///
  /// In en, this message translates to:
  /// **'Left-side rail with destinations stacked vertically.'**
  String get profileNavigationStyleSidebarDesc;

  /// No description provided for @profileNavigationStyleBottomDesc.
  ///
  /// In en, this message translates to:
  /// **'Bottom tab bar (default).'**
  String get profileNavigationStyleBottomDesc;

  /// No description provided for @profileNavStyleBottomBar.
  ///
  /// In en, this message translates to:
  /// **'Bottom bar'**
  String get profileNavStyleBottomBar;

  /// No description provided for @profileNavStyleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Sidebar'**
  String get profileNavStyleSidebar;

  /// No description provided for @profileSectionInventory.
  ///
  /// In en, this message translates to:
  /// **'INVENTORY'**
  String get profileSectionInventory;

  /// No description provided for @profileCustomFields.
  ///
  /// In en, this message translates to:
  /// **'Custom Fields'**
  String get profileCustomFields;

  /// No description provided for @profileCustomFieldsHint.
  ///
  /// In en, this message translates to:
  /// **'Track extra information on every product'**
  String get profileCustomFieldsHint;

  /// No description provided for @profileSectionNotifications.
  ///
  /// In en, this message translates to:
  /// **'NOTIFICATIONS'**
  String get profileSectionNotifications;

  /// No description provided for @profileEmailNotifications.
  ///
  /// In en, this message translates to:
  /// **'Email notifications'**
  String get profileEmailNotifications;

  /// No description provided for @profileEmailNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Low-stock alerts and weekly summary'**
  String get profileEmailNotificationsSubtitle;

  /// No description provided for @profilePreferenceSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not save preference:'**
  String get profilePreferenceSaveFailed;

  /// No description provided for @profileSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'ABOUT'**
  String get profileSectionAbout;

  /// No description provided for @profileAppVersion.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get profileAppVersion;

  /// No description provided for @profileSectionDangerZone.
  ///
  /// In en, this message translates to:
  /// **'DANGER ZONE'**
  String get profileSectionDangerZone;

  /// No description provided for @profileExportMyData.
  ///
  /// In en, this message translates to:
  /// **'Export my data'**
  String get profileExportMyData;

  /// No description provided for @profileExportMyDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Download a JSON copy of every record tied to your account.'**
  String get profileExportMyDataSubtitle;

  /// No description provided for @profileExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed:'**
  String get profileExportFailed;

  /// No description provided for @profileDataExportShareText.
  ///
  /// In en, this message translates to:
  /// **'Your ShopXY data export'**
  String get profileDataExportShareText;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently erase your account. Shop owners with invoices in the past 8 years must contact support (Companies Act / GST retention).'**
  String get profileDeleteAccountSubtitle;

  /// No description provided for @profileDeleteAccountDialogBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently erases your account and revokes every session. Owners whose invoices are still inside the 8-year Companies Act / GST retention window cannot delete in-app — contact support@shopxy.example for a controlled wipe.'**
  String get profileDeleteAccountDialogBody;

  /// No description provided for @profileAccountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get profileAccountDeleted;

  /// No description provided for @profileCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancel;

  /// No description provided for @profileDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get profileDelete;

  /// No description provided for @profileLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogout;

  /// No description provided for @profileLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get profileLogoutConfirm;

  /// No description provided for @profileComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get profileComingSoon;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsTabInbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get notificationsTabInbox;

  /// No description provided for @notificationsTabInvites.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get notificationsTabInvites;

  /// No description provided for @notificationsTabSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get notificationsTabSent;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// No description provided for @notificationsInviteButton.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get notificationsInviteButton;

  /// No description provided for @notificationsInboxEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsInboxEmptyTitle;

  /// No description provided for @notificationsInboxEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When something happens — like an invitation reply — you\'ll see it here.'**
  String get notificationsInboxEmptyBody;

  /// No description provided for @notificationsIncomingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No invitations'**
  String get notificationsIncomingEmptyTitle;

  /// No description provided for @notificationsIncomingEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'When a shop invites you as a party or vendor, you\'ll see the request here.'**
  String get notificationsIncomingEmptyBody;

  /// No description provided for @notificationsOutgoingEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No invitations sent yet'**
  String get notificationsOutgoingEmptyTitle;

  /// No description provided for @notificationsOutgoingEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the Invite button to invite a party or vendor by email.'**
  String get notificationsOutgoingEmptyBody;

  /// No description provided for @notificationsAShop.
  ///
  /// In en, this message translates to:
  /// **'A shop'**
  String get notificationsAShop;

  /// No description provided for @notificationsRolePartyCustomer.
  ///
  /// In en, this message translates to:
  /// **'Party (customer)'**
  String get notificationsRolePartyCustomer;

  /// No description provided for @notificationsRoleVendorSupplier.
  ///
  /// In en, this message translates to:
  /// **'Vendor (supplier)'**
  String get notificationsRoleVendorSupplier;

  /// No description provided for @notificationsWantsToAddYou.
  ///
  /// In en, this message translates to:
  /// **'wants to add you as their {role}'**
  String notificationsWantsToAddYou(Object role);

  /// No description provided for @notificationsDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get notificationsDecline;

  /// No description provided for @notificationsAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get notificationsAccept;

  /// No description provided for @notificationsInvitationAccepted.
  ///
  /// In en, this message translates to:
  /// **'Invitation accepted'**
  String get notificationsInvitationAccepted;

  /// No description provided for @notificationsInvitationDeclined.
  ///
  /// In en, this message translates to:
  /// **'Invitation declined'**
  String get notificationsInvitationDeclined;

  /// No description provided for @notificationsRoleParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get notificationsRoleParty;

  /// No description provided for @notificationsRoleVendor.
  ///
  /// In en, this message translates to:
  /// **'Vendor'**
  String get notificationsRoleVendor;

  /// No description provided for @notificationsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get notificationsCancel;

  /// No description provided for @notificationsInvitationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Invitation cancelled'**
  String get notificationsInvitationCancelled;

  /// No description provided for @notificationsStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get notificationsStatusPending;

  /// No description provided for @notificationsStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get notificationsStatusAccepted;

  /// No description provided for @notificationsStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get notificationsStatusDeclined;

  /// No description provided for @notificationsStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get notificationsStatusCancelled;

  /// No description provided for @notificationsStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get notificationsStatusExpired;

  /// No description provided for @notificationsInvitationSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent'**
  String get notificationsInvitationSent;

  /// No description provided for @notificationsSendInvitationTitle.
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get notificationsSendInvitationTitle;

  /// No description provided for @notificationsInviteByEmail.
  ///
  /// In en, this message translates to:
  /// **'Invite by email'**
  String get notificationsInviteByEmail;

  /// No description provided for @notificationsInviteByEmailHelp.
  ///
  /// In en, this message translates to:
  /// **'They will see your request under Notifications. If they don\'t have a Shopxy account yet, it shows up the moment they sign up with this email.'**
  String get notificationsInviteByEmailHelp;

  /// No description provided for @notificationsCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get notificationsCustomerName;

  /// No description provided for @notificationsVendorName.
  ///
  /// In en, this message translates to:
  /// **'Vendor name'**
  String get notificationsVendorName;

  /// No description provided for @notificationsRecipientEmail.
  ///
  /// In en, this message translates to:
  /// **'Recipient email'**
  String get notificationsRecipientEmail;

  /// No description provided for @notificationsMessageOptional.
  ///
  /// In en, this message translates to:
  /// **'Message (optional)'**
  String get notificationsMessageOptional;

  /// No description provided for @notificationsMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Hey! Linking your account on Shopxy…'**
  String get notificationsMessageHint;

  /// No description provided for @notificationsModeExisting.
  ///
  /// In en, this message translates to:
  /// **'Existing'**
  String get notificationsModeExisting;

  /// No description provided for @notificationsModeNewContact.
  ///
  /// In en, this message translates to:
  /// **'New contact'**
  String get notificationsModeNewContact;

  /// No description provided for @notificationsChooseParty.
  ///
  /// In en, this message translates to:
  /// **'Choose party'**
  String get notificationsChooseParty;

  /// No description provided for @notificationsChooseVendor.
  ///
  /// In en, this message translates to:
  /// **'Choose vendor'**
  String get notificationsChooseVendor;

  /// No description provided for @notificationsSearchParties.
  ///
  /// In en, this message translates to:
  /// **'Search parties…'**
  String get notificationsSearchParties;

  /// No description provided for @notificationsSearchVendors.
  ///
  /// In en, this message translates to:
  /// **'Search vendors…'**
  String get notificationsSearchVendors;

  /// No description provided for @notificationsNoContactsFound.
  ///
  /// In en, this message translates to:
  /// **'No contacts found'**
  String get notificationsNoContactsFound;

  /// No description provided for @categoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categoriesTitle;

  /// No description provided for @categoriesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get categoriesEmptyTitle;

  /// No description provided for @categoriesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add a category'**
  String get categoriesEmptyHint;

  /// No description provided for @categoriesProductsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No products in this category'**
  String get categoriesProductsEmptyTitle;

  /// No description provided for @categoriesProductsNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No products match \"{name}\"'**
  String categoriesProductsNoMatchTitle(Object name);

  /// No description provided for @categoriesProductsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Assign products to \"{name}\" from the product editor.'**
  String categoriesProductsEmptySubtitle(Object name);

  /// No description provided for @categoriesProductsNoMatchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try a shorter or different search.'**
  String get categoriesProductsNoMatchSubtitle;

  /// No description provided for @categoriesProductUnit.
  ///
  /// In en, this message translates to:
  /// **'product'**
  String get categoriesProductUnit;

  /// No description provided for @categoriesProductsUnit.
  ///
  /// In en, this message translates to:
  /// **'products'**
  String get categoriesProductsUnit;

  /// No description provided for @categoriesSearchProductsHint.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get categoriesSearchProductsHint;

  /// No description provided for @categoriesPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select category'**
  String get categoriesPickerTitle;

  /// No description provided for @categoriesCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get categoriesCancel;

  /// No description provided for @categoriesClearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear selection'**
  String get categoriesClearSelection;

  /// No description provided for @categoriesError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get categoriesError;

  /// No description provided for @categoriesNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No categories match that search.'**
  String get categoriesNoMatch;

  /// No description provided for @categoriesSubcategoriesUnit.
  ///
  /// In en, this message translates to:
  /// **'subcategories'**
  String get categoriesSubcategoriesUnit;

  /// No description provided for @couponsTitle.
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get couponsTitle;

  /// No description provided for @couponsNewCoupon.
  ///
  /// In en, this message translates to:
  /// **'New coupon'**
  String get couponsNewCoupon;

  /// No description provided for @couponsEditCoupon.
  ///
  /// In en, this message translates to:
  /// **'Edit coupon'**
  String get couponsEditCoupon;

  /// No description provided for @couponsCreateCoupon.
  ///
  /// In en, this message translates to:
  /// **'Create coupon'**
  String get couponsCreateCoupon;

  /// No description provided for @couponsSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get couponsSaveChanges;

  /// No description provided for @couponsSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get couponsSaving;

  /// No description provided for @couponsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get couponsCancel;

  /// No description provided for @couponsDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get couponsDeactivate;

  /// No description provided for @couponsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get couponsRetry;

  /// No description provided for @couponsDeactivateConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate {code}?'**
  String couponsDeactivateConfirmTitle(Object code);

  /// No description provided for @couponsDeactivateConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Buyers won\'t see this coupon anymore. Existing redemptions are unaffected.'**
  String get couponsDeactivateConfirmBody;

  /// No description provided for @couponsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'No coupons yet. Tap \"New coupon\" to create your first one.'**
  String get couponsEmptyBody;

  /// No description provided for @couponsPercentOff.
  ///
  /// In en, this message translates to:
  /// **'{value}% off'**
  String couponsPercentOff(Object value);

  /// No description provided for @couponsAmountOff.
  ///
  /// In en, this message translates to:
  /// **'{amount} off'**
  String couponsAmountOff(Object amount);

  /// No description provided for @couponsStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get couponsStatusInactive;

  /// No description provided for @couponsStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get couponsStatusExpired;

  /// No description provided for @couponsStatusExhausted.
  ///
  /// In en, this message translates to:
  /// **'Exhausted'**
  String get couponsStatusExhausted;

  /// No description provided for @couponsStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get couponsStatusLive;

  /// No description provided for @couponsBadgePublicAutoApplies.
  ///
  /// In en, this message translates to:
  /// **'Public · auto-applies'**
  String get couponsBadgePublicAutoApplies;

  /// No description provided for @couponsBadgeFirstOrderOnly.
  ///
  /// In en, this message translates to:
  /// **'First order only'**
  String get couponsBadgeFirstOrderOnly;

  /// No description provided for @couponsValidityRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Valid {from} – {until} · {count} redeemed'**
  String couponsValidityRedeemed(Object from, Object until, Object count);

  /// No description provided for @couponsFieldCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get couponsFieldCode;

  /// No description provided for @couponsFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get couponsFieldTitle;

  /// No description provided for @couponsFieldTitleHint.
  ///
  /// In en, this message translates to:
  /// **'New user offer'**
  String get couponsFieldTitleHint;

  /// No description provided for @couponsFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get couponsFieldDescription;

  /// No description provided for @couponsFieldType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get couponsFieldType;

  /// No description provided for @couponsDiscountTypePercent.
  ///
  /// In en, this message translates to:
  /// **'Percent off'**
  String get couponsDiscountTypePercent;

  /// No description provided for @couponsDiscountTypeFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat ₹ off'**
  String get couponsDiscountTypeFlat;

  /// No description provided for @couponsFieldPercentOff.
  ///
  /// In en, this message translates to:
  /// **'% off'**
  String get couponsFieldPercentOff;

  /// No description provided for @couponsFieldAmountOff.
  ///
  /// In en, this message translates to:
  /// **'₹ off'**
  String get couponsFieldAmountOff;

  /// No description provided for @couponsFieldMaxDiscount.
  ///
  /// In en, this message translates to:
  /// **'Max discount (₹) — caps the % off'**
  String get couponsFieldMaxDiscount;

  /// No description provided for @couponsFieldMinOrder.
  ///
  /// In en, this message translates to:
  /// **'Minimum order (₹)'**
  String get couponsFieldMinOrder;

  /// No description provided for @couponsDateFrom.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get couponsDateFrom;

  /// No description provided for @couponsDateUntil.
  ///
  /// In en, this message translates to:
  /// **'Until'**
  String get couponsDateUntil;

  /// No description provided for @couponsFieldPerUserLimit.
  ///
  /// In en, this message translates to:
  /// **'Per-user limit (0 = unlimited)'**
  String get couponsFieldPerUserLimit;

  /// No description provided for @couponsFieldTotalCap.
  ///
  /// In en, this message translates to:
  /// **'Total cap (0 = unlimited)'**
  String get couponsFieldTotalCap;

  /// No description provided for @couponsPublicTitle.
  ///
  /// In en, this message translates to:
  /// **'Public — auto-applies'**
  String get couponsPublicTitle;

  /// No description provided for @couponsPublicSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anyone can see and use it. Auto-applies at checkout when the cart matches — no code typing needed. Keep off for private codes shared with specific people.'**
  String get couponsPublicSubtitle;

  /// No description provided for @couponsFirstOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'First-order only'**
  String get couponsFirstOrderTitle;

  /// No description provided for @couponsFirstOrderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Restricts redemption to customers with no prior confirmed orders. Pair with \"per-user limit = 1\" for a single-shot welcome offer.'**
  String get couponsFirstOrderSubtitle;

  /// No description provided for @couponsActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get couponsActiveTitle;

  /// No description provided for @couponsActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, buyers won\'t see this coupon and can\'t redeem it.'**
  String get couponsActiveSubtitle;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your inventory, invoices and customers.'**
  String get authLoginSubtitle;

  /// No description provided for @authLoginFooterPrompt.
  ///
  /// In en, this message translates to:
  /// **'New to ShopXY?'**
  String get authLoginFooterPrompt;

  /// No description provided for @authCreateAccountCta.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get authCreateAccountCta;

  /// No description provided for @authGoogleComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is coming soon — please use your email for now.'**
  String get authGoogleComingSoon;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get authFieldRequired;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get authInvalidEmail;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authLegalAgreePrefix.
  ///
  /// In en, this message translates to:
  /// **'By signing in you agree to our '**
  String get authLegalAgreePrefix;

  /// No description provided for @authLegalTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get authLegalTerms;

  /// No description provided for @authLegalAcknowledgeMid.
  ///
  /// In en, this message translates to:
  /// **' and acknowledge our '**
  String get authLegalAcknowledgeMid;

  /// No description provided for @authLegalPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authLegalPrivacyPolicy;

  /// No description provided for @authTroubleSigningIn.
  ///
  /// In en, this message translates to:
  /// **'Trouble signing in? '**
  String get authTroubleSigningIn;

  /// No description provided for @authContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get authContactSupport;

  /// No description provided for @authContinueAs.
  ///
  /// In en, this message translates to:
  /// **'Continue as'**
  String get authContinueAs;

  /// No description provided for @authRemoveThisAccount.
  ///
  /// In en, this message translates to:
  /// **'Remove this account'**
  String get authRemoveThisAccount;

  /// No description provided for @authSavedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Logged in accounts'**
  String get authSavedAccounts;

  /// No description provided for @authContinueAsName.
  ///
  /// In en, this message translates to:
  /// **'Continue as {name}'**
  String authContinueAsName(String name);

  /// No description provided for @authPickAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose an account'**
  String get authPickAccountTitle;

  /// No description provided for @authPickAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re already signed in on this device. Tap an account to continue — no password needed.'**
  String get authPickAccountSubtitle;

  /// No description provided for @authUseAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'Use another account'**
  String get authUseAnotherAccount;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your merchant account to start managing your inventory, invoices and customers.'**
  String get authRegisterSubtitle;

  /// No description provided for @authRegisterFooterPrompt.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authRegisterFooterPrompt;

  /// No description provided for @authAcceptTermsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please accept the Terms of Service and Privacy Policy to continue.'**
  String get authAcceptTermsPrompt;

  /// No description provided for @authYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authYourName;

  /// No description provided for @authNameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters'**
  String get authNameTooShort;

  /// No description provided for @authShopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get authShopName;

  /// No description provided for @authShopNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Shown to customers in the marketplace. You can rename it later.'**
  String get authShopNameHelper;

  /// No description provided for @onboardingShopTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up your shop'**
  String get onboardingShopTitle;

  /// No description provided for @onboardingShopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Give your shop a name to get started. You can change it later in settings.'**
  String get onboardingShopSubtitle;

  /// No description provided for @onboardingShopCta.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingShopCta;

  /// No description provided for @otpVerifyTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your email'**
  String get otpVerifyTitle;

  /// No description provided for @otpVerifySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code we sent to {email}.'**
  String otpVerifySubtitle(String email);

  /// No description provided for @otpCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get otpCodeLabel;

  /// No description provided for @otpVerifyCta.
  ///
  /// In en, this message translates to:
  /// **'Verify & continue'**
  String get otpVerifyCta;

  /// No description provided for @otpResend.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResend;

  /// No description provided for @otpResendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String otpResendIn(int seconds);

  /// No description provided for @otpNoCodePrompt.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get the code?'**
  String get otpNoCodePrompt;

  /// No description provided for @otpResent.
  ///
  /// In en, this message translates to:
  /// **'A new code is on its way.'**
  String get otpResent;

  /// No description provided for @authPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 10 characters, with a letter and a number.'**
  String get authPasswordHelper;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get authConfirmPassword;

  /// No description provided for @authPasswordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordsDoNotMatch;

  /// No description provided for @authIAcceptThe.
  ///
  /// In en, this message translates to:
  /// **'I accept the'**
  String get authIAcceptThe;

  /// No description provided for @authTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get authTermsOfService;

  /// No description provided for @authPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyPolicy;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueWithGoogle;

  /// No description provided for @authOrContinueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'or continue with email'**
  String get authOrContinueWithEmail;

  /// No description provided for @authHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get authHide;

  /// No description provided for @authShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get authShow;

  /// No description provided for @dashboardHiddenTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard hidden'**
  String get dashboardHiddenTitle;

  /// No description provided for @dashboardHiddenMessage.
  ///
  /// In en, this message translates to:
  /// **'Your role doesn\'t include the dashboard overview. Ask an owner if you need it.'**
  String get dashboardHiddenMessage;

  /// No description provided for @dashboardGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get dashboardGreetingMorning;

  /// No description provided for @dashboardGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get dashboardGreetingAfternoon;

  /// No description provided for @dashboardGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get dashboardGreetingEvening;

  /// No description provided for @dashboardGreetingWithName.
  ///
  /// In en, this message translates to:
  /// **'{greeting}, {name}'**
  String dashboardGreetingWithName(Object greeting, Object name);

  /// No description provided for @dashboardYourShop.
  ///
  /// In en, this message translates to:
  /// **'your shop'**
  String get dashboardYourShop;

  /// No description provided for @dashboardShopStatus.
  ///
  /// In en, this message translates to:
  /// **'Here\'s how {shop} is doing.'**
  String dashboardShopStatus(Object shop);

  /// No description provided for @dashboardPendingInviteOne.
  ///
  /// In en, this message translates to:
  /// **'You have 1 pending invitation — review and accept.'**
  String get dashboardPendingInviteOne;

  /// No description provided for @dashboardPendingInviteMany.
  ///
  /// In en, this message translates to:
  /// **'You have {count} pending invitations — review and accept.'**
  String dashboardPendingInviteMany(Object count);

  /// No description provided for @dashboardView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get dashboardView;

  /// No description provided for @dashboardOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get dashboardOperations;

  /// No description provided for @dashboardGstThisMonth.
  ///
  /// In en, this message translates to:
  /// **'GST this month'**
  String get dashboardGstThisMonth;

  /// No description provided for @dashboardOutputTaxCollected.
  ///
  /// In en, this message translates to:
  /// **'{amount} output tax collected'**
  String dashboardOutputTaxCollected(Object amount);

  /// No description provided for @dashboardInventoryValue.
  ///
  /// In en, this message translates to:
  /// **'Inventory value'**
  String get dashboardInventoryValue;

  /// No description provided for @dashboardCostBasisOfStock.
  ///
  /// In en, this message translates to:
  /// **'Cost basis of stock on hand'**
  String get dashboardCostBasisOfStock;

  /// No description provided for @dashboardOneSale.
  ///
  /// In en, this message translates to:
  /// **'1 sale'**
  String get dashboardOneSale;

  /// No description provided for @dashboardSalesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sales'**
  String dashboardSalesCount(Object count);

  /// No description provided for @dashboardOpenTillSince.
  ///
  /// In en, this message translates to:
  /// **'Open till · since {time}'**
  String dashboardOpenTillSince(Object time);

  /// No description provided for @dashboardNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get dashboardNeedsAttention;

  /// No description provided for @dashboardAllCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up — nothing needs action right now.'**
  String get dashboardAllCaughtUp;

  /// No description provided for @dashboardOrdersToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Orders to confirm'**
  String get dashboardOrdersToConfirm;

  /// No description provided for @dashboardReturnsToReview.
  ///
  /// In en, this message translates to:
  /// **'Returns to review'**
  String get dashboardReturnsToReview;

  /// No description provided for @dashboardQuotesToPrice.
  ///
  /// In en, this message translates to:
  /// **'Quotes to price'**
  String get dashboardQuotesToPrice;

  /// No description provided for @dashboardDraftsToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Drafts to confirm'**
  String get dashboardDraftsToConfirm;

  /// No description provided for @dashboardOutOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of stock'**
  String get dashboardOutOfStock;

  /// No description provided for @dashboardLowStock.
  ///
  /// In en, this message translates to:
  /// **'Low stock'**
  String get dashboardLowStock;

  /// No description provided for @dashboardSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get dashboardSales;

  /// No description provided for @dashboardNetProfit.
  ///
  /// In en, this message translates to:
  /// **'Net profit'**
  String get dashboardNetProfit;

  /// No description provided for @dashboardMarginPct.
  ///
  /// In en, this message translates to:
  /// **'{pct}% margin'**
  String dashboardMarginPct(Object pct);

  /// No description provided for @dashboardReceivables.
  ///
  /// In en, this message translates to:
  /// **'Receivables'**
  String get dashboardReceivables;

  /// No description provided for @dashboardOnePartyOwesYou.
  ///
  /// In en, this message translates to:
  /// **'1 party owes you'**
  String get dashboardOnePartyOwesYou;

  /// No description provided for @dashboardPartiesOweYou.
  ///
  /// In en, this message translates to:
  /// **'{count} parties owe you'**
  String dashboardPartiesOweYou(Object count);

  /// No description provided for @dashboardPayables.
  ///
  /// In en, this message translates to:
  /// **'Payables'**
  String get dashboardPayables;

  /// No description provided for @dashboardOneVendorToPay.
  ///
  /// In en, this message translates to:
  /// **'1 vendor to pay'**
  String get dashboardOneVendorToPay;

  /// No description provided for @dashboardVendorsToPay.
  ///
  /// In en, this message translates to:
  /// **'{count} vendors to pay'**
  String dashboardVendorsToPay(Object count);

  /// No description provided for @kpiDrawerRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get kpiDrawerRetry;

  /// No description provided for @kpiDrawerLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load. Please try again.'**
  String get kpiDrawerLoadError;

  /// No description provided for @kpiDrawerSalesFilterHint.
  ///
  /// In en, this message translates to:
  /// **'Filter by product name or SKU'**
  String get kpiDrawerSalesFilterHint;

  /// No description provided for @kpiDrawerNoSales.
  ///
  /// In en, this message translates to:
  /// **'No sales in this period.'**
  String get kpiDrawerNoSales;

  /// No description provided for @kpiDrawerNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No products match your filter.'**
  String get kpiDrawerNoMatch;

  /// No description provided for @kpiDrawerProductCount.
  ///
  /// In en, this message translates to:
  /// **'{count} products'**
  String kpiDrawerProductCount(Object count);

  /// No description provided for @kpiDrawerRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue {value}'**
  String kpiDrawerRevenue(Object value);

  /// No description provided for @kpiDrawerQtySold.
  ///
  /// In en, this message translates to:
  /// **'{qty} {unit} sold'**
  String kpiDrawerQtySold(Object qty, Object unit);

  /// No description provided for @kpiDrawerShowingTop.
  ///
  /// In en, this message translates to:
  /// **'Showing top {count}'**
  String kpiDrawerShowingTop(Object count);

  /// No description provided for @kpiDrawerUnnamedProduct.
  ///
  /// In en, this message translates to:
  /// **'Unnamed product'**
  String get kpiDrawerUnnamedProduct;

  /// No description provided for @kpiDrawerUnits.
  ///
  /// In en, this message translates to:
  /// **'units'**
  String get kpiDrawerUnits;

  /// No description provided for @kpiDrawerViewFullReports.
  ///
  /// In en, this message translates to:
  /// **'View full reports'**
  String get kpiDrawerViewFullReports;

  /// No description provided for @kpiDrawerViewAllParties.
  ///
  /// In en, this message translates to:
  /// **'View all parties'**
  String get kpiDrawerViewAllParties;

  /// No description provided for @kpiDrawerViewAllVendors.
  ///
  /// In en, this message translates to:
  /// **'View all vendors'**
  String get kpiDrawerViewAllVendors;

  /// No description provided for @kpiDrawerNoReceivables.
  ///
  /// In en, this message translates to:
  /// **'No one owes you right now.'**
  String get kpiDrawerNoReceivables;

  /// No description provided for @kpiDrawerNoPayables.
  ///
  /// In en, this message translates to:
  /// **'You don\'t owe anyone right now.'**
  String get kpiDrawerNoPayables;

  /// No description provided for @kpiDrawerBilled.
  ///
  /// In en, this message translates to:
  /// **'Billed'**
  String get kpiDrawerBilled;

  /// No description provided for @kpiDrawerReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get kpiDrawerReceived;

  /// No description provided for @kpiDrawerPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get kpiDrawerPaid;

  /// No description provided for @kpiDrawerOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Outstanding'**
  String get kpiDrawerOutstanding;

  /// No description provided for @kpiDrawerDocCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 document} other{{count} documents}}'**
  String kpiDrawerDocCount(num count);

  /// No description provided for @dashboardSalesTrend.
  ///
  /// In en, this message translates to:
  /// **'Sales trend'**
  String get dashboardSalesTrend;

  /// No description provided for @dashboardPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get dashboardPrevious;

  /// No description provided for @dashboardPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get dashboardPurchases;

  /// No description provided for @dashboardReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get dashboardReturns;

  /// No description provided for @dashboardGetShopReady.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get your shop ready'**
  String get dashboardGetShopReady;

  /// No description provided for @dashboardOnboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Finish these steps and your dashboard fills with live numbers.'**
  String get dashboardOnboardingSubtitle;

  /// No description provided for @dashboardStepsDone.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} done'**
  String dashboardStepsDone(Object done, Object total);

  /// No description provided for @dashboardAddFirstProductTitle.
  ///
  /// In en, this message translates to:
  /// **'Add your first product'**
  String get dashboardAddFirstProductTitle;

  /// No description provided for @dashboardAddFirstProductDesc.
  ///
  /// In en, this message translates to:
  /// **'Build your catalogue so you can bill and track stock.'**
  String get dashboardAddFirstProductDesc;

  /// No description provided for @dashboardAddProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get dashboardAddProduct;

  /// No description provided for @dashboardCreateFirstInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your first invoice'**
  String get dashboardCreateFirstInvoiceTitle;

  /// No description provided for @dashboardCreateFirstInvoiceDesc.
  ///
  /// In en, this message translates to:
  /// **'Bill a sale — GST is handled for you.'**
  String get dashboardCreateFirstInvoiceDesc;

  /// No description provided for @dashboardNewInvoice.
  ///
  /// In en, this message translates to:
  /// **'New invoice'**
  String get dashboardNewInvoice;

  /// No description provided for @dashboardAddCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a customer'**
  String get dashboardAddCustomerTitle;

  /// No description provided for @dashboardAddCustomerDesc.
  ///
  /// In en, this message translates to:
  /// **'Track who owes you and send them invoices.'**
  String get dashboardAddCustomerDesc;

  /// No description provided for @dashboardAddCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get dashboardAddCustomer;

  /// No description provided for @dashboardSetUpPayoutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up payouts'**
  String get dashboardSetUpPayoutsTitle;

  /// No description provided for @dashboardSetUpPayoutsDesc.
  ///
  /// In en, this message translates to:
  /// **'Receive settlements for online orders.'**
  String get dashboardSetUpPayoutsDesc;

  /// No description provided for @dashboardSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get dashboardSetUp;

  /// No description provided for @dashboardAlertReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get dashboardAlertReorder;

  /// No description provided for @dashboardAlertFileGst.
  ///
  /// In en, this message translates to:
  /// **'File GST'**
  String get dashboardAlertFileGst;

  /// No description provided for @dashboardAlertViewReport.
  ///
  /// In en, this message translates to:
  /// **'View report'**
  String get dashboardAlertViewReport;

  /// No description provided for @dashboardAlertOpenTill.
  ///
  /// In en, this message translates to:
  /// **'Open till'**
  String get dashboardAlertOpenTill;

  /// No description provided for @dashboardDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dashboardDismiss;

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get dashboardRecentActivity;

  /// No description provided for @dashboardNoRecentMovements.
  ///
  /// In en, this message translates to:
  /// **'No recent stock movements.'**
  String get dashboardNoRecentMovements;

  /// No description provided for @dashboardProductFallback.
  ///
  /// In en, this message translates to:
  /// **'Product #{id}'**
  String dashboardProductFallback(Object id);

  /// No description provided for @dashboardTopCategories.
  ///
  /// In en, this message translates to:
  /// **'Top categories'**
  String get dashboardTopCategories;

  /// No description provided for @dashboardTopProducts.
  ///
  /// In en, this message translates to:
  /// **'Top products'**
  String get dashboardTopProducts;

  /// No description provided for @dashboardSlowMovers.
  ///
  /// In en, this message translates to:
  /// **'Slow movers'**
  String get dashboardSlowMovers;

  /// No description provided for @dashboardSlowMoversHint.
  ///
  /// In en, this message translates to:
  /// **'Share of idle in-stock units — capital that isn\'t moving.'**
  String get dashboardSlowMoversHint;

  /// No description provided for @dashboardUnitsValue.
  ///
  /// In en, this message translates to:
  /// **'{count} units'**
  String dashboardUnitsValue(Object count);

  /// No description provided for @dashboardSubjectCategorySales.
  ///
  /// In en, this message translates to:
  /// **'category sales'**
  String get dashboardSubjectCategorySales;

  /// No description provided for @dashboardSubjectProductSales.
  ///
  /// In en, this message translates to:
  /// **'product sales'**
  String get dashboardSubjectProductSales;

  /// No description provided for @dashboardSubjectIdleStock.
  ///
  /// In en, this message translates to:
  /// **'idle stock'**
  String get dashboardSubjectIdleStock;

  /// No description provided for @dashboardNounCategories.
  ///
  /// In en, this message translates to:
  /// **'categories'**
  String get dashboardNounCategories;

  /// No description provided for @dashboardNounProducts.
  ///
  /// In en, this message translates to:
  /// **'products'**
  String get dashboardNounProducts;

  /// No description provided for @dashboardPieOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get dashboardPieOther;

  /// No description provided for @dashboardNoDataInPeriod.
  ///
  /// In en, this message translates to:
  /// **'No data in this period yet.'**
  String get dashboardNoDataInPeriod;

  /// No description provided for @dashboardAboutThisChart.
  ///
  /// In en, this message translates to:
  /// **'About this chart'**
  String get dashboardAboutThisChart;

  /// No description provided for @dashboardTapSliceHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a slice for its breakdown.'**
  String get dashboardTapSliceHint;

  /// No description provided for @dashboardPieSummaryBase.
  ///
  /// In en, this message translates to:
  /// **'{total} across {count} {noun} (avg {avg} each).'**
  String dashboardPieSummaryBase(
    Object total,
    Object count,
    Object noun,
    Object avg,
  );

  /// No description provided for @dashboardPieSummaryLead.
  ///
  /// In en, this message translates to:
  /// **'{label} leads with {pct}% ({value})'**
  String dashboardPieSummaryLead(Object label, Object pct, Object value);

  /// No description provided for @dashboardPieSummaryAheadOf.
  ///
  /// In en, this message translates to:
  /// **', ahead of {label} at {pct}%'**
  String dashboardPieSummaryAheadOf(Object label, Object pct);

  /// No description provided for @dashboardPieSummaryTopK.
  ///
  /// In en, this message translates to:
  /// **'The top {k} make up {pct}% of {subject}'**
  String dashboardPieSummaryTopK(Object k, Object pct, Object subject);

  /// No description provided for @dashboardPieSummaryTrails.
  ///
  /// In en, this message translates to:
  /// **', while {label} trails at {pct}%'**
  String dashboardPieSummaryTrails(Object label, Object pct);

  /// No description provided for @dashboardPieDetailTail.
  ///
  /// In en, this message translates to:
  /// **', {pct}% of {subject}.'**
  String dashboardPieDetailTail(Object pct, Object subject);

  /// No description provided for @dashboardPeriodToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dashboardPeriodToday;

  /// No description provided for @dashboardPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get dashboardPeriodWeek;

  /// No description provided for @dashboardPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get dashboardPeriodMonth;

  /// No description provided for @dashboardDeltaNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get dashboardDeltaNew;

  /// No description provided for @shopSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shopSave;

  /// No description provided for @shopSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get shopSaving;

  /// No description provided for @shopSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get shopSaveFailed;

  /// No description provided for @shopCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shopCancel;

  /// No description provided for @shopDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get shopDelete;

  /// No description provided for @shopRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get shopRemove;

  /// No description provided for @shopContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get shopContinue;

  /// No description provided for @shopBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get shopBack;

  /// No description provided for @shopRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get shopRetry;

  /// No description provided for @shopTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get shopTryAgain;

  /// No description provided for @shopDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get shopDismiss;

  /// No description provided for @shopEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get shopEnabled;

  /// No description provided for @shopNotYetEnabled.
  ///
  /// In en, this message translates to:
  /// **'Not yet enabled'**
  String get shopNotYetEnabled;

  /// No description provided for @shopNotEnabledYet.
  ///
  /// In en, this message translates to:
  /// **'Not enabled yet'**
  String get shopNotEnabledYet;

  /// No description provided for @shopHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'Hours & vacation mode'**
  String get shopHoursTitle;

  /// No description provided for @shopHoursSaved.
  ///
  /// In en, this message translates to:
  /// **'Hours saved'**
  String get shopHoursSaved;

  /// No description provided for @shopVacationMode.
  ///
  /// In en, this message translates to:
  /// **'Vacation mode'**
  String get shopVacationMode;

  /// No description provided for @shopVacationModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Blocks new orders. Existing orders, stock, and invoices stay editable as usual.'**
  String get shopVacationModeSubtitle;

  /// No description provided for @shopVacationMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Message shown to customers (optional)'**
  String get shopVacationMessageLabel;

  /// No description provided for @shopVacationMessageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Back on Jun 5. Thanks for your patience!'**
  String get shopVacationMessageHint;

  /// No description provided for @shopOpeningHours.
  ///
  /// In en, this message translates to:
  /// **'OPENING HOURS'**
  String get shopOpeningHours;

  /// No description provided for @shopHoursHint.
  ///
  /// In en, this message translates to:
  /// **'Hours are a hint to customers — orders outside hours still go through.'**
  String get shopHoursHint;

  /// No description provided for @shopDayClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get shopDayClosed;

  /// No description provided for @shopDayMonday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get shopDayMonday;

  /// No description provided for @shopDayTuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get shopDayTuesday;

  /// No description provided for @shopDayWednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get shopDayWednesday;

  /// No description provided for @shopDayThursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get shopDayThursday;

  /// No description provided for @shopDayFriday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get shopDayFriday;

  /// No description provided for @shopDaySaturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get shopDaySaturday;

  /// No description provided for @shopDaySunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get shopDaySunday;

  /// No description provided for @shopOperationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop operations'**
  String get shopOperationsTitle;

  /// No description provided for @shopOpsHoursOnVacation.
  ///
  /// In en, this message translates to:
  /// **'On vacation — new orders blocked'**
  String get shopOpsHoursOnVacation;

  /// No description provided for @shopOpsHoursSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set opening hours and pause new orders.'**
  String get shopOpsHoursSubtitle;

  /// No description provided for @shopOnVacationBadge.
  ///
  /// In en, this message translates to:
  /// **'On vacation'**
  String get shopOnVacationBadge;

  /// No description provided for @shopPayoutsTitle.
  ///
  /// In en, this message translates to:
  /// **'Payouts & settlement'**
  String get shopPayoutsTitle;

  /// No description provided for @shopKycTitle.
  ///
  /// In en, this message translates to:
  /// **'KYC documents'**
  String get shopKycTitle;

  /// No description provided for @shopOpsKycSubtitle.
  ///
  /// In en, this message translates to:
  /// **'PAN, GSTIN certificate, cancelled cheque. Required before payouts go live.'**
  String get shopOpsKycSubtitle;

  /// No description provided for @shopComingSoonBadge.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get shopComingSoonBadge;

  /// No description provided for @shopTeamTitle.
  ///
  /// In en, this message translates to:
  /// **'Team & roles'**
  String get shopTeamTitle;

  /// No description provided for @shopOpsTeamSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Invite staff and scope exactly what each person can view and manage.'**
  String get shopOpsTeamSubtitle;

  /// No description provided for @shopOpsPayoutsLinkBank.
  ///
  /// In en, this message translates to:
  /// **'Link a bank account to receive your sales settlements.'**
  String get shopOpsPayoutsLinkBank;

  /// No description provided for @shopOpsPayoutsResume.
  ///
  /// In en, this message translates to:
  /// **'Resume your payout setup — you have a saved draft.'**
  String get shopOpsPayoutsResume;

  /// No description provided for @shopOpsPayoutsSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up your bank account to start receiving settlements.'**
  String get shopOpsPayoutsSetUp;

  /// No description provided for @shopOpsPayoutsActive.
  ///
  /// In en, this message translates to:
  /// **'Active — your sales settle to your linked bank account.'**
  String get shopOpsPayoutsActive;

  /// No description provided for @shopOpsPayoutsSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted — Razorpay is verifying your account.'**
  String get shopOpsPayoutsSubmitted;

  /// No description provided for @shopInProgressBadge.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get shopInProgressBadge;

  /// No description provided for @shopSetUpBadge.
  ///
  /// In en, this message translates to:
  /// **'Set up'**
  String get shopSetUpBadge;

  /// No description provided for @shopActiveBadge.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get shopActiveBadge;

  /// No description provided for @shopUnderReviewBadge.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get shopUnderReviewBadge;

  /// No description provided for @shopKycIntro.
  ///
  /// In en, this message translates to:
  /// **'Document uploads launch with the verified-seller badge. Until then, this lists what you\'ll be asked for so you can prepare ahead. Your payout KYC is handled in Payouts & settlement.'**
  String get shopKycIntro;

  /// No description provided for @shopKycPanTitle.
  ///
  /// In en, this message translates to:
  /// **'PAN card'**
  String get shopKycPanTitle;

  /// No description provided for @shopKycPanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Owner or business PAN. Required for payouts.'**
  String get shopKycPanSubtitle;

  /// No description provided for @shopKycGstinTitle.
  ///
  /// In en, this message translates to:
  /// **'GSTIN certificate'**
  String get shopKycGstinTitle;

  /// No description provided for @shopKycGstinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'If your shop has a GSTIN, upload the registration certificate.'**
  String get shopKycGstinSubtitle;

  /// No description provided for @shopKycChequeTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancelled cheque'**
  String get shopKycChequeTitle;

  /// No description provided for @shopKycChequeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bank-issued cheque with account holder name visible. Confirms settlement-account ownership.'**
  String get shopKycChequeSubtitle;

  /// No description provided for @shopKycAadhaarTitle.
  ///
  /// In en, this message translates to:
  /// **'Aadhaar / address proof'**
  String get shopKycAadhaarTitle;

  /// No description provided for @shopKycAadhaarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For sole-proprietor shops. Skip if you already have GSTIN on file.'**
  String get shopKycAadhaarSubtitle;

  /// No description provided for @shopKycPhotoTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop / business photo'**
  String get shopKycPhotoTitle;

  /// No description provided for @shopKycPhotoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional. Front-of-store photo helps trust + verification reviews.'**
  String get shopKycPhotoSubtitle;

  /// No description provided for @shopKycNotUploaded.
  ///
  /// In en, this message translates to:
  /// **'Not uploaded'**
  String get shopKycNotUploaded;

  /// No description provided for @shopKycUploadComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Upload (coming soon)'**
  String get shopKycUploadComingSoon;

  /// No description provided for @shopConnectExistingAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect existing account'**
  String get shopConnectExistingAccountTitle;

  /// No description provided for @shopConnectIntro.
  ///
  /// In en, this message translates to:
  /// **'Already have a Razorpay linked account? Paste its id to link it — no need to re-do KYC.'**
  String get shopConnectIntro;

  /// No description provided for @shopConnectAccountIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Account id'**
  String get shopConnectAccountIdLabel;

  /// No description provided for @shopConnectVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get shopConnectVerify;

  /// No description provided for @shopConnectConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm this is your account'**
  String get shopConnectConfirmTitle;

  /// No description provided for @shopConnectFactAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get shopConnectFactAccount;

  /// No description provided for @shopConnectFactBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get shopConnectFactBusiness;

  /// No description provided for @shopConnectFactContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get shopConnectFactContact;

  /// No description provided for @shopConnectFactEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get shopConnectFactEmail;

  /// No description provided for @shopConnectFactKycStatus.
  ///
  /// In en, this message translates to:
  /// **'KYC status'**
  String get shopConnectFactKycStatus;

  /// No description provided for @shopConnectFactPayouts.
  ///
  /// In en, this message translates to:
  /// **'Payouts'**
  String get shopConnectFactPayouts;

  /// No description provided for @shopConnectPayoutsNotEnabledWarning.
  ///
  /// In en, this message translates to:
  /// **'Payouts aren\'t enabled yet — you can link it, but UPI at the till stays off until Razorpay activates the account.'**
  String get shopConnectPayoutsNotEnabledWarning;

  /// No description provided for @shopConnectLinkAccount.
  ///
  /// In en, this message translates to:
  /// **'Link this account'**
  String get shopConnectLinkAccount;

  /// No description provided for @shopPermissionView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get shopPermissionView;

  /// No description provided for @shopPermissionManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get shopPermissionManage;

  /// No description provided for @shopStartFromRole.
  ///
  /// In en, this message translates to:
  /// **'START FROM A ROLE'**
  String get shopStartFromRole;

  /// No description provided for @shopCustomRole.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get shopCustomRole;

  /// No description provided for @shopAccessManageable.
  ///
  /// In en, this message translates to:
  /// **'ACCESS · {count} manageable'**
  String shopAccessManageable(Object count);

  /// No description provided for @shopPermissionTrustHint.
  ///
  /// In en, this message translates to:
  /// **'Manage includes view. Payouts & KYC and Team are sensitive — grant them only to people you trust.'**
  String get shopPermissionTrustHint;

  /// No description provided for @shopGiveRoleName.
  ///
  /// In en, this message translates to:
  /// **'Give the role a name'**
  String get shopGiveRoleName;

  /// No description provided for @shopNewRole.
  ///
  /// In en, this message translates to:
  /// **'New role'**
  String get shopNewRole;

  /// No description provided for @shopEditRole.
  ///
  /// In en, this message translates to:
  /// **'Edit role'**
  String get shopEditRole;

  /// No description provided for @shopRoleNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Role name'**
  String get shopRoleNameLabel;

  /// No description provided for @shopRoleNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Warehouse Lead'**
  String get shopRoleNameHint;

  /// No description provided for @shopRoleTemplatesHint.
  ///
  /// In en, this message translates to:
  /// **'Members keep their current access when a role changes — roles are templates you assign, not live links.'**
  String get shopRoleTemplatesHint;

  /// No description provided for @shopPayoutsSubmittedSnack.
  ///
  /// In en, this message translates to:
  /// **'Submitted — Razorpay will verify your account.'**
  String get shopPayoutsSubmittedSnack;

  /// No description provided for @shopConnectExisting.
  ///
  /// In en, this message translates to:
  /// **'Connect existing'**
  String get shopConnectExisting;

  /// No description provided for @shopStepBusiness.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get shopStepBusiness;

  /// No description provided for @shopStepIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity'**
  String get shopStepIdentity;

  /// No description provided for @shopStepAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get shopStepAddress;

  /// No description provided for @shopStepBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get shopStepBank;

  /// No description provided for @shopStepProgress.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total} · {title}'**
  String shopStepProgress(Object current, Object total, Object title);

  /// No description provided for @shopSetUpPayouts.
  ///
  /// In en, this message translates to:
  /// **'Set up payouts'**
  String get shopSetUpPayouts;

  /// No description provided for @shopFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get shopFieldRequired;

  /// No description provided for @shopInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get shopInvalidEmail;

  /// No description provided for @shopBusinessStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Your business'**
  String get shopBusinessStepTitle;

  /// No description provided for @shopBusinessStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The legal entity that receives settlements.'**
  String get shopBusinessStepSubtitle;

  /// No description provided for @shopLegalBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Legal business name'**
  String get shopLegalBusinessName;

  /// No description provided for @shopDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name (optional)'**
  String get shopDisplayName;

  /// No description provided for @shopDisplayNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Shown to customers. Defaults to the legal name.'**
  String get shopDisplayNameHelper;

  /// No description provided for @shopContactPersonName.
  ///
  /// In en, this message translates to:
  /// **'Contact person name'**
  String get shopContactPersonName;

  /// No description provided for @shopEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get shopEmail;

  /// No description provided for @shopPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get shopPhone;

  /// No description provided for @shopEnter10DigitNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a 10-digit number'**
  String get shopEnter10DigitNumber;

  /// No description provided for @shopBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get shopBusinessType;

  /// No description provided for @shopBusinessTypeProprietorship.
  ///
  /// In en, this message translates to:
  /// **'Proprietorship'**
  String get shopBusinessTypeProprietorship;

  /// No description provided for @shopBusinessTypePartnership.
  ///
  /// In en, this message translates to:
  /// **'Partnership'**
  String get shopBusinessTypePartnership;

  /// No description provided for @shopBusinessTypePrivateLimited.
  ///
  /// In en, this message translates to:
  /// **'Private Limited'**
  String get shopBusinessTypePrivateLimited;

  /// No description provided for @shopBusinessTypePublicLimited.
  ///
  /// In en, this message translates to:
  /// **'Public Limited'**
  String get shopBusinessTypePublicLimited;

  /// No description provided for @shopBusinessTypeLlp.
  ///
  /// In en, this message translates to:
  /// **'LLP'**
  String get shopBusinessTypeLlp;

  /// No description provided for @shopBusinessTypeIndividual.
  ///
  /// In en, this message translates to:
  /// **'Individual'**
  String get shopBusinessTypeIndividual;

  /// No description provided for @shopBusinessTypeTrust.
  ///
  /// In en, this message translates to:
  /// **'Trust'**
  String get shopBusinessTypeTrust;

  /// No description provided for @shopBusinessTypeSociety.
  ///
  /// In en, this message translates to:
  /// **'Society'**
  String get shopBusinessTypeSociety;

  /// No description provided for @shopBusinessTypeNgo.
  ///
  /// In en, this message translates to:
  /// **'NGO'**
  String get shopBusinessTypeNgo;

  /// No description provided for @shopBusinessCategory.
  ///
  /// In en, this message translates to:
  /// **'Business category'**
  String get shopBusinessCategory;

  /// No description provided for @shopCategoryEcommerce.
  ///
  /// In en, this message translates to:
  /// **'E-commerce / Retail'**
  String get shopCategoryEcommerce;

  /// No description provided for @shopCategoryFood.
  ///
  /// In en, this message translates to:
  /// **'Food & Beverage'**
  String get shopCategoryFood;

  /// No description provided for @shopCategoryServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get shopCategoryServices;

  /// No description provided for @shopCategoryHealthcare.
  ///
  /// In en, this message translates to:
  /// **'Healthcare'**
  String get shopCategoryHealthcare;

  /// No description provided for @shopCategoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get shopCategoryEducation;

  /// No description provided for @shopCategoryOthers.
  ///
  /// In en, this message translates to:
  /// **'Others'**
  String get shopCategoryOthers;

  /// No description provided for @shopIdentityStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Identity & tax'**
  String get shopIdentityStepTitle;

  /// No description provided for @shopIdentityStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Verified with the tax authority. Sent to Razorpay, never stored by this app.'**
  String get shopIdentityStepSubtitle;

  /// No description provided for @shopPanHelper.
  ///
  /// In en, this message translates to:
  /// **'Business or proprietor PAN (e.g. AAACL1234C).'**
  String get shopPanHelper;

  /// No description provided for @shopInvalidPan.
  ///
  /// In en, this message translates to:
  /// **'Invalid PAN'**
  String get shopInvalidPan;

  /// No description provided for @shopGstinOptional.
  ///
  /// In en, this message translates to:
  /// **'GSTIN (optional)'**
  String get shopGstinOptional;

  /// No description provided for @shopGstinHelper.
  ///
  /// In en, this message translates to:
  /// **'Add if your business is GST-registered.'**
  String get shopGstinHelper;

  /// No description provided for @shopInvalidGstin.
  ///
  /// In en, this message translates to:
  /// **'Invalid GSTIN'**
  String get shopInvalidGstin;

  /// No description provided for @shopAddressStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Registered address'**
  String get shopAddressStepTitle;

  /// No description provided for @shopAddressStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The address on your business registration.'**
  String get shopAddressStepSubtitle;

  /// No description provided for @shopAddressLine1.
  ///
  /// In en, this message translates to:
  /// **'Address line 1'**
  String get shopAddressLine1;

  /// No description provided for @shopAddressLine2.
  ///
  /// In en, this message translates to:
  /// **'Address line 2 (optional)'**
  String get shopAddressLine2;

  /// No description provided for @shopCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get shopCity;

  /// No description provided for @shopState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get shopState;

  /// No description provided for @shopSelectState.
  ///
  /// In en, this message translates to:
  /// **'Select a state'**
  String get shopSelectState;

  /// No description provided for @shopPinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get shopPinCode;

  /// No description provided for @shopEnter6DigitPin.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit PIN'**
  String get shopEnter6DigitPin;

  /// No description provided for @shopCountryIndia.
  ///
  /// In en, this message translates to:
  /// **'Country: India'**
  String get shopCountryIndia;

  /// No description provided for @shopBankStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Settlement bank account'**
  String get shopBankStepTitle;

  /// No description provided for @shopBankStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Where your payouts land. Sent securely to Razorpay; this app never stores your bank details.'**
  String get shopBankStepSubtitle;

  /// No description provided for @shopAccountHolderName.
  ///
  /// In en, this message translates to:
  /// **'Account holder name'**
  String get shopAccountHolderName;

  /// No description provided for @shopBankAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Bank account number'**
  String get shopBankAccountNumber;

  /// No description provided for @shopEnterValidAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid account number'**
  String get shopEnterValidAccountNumber;

  /// No description provided for @shopInvalidIfsc.
  ///
  /// In en, this message translates to:
  /// **'Invalid IFSC'**
  String get shopInvalidIfsc;

  /// No description provided for @shopResumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue where you left off?'**
  String get shopResumeTitle;

  /// No description provided for @shopResumeDraftUpTo.
  ///
  /// In en, this message translates to:
  /// **'You had a saved draft up to the {step} step.'**
  String shopResumeDraftUpTo(Object step);

  /// No description provided for @shopStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get shopStartOver;

  /// No description provided for @shopResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get shopResume;

  /// No description provided for @shopStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active — payouts enabled'**
  String get shopStatusActive;

  /// No description provided for @shopStatusNeedsClarification.
  ///
  /// In en, this message translates to:
  /// **'Action needed — Razorpay needs more info'**
  String get shopStatusNeedsClarification;

  /// No description provided for @shopStatusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended — contact support'**
  String get shopStatusSuspended;

  /// No description provided for @shopStatusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under review by Razorpay'**
  String get shopStatusUnderReview;

  /// No description provided for @shopStatusNotActivated.
  ///
  /// In en, this message translates to:
  /// **'Not activated yet — finish KYC at Razorpay'**
  String get shopStatusNotActivated;

  /// No description provided for @shopStatusActivatedDesc.
  ///
  /// In en, this message translates to:
  /// **'Your settlement account is verified. Order + UPI payouts will land in your bank.'**
  String get shopStatusActivatedDesc;

  /// No description provided for @shopStatusNotEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'This account is not payout-enabled yet (Razorpay status: {status}). Finish its Route KYC in the Razorpay dashboard, then tap refresh to re-check live.'**
  String shopStatusNotEnabledDesc(Object status);

  /// No description provided for @shopDetailAccountId.
  ///
  /// In en, this message translates to:
  /// **'Account ID'**
  String get shopDetailAccountId;

  /// No description provided for @shopDetailName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get shopDetailName;

  /// No description provided for @shopDetailEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get shopDetailEmail;

  /// No description provided for @shopDetailBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get shopDetailBusinessType;

  /// No description provided for @shopDetailKycStatus.
  ///
  /// In en, this message translates to:
  /// **'KYC status'**
  String get shopDetailKycStatus;

  /// No description provided for @shopDetailPayouts.
  ///
  /// In en, this message translates to:
  /// **'Payouts'**
  String get shopDetailPayouts;

  /// No description provided for @shopRefreshFromRazorpay.
  ///
  /// In en, this message translates to:
  /// **'Refresh from Razorpay'**
  String get shopRefreshFromRazorpay;

  /// No description provided for @shopImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is larger than 5 MB. Pick a smaller image or crop tighter.'**
  String get shopImageTooLarge;

  /// No description provided for @shopImageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed'**
  String get shopImageUploadFailed;

  /// No description provided for @shopProfileSaved.
  ///
  /// In en, this message translates to:
  /// **'Shop profile saved'**
  String get shopProfileSaved;

  /// No description provided for @shopUnpublishTitle.
  ///
  /// In en, this message translates to:
  /// **'Unpublish shop?'**
  String get shopUnpublishTitle;

  /// No description provided for @shopUnpublishMessage.
  ///
  /// In en, this message translates to:
  /// **'Customers will stop seeing your shop on the marketplace. Your inventory and orders are unaffected.'**
  String get shopUnpublishMessage;

  /// No description provided for @shopUnpublish.
  ///
  /// In en, this message translates to:
  /// **'Unpublish'**
  String get shopUnpublish;

  /// No description provided for @shopNowLive.
  ///
  /// In en, this message translates to:
  /// **'Shop is now live on the marketplace'**
  String get shopNowLive;

  /// No description provided for @shopHiddenFromMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Shop hidden from marketplace'**
  String get shopHiddenFromMarketplace;

  /// No description provided for @shopPublishUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update publish state'**
  String get shopPublishUpdateFailed;

  /// No description provided for @shopDiscardChangesTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get shopDiscardChangesTitle;

  /// No description provided for @shopDiscardChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved edits. Leaving now drops them.'**
  String get shopDiscardChangesMessage;

  /// No description provided for @shopKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get shopKeepEditing;

  /// No description provided for @shopDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get shopDiscard;

  /// No description provided for @shopMyShopTitle.
  ///
  /// In en, this message translates to:
  /// **'My Shop'**
  String get shopMyShopTitle;

  /// No description provided for @shopNotFound.
  ///
  /// In en, this message translates to:
  /// **'Shop not found'**
  String get shopNotFound;

  /// No description provided for @shopLiveOnMarketplaceSlug.
  ///
  /// In en, this message translates to:
  /// **'Live on marketplace · /{slug}'**
  String shopLiveOnMarketplaceSlug(Object slug);

  /// No description provided for @shopNotPublished.
  ///
  /// In en, this message translates to:
  /// **'Not published'**
  String get shopNotPublished;

  /// No description provided for @shopNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get shopNameLabel;

  /// No description provided for @shopNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Shown on the marketplace. Renaming updates the public URL slug.'**
  String get shopNameHelper;

  /// No description provided for @shopMin2Chars.
  ///
  /// In en, this message translates to:
  /// **'Min 2 characters'**
  String get shopMin2Chars;

  /// No description provided for @shopMax80Chars.
  ///
  /// In en, this message translates to:
  /// **'Max 80 characters'**
  String get shopMax80Chars;

  /// No description provided for @shopTaglineLabel.
  ///
  /// In en, this message translates to:
  /// **'Tagline (optional)'**
  String get shopTaglineLabel;

  /// No description provided for @shopTaglineHelper.
  ///
  /// In en, this message translates to:
  /// **'One-liner shown below your shop name.'**
  String get shopTaglineHelper;

  /// No description provided for @shopLocationSection.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get shopLocationSection;

  /// No description provided for @shopLocationSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional. Surfaces a \"Based in …\" line on your public shop page.'**
  String get shopLocationSectionSubtitle;

  /// No description provided for @shopPoliciesSection.
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get shopPoliciesSection;

  /// No description provided for @shopPoliciesSectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Customers see these on your shop page and as a \"Policies\" pill on every PDP. Plain text. Up to 4 KB each.'**
  String get shopPoliciesSectionSubtitle;

  /// No description provided for @shopReturnPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Return policy'**
  String get shopReturnPolicyLabel;

  /// No description provided for @shopReturnPolicyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 7-day return on unused items. Original packaging required.'**
  String get shopReturnPolicyHint;

  /// No description provided for @shopShippingPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Shipping policy'**
  String get shopShippingPolicyLabel;

  /// No description provided for @shopShippingPolicyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ships within 24 hours from Bengaluru. 3–5 business days delivery.'**
  String get shopShippingPolicyHint;

  /// No description provided for @shopRefundPolicyLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund policy'**
  String get shopRefundPolicyLabel;

  /// No description provided for @shopRefundPolicyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Refunds processed within 5 business days to the original payment method.'**
  String get shopRefundPolicyHint;

  /// No description provided for @shopReturnsCancellationSection.
  ///
  /// In en, this message translates to:
  /// **'Returns & cancellation'**
  String get shopReturnsCancellationSection;

  /// No description provided for @shopReturnsCancellationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Whether customers can return orders, how refunds are issued, and how late an order can be cancelled.'**
  String get shopReturnsCancellationSubtitle;

  /// No description provided for @shopAcceptReturns.
  ///
  /// In en, this message translates to:
  /// **'Accept returns'**
  String get shopAcceptReturns;

  /// No description provided for @shopAcceptReturnsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, customers can\'t request post-delivery returns.'**
  String get shopAcceptReturnsSubtitle;

  /// No description provided for @shopReturnWindowLabel.
  ///
  /// In en, this message translates to:
  /// **'Return window (days)'**
  String get shopReturnWindowLabel;

  /// No description provided for @shopReturnWindowHelper.
  ///
  /// In en, this message translates to:
  /// **'0 means no time limit.'**
  String get shopReturnWindowHelper;

  /// No description provided for @shopReturnWindowError.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number between 0 and 365'**
  String get shopReturnWindowError;

  /// No description provided for @shopRefundMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund method'**
  String get shopRefundMethodLabel;

  /// No description provided for @shopRefundMethodOriginal.
  ///
  /// In en, this message translates to:
  /// **'Original payment method'**
  String get shopRefundMethodOriginal;

  /// No description provided for @shopRefundMethodReplacement.
  ///
  /// In en, this message translates to:
  /// **'Replacement only'**
  String get shopRefundMethodReplacement;

  /// No description provided for @shopReturnPolicyNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Return policy note (optional)'**
  String get shopReturnPolicyNoteLabel;

  /// No description provided for @shopReturnPolicyNoteHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Items must be unused and in original packaging. Buyer pays return shipping.'**
  String get shopReturnPolicyNoteHint;

  /// No description provided for @shopCustomersCanCancelLabel.
  ///
  /// In en, this message translates to:
  /// **'Customers can cancel'**
  String get shopCustomersCanCancelLabel;

  /// No description provided for @shopCustomersCanCancelHelper.
  ///
  /// In en, this message translates to:
  /// **'After this stage they must use a post-delivery return instead.'**
  String get shopCustomersCanCancelHelper;

  /// No description provided for @shopCancelUntilConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Until I confirm the order'**
  String get shopCancelUntilConfirmed;

  /// No description provided for @shopCancelUntilPacked.
  ///
  /// In en, this message translates to:
  /// **'Until packed'**
  String get shopCancelUntilPacked;

  /// No description provided for @shopCancelUntilShipped.
  ///
  /// In en, this message translates to:
  /// **'Until shipped (recommended)'**
  String get shopCancelUntilShipped;

  /// No description provided for @shopCancelUntilDelivered.
  ///
  /// In en, this message translates to:
  /// **'Until delivered'**
  String get shopCancelUntilDelivered;

  /// No description provided for @shopAddBanner.
  ///
  /// In en, this message translates to:
  /// **'Add banner'**
  String get shopAddBanner;

  /// No description provided for @shopReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get shopReplace;

  /// No description provided for @shopLiveOnMarketplace.
  ///
  /// In en, this message translates to:
  /// **'Live on marketplace'**
  String get shopLiveOnMarketplace;

  /// No description provided for @shopNotPublishedYet.
  ///
  /// In en, this message translates to:
  /// **'Not published yet'**
  String get shopNotPublishedYet;

  /// No description provided for @shopPublishCardLiveDesc.
  ///
  /// In en, this message translates to:
  /// **'Customers can find your shop and your published products.'**
  String get shopPublishCardLiveDesc;

  /// No description provided for @shopPublishCardHiddenDesc.
  ///
  /// In en, this message translates to:
  /// **'Toggle on once your logo, banner and at least one product are ready.'**
  String get shopPublishCardHiddenDesc;

  /// No description provided for @shopInviteTeammate.
  ///
  /// In en, this message translates to:
  /// **'Invite a teammate'**
  String get shopInviteTeammate;

  /// No description provided for @shopInviteAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Invite access'**
  String get shopInviteAccessTitle;

  /// No description provided for @shopSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invite'**
  String get shopSendInvite;

  /// No description provided for @shopInviteAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what {email} can view and manage. You can change this anytime.'**
  String shopInviteAccessSubtitle(Object email);

  /// No description provided for @shopInvitationSentTo.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to {email}'**
  String shopInvitationSentTo(Object email);

  /// No description provided for @shopEditAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit access'**
  String get shopEditAccessTitle;

  /// No description provided for @shopEditAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set exactly what {name} can view and manage.'**
  String shopEditAccessSubtitle(Object name);

  /// No description provided for @shopAccessUpdated.
  ///
  /// In en, this message translates to:
  /// **'Access updated'**
  String get shopAccessUpdated;

  /// No description provided for @shopRemoveFromTeamTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from team?'**
  String get shopRemoveFromTeamTitle;

  /// No description provided for @shopRemoveFromTeamMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} will lose access to this shop immediately. You can invite them again later.'**
  String shopRemoveFromTeamMessage(Object name);

  /// No description provided for @shopRemovedFromTeam.
  ///
  /// In en, this message translates to:
  /// **'Removed from team'**
  String get shopRemovedFromTeam;

  /// No description provided for @shopRoleCreated.
  ///
  /// In en, this message translates to:
  /// **'Role created'**
  String get shopRoleCreated;

  /// No description provided for @shopRoleSaved.
  ///
  /// In en, this message translates to:
  /// **'Role saved'**
  String get shopRoleSaved;

  /// No description provided for @shopDeleteRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String shopDeleteRoleTitle(Object name);

  /// No description provided for @shopDeleteRoleMessage.
  ///
  /// In en, this message translates to:
  /// **'This removes the role from the picker. Teammates who already have it keep their current access.'**
  String get shopDeleteRoleMessage;

  /// No description provided for @shopRoleDeleted.
  ///
  /// In en, this message translates to:
  /// **'Role deleted'**
  String get shopRoleDeleted;

  /// No description provided for @shopInvitationCancelled.
  ///
  /// In en, this message translates to:
  /// **'Invitation cancelled'**
  String get shopInvitationCancelled;

  /// No description provided for @shopTeamViewOnlyBanner.
  ///
  /// In en, this message translates to:
  /// **'You can view the team but not change it. Ask an owner to invite people or adjust who does what.'**
  String get shopTeamViewOnlyBanner;

  /// No description provided for @shopTeamSectionHeader.
  ///
  /// In en, this message translates to:
  /// **'TEAM · {count}'**
  String shopTeamSectionHeader(Object count);

  /// No description provided for @shopPendingInvitesHeader.
  ///
  /// In en, this message translates to:
  /// **'PENDING INVITES · {count}'**
  String shopPendingInvitesHeader(Object count);

  /// No description provided for @shopRolesHeader.
  ///
  /// In en, this message translates to:
  /// **'ROLES · {count}'**
  String shopRolesHeader(Object count);

  /// No description provided for @shopEditAccessMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit access'**
  String get shopEditAccessMenu;

  /// No description provided for @shopRemoveFromTeamMenu.
  ///
  /// In en, this message translates to:
  /// **'Remove from team'**
  String get shopRemoveFromTeamMenu;

  /// No description provided for @shopInvitedAsAwaitingReply.
  ///
  /// In en, this message translates to:
  /// **'Invited as {role} · awaiting reply'**
  String shopInvitedAsAwaitingReply(Object role);

  /// No description provided for @shopBuiltIn.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get shopBuiltIn;

  /// No description provided for @shopRoleViewOnly.
  ///
  /// In en, this message translates to:
  /// **'View-only'**
  String get shopRoleViewOnly;

  /// No description provided for @shopRoleAreaManageable.
  ///
  /// In en, this message translates to:
  /// **'{count} area manageable'**
  String shopRoleAreaManageable(Object count);

  /// No description provided for @shopRoleAreasManageable.
  ///
  /// In en, this message translates to:
  /// **'{count} areas manageable'**
  String shopRoleAreasManageable(Object count);

  /// No description provided for @shopEditRoleMenu.
  ///
  /// In en, this message translates to:
  /// **'Edit role'**
  String get shopEditRoleMenu;

  /// No description provided for @shopDeleteRoleMenu.
  ///
  /// In en, this message translates to:
  /// **'Delete role'**
  String get shopDeleteRoleMenu;

  /// No description provided for @shopInviteSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Use a dedicated work email — shopper accounts can\'t be staff. You\'ll pick their access next.'**
  String get shopInviteSheetSubtitle;

  /// No description provided for @shopEnterEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter an email'**
  String get shopEnterEmail;

  /// No description provided for @shopEnterValidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get shopEnterValidEmail;

  /// No description provided for @shopChooseAccess.
  ///
  /// In en, this message translates to:
  /// **'Choose access'**
  String get shopChooseAccess;

  /// No description provided for @shopNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get shopNotNow;

  /// No description provided for @shopJoinFallbackShop.
  ///
  /// In en, this message translates to:
  /// **'A shop'**
  String get shopJoinFallbackShop;

  /// No description provided for @shopStaffRole.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get shopStaffRole;

  /// No description provided for @shopYoureInvitedToJoin.
  ///
  /// In en, this message translates to:
  /// **'You\'re invited to join'**
  String get shopYoureInvitedToJoin;

  /// No description provided for @shopAsA.
  ///
  /// In en, this message translates to:
  /// **'as a '**
  String get shopAsA;

  /// No description provided for @shopWhatYoullBeAbleToDo.
  ///
  /// In en, this message translates to:
  /// **'WHAT YOU\'LL BE ABLE TO DO'**
  String get shopWhatYoullBeAbleToDo;

  /// No description provided for @shopLimitedAccess.
  ///
  /// In en, this message translates to:
  /// **'Limited access — ask the owner for details.'**
  String get shopLimitedAccess;

  /// No description provided for @shopJoinTheTeam.
  ///
  /// In en, this message translates to:
  /// **'Join the team'**
  String get shopJoinTheTeam;

  /// No description provided for @shopJoinNamed.
  ///
  /// In en, this message translates to:
  /// **'Join {shop}'**
  String shopJoinNamed(Object shop);

  /// No description provided for @shopDeclineInvitation.
  ///
  /// In en, this message translates to:
  /// **'Decline invitation'**
  String get shopDeclineInvitation;

  /// No description provided for @shopSheetFinishTitle.
  ///
  /// In en, this message translates to:
  /// **'Finish setting up payouts'**
  String get shopSheetFinishTitle;

  /// No description provided for @shopSheetSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set up payouts to get paid'**
  String get shopSheetSetupTitle;

  /// No description provided for @shopSheetFinishBody.
  ///
  /// In en, this message translates to:
  /// **'You started setting up payouts — pick up right where you left off. Your saved details are kept securely on this device.'**
  String get shopSheetFinishBody;

  /// No description provided for @shopSheetSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Add your settlement bank account so your share of each order can reach you. Your money is held until the order is delivered, then settled to your bank — usually within a few days.'**
  String get shopSheetSetupBody;

  /// No description provided for @shopSetUpNow.
  ///
  /// In en, this message translates to:
  /// **'Set up now'**
  String get shopSetUpNow;

  /// No description provided for @shopLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get shopLater;

  /// No description provided for @cashierTitle.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashierTitle;

  /// No description provided for @cashierRoleCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashierRoleCashier;

  /// No description provided for @cashierShiftClosedVariance.
  ///
  /// In en, this message translates to:
  /// **'Shift closed · variance {variance}'**
  String cashierShiftClosedVariance(Object variance);

  /// No description provided for @cashierPastShiftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Past shifts · Z-receipts'**
  String get cashierPastShiftsTitle;

  /// No description provided for @cashierLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get cashierLoading;

  /// No description provided for @cashierNoShiftsYet.
  ///
  /// In en, this message translates to:
  /// **'No shifts yet.'**
  String get cashierNoShiftsYet;

  /// No description provided for @cashierVarianceLabel.
  ///
  /// In en, this message translates to:
  /// **'variance {amount}'**
  String cashierVarianceLabel(Object amount);

  /// No description provided for @cashierShiftReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Shift report (X)'**
  String get cashierShiftReportTitle;

  /// No description provided for @cashierSalesSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} sales · {gross} gross'**
  String cashierSalesSummary(Object count, Object gross);

  /// No description provided for @cashierOpeningFloat.
  ///
  /// In en, this message translates to:
  /// **'Opening float'**
  String get cashierOpeningFloat;

  /// No description provided for @cashierCashSales.
  ///
  /// In en, this message translates to:
  /// **'Cash sales'**
  String get cashierCashSales;

  /// No description provided for @cashierPayIns.
  ///
  /// In en, this message translates to:
  /// **'Pay-ins'**
  String get cashierPayIns;

  /// No description provided for @cashierPayOuts.
  ///
  /// In en, this message translates to:
  /// **'Pay-outs'**
  String get cashierPayOuts;

  /// No description provided for @cashierDrops.
  ///
  /// In en, this message translates to:
  /// **'Drops'**
  String get cashierDrops;

  /// No description provided for @cashierRefunds.
  ///
  /// In en, this message translates to:
  /// **'Refunds'**
  String get cashierRefunds;

  /// No description provided for @cashierExpectedInDrawer.
  ///
  /// In en, this message translates to:
  /// **'Expected in drawer'**
  String get cashierExpectedInDrawer;

  /// No description provided for @cashierGstTaxable.
  ///
  /// In en, this message translates to:
  /// **'GST taxable'**
  String get cashierGstTaxable;

  /// No description provided for @cashierReturnsCount.
  ///
  /// In en, this message translates to:
  /// **'Returns ({count})'**
  String cashierReturnsCount(Object count);

  /// No description provided for @cashierOpenShiftTitle.
  ///
  /// In en, this message translates to:
  /// **'Open a shift'**
  String get cashierOpenShiftTitle;

  /// No description provided for @cashierOpenShiftHint.
  ///
  /// In en, this message translates to:
  /// **'Count the drawer and enter the opening float.'**
  String get cashierOpenShiftHint;

  /// No description provided for @cashierOpeningFloatField.
  ///
  /// In en, this message translates to:
  /// **'Opening float ₹'**
  String get cashierOpeningFloatField;

  /// No description provided for @cashierOpenShiftButton.
  ///
  /// In en, this message translates to:
  /// **'Open shift'**
  String get cashierOpenShiftButton;

  /// No description provided for @cashierCashDrawerTitle.
  ///
  /// In en, this message translates to:
  /// **'Cash drawer'**
  String get cashierCashDrawerTitle;

  /// No description provided for @cashierPayIn.
  ///
  /// In en, this message translates to:
  /// **'Pay in'**
  String get cashierPayIn;

  /// No description provided for @cashierPayOut.
  ///
  /// In en, this message translates to:
  /// **'Pay out'**
  String get cashierPayOut;

  /// No description provided for @cashierDrop.
  ///
  /// In en, this message translates to:
  /// **'Drop'**
  String get cashierDrop;

  /// No description provided for @cashierAmountField.
  ///
  /// In en, this message translates to:
  /// **'Amount ₹'**
  String get cashierAmountField;

  /// No description provided for @cashierReasonField.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get cashierReasonField;

  /// No description provided for @cashierRecordButton.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get cashierRecordButton;

  /// No description provided for @cashierCloseShiftTitle.
  ///
  /// In en, this message translates to:
  /// **'Close shift'**
  String get cashierCloseShiftTitle;

  /// No description provided for @cashierExpectedInDrawerValue.
  ///
  /// In en, this message translates to:
  /// **'Expected in drawer: {amount}'**
  String cashierExpectedInDrawerValue(Object amount);

  /// No description provided for @cashierCountedCashField.
  ///
  /// In en, this message translates to:
  /// **'Counted cash ₹'**
  String get cashierCountedCashField;

  /// No description provided for @cashierVarianceValue.
  ///
  /// In en, this message translates to:
  /// **'Variance: {amount} {status}'**
  String cashierVarianceValue(Object amount, Object status);

  /// No description provided for @cashierVarianceBalanced.
  ///
  /// In en, this message translates to:
  /// **'(balanced)'**
  String get cashierVarianceBalanced;

  /// No description provided for @cashierVarianceOver.
  ///
  /// In en, this message translates to:
  /// **'(over)'**
  String get cashierVarianceOver;

  /// No description provided for @cashierVarianceShort.
  ///
  /// In en, this message translates to:
  /// **'(short)'**
  String get cashierVarianceShort;

  /// No description provided for @cashierNoteField.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get cashierNoteField;

  /// No description provided for @cashierCloseZReportButton.
  ///
  /// In en, this message translates to:
  /// **'Close & Z-report'**
  String get cashierCloseZReportButton;

  /// No description provided for @cashierReturnsTitle.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get cashierReturnsTitle;

  /// No description provided for @cashierOriginalInvoiceIdField.
  ///
  /// In en, this message translates to:
  /// **'Original invoice id'**
  String get cashierOriginalInvoiceIdField;

  /// No description provided for @cashierLookUpButton.
  ///
  /// In en, this message translates to:
  /// **'Look up'**
  String get cashierLookUpButton;

  /// No description provided for @cashierReturnableLine.
  ///
  /// In en, this message translates to:
  /// **'returnable {qty} · {price}'**
  String cashierReturnableLine(Object qty, Object price);

  /// No description provided for @cashierEnterQuantityError.
  ///
  /// In en, this message translates to:
  /// **'Enter a quantity to return.'**
  String get cashierEnterQuantityError;

  /// No description provided for @cashierCreditNoteCreated.
  ///
  /// In en, this message translates to:
  /// **'Credit note {no} · {amount}'**
  String cashierCreditNoteCreated(Object no, Object amount);

  /// No description provided for @cashierProcessReturnButton.
  ///
  /// In en, this message translates to:
  /// **'Process return'**
  String get cashierProcessReturnButton;

  /// No description provided for @posTitle.
  ///
  /// In en, this message translates to:
  /// **'Point of sale'**
  String get posTitle;

  /// No description provided for @posFindItem.
  ///
  /// In en, this message translates to:
  /// **'Find item'**
  String get posFindItem;

  /// No description provided for @posCashierTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cashier (shift · drawer · returns)'**
  String get posCashierTooltip;

  /// No description provided for @posHold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get posHold;

  /// No description provided for @posRecall.
  ///
  /// In en, this message translates to:
  /// **'Recall'**
  String get posRecall;

  /// No description provided for @posLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get posLogOut;

  /// No description provided for @posCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get posCashier;

  /// No description provided for @posOpenShiftToBill.
  ///
  /// In en, this message translates to:
  /// **'Open a shift to start billing'**
  String get posOpenShiftToBill;

  /// No description provided for @posOpenShift.
  ///
  /// In en, this message translates to:
  /// **'Open shift'**
  String get posOpenShift;

  /// No description provided for @posScanFirstItem.
  ///
  /// In en, this message translates to:
  /// **'Scan the first item.'**
  String get posScanFirstItem;

  /// No description provided for @posTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get posTotal;

  /// No description provided for @posBillDiscount.
  ///
  /// In en, this message translates to:
  /// **'Bill discount'**
  String get posBillDiscount;

  /// No description provided for @posCheckout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get posCheckout;

  /// No description provided for @posLineDiscount.
  ///
  /// In en, this message translates to:
  /// **'Line discount'**
  String get posLineDiscount;

  /// No description provided for @posNewItem.
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get posNewItem;

  /// No description provided for @posName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get posName;

  /// No description provided for @posSellingPrice.
  ///
  /// In en, this message translates to:
  /// **'Selling price ₹'**
  String get posSellingPrice;

  /// No description provided for @posGstPercentOptional.
  ///
  /// In en, this message translates to:
  /// **'GST % (optional)'**
  String get posGstPercentOptional;

  /// No description provided for @posOnHand.
  ///
  /// In en, this message translates to:
  /// **'On hand'**
  String get posOnHand;

  /// No description provided for @posCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get posCancel;

  /// No description provided for @posAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get posAdd;

  /// No description provided for @posSaleComplete.
  ///
  /// In en, this message translates to:
  /// **'Sale complete'**
  String get posSaleComplete;

  /// No description provided for @posInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get posInvoice;

  /// No description provided for @posPrint.
  ///
  /// In en, this message translates to:
  /// **'Print'**
  String get posPrint;

  /// No description provided for @posDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get posDone;

  /// No description provided for @posCouldNotGenerateReceipt.
  ///
  /// In en, this message translates to:
  /// **'Could not generate the receipt'**
  String get posCouldNotGenerateReceipt;

  /// No description provided for @posDiscountMax.
  ///
  /// In en, this message translates to:
  /// **'Discount ₹ (max {max})'**
  String posDiscountMax(Object max);

  /// No description provided for @posApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get posApply;

  /// No description provided for @posDiscount.
  ///
  /// In en, this message translates to:
  /// **'Discount ₹'**
  String get posDiscount;

  /// No description provided for @posCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect'**
  String get posCollect;

  /// No description provided for @posCustomerOptional.
  ///
  /// In en, this message translates to:
  /// **'Customer (optional)'**
  String get posCustomerOptional;

  /// No description provided for @posPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get posPhone;

  /// No description provided for @posCashReceived.
  ///
  /// In en, this message translates to:
  /// **'Cash received ₹'**
  String get posCashReceived;

  /// No description provided for @posChangeDue.
  ///
  /// In en, this message translates to:
  /// **'Change due'**
  String get posChangeDue;

  /// No description provided for @posCashDone.
  ///
  /// In en, this message translates to:
  /// **'Cash — done'**
  String get posCashDone;

  /// No description provided for @posOtherTenders.
  ///
  /// In en, this message translates to:
  /// **'Other tenders'**
  String get posOtherTenders;

  /// No description provided for @posOnline.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get posOnline;

  /// No description provided for @posPaymentFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Please retry.'**
  String get posPaymentFailedRetry;

  /// No description provided for @posNoHeldBills.
  ///
  /// In en, this message translates to:
  /// **'No held bills.'**
  String get posNoHeldBills;

  /// No description provided for @posHeldBills.
  ///
  /// In en, this message translates to:
  /// **'Held bills'**
  String get posHeldBills;

  /// No description provided for @posBill.
  ///
  /// In en, this message translates to:
  /// **'Bill'**
  String get posBill;

  /// No description provided for @posItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} item(s)'**
  String posItemCount(Object count);

  /// No description provided for @posQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get posQuantity;

  /// No description provided for @posSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get posSet;

  /// No description provided for @posFindItemByNameSku.
  ///
  /// In en, this message translates to:
  /// **'Find item by name / SKU'**
  String get posFindItemByNameSku;

  /// No description provided for @posSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get posSearching;

  /// No description provided for @posTypeToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type to search the catalogue.'**
  String get posTypeToSearch;

  /// No description provided for @posStock.
  ///
  /// In en, this message translates to:
  /// **'stock'**
  String get posStock;

  /// No description provided for @posAddedItem.
  ///
  /// In en, this message translates to:
  /// **'Added {name}'**
  String posAddedItem(Object name);

  /// No description provided for @posStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get posStatusLive;

  /// No description provided for @posStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get posStatusConnecting;

  /// No description provided for @posStatusReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting'**
  String get posStatusReconnecting;

  /// No description provided for @posStatusOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get posStatusOffline;

  /// No description provided for @bannersTitle.
  ///
  /// In en, this message translates to:
  /// **'Banners'**
  String get bannersTitle;

  /// No description provided for @bannersRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get bannersRefresh;

  /// No description provided for @bannersNewBanner.
  ///
  /// In en, this message translates to:
  /// **'New banner'**
  String get bannersNewBanner;

  /// No description provided for @bannersDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete banner?'**
  String get bannersDeleteTitle;

  /// No description provided for @bannersDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'This banner will be removed from {placement}.'**
  String bannersDeleteMessage(Object placement);

  /// No description provided for @bannersCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bannersCancel;

  /// No description provided for @bannersDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get bannersDelete;

  /// No description provided for @bannersEmptyPlacement.
  ///
  /// In en, this message translates to:
  /// **'No banners in this placement yet'**
  String get bannersEmptyPlacement;

  /// No description provided for @bannersStatusLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get bannersStatusLive;

  /// No description provided for @bannersStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get bannersStatusScheduled;

  /// No description provided for @bannersStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get bannersStatusExpired;

  /// No description provided for @bannersStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get bannersStatusOff;

  /// No description provided for @bannersSortOrder.
  ///
  /// In en, this message translates to:
  /// **'Sort {order}'**
  String bannersSortOrder(Object order);

  /// No description provided for @bannersProductCountOne.
  ///
  /// In en, this message translates to:
  /// **'{count} product'**
  String bannersProductCountOne(Object count);

  /// No description provided for @bannersProductCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} products'**
  String bannersProductCountOther(Object count);

  /// No description provided for @bannersWindowFrom.
  ///
  /// In en, this message translates to:
  /// **'from {date}'**
  String bannersWindowFrom(Object date);

  /// No description provided for @bannersWindowUntil.
  ///
  /// In en, this message translates to:
  /// **'until {date}'**
  String bannersWindowUntil(Object date);

  /// No description provided for @bannersImageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed'**
  String get bannersImageUploadFailed;

  /// No description provided for @bannersImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is larger than 5 MB. Pick a smaller image or crop tighter.'**
  String get bannersImageTooLarge;

  /// No description provided for @bannersImageRequired.
  ///
  /// In en, this message translates to:
  /// **'An image is required'**
  String get bannersImageRequired;

  /// No description provided for @bannersSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get bannersSaveFailed;

  /// No description provided for @bannersProductsSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Banner saved, but products failed: {error}'**
  String bannersProductsSaveFailed(Object error);

  /// No description provided for @bannersAlreadyPinned.
  ///
  /// In en, this message translates to:
  /// **'Already pinned to this banner'**
  String get bannersAlreadyPinned;

  /// No description provided for @bannersEditBanner.
  ///
  /// In en, this message translates to:
  /// **'Edit banner'**
  String get bannersEditBanner;

  /// No description provided for @bannersPlacement.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get bannersPlacement;

  /// No description provided for @bannersLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get bannersLink;

  /// No description provided for @bannersSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get bannersSort;

  /// No description provided for @bannersActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get bannersActive;

  /// No description provided for @bannersActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, hidden regardless of schedule'**
  String get bannersActiveSubtitle;

  /// No description provided for @bannersSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get bannersSaving;

  /// No description provided for @bannersSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get bannersSaveChanges;

  /// No description provided for @bannersCreateBanner.
  ///
  /// In en, this message translates to:
  /// **'Create banner'**
  String get bannersCreateBanner;

  /// No description provided for @bannersUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload image *'**
  String get bannersUploadImage;

  /// No description provided for @bannersReplaceImage.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get bannersReplaceImage;

  /// No description provided for @bannersStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get bannersStarts;

  /// No description provided for @bannersEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get bannersEnds;

  /// No description provided for @bannersProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get bannersProducts;

  /// No description provided for @bannersAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get bannersAdd;

  /// No description provided for @bannersSaveFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Save the banner first to add products.'**
  String get bannersSaveFirstHint;

  /// No description provided for @bannersAddProductsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap “Add” to pin products with an optional discount.'**
  String get bannersAddProductsHint;

  /// No description provided for @bannersNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get bannersNotSet;

  /// No description provided for @bannersSearchProduct.
  ///
  /// In en, this message translates to:
  /// **'Search product name or SKU'**
  String get bannersSearchProduct;

  /// No description provided for @bannersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Type 2+ characters to search'**
  String get bannersSearchHint;

  /// No description provided for @challansTitle.
  ///
  /// In en, this message translates to:
  /// **'Challans'**
  String get challansTitle;

  /// No description provided for @challansSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search challans...'**
  String get challansSearchHint;

  /// No description provided for @challansFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get challansFilterAll;

  /// No description provided for @challansEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No challans found'**
  String get challansEmptyTitle;

  /// No description provided for @challansEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap + to create a challan'**
  String get challansEmptySubtitle;

  /// No description provided for @challansCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Challan'**
  String get challansCreate;

  /// No description provided for @challansItemsLabel.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get challansItemsLabel;

  /// No description provided for @challansCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Challan'**
  String get challansCancel;

  /// No description provided for @challansCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel this challan? This cannot be undone.'**
  String get challansCancelConfirm;

  /// No description provided for @challansYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get challansYes;

  /// No description provided for @challansNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get challansNo;

  /// No description provided for @challansError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get challansError;

  /// No description provided for @challansPartyName.
  ///
  /// In en, this message translates to:
  /// **'Party Name'**
  String get challansPartyName;

  /// No description provided for @challansPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get challansPhone;

  /// No description provided for @challansNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get challansNote;

  /// No description provided for @challansLinkedInvoice.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get challansLinkedInvoice;

  /// No description provided for @challansItemsHeader.
  ///
  /// In en, this message translates to:
  /// **'Challan Items'**
  String get challansItemsHeader;

  /// No description provided for @challansEmptyItems.
  ///
  /// In en, this message translates to:
  /// **'No items added yet'**
  String get challansEmptyItems;

  /// No description provided for @challansConvertToInvoice.
  ///
  /// In en, this message translates to:
  /// **'Convert to Invoice'**
  String get challansConvertToInvoice;

  /// No description provided for @challansAddAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Add at least one product'**
  String get challansAddAtLeastOne;

  /// No description provided for @challansDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get challansDiscardTitle;

  /// No description provided for @challansDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Your edits will be lost.'**
  String get challansDiscardMessage;

  /// No description provided for @challansKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get challansKeepEditing;

  /// No description provided for @challansDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get challansDiscard;

  /// No description provided for @challansSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get challansSubmit;

  /// No description provided for @challansPartyInfo.
  ///
  /// In en, this message translates to:
  /// **'Party Info'**
  String get challansPartyInfo;

  /// No description provided for @challansSelectParty.
  ///
  /// In en, this message translates to:
  /// **'Select party'**
  String get challansSelectParty;

  /// No description provided for @challansFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get challansFieldRequired;

  /// No description provided for @challansAddProducts.
  ///
  /// In en, this message translates to:
  /// **'Add Products'**
  String get challansAddProducts;

  /// No description provided for @challansNoPricesHint.
  ///
  /// In en, this message translates to:
  /// **'Prices are not visible to the party'**
  String get challansNoPricesHint;

  /// No description provided for @challansSearchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get challansSearchProducts;

  /// No description provided for @challansChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get challansChange;

  /// No description provided for @returnsTitle.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get returnsTitle;

  /// No description provided for @returnsTabOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get returnsTabOpen;

  /// No description provided for @returnsTabApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get returnsTabApproved;

  /// No description provided for @returnsTabReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get returnsTabReceived;

  /// No description provided for @returnsTabRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get returnsTabRefunded;

  /// No description provided for @returnsTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get returnsTabAll;

  /// No description provided for @returnsRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Return #{id} · {name}'**
  String returnsRowTitle(Object id, Object name);

  /// No description provided for @returnsItemCountOne.
  ///
  /// In en, this message translates to:
  /// **'1 item'**
  String get returnsItemCountOne;

  /// No description provided for @returnsItemCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String returnsItemCountOther(Object count);

  /// No description provided for @returnsRefundLabel.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get returnsRefundLabel;

  /// No description provided for @returnsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No returns in this view yet.'**
  String get returnsEmpty;

  /// No description provided for @returnsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get returnsRetry;

  /// No description provided for @returnsStatusRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get returnsStatusRequested;

  /// No description provided for @returnsStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get returnsStatusApproved;

  /// No description provided for @returnsStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get returnsStatusRejected;

  /// No description provided for @returnsStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get returnsStatusCancelled;

  /// No description provided for @returnsStatusPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Picked up'**
  String get returnsStatusPickedUp;

  /// No description provided for @returnsStatusReceived.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get returnsStatusReceived;

  /// No description provided for @returnsStatusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get returnsStatusRefunded;

  /// No description provided for @returnsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Return #{id}'**
  String returnsDetailTitle(Object id);

  /// No description provided for @returnsNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get returnsNoteOptional;

  /// No description provided for @returnsNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Note required'**
  String get returnsNoteRequired;

  /// No description provided for @returnsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get returnsCancel;

  /// No description provided for @returnsBuyerNote.
  ///
  /// In en, this message translates to:
  /// **'Buyer note'**
  String get returnsBuyerNote;

  /// No description provided for @returnsYourNote.
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get returnsYourNote;

  /// No description provided for @returnsRefundedToOriginal.
  ///
  /// In en, this message translates to:
  /// **'Refunded {amount} to {name}\'s original payment method'**
  String returnsRefundedToOriginal(Object amount, Object name);

  /// No description provided for @returnsApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve return'**
  String get returnsApproveTitle;

  /// No description provided for @returnsApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get returnsApprove;

  /// No description provided for @returnsApproveHint.
  ///
  /// In en, this message translates to:
  /// **'Pickup instructions for the buyer (optional)'**
  String get returnsApproveHint;

  /// No description provided for @returnsApprovedToast.
  ///
  /// In en, this message translates to:
  /// **'Return approved'**
  String get returnsApprovedToast;

  /// No description provided for @returnsRejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject return'**
  String get returnsRejectTitle;

  /// No description provided for @returnsReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get returnsReject;

  /// No description provided for @returnsRejectHint.
  ///
  /// In en, this message translates to:
  /// **'Why? Shown to the buyer'**
  String get returnsRejectHint;

  /// No description provided for @returnsRejectedToast.
  ///
  /// In en, this message translates to:
  /// **'Return rejected'**
  String get returnsRejectedToast;

  /// No description provided for @returnsPickedUpToast.
  ///
  /// In en, this message translates to:
  /// **'Marked as picked up'**
  String get returnsPickedUpToast;

  /// No description provided for @returnsReceivedToast.
  ///
  /// In en, this message translates to:
  /// **'Marked as received'**
  String get returnsReceivedToast;

  /// No description provided for @returnsRefundConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Refund {amount}?'**
  String returnsRefundConfirmTitle(Object amount);

  /// No description provided for @returnsRefundConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This refunds the buyer to their original payment method. The action can\'t be undone.'**
  String get returnsRefundConfirmBody;

  /// No description provided for @returnsRefund.
  ///
  /// In en, this message translates to:
  /// **'Refund'**
  String get returnsRefund;

  /// No description provided for @returnsRefundIssuedToast.
  ///
  /// In en, this message translates to:
  /// **'Refund issued to original payment method'**
  String get returnsRefundIssuedToast;

  /// No description provided for @returnsOrderSlice.
  ///
  /// In en, this message translates to:
  /// **'Order #{orderId} · Slice #{sliceId}'**
  String returnsOrderSlice(Object orderId, Object sliceId);

  /// No description provided for @returnsRefundPreview.
  ///
  /// In en, this message translates to:
  /// **'Refund preview: '**
  String get returnsRefundPreview;

  /// No description provided for @returnsItems.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get returnsItems;

  /// No description provided for @returnsReasonDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged on arrival'**
  String get returnsReasonDamaged;

  /// No description provided for @returnsReasonWrongItem.
  ///
  /// In en, this message translates to:
  /// **'Wrong item sent'**
  String get returnsReasonWrongItem;

  /// No description provided for @returnsReasonNotAsDescribed.
  ///
  /// In en, this message translates to:
  /// **'Not as described'**
  String get returnsReasonNotAsDescribed;

  /// No description provided for @returnsReasonSizeFit.
  ///
  /// In en, this message translates to:
  /// **'Size / fit issue'**
  String get returnsReasonSizeFit;

  /// No description provided for @returnsReasonChangedMind.
  ///
  /// In en, this message translates to:
  /// **'Buyer changed mind'**
  String get returnsReasonChangedMind;

  /// No description provided for @returnsReasonDefective.
  ///
  /// In en, this message translates to:
  /// **'Defective / not working'**
  String get returnsReasonDefective;

  /// No description provided for @returnsReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get returnsReasonOther;

  /// No description provided for @returnsTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get returnsTimeline;

  /// No description provided for @returnsMarkPickedUp.
  ///
  /// In en, this message translates to:
  /// **'Mark as picked up'**
  String get returnsMarkPickedUp;

  /// No description provided for @returnsMarkReceived.
  ///
  /// In en, this message translates to:
  /// **'Mark as received'**
  String get returnsMarkReceived;

  /// No description provided for @adminActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get adminActive;

  /// No description provided for @adminCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get adminCancel;

  /// No description provided for @adminDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get adminDelete;

  /// No description provided for @adminDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get adminDeactivate;

  /// No description provided for @adminCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get adminCreate;

  /// No description provided for @adminSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get adminSave;

  /// No description provided for @adminSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get adminSaving;

  /// No description provided for @adminSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get adminSaveChanges;

  /// No description provided for @adminSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get adminSaveFailed;

  /// No description provided for @adminRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get adminRefresh;

  /// No description provided for @adminRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get adminRetry;

  /// No description provided for @adminNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get adminNotSet;

  /// No description provided for @adminPublished.
  ///
  /// In en, this message translates to:
  /// **'Published'**
  String get adminPublished;

  /// No description provided for @adminDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get adminDraft;

  /// No description provided for @adminSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get adminSortLabel;

  /// No description provided for @adminImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is larger than 5 MB. Pick a smaller image or crop tighter.'**
  String get adminImageTooLarge;

  /// No description provided for @adminImageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Image upload failed'**
  String get adminImageUploadFailed;

  /// No description provided for @adminReplaceImage.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get adminReplaceImage;

  /// No description provided for @adminLinkTargetHelper.
  ///
  /// In en, this message translates to:
  /// **'category:slug | product:id | url:https://…'**
  String get adminLinkTargetHelper;

  /// No description provided for @adminBankOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'Bank offers'**
  String get adminBankOffersTitle;

  /// No description provided for @adminBankOfferNew.
  ///
  /// In en, this message translates to:
  /// **'New offer'**
  String get adminBankOfferNew;

  /// No description provided for @adminBankOffersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bank offers yet. Tap \"New offer\" to curate the first one.'**
  String get adminBankOffersEmpty;

  /// No description provided for @adminBankOfferDeactivateTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate offer?'**
  String get adminBankOfferDeactivateTitle;

  /// No description provided for @adminBankOfferDeactivateBody.
  ///
  /// In en, this message translates to:
  /// **'Customers won\'t see this offer on any PDP. You can re-activate it later from this page.'**
  String get adminBankOfferDeactivateBody;

  /// No description provided for @adminBankOfferPercentOff.
  ///
  /// In en, this message translates to:
  /// **'{value}% off'**
  String adminBankOfferPercentOff(Object value);

  /// No description provided for @adminBankOfferAmountOff.
  ///
  /// In en, this message translates to:
  /// **'{value} off'**
  String adminBankOfferAmountOff(Object value);

  /// No description provided for @adminBankOfferMinOrder.
  ///
  /// In en, this message translates to:
  /// **'min order {value}'**
  String adminBankOfferMinOrder(Object value);

  /// No description provided for @adminBankOfferCap.
  ///
  /// In en, this message translates to:
  /// **'cap {value}'**
  String adminBankOfferCap(Object value);

  /// No description provided for @adminBankOfferValidRange.
  ///
  /// In en, this message translates to:
  /// **'Valid {from} – {until}'**
  String adminBankOfferValidRange(Object from, Object until);

  /// No description provided for @adminBankOfferEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit bank offer'**
  String get adminBankOfferEditTitle;

  /// No description provided for @adminBankOfferNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New bank offer'**
  String get adminBankOfferNewTitle;

  /// No description provided for @adminBankOfferBankLabel.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get adminBankOfferBankLabel;

  /// No description provided for @adminBankOfferCardTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Card type'**
  String get adminBankOfferCardTypeLabel;

  /// No description provided for @adminBankOfferTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get adminBankOfferTypeLabel;

  /// No description provided for @adminBankOfferTypePercent.
  ///
  /// In en, this message translates to:
  /// **'Percent off'**
  String get adminBankOfferTypePercent;

  /// No description provided for @adminBankOfferTypeFlat.
  ///
  /// In en, this message translates to:
  /// **'Flat ₹ off'**
  String get adminBankOfferTypeFlat;

  /// No description provided for @adminBankOfferPercentField.
  ///
  /// In en, this message translates to:
  /// **'% off'**
  String get adminBankOfferPercentField;

  /// No description provided for @adminBankOfferAmountField.
  ///
  /// In en, this message translates to:
  /// **'₹ off'**
  String get adminBankOfferAmountField;

  /// No description provided for @adminBankOfferMaxDiscountLabel.
  ///
  /// In en, this message translates to:
  /// **'Max discount (₹) — caps the % off'**
  String get adminBankOfferMaxDiscountLabel;

  /// No description provided for @adminBankOfferMinOrderLabel.
  ///
  /// In en, this message translates to:
  /// **'Minimum order (₹) — eligibility filter'**
  String get adminBankOfferMinOrderLabel;

  /// No description provided for @adminBankOfferTermsLabel.
  ///
  /// In en, this message translates to:
  /// **'Terms (optional)'**
  String get adminBankOfferTermsLabel;

  /// No description provided for @adminBankOfferTermsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Not valid on no-cost EMI. Excludes Apple products.'**
  String get adminBankOfferTermsHint;

  /// No description provided for @adminBankOfferFrom.
  ///
  /// In en, this message translates to:
  /// **'From  {date}'**
  String adminBankOfferFrom(Object date);

  /// No description provided for @adminBankOfferUntil.
  ///
  /// In en, this message translates to:
  /// **'Until {date}'**
  String adminBankOfferUntil(Object date);

  /// No description provided for @adminBankOfferActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, the offer never decorates a PDP. Use this to park a draft or expire an offer early without deleting it.'**
  String get adminBankOfferActiveSubtitle;

  /// No description provided for @adminBankOfferPdpPreview.
  ///
  /// In en, this message translates to:
  /// **'PDP preview'**
  String get adminBankOfferPdpPreview;

  /// No description provided for @adminBankOfferPreviewCap.
  ///
  /// In en, this message translates to:
  /// **' up to ₹{value}'**
  String adminBankOfferPreviewCap(Object value);

  /// No description provided for @adminBankOfferPreviewPercent.
  ///
  /// In en, this message translates to:
  /// **'{discount}% off{cap} on {target}'**
  String adminBankOfferPreviewPercent(
    Object discount,
    Object cap,
    Object target,
  );

  /// No description provided for @adminBankOfferPreviewFlat.
  ///
  /// In en, this message translates to:
  /// **'₹{discount} off on {target}'**
  String adminBankOfferPreviewFlat(Object discount, Object target);

  /// No description provided for @adminBankOfferCreate.
  ///
  /// In en, this message translates to:
  /// **'Create offer'**
  String get adminBankOfferCreate;

  /// No description provided for @adminBannersTitle.
  ///
  /// In en, this message translates to:
  /// **'Banner manager'**
  String get adminBannersTitle;

  /// No description provided for @adminBannerNew.
  ///
  /// In en, this message translates to:
  /// **'New banner'**
  String get adminBannerNew;

  /// No description provided for @adminBannerDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete banner?'**
  String get adminBannerDeleteTitle;

  /// No description provided for @adminBannerDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This banner will be removed from {placement}.'**
  String adminBannerDeleteBody(Object placement);

  /// No description provided for @adminBannerPlacementEmpty.
  ///
  /// In en, this message translates to:
  /// **'No banners in this placement yet'**
  String get adminBannerPlacementEmpty;

  /// No description provided for @adminBannerSort.
  ///
  /// In en, this message translates to:
  /// **'Sort {value}'**
  String adminBannerSort(Object value);

  /// No description provided for @adminBannerEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit banner'**
  String get adminBannerEditTitle;

  /// No description provided for @adminBannerNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New banner'**
  String get adminBannerNewTitle;

  /// No description provided for @adminBannerImageRequired.
  ///
  /// In en, this message translates to:
  /// **'An image is required'**
  String get adminBannerImageRequired;

  /// No description provided for @adminBannerPlacementLabel.
  ///
  /// In en, this message translates to:
  /// **'Placement'**
  String get adminBannerPlacementLabel;

  /// No description provided for @adminBannerLinkLabel.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get adminBannerLinkLabel;

  /// No description provided for @adminBannerActiveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, hidden regardless of schedule'**
  String get adminBannerActiveSubtitle;

  /// No description provided for @adminBannerCreate.
  ///
  /// In en, this message translates to:
  /// **'Create banner'**
  String get adminBannerCreate;

  /// No description provided for @adminBannerUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload image *'**
  String get adminBannerUploadImage;

  /// No description provided for @adminBannerStarts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get adminBannerStarts;

  /// No description provided for @adminBannerEnds.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get adminBannerEnds;

  /// No description provided for @adminCategoryTaxonomyTitle.
  ///
  /// In en, this message translates to:
  /// **'Category taxonomy'**
  String get adminCategoryTaxonomyTitle;

  /// No description provided for @adminCategoryRoot.
  ///
  /// In en, this message translates to:
  /// **'Root category'**
  String get adminCategoryRoot;

  /// No description provided for @adminCategoryDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String adminCategoryDeleteTitle(Object name);

  /// No description provided for @adminCategoryDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Children re-parent to root. Products in this category fall back to \"uncategorised\" (the link goes null).'**
  String get adminCategoryDeleteBody;

  /// No description provided for @adminCategoryProductCount.
  ///
  /// In en, this message translates to:
  /// **'{value} products'**
  String adminCategoryProductCount(Object value);

  /// No description provided for @adminCategoryAddChild.
  ///
  /// In en, this message translates to:
  /// **'Add child'**
  String get adminCategoryAddChild;

  /// No description provided for @adminCategoryNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get adminCategoryNameRequired;

  /// No description provided for @adminCategoryEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit category'**
  String get adminCategoryEditTitle;

  /// No description provided for @adminCategoryNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get adminCategoryNewTitle;

  /// No description provided for @adminCategoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get adminCategoryNameLabel;

  /// No description provided for @adminCategoryNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Slug auto-derives from this.'**
  String get adminCategoryNameHelper;

  /// No description provided for @adminCategoryDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get adminCategoryDescriptionLabel;

  /// No description provided for @adminCategoryImageUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Image URL'**
  String get adminCategoryImageUrlLabel;

  /// No description provided for @adminCategoryImageUrlHelper.
  ///
  /// In en, this message translates to:
  /// **'Customer-side circle puck image.'**
  String get adminCategoryImageUrlHelper;

  /// No description provided for @adminCategoryParentLabel.
  ///
  /// In en, this message translates to:
  /// **'Parent'**
  String get adminCategoryParentLabel;

  /// No description provided for @adminCategoryRootOption.
  ///
  /// In en, this message translates to:
  /// **'— Root —'**
  String get adminCategoryRootOption;

  /// No description provided for @adminCollectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get adminCollectionsTitle;

  /// No description provided for @adminCollectionNew.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get adminCollectionNew;

  /// No description provided for @adminCollectionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No collections yet'**
  String get adminCollectionsEmpty;

  /// No description provided for @adminCollectionDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete collection?'**
  String get adminCollectionDeleteTitle;

  /// No description provided for @adminCollectionDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" and its item list will be removed.'**
  String adminCollectionDeleteBody(Object title);

  /// No description provided for @adminCollectionItemCountOne.
  ///
  /// In en, this message translates to:
  /// **'{value} item'**
  String adminCollectionItemCountOne(Object value);

  /// No description provided for @adminCollectionItemCountOther.
  ///
  /// In en, this message translates to:
  /// **'{value} items'**
  String adminCollectionItemCountOther(Object value);

  /// No description provided for @adminCollectionEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit collection'**
  String get adminCollectionEditTitle;

  /// No description provided for @adminCollectionNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New collection'**
  String get adminCollectionNewTitle;

  /// No description provided for @adminCollectionAddProduct.
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get adminCollectionAddProduct;

  /// No description provided for @adminCollectionTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get adminCollectionTitleRequired;

  /// No description provided for @adminCollectionAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already in this collection'**
  String get adminCollectionAlreadyAdded;

  /// No description provided for @adminCollectionTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get adminCollectionTitleLabel;

  /// No description provided for @adminCollectionSlugLabel.
  ///
  /// In en, this message translates to:
  /// **'Slug'**
  String get adminCollectionSlugLabel;

  /// No description provided for @adminCollectionSlugHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to auto-derive from title'**
  String get adminCollectionSlugHelper;

  /// No description provided for @adminCollectionEyebrowLabel.
  ///
  /// In en, this message translates to:
  /// **'Eyebrow'**
  String get adminCollectionEyebrowLabel;

  /// No description provided for @adminCollectionEyebrowHelper.
  ///
  /// In en, this message translates to:
  /// **'Tiny copy above title'**
  String get adminCollectionEyebrowHelper;

  /// No description provided for @adminCollectionSubtitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtitle'**
  String get adminCollectionSubtitleLabel;

  /// No description provided for @adminCollectionCtaTextLabel.
  ///
  /// In en, this message translates to:
  /// **'CTA text'**
  String get adminCollectionCtaTextLabel;

  /// No description provided for @adminCollectionCtaTargetLabel.
  ///
  /// In en, this message translates to:
  /// **'CTA target'**
  String get adminCollectionCtaTargetLabel;

  /// No description provided for @adminCollectionBgColorLabel.
  ///
  /// In en, this message translates to:
  /// **'BG color (#hex)'**
  String get adminCollectionBgColorLabel;

  /// No description provided for @adminCollectionBgColorHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional — accent surface in rails'**
  String get adminCollectionBgColorHelper;

  /// No description provided for @adminCollectionPublishedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Visible to shoppers on the customer app'**
  String get adminCollectionPublishedSubtitle;

  /// No description provided for @adminCollectionItemsSection.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get adminCollectionItemsSection;

  /// No description provided for @adminCollectionItemsHintNew.
  ///
  /// In en, this message translates to:
  /// **'Save the collection first, then add products from the + button.'**
  String get adminCollectionItemsHintNew;

  /// No description provided for @adminCollectionItemsHintEmpty.
  ///
  /// In en, this message translates to:
  /// **'Tap + in the app bar to add products.'**
  String get adminCollectionItemsHintEmpty;

  /// No description provided for @adminCollectionCoverImage.
  ///
  /// In en, this message translates to:
  /// **'Cover image'**
  String get adminCollectionCoverImage;

  /// No description provided for @adminCollectionReplaceCover.
  ///
  /// In en, this message translates to:
  /// **'Replace cover'**
  String get adminCollectionReplaceCover;

  /// No description provided for @adminCollectionProductSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search product name or SKU'**
  String get adminCollectionProductSearchLabel;

  /// No description provided for @adminCollectionProductSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Type 2+ characters to search'**
  String get adminCollectionProductSearchHint;

  /// No description provided for @adminShopsTitle.
  ///
  /// In en, this message translates to:
  /// **'Shop verification'**
  String get adminShopsTitle;

  /// No description provided for @adminShopsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by shop name or slug'**
  String get adminShopsSearchHint;

  /// No description provided for @adminShopVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get adminShopVerified;

  /// No description provided for @adminShopDraft.
  ///
  /// In en, this message translates to:
  /// **'draft'**
  String get adminShopDraft;

  /// No description provided for @adminShopsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No shops found.'**
  String get adminShopsEmpty;

  /// No description provided for @analyticsTitle.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get analyticsRefresh;

  /// No description provided for @analyticsByProduct.
  ///
  /// In en, this message translates to:
  /// **'By product'**
  String get analyticsByProduct;

  /// No description provided for @analyticsNoActiveProducts.
  ///
  /// In en, this message translates to:
  /// **'No active products yet'**
  String get analyticsNoActiveProducts;

  /// No description provided for @analyticsKpiImpressions.
  ///
  /// In en, this message translates to:
  /// **'Impressions'**
  String get analyticsKpiImpressions;

  /// No description provided for @analyticsKpiTaps.
  ///
  /// In en, this message translates to:
  /// **'Taps'**
  String get analyticsKpiTaps;

  /// No description provided for @analyticsKpiViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get analyticsKpiViews;

  /// No description provided for @analyticsKpiAddToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to cart'**
  String get analyticsKpiAddToCart;

  /// No description provided for @analyticsKpiPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get analyticsKpiPurchases;

  /// No description provided for @analyticsKpiWishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get analyticsKpiWishlist;

  /// No description provided for @analyticsKpiCtr.
  ///
  /// In en, this message translates to:
  /// **'CTR'**
  String get analyticsKpiCtr;

  /// No description provided for @analyticsKpiCvr.
  ///
  /// In en, this message translates to:
  /// **'CVR'**
  String get analyticsKpiCvr;

  /// No description provided for @analyticsColProduct.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get analyticsColProduct;

  /// No description provided for @analyticsColImpressions.
  ///
  /// In en, this message translates to:
  /// **'Imp'**
  String get analyticsColImpressions;

  /// No description provided for @analyticsColTaps.
  ///
  /// In en, this message translates to:
  /// **'Taps'**
  String get analyticsColTaps;

  /// No description provided for @analyticsColViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get analyticsColViews;

  /// No description provided for @analyticsColAddToCart.
  ///
  /// In en, this message translates to:
  /// **'ATC'**
  String get analyticsColAddToCart;

  /// No description provided for @analyticsColPurchases.
  ///
  /// In en, this message translates to:
  /// **'Buys'**
  String get analyticsColPurchases;

  /// No description provided for @analyticsColCtr.
  ///
  /// In en, this message translates to:
  /// **'CTR'**
  String get analyticsColCtr;

  /// No description provided for @analyticsColCvr.
  ///
  /// In en, this message translates to:
  /// **'CVR'**
  String get analyticsColCvr;

  /// No description provided for @customFieldsTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom Fields'**
  String get customFieldsTitle;

  /// No description provided for @customFieldsTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get customFieldsTemplates;

  /// No description provided for @customFieldsAddField.
  ///
  /// In en, this message translates to:
  /// **'Add field'**
  String get customFieldsAddField;

  /// No description provided for @customFieldsAddSection.
  ///
  /// In en, this message translates to:
  /// **'Add section'**
  String get customFieldsAddSection;

  /// No description provided for @customFieldsEditField.
  ///
  /// In en, this message translates to:
  /// **'Edit field'**
  String get customFieldsEditField;

  /// No description provided for @customFieldsEditSection.
  ///
  /// In en, this message translates to:
  /// **'Edit section'**
  String get customFieldsEditSection;

  /// No description provided for @customFieldsArchive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get customFieldsArchive;

  /// No description provided for @customFieldsArchiveSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive \"{name}\"?'**
  String customFieldsArchiveSectionTitle(Object name);

  /// No description provided for @customFieldsArchiveSectionMessage.
  ///
  /// In en, this message translates to:
  /// **'Archiving hides the section. Its fields stay where they are and can be reassigned later.'**
  String get customFieldsArchiveSectionMessage;

  /// No description provided for @customFieldsArchiveFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Archive \"{name}\"?'**
  String customFieldsArchiveFieldTitle(Object name);

  /// No description provided for @customFieldsArchiveFieldConfirm.
  ///
  /// In en, this message translates to:
  /// **'Archive this field? Existing values stay on each product, but the field stops appearing on new ones.'**
  String get customFieldsArchiveFieldConfirm;

  /// No description provided for @customFieldsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No custom fields yet'**
  String get customFieldsEmptyTitle;

  /// No description provided for @customFieldsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Define fields like Warranty, Model Number, Material — visible on every product.'**
  String get customFieldsEmptyHint;

  /// No description provided for @customFieldsBrowseTemplates.
  ///
  /// In en, this message translates to:
  /// **'Browse templates'**
  String get customFieldsBrowseTemplates;

  /// No description provided for @customFieldsTemplatesCalloutTitle.
  ///
  /// In en, this message translates to:
  /// **'Stamp a quick-start template'**
  String get customFieldsTemplatesCalloutTitle;

  /// No description provided for @customFieldsTemplatesCalloutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Electronics, Apparel, Logistics, Food, Warranty…'**
  String get customFieldsTemplatesCalloutSubtitle;

  /// No description provided for @customFieldsFieldCountOne.
  ///
  /// In en, this message translates to:
  /// **'{count} field'**
  String customFieldsFieldCountOne(Object count);

  /// No description provided for @customFieldsFieldCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} fields'**
  String customFieldsFieldCountOther(Object count);

  /// No description provided for @customFieldsNoSection.
  ///
  /// In en, this message translates to:
  /// **'No section'**
  String get customFieldsNoSection;

  /// No description provided for @customFieldsUngroupedCountOne.
  ///
  /// In en, this message translates to:
  /// **'{count} ungrouped field'**
  String customFieldsUngroupedCountOne(Object count);

  /// No description provided for @customFieldsUngroupedCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} ungrouped fields'**
  String customFieldsUngroupedCountOther(Object count);

  /// No description provided for @customFieldsUnitInline.
  ///
  /// In en, this message translates to:
  /// **'in {unit}'**
  String customFieldsUnitInline(Object unit);

  /// No description provided for @customFieldsOptionCountOne.
  ///
  /// In en, this message translates to:
  /// **'{count} option'**
  String customFieldsOptionCountOne(Object count);

  /// No description provided for @customFieldsOptionCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} options'**
  String customFieldsOptionCountOther(Object count);

  /// No description provided for @customFieldsSectionName.
  ///
  /// In en, this message translates to:
  /// **'Section name'**
  String get customFieldsSectionName;

  /// No description provided for @customFieldsFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get customFieldsFieldRequired;

  /// No description provided for @customFieldsPickIcon.
  ///
  /// In en, this message translates to:
  /// **'Pick an icon'**
  String get customFieldsPickIcon;

  /// No description provided for @customFieldsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get customFieldsLoading;

  /// No description provided for @customFieldsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get customFieldsSave;

  /// No description provided for @customFieldsDropdownMinOptions.
  ///
  /// In en, this message translates to:
  /// **'Add at least two options for a dropdown.'**
  String get customFieldsDropdownMinOptions;

  /// No description provided for @customFieldsFieldName.
  ///
  /// In en, this message translates to:
  /// **'Field name'**
  String get customFieldsFieldName;

  /// No description provided for @customFieldsFieldType.
  ///
  /// In en, this message translates to:
  /// **'Field type'**
  String get customFieldsFieldType;

  /// No description provided for @customFieldsSectionOptional.
  ///
  /// In en, this message translates to:
  /// **'Section (optional)'**
  String get customFieldsSectionOptional;

  /// No description provided for @customFieldsUnitSuffix.
  ///
  /// In en, this message translates to:
  /// **'Unit (optional)'**
  String get customFieldsUnitSuffix;

  /// No description provided for @customFieldsUnitSuffixHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. kg, days, GB'**
  String get customFieldsUnitSuffixHint;

  /// No description provided for @customFieldsOptions.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get customFieldsOptions;

  /// No description provided for @customFieldsOptionsHint.
  ///
  /// In en, this message translates to:
  /// **'One per line. Used for dropdown choices.'**
  String get customFieldsOptionsHint;

  /// No description provided for @customFieldsTemplateApplied.
  ///
  /// In en, this message translates to:
  /// **'Template applied'**
  String get customFieldsTemplateApplied;

  /// No description provided for @customFieldsQuickStartTemplates.
  ///
  /// In en, this message translates to:
  /// **'Quick-start templates'**
  String get customFieldsQuickStartTemplates;

  /// No description provided for @customFieldsTemplatesSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap any template to add its section and fields to your shop.'**
  String get customFieldsTemplatesSheetSubtitle;

  /// No description provided for @customFieldsTemplatesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Templates unavailable. Check your connection and try again.'**
  String get customFieldsTemplatesUnavailable;

  /// No description provided for @customFieldsTemplateFieldCount.
  ///
  /// In en, this message translates to:
  /// **'{count} fields'**
  String customFieldsTemplateFieldCount(Object count);

  /// No description provided for @customFieldsPickDate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get customFieldsPickDate;

  /// No description provided for @paymentsCounterpartyParty.
  ///
  /// In en, this message translates to:
  /// **'party'**
  String get paymentsCounterpartyParty;

  /// No description provided for @paymentsCounterpartyVendor.
  ///
  /// In en, this message translates to:
  /// **'vendor'**
  String get paymentsCounterpartyVendor;

  /// No description provided for @paymentsRecordReceiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Record receipt'**
  String get paymentsRecordReceiptTitle;

  /// No description provided for @paymentsRecordPaymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get paymentsRecordPaymentTitle;

  /// No description provided for @paymentsFromCounterparty.
  ///
  /// In en, this message translates to:
  /// **'From {name}'**
  String paymentsFromCounterparty(Object name);

  /// No description provided for @paymentsToCounterparty.
  ///
  /// In en, this message translates to:
  /// **'To {name}'**
  String paymentsToCounterparty(Object name);

  /// No description provided for @paymentsAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get paymentsAmountLabel;

  /// No description provided for @paymentsAmountPositiveError.
  ///
  /// In en, this message translates to:
  /// **'Enter a positive amount'**
  String get paymentsAmountPositiveError;

  /// No description provided for @paymentsModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get paymentsModeLabel;

  /// No description provided for @paymentsUpiTransactionIdLabel.
  ///
  /// In en, this message translates to:
  /// **'UPI transaction id'**
  String get paymentsUpiTransactionIdLabel;

  /// No description provided for @paymentsChequeNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Cheque number'**
  String get paymentsChequeNumberLabel;

  /// No description provided for @paymentsReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get paymentsReferenceLabel;

  /// No description provided for @paymentsDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get paymentsDateLabel;

  /// No description provided for @paymentsAllocatedToLabel.
  ///
  /// In en, this message translates to:
  /// **'Allocated to'**
  String get paymentsAllocatedToLabel;

  /// No description provided for @paymentsInvoiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Invoice'**
  String get paymentsInvoiceLabel;

  /// No description provided for @paymentsAllocateToInvoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Allocate to an invoice'**
  String get paymentsAllocateToInvoiceTitle;

  /// No description provided for @paymentsAllocateToInvoiceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Off = on-account credit'**
  String get paymentsAllocateToInvoiceSubtitle;

  /// No description provided for @paymentsNoInvoicesFound.
  ///
  /// In en, this message translates to:
  /// **'No invoices found for this {name}.'**
  String paymentsNoInvoicesFound(Object name);

  /// No description provided for @paymentsPickInvoiceError.
  ///
  /// In en, this message translates to:
  /// **'Pick an invoice'**
  String get paymentsPickInvoiceError;

  /// No description provided for @paymentsNoteOptionalLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get paymentsNoteOptionalLabel;

  /// No description provided for @paymentsSaveReceipt.
  ///
  /// In en, this message translates to:
  /// **'Save receipt'**
  String get paymentsSaveReceipt;

  /// No description provided for @paymentsSavePayment.
  ///
  /// In en, this message translates to:
  /// **'Save payment'**
  String get paymentsSavePayment;

  /// No description provided for @reviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reviews · {name}'**
  String reviewsTitle(Object name);

  /// No description provided for @reviewsLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get reviewsLoadMore;

  /// No description provided for @reviewsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet — they\'ll show up here once buyers leave one.'**
  String get reviewsEmpty;

  /// No description provided for @reviewsNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get reviewsNoneYet;

  /// No description provided for @reviewsCountSingular.
  ///
  /// In en, this message translates to:
  /// **'1 review'**
  String get reviewsCountSingular;

  /// No description provided for @reviewsCountPlural.
  ///
  /// In en, this message translates to:
  /// **'{count} reviews'**
  String reviewsCountPlural(Object count);

  /// No description provided for @reviewsCustomerFallback.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get reviewsCustomerFallback;

  /// No description provided for @scanConsoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan to console'**
  String get scanConsoleTitle;

  /// No description provided for @scanConsoleClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get scanConsoleClear;

  /// No description provided for @scanConsoleClearFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not clear: {error}'**
  String scanConsoleClearFailed(Object error);

  /// No description provided for @scanConsoleEmpty.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at a product barcode or QR.'**
  String get scanConsoleEmpty;

  /// No description provided for @scanConsoleConnected.
  ///
  /// In en, this message translates to:
  /// **'Connection established'**
  String get scanConsoleConnected;

  /// No description provided for @scanConsoleWatching.
  ///
  /// In en, this message translates to:
  /// **'{count} consoles watching · {sent} sent'**
  String scanConsoleWatching(Object count, Object sent);

  /// No description provided for @scanConsoleOpenWebHint.
  ///
  /// In en, this message translates to:
  /// **'Open the Scan console on the web to see scans live'**
  String get scanConsoleOpenWebHint;

  /// No description provided for @scanConsoleConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get scanConsoleConnecting;

  /// No description provided for @scanConsoleReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get scanConsoleReconnecting;

  /// No description provided for @scanConsoleNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get scanConsoleNotConnected;

  /// No description provided for @stockLedgerTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock Ledger'**
  String get stockLedgerTitle;

  /// No description provided for @stockLedgerEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'No movements recorded for this product yet.'**
  String get stockLedgerEmptySubtitle;

  /// No description provided for @stockLedgerReversalBadge.
  ///
  /// In en, this message translates to:
  /// **'Reversal'**
  String get stockLedgerReversalBadge;

  /// No description provided for @stockLedgerByName.
  ///
  /// In en, this message translates to:
  /// **'by {name}'**
  String stockLedgerByName(Object name);

  /// No description provided for @stockLedgerBalance.
  ///
  /// In en, this message translates to:
  /// **'Bal: {qty}'**
  String stockLedgerBalance(Object qty);

  /// No description provided for @stockLedgerViewSource.
  ///
  /// In en, this message translates to:
  /// **'View source'**
  String get stockLedgerViewSource;

  /// No description provided for @stockSheetDraftCreated.
  ///
  /// In en, this message translates to:
  /// **'Draft invoice created — confirm it from the Invoices tab to post stock.'**
  String get stockSheetDraftCreated;

  /// No description provided for @stockSheetCurrentStock.
  ///
  /// In en, this message translates to:
  /// **'Current stock: {qty} {unit}'**
  String stockSheetCurrentStock(Object qty, Object unit);

  /// No description provided for @stockSheetPurchase.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get stockSheetPurchase;

  /// No description provided for @stockSheetSale.
  ///
  /// In en, this message translates to:
  /// **'Sale'**
  String get stockSheetSale;

  /// No description provided for @stockSheetQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get stockSheetQuantity;

  /// No description provided for @stockSheetFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get stockSheetFieldRequired;

  /// No description provided for @stockSheetInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get stockSheetInvalidNumber;

  /// No description provided for @stockSheetUnitPrice.
  ///
  /// In en, this message translates to:
  /// **'Unit price'**
  String get stockSheetUnitPrice;

  /// No description provided for @stockSheetCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get stockSheetCustomer;

  /// No description provided for @stockSheetSearchParties.
  ///
  /// In en, this message translates to:
  /// **'Search parties — defaults to Walk-in Customer'**
  String get stockSheetSearchParties;

  /// No description provided for @stockSheetClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get stockSheetClear;

  /// No description provided for @stockSheetSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get stockSheetSupplier;

  /// No description provided for @stockSheetSupplierHint.
  ///
  /// In en, this message translates to:
  /// **'Track supplier-wise price history'**
  String get stockSheetSupplierHint;

  /// No description provided for @stockSheetSupplierAutocompleteHint.
  ///
  /// In en, this message translates to:
  /// **'Start typing to see previous suppliers'**
  String get stockSheetSupplierAutocompleteHint;

  /// No description provided for @stockSheetNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get stockSheetNote;

  /// No description provided for @stockSheetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get stockSheetConfirm;

  /// No description provided for @stockAdjTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock adjustments'**
  String get stockAdjTitle;

  /// No description provided for @stockAdjEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No adjustments yet'**
  String get stockAdjEmptyTitle;

  /// No description provided for @stockAdjEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap + to record damage, expired stock, or a count correction.'**
  String get stockAdjEmptySubtitle;

  /// No description provided for @stockAdjItemSingular.
  ///
  /// In en, this message translates to:
  /// **'item'**
  String get stockAdjItemSingular;

  /// No description provided for @stockAdjItemPlural.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get stockAdjItemPlural;

  /// No description provided for @stockAdjNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New stock adjustment'**
  String get stockAdjNewTitle;

  /// No description provided for @stockAdjSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get stockAdjSubmit;

  /// No description provided for @stockAdjAddAtLeastOne.
  ///
  /// In en, this message translates to:
  /// **'Add at least one item to adjust.'**
  String get stockAdjAddAtLeastOne;

  /// No description provided for @stockAdjDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get stockAdjDiscardTitle;

  /// No description provided for @stockAdjDiscardMessage.
  ///
  /// In en, this message translates to:
  /// **'Your edits will be lost.'**
  String get stockAdjDiscardMessage;

  /// No description provided for @stockAdjKeepEditing.
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get stockAdjKeepEditing;

  /// No description provided for @stockAdjDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get stockAdjDiscard;

  /// No description provided for @stockAdjReasonSection.
  ///
  /// In en, this message translates to:
  /// **'REASON'**
  String get stockAdjReasonSection;

  /// No description provided for @stockAdjProductsSection.
  ///
  /// In en, this message translates to:
  /// **'PRODUCTS'**
  String get stockAdjProductsSection;

  /// No description provided for @stockAdjReasonDamage.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get stockAdjReasonDamage;

  /// No description provided for @stockAdjReasonExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get stockAdjReasonExpired;

  /// No description provided for @stockAdjReasonShrinkage.
  ///
  /// In en, this message translates to:
  /// **'Shrinkage'**
  String get stockAdjReasonShrinkage;

  /// No description provided for @stockAdjReasonRecount.
  ///
  /// In en, this message translates to:
  /// **'Recount correction'**
  String get stockAdjReasonRecount;

  /// No description provided for @stockAdjReasonOpening.
  ///
  /// In en, this message translates to:
  /// **'Opening balance'**
  String get stockAdjReasonOpening;

  /// No description provided for @stockAdjAddStock.
  ///
  /// In en, this message translates to:
  /// **'Add stock'**
  String get stockAdjAddStock;

  /// No description provided for @stockAdjRemoveStock.
  ///
  /// In en, this message translates to:
  /// **'Remove stock'**
  String get stockAdjRemoveStock;

  /// No description provided for @stockAdjNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get stockAdjNote;

  /// No description provided for @stockAdjSearchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get stockAdjSearchProducts;

  /// No description provided for @stockAdjNoProductsAdded.
  ///
  /// In en, this message translates to:
  /// **'No products added yet.'**
  String get stockAdjNoProductsAdded;

  /// No description provided for @stockAdjSearchToAdd.
  ///
  /// In en, this message translates to:
  /// **'Search above to add the products you\'re adjusting.'**
  String get stockAdjSearchToAdd;

  /// No description provided for @stockAdjAddsStock.
  ///
  /// In en, this message translates to:
  /// **'Adds to stock'**
  String get stockAdjAddsStock;

  /// No description provided for @stockAdjReducesStock.
  ///
  /// In en, this message translates to:
  /// **'Removes from stock'**
  String get stockAdjReducesStock;

  /// No description provided for @stockAdjPostAdjustment.
  ///
  /// In en, this message translates to:
  /// **'Post adjustment'**
  String get stockAdjPostAdjustment;

  /// No description provided for @sharedContactChangesRecentChanges.
  ///
  /// In en, this message translates to:
  /// **'Recent changes'**
  String get sharedContactChangesRecentChanges;

  /// No description provided for @sharedContactChangesChangedSuffix.
  ///
  /// In en, this message translates to:
  /// **'changed'**
  String get sharedContactChangesChangedSuffix;

  /// No description provided for @sharedContactChangesFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get sharedContactChangesFieldName;

  /// No description provided for @sharedContactChangesFieldContactPerson.
  ///
  /// In en, this message translates to:
  /// **'Contact person'**
  String get sharedContactChangesFieldContactPerson;

  /// No description provided for @sharedContactChangesFieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get sharedContactChangesFieldPhone;

  /// No description provided for @sharedContactChangesFieldEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get sharedContactChangesFieldEmail;

  /// No description provided for @sharedContactChangesFieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get sharedContactChangesFieldAddress;

  /// No description provided for @sharedContactChangesFieldCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get sharedContactChangesFieldCity;

  /// No description provided for @sharedContactChangesFieldState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get sharedContactChangesFieldState;

  /// No description provided for @sharedContactChangesFieldStateCode.
  ///
  /// In en, this message translates to:
  /// **'State code'**
  String get sharedContactChangesFieldStateCode;

  /// No description provided for @sharedContactChangesFieldPinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN code'**
  String get sharedContactChangesFieldPinCode;

  /// No description provided for @sharedContactChangesFieldActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get sharedContactChangesFieldActive;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navProducts.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get navProducts;

  /// No description provided for @navOrders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get navOrders;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get navCategories;

  /// No description provided for @navVendors.
  ///
  /// In en, this message translates to:
  /// **'Vendors'**
  String get navVendors;

  /// No description provided for @navParties.
  ///
  /// In en, this message translates to:
  /// **'Parties'**
  String get navParties;

  /// No description provided for @navInvoices.
  ///
  /// In en, this message translates to:
  /// **'Invoices'**
  String get navInvoices;

  /// No description provided for @navQuotations.
  ///
  /// In en, this message translates to:
  /// **'Quotations'**
  String get navQuotations;

  /// No description provided for @navChallans.
  ///
  /// In en, this message translates to:
  /// **'Challans'**
  String get navChallans;

  /// No description provided for @navMyShop.
  ///
  /// In en, this message translates to:
  /// **'My Shop'**
  String get navMyShop;

  /// No description provided for @navTeamRoles.
  ///
  /// In en, this message translates to:
  /// **'Team & roles'**
  String get navTeamRoles;

  /// No description provided for @navBanners.
  ///
  /// In en, this message translates to:
  /// **'Banners'**
  String get navBanners;

  /// No description provided for @navCoupons.
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get navCoupons;

  /// No description provided for @navPointOfSale.
  ///
  /// In en, this message translates to:
  /// **'Point of sale'**
  String get navPointOfSale;

  /// No description provided for @navCashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get navCashier;

  /// No description provided for @navScanToConsole.
  ///
  /// In en, this message translates to:
  /// **'Scan to console'**
  String get navScanToConsole;

  /// No description provided for @navStockAdjustments.
  ///
  /// In en, this message translates to:
  /// **'Stock adjustments'**
  String get navStockAdjustments;

  /// No description provided for @navReturns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get navReturns;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get navAnalytics;

  /// No description provided for @navBannerManager.
  ///
  /// In en, this message translates to:
  /// **'Banner manager'**
  String get navBannerManager;

  /// No description provided for @navCategoryTaxonomy.
  ///
  /// In en, this message translates to:
  /// **'Category taxonomy'**
  String get navCategoryTaxonomy;

  /// No description provided for @navCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get navCollections;

  /// No description provided for @navBankOffers.
  ///
  /// In en, this message translates to:
  /// **'Bank offers'**
  String get navBankOffers;

  /// No description provided for @navShopVerification.
  ///
  /// In en, this message translates to:
  /// **'Shop verification'**
  String get navShopVerification;

  /// No description provided for @navSectionManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get navSectionManage;

  /// No description provided for @navSectionOperations.
  ///
  /// In en, this message translates to:
  /// **'Operations'**
  String get navSectionOperations;

  /// No description provided for @navSectionPlatformAdmin.
  ///
  /// In en, this message translates to:
  /// **'Platform admin'**
  String get navSectionPlatformAdmin;

  /// No description provided for @navMenu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get navMenu;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @reportsRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get reportsRefresh;

  /// No description provided for @reportsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get reportsRetry;

  /// No description provided for @reportsPresetThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get reportsPresetThisMonth;

  /// No description provided for @reportsPresetLast30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get reportsPresetLast30Days;

  /// No description provided for @reportsPresetThisFy.
  ///
  /// In en, this message translates to:
  /// **'This FY'**
  String get reportsPresetThisFy;

  /// No description provided for @reportsTabSales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get reportsTabSales;

  /// No description provided for @reportsTabPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get reportsTabPurchases;

  /// No description provided for @reportsTabGst.
  ///
  /// In en, this message translates to:
  /// **'GST'**
  String get reportsTabGst;

  /// No description provided for @reportsTabPnl.
  ///
  /// In en, this message translates to:
  /// **'P&L'**
  String get reportsTabPnl;

  /// No description provided for @reportsTabCalculator.
  ///
  /// In en, this message translates to:
  /// **'Calculator'**
  String get reportsTabCalculator;

  /// No description provided for @reportsNoActivityInRange.
  ///
  /// In en, this message translates to:
  /// **'No activity in this range.'**
  String get reportsNoActivityInRange;

  /// No description provided for @reportsPace.
  ///
  /// In en, this message translates to:
  /// **'≈ {perDay}/day at this pace · ~{projected} over 30 days'**
  String reportsPace(Object perDay, Object projected);

  /// No description provided for @reportsTotalSales.
  ///
  /// In en, this message translates to:
  /// **'TOTAL SALES'**
  String get reportsTotalSales;

  /// No description provided for @reportsSalesHelper.
  ///
  /// In en, this message translates to:
  /// **'{count} confirmed invoices · {tax} GST · net {net} after refunds'**
  String reportsSalesHelper(Object count, Object tax, Object net);

  /// No description provided for @reportsTopProducts.
  ///
  /// In en, this message translates to:
  /// **'TOP PRODUCTS'**
  String get reportsTopProducts;

  /// No description provided for @reportsNoSalesInRange.
  ///
  /// In en, this message translates to:
  /// **'No sales in this range.'**
  String get reportsNoSalesInRange;

  /// No description provided for @reportsSoldCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sold'**
  String reportsSoldCount(Object count);

  /// No description provided for @reportsTopCustomers.
  ///
  /// In en, this message translates to:
  /// **'TOP CUSTOMERS'**
  String get reportsTopCustomers;

  /// No description provided for @reportsNoCustomersInRange.
  ///
  /// In en, this message translates to:
  /// **'No customers in this range.'**
  String get reportsNoCustomersInRange;

  /// No description provided for @reportsInvoiceCountOne.
  ///
  /// In en, this message translates to:
  /// **'{count} invoice'**
  String reportsInvoiceCountOne(Object count);

  /// No description provided for @reportsInvoiceCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} invoices'**
  String reportsInvoiceCountOther(Object count);

  /// No description provided for @reportsTotalPurchases.
  ///
  /// In en, this message translates to:
  /// **'TOTAL PURCHASES'**
  String get reportsTotalPurchases;

  /// No description provided for @reportsPurchasesHelper.
  ///
  /// In en, this message translates to:
  /// **'{count} confirmed bills · {tax} GST'**
  String reportsPurchasesHelper(Object count, Object tax);

  /// No description provided for @reportsTopPurchasedProducts.
  ///
  /// In en, this message translates to:
  /// **'TOP PURCHASED PRODUCTS'**
  String get reportsTopPurchasedProducts;

  /// No description provided for @reportsNoPurchasesInRange.
  ///
  /// In en, this message translates to:
  /// **'No purchases in this range.'**
  String get reportsNoPurchasesInRange;

  /// No description provided for @reportsBoughtCount.
  ///
  /// In en, this message translates to:
  /// **'{count} bought'**
  String reportsBoughtCount(Object count);

  /// No description provided for @reportsTopVendors.
  ///
  /// In en, this message translates to:
  /// **'TOP VENDORS'**
  String get reportsTopVendors;

  /// No description provided for @reportsNoVendorsInRange.
  ///
  /// In en, this message translates to:
  /// **'No vendors in this range.'**
  String get reportsNoVendorsInRange;

  /// No description provided for @reportsBillCountOne.
  ///
  /// In en, this message translates to:
  /// **'{count} bill'**
  String reportsBillCountOne(Object count);

  /// No description provided for @reportsBillCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} bills'**
  String reportsBillCountOther(Object count);

  /// No description provided for @reportsOutputGst.
  ///
  /// In en, this message translates to:
  /// **'OUTPUT GST'**
  String get reportsOutputGst;

  /// No description provided for @reportsCollectedOnSales.
  ///
  /// In en, this message translates to:
  /// **'Collected on sales'**
  String get reportsCollectedOnSales;

  /// No description provided for @reportsInputGstItc.
  ///
  /// In en, this message translates to:
  /// **'INPUT GST (ITC)'**
  String get reportsInputGstItc;

  /// No description provided for @reportsPaidOnPurchases.
  ///
  /// In en, this message translates to:
  /// **'Paid on purchases'**
  String get reportsPaidOnPurchases;

  /// No description provided for @reportsNetGstPayable.
  ///
  /// In en, this message translates to:
  /// **'NET GST PAYABLE'**
  String get reportsNetGstPayable;

  /// No description provided for @reportsGstOwedNote.
  ///
  /// In en, this message translates to:
  /// **'You owe this to the tax authority'**
  String get reportsGstOwedNote;

  /// No description provided for @reportsGstCreditCarriedNote.
  ///
  /// In en, this message translates to:
  /// **'Input credit carried forward'**
  String get reportsGstCreditCarriedNote;

  /// No description provided for @reportsNetPayableByTaxHead.
  ///
  /// In en, this message translates to:
  /// **'NET PAYABLE BY TAX HEAD'**
  String get reportsNetPayableByTaxHead;

  /// No description provided for @reportsTaxHeadNote.
  ///
  /// In en, this message translates to:
  /// **'CGST + SGST apply to in-state sales; IGST to inter-state. Net is each head’s output tax minus its own input credit.'**
  String get reportsTaxHeadNote;

  /// No description provided for @reportsOutputGstByRate.
  ///
  /// In en, this message translates to:
  /// **'OUTPUT GST BY RATE'**
  String get reportsOutputGstByRate;

  /// No description provided for @reportsNoOutputGstInRange.
  ///
  /// In en, this message translates to:
  /// **'No output GST in this range.'**
  String get reportsNoOutputGstInRange;

  /// No description provided for @reportsInputGstByRate.
  ///
  /// In en, this message translates to:
  /// **'INPUT GST BY RATE'**
  String get reportsInputGstByRate;

  /// No description provided for @reportsNoInputGstInRange.
  ///
  /// In en, this message translates to:
  /// **'No input GST in this range.'**
  String get reportsNoInputGstInRange;

  /// No description provided for @reportsCess.
  ///
  /// In en, this message translates to:
  /// **'CESS'**
  String get reportsCess;

  /// No description provided for @reportsOutputCess.
  ///
  /// In en, this message translates to:
  /// **'Output cess'**
  String get reportsOutputCess;

  /// No description provided for @reportsInputCess.
  ///
  /// In en, this message translates to:
  /// **'Input cess'**
  String get reportsInputCess;

  /// No description provided for @reportsNetCessPayable.
  ///
  /// In en, this message translates to:
  /// **'Net cess payable'**
  String get reportsNetCessPayable;

  /// No description provided for @reportsCessNote.
  ///
  /// In en, this message translates to:
  /// **'Cess is set off only against cess, never against GST.'**
  String get reportsCessNote;

  /// No description provided for @reportsOutputGstReturnsNote.
  ///
  /// In en, this message translates to:
  /// **'Output GST is shown net of {amount} reversed on refunded returns in this period.'**
  String reportsOutputGstReturnsNote(Object amount);

  /// No description provided for @reportsColHead.
  ///
  /// In en, this message translates to:
  /// **'HEAD'**
  String get reportsColHead;

  /// No description provided for @reportsColOutput.
  ///
  /// In en, this message translates to:
  /// **'OUTPUT'**
  String get reportsColOutput;

  /// No description provided for @reportsColItc.
  ///
  /// In en, this message translates to:
  /// **'ITC'**
  String get reportsColItc;

  /// No description provided for @reportsColNet.
  ///
  /// In en, this message translates to:
  /// **'NET'**
  String get reportsColNet;

  /// No description provided for @reportsColTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get reportsColTotal;

  /// No description provided for @reportsColRate.
  ///
  /// In en, this message translates to:
  /// **'RATE'**
  String get reportsColRate;

  /// No description provided for @reportsColTaxable.
  ///
  /// In en, this message translates to:
  /// **'TAXABLE'**
  String get reportsColTaxable;

  /// No description provided for @reportsHeadInterState.
  ///
  /// In en, this message translates to:
  /// **'Inter-state'**
  String get reportsHeadInterState;

  /// No description provided for @reportsHeadCentral.
  ///
  /// In en, this message translates to:
  /// **'Central'**
  String get reportsHeadCentral;

  /// No description provided for @reportsHeadState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get reportsHeadState;

  /// No description provided for @reportsNetProfit.
  ///
  /// In en, this message translates to:
  /// **'NET PROFIT'**
  String get reportsNetProfit;

  /// No description provided for @reportsGrossMargin.
  ///
  /// In en, this message translates to:
  /// **'Gross margin {pct}%'**
  String reportsGrossMargin(Object pct);

  /// No description provided for @reportsRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportsRevenue;

  /// No description provided for @reportsCostOfGoodsSold.
  ///
  /// In en, this message translates to:
  /// **'Cost of goods sold'**
  String get reportsCostOfGoodsSold;

  /// No description provided for @reportsGrossProfit.
  ///
  /// In en, this message translates to:
  /// **'Gross profit'**
  String get reportsGrossProfit;

  /// No description provided for @reportsAdjustmentWriteoffs.
  ///
  /// In en, this message translates to:
  /// **'Adjustment write-offs'**
  String get reportsAdjustmentWriteoffs;

  /// No description provided for @reportsNetProfitRow.
  ///
  /// In en, this message translates to:
  /// **'Net profit'**
  String get reportsNetProfitRow;

  /// No description provided for @reportsHowThisIsCalculated.
  ///
  /// In en, this message translates to:
  /// **'HOW THIS IS CALCULATED'**
  String get reportsHowThisIsCalculated;

  /// No description provided for @reportsConfirmedSales.
  ///
  /// In en, this message translates to:
  /// **'Confirmed sales'**
  String get reportsConfirmedSales;

  /// No description provided for @reportsConfirmedSalesBasis.
  ///
  /// In en, this message translates to:
  /// **'Taxable value (ex-GST) of confirmed sale invoices, less credit notes'**
  String get reportsConfirmedSalesBasis;

  /// No description provided for @reportsLessSalesReturns.
  ///
  /// In en, this message translates to:
  /// **'Less: sales returns'**
  String get reportsLessSalesReturns;

  /// No description provided for @reportsLessSalesReturnsBasis.
  ///
  /// In en, this message translates to:
  /// **'Ex-GST value of refunded returns, pro-rated by returned quantity'**
  String get reportsLessSalesReturnsBasis;

  /// No description provided for @reportsRevenueA.
  ///
  /// In en, this message translates to:
  /// **'Revenue (A)'**
  String get reportsRevenueA;

  /// No description provided for @reportsGoodsSoldAtCost.
  ///
  /// In en, this message translates to:
  /// **'Goods sold, at cost'**
  String get reportsGoodsSoldAtCost;

  /// No description provided for @reportsGoodsSoldAtCostBasis.
  ///
  /// In en, this message translates to:
  /// **'Stock cost layers consumed when each sale was confirmed'**
  String get reportsGoodsSoldAtCostBasis;

  /// No description provided for @reportsLessReturnedGoodsRestocked.
  ///
  /// In en, this message translates to:
  /// **'Less: returned goods restocked'**
  String get reportsLessReturnedGoodsRestocked;

  /// No description provided for @reportsLessReturnedGoodsRestockedBasis.
  ///
  /// In en, this message translates to:
  /// **'Returned items put back into inventory at their consumed cost'**
  String get reportsLessReturnedGoodsRestockedBasis;

  /// No description provided for @reportsCostOfGoodsSoldB.
  ///
  /// In en, this message translates to:
  /// **'Cost of goods sold (B)'**
  String get reportsCostOfGoodsSoldB;

  /// No description provided for @reportsGrossProfitAB.
  ///
  /// In en, this message translates to:
  /// **'Gross profit (A − B)'**
  String get reportsGrossProfitAB;

  /// No description provided for @reportsLessStockWriteoffs.
  ///
  /// In en, this message translates to:
  /// **'Less: stock write-offs'**
  String get reportsLessStockWriteoffs;

  /// No description provided for @reportsLessStockWriteoffsBasis.
  ///
  /// In en, this message translates to:
  /// **'Damage, expiry and shrinkage stock adjustments dated in this range'**
  String get reportsLessStockWriteoffsBasis;

  /// No description provided for @reportsNetProfitFormula.
  ///
  /// In en, this message translates to:
  /// **'Net profit (A − B − write-offs)'**
  String get reportsNetProfitFormula;

  /// No description provided for @reportsPnlNote.
  ///
  /// In en, this message translates to:
  /// **'Gross margin {pct}% = gross profit ÷ revenue. Every figure is summed from confirmed invoices, refunded returns and stock adjustments dated in this range; estimates and proformas are excluded.'**
  String reportsPnlNote(Object pct);

  /// No description provided for @reportsProductsSold.
  ///
  /// In en, this message translates to:
  /// **'PRODUCTS SOLD'**
  String get reportsProductsSold;

  /// No description provided for @reportsCountOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}'**
  String reportsCountOfTotal(Object count, Object total);

  /// No description provided for @reportsSearchByProductOrSku.
  ///
  /// In en, this message translates to:
  /// **'Search by product or SKU…'**
  String get reportsSearchByProductOrSku;

  /// No description provided for @reportsNoSoldProductsMatch.
  ///
  /// In en, this message translates to:
  /// **'No sold products match “{query}”.'**
  String reportsNoSoldProductsMatch(Object query);

  /// No description provided for @reportsNoProductsSoldInRange.
  ///
  /// In en, this message translates to:
  /// **'No products sold in this range.'**
  String get reportsNoProductsSoldInRange;

  /// No description provided for @reportsSaleCountOne.
  ///
  /// In en, this message translates to:
  /// **'{count} sale'**
  String reportsSaleCountOne(Object count);

  /// No description provided for @reportsSaleCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} sales'**
  String reportsSaleCountOther(Object count);

  /// No description provided for @reportsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get reportsLoading;

  /// No description provided for @reportsLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more ({count} left)'**
  String reportsLoadMore(Object count);

  /// No description provided for @reportsAllProductsShownOne.
  ///
  /// In en, this message translates to:
  /// **'All {count} product shown.'**
  String reportsAllProductsShownOne(Object count);

  /// No description provided for @reportsAllProductsShownOther.
  ///
  /// In en, this message translates to:
  /// **'All {count} products shown.'**
  String reportsAllProductsShownOther(Object count);

  /// No description provided for @reportsProductFallback.
  ///
  /// In en, this message translates to:
  /// **'Product'**
  String get reportsProductFallback;

  /// No description provided for @reportsNoSalesForProduct.
  ///
  /// In en, this message translates to:
  /// **'No sales found for this product.'**
  String get reportsNoSalesForProduct;

  /// No description provided for @reportsCalcTitle.
  ///
  /// In en, this message translates to:
  /// **'Pricing & profit calculator'**
  String get reportsCalcTitle;

  /// No description provided for @reportsCalcIntro.
  ///
  /// In en, this message translates to:
  /// **'Add products below, then set quantity, GST and discount per line — totals, GST, profit and margin update live.'**
  String get reportsCalcIntro;

  /// No description provided for @reportsCalcNoProductsYet.
  ///
  /// In en, this message translates to:
  /// **'No products yet — add some from the list below.'**
  String get reportsCalcNoProductsYet;

  /// No description provided for @reportsCalcSupply.
  ///
  /// In en, this message translates to:
  /// **'Supply'**
  String get reportsCalcSupply;

  /// No description provided for @reportsCalcWithinState.
  ///
  /// In en, this message translates to:
  /// **'Within state'**
  String get reportsCalcWithinState;

  /// No description provided for @reportsCalcInterState.
  ///
  /// In en, this message translates to:
  /// **'Inter-state'**
  String get reportsCalcInterState;

  /// No description provided for @reportsCalcDiscountIn.
  ///
  /// In en, this message translates to:
  /// **'Discount in'**
  String get reportsCalcDiscountIn;

  /// No description provided for @reportsCalcOverallDiscount.
  ///
  /// In en, this message translates to:
  /// **'Overall discount'**
  String get reportsCalcOverallDiscount;

  /// No description provided for @reportsCalcGrandTotalInclGst.
  ///
  /// In en, this message translates to:
  /// **'GRAND TOTAL · INCL. GST'**
  String get reportsCalcGrandTotalInclGst;

  /// No description provided for @reportsCalcProductCountOne.
  ///
  /// In en, this message translates to:
  /// **'{count} product'**
  String reportsCalcProductCountOne(Object count);

  /// No description provided for @reportsCalcProductCountOther.
  ///
  /// In en, this message translates to:
  /// **'{count} products'**
  String reportsCalcProductCountOther(Object count);

  /// No description provided for @reportsCalcQtySummary.
  ///
  /// In en, this message translates to:
  /// **' · {qty} qty'**
  String reportsCalcQtySummary(Object qty);

  /// No description provided for @reportsCalcDiscOff.
  ///
  /// In en, this message translates to:
  /// **' · {amount} off'**
  String reportsCalcDiscOff(Object amount);

  /// No description provided for @reportsCalcProfit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get reportsCalcProfit;

  /// No description provided for @reportsCalcMargin.
  ///
  /// In en, this message translates to:
  /// **'Margin'**
  String get reportsCalcMargin;

  /// No description provided for @reportsCalcBlockTotal.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get reportsCalcBlockTotal;

  /// No description provided for @reportsCalcGrossSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Gross subtotal'**
  String get reportsCalcGrossSubtotal;

  /// No description provided for @reportsCalcHintInclGst.
  ///
  /// In en, this message translates to:
  /// **'incl. GST'**
  String get reportsCalcHintInclGst;

  /// No description provided for @reportsCalcLineDiscounts.
  ///
  /// In en, this message translates to:
  /// **'Line discounts'**
  String get reportsCalcLineDiscounts;

  /// No description provided for @reportsCalcGrandTotalRow.
  ///
  /// In en, this message translates to:
  /// **'Grand total (incl. GST)'**
  String get reportsCalcGrandTotalRow;

  /// No description provided for @reportsCalcBlockGstInterState.
  ///
  /// In en, this message translates to:
  /// **'GST · INTER-STATE'**
  String get reportsCalcBlockGstInterState;

  /// No description provided for @reportsCalcBlockGstWithinState.
  ///
  /// In en, this message translates to:
  /// **'GST · WITHIN STATE'**
  String get reportsCalcBlockGstWithinState;

  /// No description provided for @reportsCalcSubtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get reportsCalcSubtotal;

  /// No description provided for @reportsCalcHintTaxableExGst.
  ///
  /// In en, this message translates to:
  /// **'taxable, ex-GST'**
  String get reportsCalcHintTaxableExGst;

  /// No description provided for @reportsCalcGstTotal.
  ///
  /// In en, this message translates to:
  /// **'GST total'**
  String get reportsCalcGstTotal;

  /// No description provided for @reportsCalcBlockProfit.
  ///
  /// In en, this message translates to:
  /// **'PROFIT'**
  String get reportsCalcBlockProfit;

  /// No description provided for @reportsCalcCostOfGoods.
  ///
  /// In en, this message translates to:
  /// **'Cost of goods'**
  String get reportsCalcCostOfGoods;

  /// No description provided for @reportsCalcRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get reportsCalcRevenue;

  /// No description provided for @reportsCalcMarkup.
  ///
  /// In en, this message translates to:
  /// **'Markup'**
  String get reportsCalcMarkup;

  /// No description provided for @reportsCalcHintReturnOnCost.
  ///
  /// In en, this message translates to:
  /// **'return on cost'**
  String get reportsCalcHintReturnOnCost;

  /// No description provided for @reportsCalcProfitMargin.
  ///
  /// In en, this message translates to:
  /// **'Profit margin'**
  String get reportsCalcProfitMargin;

  /// No description provided for @reportsCalcQuotation.
  ///
  /// In en, this message translates to:
  /// **'QUOTATION'**
  String get reportsCalcQuotation;

  /// No description provided for @reportsCalcStatusRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get reportsCalcStatusRequested;

  /// No description provided for @reportsCalcStatusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get reportsCalcStatusSent;

  /// No description provided for @reportsCalcStatusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get reportsCalcStatusAccepted;

  /// No description provided for @reportsCalcStatusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get reportsCalcStatusDeclined;

  /// No description provided for @reportsCalcStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get reportsCalcStatusCancelled;

  /// No description provided for @reportsCalcStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get reportsCalcStatusExpired;

  /// No description provided for @reportsCalcLoadQuotation.
  ///
  /// In en, this message translates to:
  /// **'Load a quotation'**
  String get reportsCalcLoadQuotation;

  /// No description provided for @reportsCalcChooseCustomer.
  ///
  /// In en, this message translates to:
  /// **'Choose customer'**
  String get reportsCalcChooseCustomer;

  /// No description provided for @reportsCalcDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get reportsCalcDownload;

  /// No description provided for @reportsCalcSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get reportsCalcSending;

  /// No description provided for @reportsCalcPriceAndSend.
  ///
  /// In en, this message translates to:
  /// **'Price & send'**
  String get reportsCalcPriceAndSend;

  /// No description provided for @reportsCalcSendQuotation.
  ///
  /// In en, this message translates to:
  /// **'Send quotation'**
  String get reportsCalcSendQuotation;

  /// No description provided for @reportsCalcNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get reportsCalcNew;

  /// No description provided for @reportsCalcNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get reportsCalcNoteLabel;

  /// No description provided for @reportsCalcNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Shown on the quotation…'**
  String get reportsCalcNoteHint;

  /// No description provided for @reportsCalcQuoteNote.
  ///
  /// In en, this message translates to:
  /// **'Download and Send both save the quotation (the PDF is generated from a saved quote). A customer-requested quote is priced & sent back; otherwise a new one goes to the chosen customer. Totals are GST-inclusive — the quote matches the grand total above.'**
  String get reportsCalcQuoteNote;

  /// No description provided for @reportsCalcYourProducts.
  ///
  /// In en, this message translates to:
  /// **'YOUR PRODUCTS'**
  String get reportsCalcYourProducts;

  /// No description provided for @reportsCalcAddedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} added'**
  String reportsCalcAddedCount(Object count);

  /// No description provided for @reportsCalcSearchByNameOrSku.
  ///
  /// In en, this message translates to:
  /// **'Search by name or SKU…'**
  String get reportsCalcSearchByNameOrSku;

  /// No description provided for @reportsCalcLoadingProducts.
  ///
  /// In en, this message translates to:
  /// **'Loading your products…'**
  String get reportsCalcLoadingProducts;

  /// No description provided for @reportsCalcNoProductsFound.
  ///
  /// In en, this message translates to:
  /// **'No products found.'**
  String get reportsCalcNoProductsFound;

  /// No description provided for @reportsCalcEach.
  ///
  /// In en, this message translates to:
  /// **'each'**
  String get reportsCalcEach;

  /// No description provided for @reportsCalcRemoveProduct.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String reportsCalcRemoveProduct(Object name);

  /// No description provided for @reportsCalcQty.
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get reportsCalcQty;

  /// No description provided for @reportsCalcDisc.
  ///
  /// In en, this message translates to:
  /// **'Disc'**
  String get reportsCalcDisc;

  /// No description provided for @reportsCalcSearchByNumberOrCustomer.
  ///
  /// In en, this message translates to:
  /// **'Search by number or customer…'**
  String get reportsCalcSearchByNumberOrCustomer;

  /// No description provided for @reportsCalcNoQuotationsYet.
  ///
  /// In en, this message translates to:
  /// **'No quotations yet.'**
  String get reportsCalcNoQuotationsYet;

  /// No description provided for @reportsCalcAddOneProduct.
  ///
  /// In en, this message translates to:
  /// **'Add at least one product with a price and quantity.'**
  String get reportsCalcAddOneProduct;

  /// No description provided for @reportsCalcChooseCustomerFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a customer first.'**
  String get reportsCalcChooseCustomerFirst;

  /// No description provided for @reportsCalcQuoteSent.
  ///
  /// In en, this message translates to:
  /// **'Quotation {number} sent to {name}.'**
  String reportsCalcQuoteSent(Object number, Object name);

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @menuDescMyShop.
  ///
  /// In en, this message translates to:
  /// **'Storefront, hours and policies'**
  String get menuDescMyShop;

  /// No description provided for @menuDescTeam.
  ///
  /// In en, this message translates to:
  /// **'Staff and their permissions'**
  String get menuDescTeam;

  /// No description provided for @menuDescCategories.
  ///
  /// In en, this message translates to:
  /// **'Product categories and grouping'**
  String get menuDescCategories;

  /// No description provided for @menuDescVendors.
  ///
  /// In en, this message translates to:
  /// **'Suppliers you buy from'**
  String get menuDescVendors;

  /// No description provided for @menuDescParties.
  ///
  /// In en, this message translates to:
  /// **'Customers you sell to'**
  String get menuDescParties;

  /// No description provided for @menuDescBanners.
  ///
  /// In en, this message translates to:
  /// **'Storefront home banners'**
  String get menuDescBanners;

  /// No description provided for @menuDescCoupons.
  ///
  /// In en, this message translates to:
  /// **'Discount codes and offers'**
  String get menuDescCoupons;

  /// No description provided for @menuDescPos.
  ///
  /// In en, this message translates to:
  /// **'Fast in-store billing'**
  String get menuDescPos;

  /// No description provided for @menuDescCashier.
  ///
  /// In en, this message translates to:
  /// **'Quick checkout register'**
  String get menuDescCashier;

  /// No description provided for @menuDescScan.
  ///
  /// In en, this message translates to:
  /// **'Scan items into a session'**
  String get menuDescScan;

  /// No description provided for @menuDescQuotations.
  ///
  /// In en, this message translates to:
  /// **'Price quotes for customers'**
  String get menuDescQuotations;

  /// No description provided for @menuDescChallans.
  ///
  /// In en, this message translates to:
  /// **'Delivery notes without prices'**
  String get menuDescChallans;

  /// No description provided for @menuDescStockAdj.
  ///
  /// In en, this message translates to:
  /// **'Damage, expiry and corrections'**
  String get menuDescStockAdj;

  /// No description provided for @menuDescReturns.
  ///
  /// In en, this message translates to:
  /// **'Customer returns and refunds'**
  String get menuDescReturns;

  /// No description provided for @menuDescReports.
  ///
  /// In en, this message translates to:
  /// **'Sales, purchases, GST and P&L'**
  String get menuDescReports;

  /// No description provided for @menuDescAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Traffic and performance'**
  String get menuDescAnalytics;

  /// No description provided for @menuDescBannerManager.
  ///
  /// In en, this message translates to:
  /// **'Marketplace home banners'**
  String get menuDescBannerManager;

  /// No description provided for @menuDescCategoryTaxonomy.
  ///
  /// In en, this message translates to:
  /// **'Global category tree'**
  String get menuDescCategoryTaxonomy;

  /// No description provided for @menuDescCollections.
  ///
  /// In en, this message translates to:
  /// **'Curated product collections'**
  String get menuDescCollections;

  /// No description provided for @menuDescBankOffers.
  ///
  /// In en, this message translates to:
  /// **'Card and bank discounts'**
  String get menuDescBankOffers;

  /// No description provided for @menuDescShopVerification.
  ///
  /// In en, this message translates to:
  /// **'Review and verify shops'**
  String get menuDescShopVerification;

  /// No description provided for @menuDescProfile.
  ///
  /// In en, this message translates to:
  /// **'Your account and shop'**
  String get menuDescProfile;

  /// No description provided for @menuDescSettings.
  ///
  /// In en, this message translates to:
  /// **'Currency, theme and language'**
  String get menuDescSettings;

  /// No description provided for @profileDevicesSessions.
  ///
  /// In en, this message translates to:
  /// **'Devices & sessions'**
  String get profileDevicesSessions;

  /// No description provided for @profileDevicesSessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'See where you\'re signed in and sign out devices'**
  String get profileDevicesSessionsSubtitle;

  /// No description provided for @sessionsThisDevice.
  ///
  /// In en, this message translates to:
  /// **'This device'**
  String get sessionsThisDevice;

  /// No description provided for @sessionsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get sessionsSignOut;

  /// No description provided for @sessionsSignOutOthers.
  ///
  /// In en, this message translates to:
  /// **'Sign out all other devices'**
  String get sessionsSignOutOthers;

  /// No description provided for @sessionsSignedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out.'**
  String get sessionsSignedOut;

  /// No description provided for @sessionsLastActive.
  ///
  /// In en, this message translates to:
  /// **'Last active {time}'**
  String sessionsLastActive(String time);

  /// No description provided for @sessionsSignedInOn.
  ///
  /// In en, this message translates to:
  /// **'Signed in {time}'**
  String sessionsSignedInOn(String time);

  /// No description provided for @sessionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active sessions.'**
  String get sessionsEmpty;

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m ago'**
  String timeMinutesAgo(int n);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String timeHoursAgo(int n);

  /// No description provided for @timeDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String timeDaysAgo(int n);

  /// No description provided for @productsHsnSuggestedFor.
  ///
  /// In en, this message translates to:
  /// **'Suggested for this product'**
  String get productsHsnSuggestedFor;

  /// No description provided for @productsHsnNotThis.
  ///
  /// In en, this message translates to:
  /// **'Not this?'**
  String get productsHsnNotThis;

  /// No description provided for @productsHsnSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to your codes'**
  String get productsHsnSaved;

  /// No description provided for @productsHsnSaveShortcut.
  ///
  /// In en, this message translates to:
  /// **'Save as my code for “{name}”'**
  String productsHsnSaveShortcut(String name);

  /// No description provided for @productsGstAwaitingCode.
  ///
  /// In en, this message translates to:
  /// **'Pick an HSN code'**
  String get productsGstAwaitingCode;

  /// No description provided for @productsGstFromRule.
  ///
  /// In en, this message translates to:
  /// **'by price'**
  String get productsGstFromRule;

  /// No description provided for @productsGstFromOverride.
  ///
  /// In en, this message translates to:
  /// **'your override'**
  String get productsGstFromOverride;

  /// No description provided for @productsGstRuleApplied.
  ///
  /// In en, this message translates to:
  /// **'Priced at ₹{price}, against the ₹{threshold} threshold.'**
  String productsGstRuleApplied(String price, String threshold);

  /// No description provided for @productsGstManualDiverges.
  ///
  /// In en, this message translates to:
  /// **'This differs from HSN {code}, which is {rate}%. Make sure you have a basis for it.'**
  String productsGstManualDiverges(String code, String rate);

  /// No description provided for @productsGstSetManually.
  ///
  /// In en, this message translates to:
  /// **'Set the rate manually'**
  String get productsGstSetManually;

  /// No description provided for @productsGstUseHsnRate.
  ///
  /// In en, this message translates to:
  /// **'Use the rate from the HSN code'**
  String get productsGstUseHsnRate;

  /// No description provided for @hsnCodesTitle.
  ///
  /// In en, this message translates to:
  /// **'My HSN codes'**
  String get hsnCodesTitle;

  /// No description provided for @hsnCodesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The codes you\'ve saved and any rate you\'ve set differently from ours. Saved codes only decide classification — the GST rate is always read live, so a Council change reaches you without you touching anything here.'**
  String get hsnCodesSubtitle;

  /// No description provided for @hsnRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get hsnRetry;

  /// No description provided for @hsnSavedHeading.
  ///
  /// In en, this message translates to:
  /// **'Saved codes'**
  String get hsnSavedHeading;

  /// No description provided for @hsnSavedBlurb.
  ///
  /// In en, this message translates to:
  /// **'When you say one of these words on a product, we fill in this code. Created from the product form — no rate is stored, so these can\'t go stale.'**
  String get hsnSavedBlurb;

  /// No description provided for @hsnSavedEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet'**
  String get hsnSavedEmptyTitle;

  /// No description provided for @hsnSavedEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Pick an HSN code on a product and choose “Save as my code”.'**
  String get hsnSavedEmptyHint;

  /// No description provided for @hsnSavedBrokenBadge.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get hsnSavedBrokenBadge;

  /// No description provided for @hsnSavedBrokenBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 saved code no longer exists} other{{count} saved codes no longer exist}} in the tariff. Pick a replacement — we won\'t guess one for you.'**
  String hsnSavedBrokenBanner(num count);

  /// No description provided for @hsnSavedUsedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{used 1 time} other{used {count} times}}'**
  String hsnSavedUsedCount(num count);

  /// No description provided for @hsnActionChangeCode.
  ///
  /// In en, this message translates to:
  /// **'Change code'**
  String get hsnActionChangeCode;

  /// No description provided for @hsnActionRemoveSaved.
  ///
  /// In en, this message translates to:
  /// **'Remove saved code'**
  String get hsnActionRemoveSaved;

  /// No description provided for @hsnActionRemoveOverride.
  ///
  /// In en, this message translates to:
  /// **'Remove override'**
  String get hsnActionRemoveOverride;

  /// No description provided for @hsnRepointTitle.
  ///
  /// In en, this message translates to:
  /// **'Change the code for “{label}”'**
  String hsnRepointTitle(String label);

  /// No description provided for @hsnRepointBlurb.
  ///
  /// In en, this message translates to:
  /// **'This keeps your wording and points it at a different HSN code. Products already saved keep the rate they were billed at.'**
  String get hsnRepointBlurb;

  /// No description provided for @hsnOverridesHeading.
  ///
  /// In en, this message translates to:
  /// **'Rate overrides'**
  String get hsnOverridesHeading;

  /// No description provided for @hsnOverridesBlurb.
  ///
  /// In en, this message translates to:
  /// **'A rate you bill that differs from ours, for one code, across your whole catalogue. Use this only when you have a basis for it — the reason you give is what an auditor will ask about.'**
  String get hsnOverridesBlurb;

  /// No description provided for @hsnOverridesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No overrides. Every code bills at the rate in the shared tariff.'**
  String get hsnOverridesEmpty;

  /// No description provided for @hsnOverridesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get hsnOverridesAdd;

  /// No description provided for @hsnOverridesEffectiveFrom.
  ///
  /// In en, this message translates to:
  /// **'In force from {date}'**
  String hsnOverridesEffectiveFrom(String date);

  /// No description provided for @hsnOverridesDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Override a GST rate'**
  String get hsnOverridesDialogTitle;

  /// No description provided for @hsnOverridesDialogBlurb.
  ///
  /// In en, this message translates to:
  /// **'Pick the code first, so you can see the rate you\'re departing from.'**
  String get hsnOverridesDialogBlurb;

  /// No description provided for @hsnOverridesPlatformRate.
  ///
  /// In en, this message translates to:
  /// **'Our rate for {code} is {rate}%.'**
  String hsnOverridesPlatformRate(String code, String rate);

  /// No description provided for @hsnOverridesRateLabel.
  ///
  /// In en, this message translates to:
  /// **'Your GST rate (%)'**
  String get hsnOverridesRateLabel;

  /// No description provided for @hsnOverridesDiverges.
  ///
  /// In en, this message translates to:
  /// **'You\'re billing {yours}% on {code} where the tariff says {platform}%. This applies to every product on this code and every invoice from here on.'**
  String hsnOverridesDiverges(String code, String yours, String platform);

  /// No description provided for @hsnOverridesReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Why'**
  String get hsnOverridesReasonLabel;

  /// No description provided for @hsnOverridesReasonHelper.
  ///
  /// In en, this message translates to:
  /// **'Required. An override with no stated basis can\'t be told apart from a typo.'**
  String get hsnOverridesReasonHelper;

  /// No description provided for @hsnOverridesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Save override'**
  String get hsnOverridesConfirm;
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
