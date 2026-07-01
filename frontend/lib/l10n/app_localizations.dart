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

  /// No description provided for @productsCodesInventoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Codes & inventory'**
  String get productsCodesInventoryTitle;

  /// No description provided for @productsCodesInventorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Barcode, HSN code, low-stock alert'**
  String get productsCodesInventorySubtitle;

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
