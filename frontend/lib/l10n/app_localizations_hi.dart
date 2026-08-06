// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get settingsPreferences => 'प्राथमिकताएँ';

  @override
  String get settingsPreferencesSubtitle => 'मुद्रा, थीम और भाषा।';

  @override
  String get theme => 'थीम';

  @override
  String get themeSubtitle => 'चुनें कि इस डिवाइस पर ShopXY कैसा दिखे।';

  @override
  String get themeLight => 'लाइट';

  @override
  String get themeBeige => 'बेज';

  @override
  String get themeRose => 'रोज़';

  @override
  String get themeSage => 'सेज';

  @override
  String get themeDark => 'डार्क';

  @override
  String get themeOled => 'OLED';

  @override
  String get themeMidnight => 'मिडनाइट';

  @override
  String get themeNord => 'नॉर्ड';

  @override
  String get themeLightDesc => 'गर्म कैनवास, गहरा टेक्स्ट (डिफ़ॉल्ट)।';

  @override
  String get themeBeigeDesc => 'मुलायम सीपिया कागज़ — गर्म, कम चमक।';

  @override
  String get themeRoseDesc => 'गर्म गुलाबी — आँखों के लिए सुकूनदेह।';

  @override
  String get themeSageDesc => 'शीतल पुदीना हरा — शांत और सौम्य।';

  @override
  String get themeDarkDesc => 'गहरे स्लेट सरफेस, आँखों के लिए आरामदेह।';

  @override
  String get themeOledDesc => 'सच्चा काला — OLED डिस्प्ले के लिए सर्वोत्तम।';

  @override
  String get themeMidnightDesc => 'गहरा नेवी — इंडिगो रंगत वाला डार्क।';

  @override
  String get themeNordDesc => 'मंद आर्कटिक नीला-धूसर — कोमल डार्क।';

  @override
  String get language => 'भाषा';

  @override
  String get languageSubtitle => 'अपनी पसंदीदा भाषा चुनें।';

  @override
  String get commonSave => 'सहेजें';

  @override
  String get commonCancel => 'रद्द करें';

  @override
  String get commonSignOut => 'साइन आउट';

  @override
  String get offlineBannerMessage => 'नेटवर्क नहीं — सहेजा गया डेटा दिख रहा है';

  @override
  String offlineSyncingMessage(int count) {
    return '$count बदलाव सिंक हो रहे हैं…';
  }

  @override
  String get noShopTitle => 'अभी तक कोई दुकान लिंक नहीं है';

  @override
  String get noShopBody =>
      'किसी दुकान मालिक से अपनी टीम में आमंत्रित करने को कहें, फिर स्वीकार करने के लिए दोबारा साइन इन करें।';

  @override
  String get productsTitle => 'उत्पाद';

  @override
  String get productsSwitchToCardView => 'कार्ड व्यू पर जाएँ';

  @override
  String get productsSwitchToCompactView => 'कॉम्पैक्ट व्यू पर जाएँ';

  @override
  String get productsGridView => 'ग्रिड व्यू';

  @override
  String get productsListView => 'सूची व्यू';

  @override
  String get productsAddProduct => 'उत्पाद जोड़ें';

  @override
  String get productsHidden => 'उत्पाद छिपे हैं';

  @override
  String get productsSearchHint => 'उत्पाद खोजें...';

  @override
  String get productsFilterAll => 'सभी';

  @override
  String get productsLowStock => 'कम स्टॉक';

  @override
  String get productsOutOfStock => 'स्टॉक ख़त्म';

  @override
  String get productsCategoryPickerLabel => 'श्रेणी';

  @override
  String get productsAllStockedUpTitle => 'पूरा स्टॉक उपलब्ध';

  @override
  String get productsAllStockedUpHint =>
      'अभी किसी भी चीज़ का स्टॉक कम नहीं है। बढ़िया काम।';

  @override
  String get productsNoMatches => 'कोई मिलान नहीं';

  @override
  String get productsNoProducts => 'कोई उत्पाद नहीं मिला';

  @override
  String get productsNoMatchesHint => 'फ़िल्टर हटाकर देखें या कुछ और खोजें।';

  @override
  String get productsNoProductsHint => 'अपना पहला उत्पाद जोड़ने के लिए + दबाएँ';

  @override
  String get productsStockInAction => 'स्टॉक इन';

  @override
  String get productsStockOutAction => 'स्टॉक आउट';

  @override
  String get productsNotFoundTitle => 'उत्पाद नहीं मिला';

  @override
  String get productsNotFoundHint => 'स्कैन किए गए कोड के साथ इसे अभी जोड़ें';

  @override
  String get productsScanAgain => 'फिर से स्कैन करें';

  @override
  String get productsScanQr => 'QR / बारकोड स्कैन करें';

  @override
  String get productsScanHint => 'कैमरा QR या बारकोड की ओर करें';

  @override
  String get productsLoading => 'लोड हो रहा है...';

  @override
  String get productsSpecifications => 'विशिष्टताएँ';

  @override
  String get productsGenerateQr => 'QR कोड बनाएँ';

  @override
  String get productsClose => 'बंद करें';

  @override
  String get productsListedOnMarketplace => 'मार्केटप्लेस पर सूचीबद्ध।';

  @override
  String get productsHiddenFromMarketplace => 'मार्केटप्लेस से छिपाया गया।';

  @override
  String get productsCouldntUpdateVisibility => 'दृश्यता अपडेट नहीं हो सकी';

  @override
  String get productsDelete => 'हटाएँ';

  @override
  String get productsDeleteConfirm => 'क्या यह उत्पाद हटाएँ?';

  @override
  String get productsDeleted => 'उत्पाद हटाया गया';

  @override
  String get productsError => 'कुछ गड़बड़ हो गई';

  @override
  String get productsDetailsTitle => 'उत्पाद विवरण';

  @override
  String get productsShare => 'साझा करें';

  @override
  String get productsEdit => 'संपादित करें';

  @override
  String get productsStockLedger => 'स्टॉक बहीखाता';

  @override
  String get productsStockLedgerHint => 'हर लेन-देन स्रोत दस्तावेज़ों के साथ';

  @override
  String get productsPricingSection => 'मूल्य निर्धारण';

  @override
  String get productsMrp => 'MRP';

  @override
  String get productsSellingPrice => 'बिक्री मूल्य';

  @override
  String get productsPurchasePrice => 'खरीद मूल्य';

  @override
  String get productsTaxPercent => 'कर %';

  @override
  String get productsNone => 'कोई नहीं';

  @override
  String get productsProfitMargin => 'लाभ मार्जिन';

  @override
  String get productsDetailsSection => 'विवरण';

  @override
  String get productsHsnCode => 'HSN कोड';

  @override
  String get productsUnit => 'इकाई';

  @override
  String get productsCategory => 'श्रेणी';

  @override
  String get productsCreated => 'बनाया गया';

  @override
  String get productsLastUpdated => 'अंतिम अपडेट';

  @override
  String get productsStatus => 'स्थिति';

  @override
  String get productsActive => 'सक्रिय';

  @override
  String get productsInactive => 'निष्क्रिय';

  @override
  String get productsTagBestseller => 'बेस्टसेलर';

  @override
  String get productsTagEditorsPick => 'संपादक की पसंद';

  @override
  String get productsTagNewArrival => 'नया आगमन';

  @override
  String get productsTagTrending => 'ट्रेंडिंग';

  @override
  String get productsReviewSingular => 'समीक्षा';

  @override
  String get productsReviewPlural => 'समीक्षाएँ';

  @override
  String get productsNoReviewsYet => 'अभी कोई समीक्षा नहीं';

  @override
  String get productsListedTitle => 'मार्केटप्लेस पर सूचीबद्ध';

  @override
  String get productsNotListedTitle => 'सूचीबद्ध नहीं';

  @override
  String get productsListedHint => 'ग्राहक इस उत्पाद को ढूँढ और खरीद सकते हैं।';

  @override
  String get productsNotListedHint =>
      'केवल आपको दिखाई देता है। प्रकाशित करने के लिए टॉगल करें।';

  @override
  String get productsPerformance => 'प्रदर्शन';

  @override
  String get productsLifetimeSold => 'कुल बिक्री';

  @override
  String get productsSold30d => 'बिक्री (30 दिन)';

  @override
  String get productsReviewsLabel => 'समीक्षाएँ';

  @override
  String get productsLastActivity => 'अंतिम गतिविधि';

  @override
  String get productsStockedIn => 'स्टॉक आया';

  @override
  String get productsSold => 'बिका';

  @override
  String get productsVariantsSection => 'वेरिएंट';

  @override
  String get productsDefaultVariant => 'डिफ़ॉल्ट';

  @override
  String get productsDefaultBadge => 'डिफ़ॉल्ट';

  @override
  String get productsInactiveBadge => 'निष्क्रिय';

  @override
  String get productsHighlightsSection => 'मुख्य बातें';

  @override
  String get productsProductSpecs => 'उत्पाद विशिष्टताएँ';

  @override
  String get productsCouponCopied => 'कूपन कोड कॉपी किया गया';

  @override
  String get productsOffersSection => 'ऑफ़र';

  @override
  String get productsBlockHero => 'हीरो';

  @override
  String get productsBlockFeature => 'फ़ीचर';

  @override
  String get productsBlockComparison => 'तुलना';

  @override
  String get productsBlockGallery => 'गैलरी';

  @override
  String get productsBlockText => 'टेक्स्ट';

  @override
  String get productsColumnsUnit => 'कॉलम';

  @override
  String get productsRowsUnit => 'पंक्तियाँ';

  @override
  String get productsImagesUnit => 'चित्र';

  @override
  String get productsRichContentSection => 'समृद्ध सामग्री';

  @override
  String get productsTagsSection => 'टैग';

  @override
  String get productsLowStockAlertAt => 'कम स्टॉक अलर्ट';

  @override
  String get productsInStock => 'स्टॉक में';

  @override
  String get productsSupplierPriceHistory => 'आपूर्तिकर्ता अनुसार मूल्य इतिहास';

  @override
  String get productsNoSupplierHistory =>
      'अभी कोई आपूर्तिकर्ता स्टॉक-इन इतिहास नहीं';

  @override
  String get productsUnknownSupplier => 'अज्ञात आपूर्तिकर्ता';

  @override
  String get productsVendor => 'विक्रेता';

  @override
  String get productsLatestPrice => 'नवीनतम मूल्य';

  @override
  String get productsAveragePrice => 'औसत मूल्य';

  @override
  String get productsTotalQuantityBought => 'कुल खरीदा';

  @override
  String get productsPurchasesUnit => 'खरीद';

  @override
  String get productsLastStockIn => 'अंतिम स्टॉक इन';

  @override
  String get productsPolicy => 'नीति';

  @override
  String get productsRecentBuys => 'हाल की खरीद';

  @override
  String get productsQtyLabel => 'मात्रा';

  @override
  String get productsWeightedAverage => 'भारित औसत';

  @override
  String get productsUseLatestPrice => 'नवीनतम उपयोग करें';

  @override
  String get productsKeepCurrentPrice => 'वर्तमान रखें';

  @override
  String get productsStockIn => 'स्टॉक इन';

  @override
  String get productsStockOut => 'स्टॉक आउट';

  @override
  String get productsCopiedSuffix => 'कॉपी किया गया';

  @override
  String get productsSku => 'SKU';

  @override
  String get productsBarcode => 'बारकोड';

  @override
  String get productsPendingDrafts => 'लंबित ड्राफ़्ट';

  @override
  String get productsPendingDraftsHint => 'पुष्टि होने के बाद स्टॉक बदल जाएगा।';

  @override
  String get productsCustomer => 'ग्राहक';

  @override
  String get productsSale => 'बिक्री';

  @override
  String get productsPurchase => 'खरीद';

  @override
  String get productsPriceGstBreakdown => 'मूल्य और GST विवरण';

  @override
  String get productsTaxableValue => 'कर योग्य मूल्य';

  @override
  String get productsPriceBeforeGst => 'GST से पहले का मूल्य';

  @override
  String get productsTotalGst => 'कुल GST';

  @override
  String get productsSellingPriceInclGst => 'बिक्री मूल्य (GST सहित)';

  @override
  String get productsTotalPayableExclGst => 'कुल देय (GST सहित)';

  @override
  String get productsGstExplainer =>
      'मूल्यों में GST शामिल है। CGST + SGST आपके राज्य के भीतर बिक्री के लिए दिखाए गए हैं; दूसरे राज्य में बिक्री पर वही कुल राशि IGST के रूप में ली जाती है।';

  @override
  String get productsGstExplainerExclusive =>
      'बिल बनाते समय इस कीमत पर GST ऊपर से जोड़ा जाता है। CGST + SGST आपके राज्य के भीतर बिक्री के लिए दिखाए गए हैं; दूसरे राज्य में बिक्री पर वही कुल राशि IGST के रूप में ली जाती है।';

  @override
  String get productsPricingModeLabel => 'GST मूल्य निर्धारण';

  @override
  String get productsPricingModeExclusive =>
      'एक्सक्लूसिव — बिल बनाते समय GST ऊपर से जोड़ा जाएगा';

  @override
  String get productsPricingModeInclusive =>
      'इन्क्लूसिव — कीमत में GST पहले से शामिल है';

  @override
  String get productsPricingModeNoGst => 'कोई GST नहीं — कर-मुक्त';

  @override
  String get productsPricingModeHelper =>
      'यह तय करता है कि इनवॉइस, कोटेशन और ऑर्डर इस उत्पाद की कीमत पर बिल कैसे बनाएंगे।';

  @override
  String get productsReviewsSection => 'समीक्षाएँ';

  @override
  String get productsNoReviewsBody =>
      'अभी कोई समीक्षा नहीं। सत्यापित खरीदार पुष्टि की गई खरीद के बाद इस उत्पाद को रेट कर सकते हैं।';

  @override
  String get productsRatingSingular => 'रेटिंग';

  @override
  String get productsRatingPlural => 'रेटिंग';

  @override
  String get productsVerified => 'सत्यापित';

  @override
  String get productsSeeAllReviews => 'सभी समीक्षाएँ देखें';

  @override
  String productsDuplicateWarning(Object label) {
    return 'उस $label वाला एक उत्पाद पहले से मौजूद है — सहेजने पर विलय नहीं होगा';
  }

  @override
  String get productsBarcodeLower => 'बारकोड';

  @override
  String get productsDroppedBlocksPrefix => 'हटाया गया';

  @override
  String get productsMalformedBlockSingular => 'त्रुटिपूर्ण सामग्री ब्लॉक';

  @override
  String get productsMalformedBlockPlural => 'त्रुटिपूर्ण सामग्री ब्लॉक';

  @override
  String get productsFieldRequired => 'यह फ़ील्ड आवश्यक है';

  @override
  String get productsInvalidNumber => 'मान्य संख्या दर्ज करें';

  @override
  String get productsPriceMustBePositive => 'मूल्य 0 से अधिक होना चाहिए';

  @override
  String get productsOcrApplied => 'स्कैन परिणाम लागू किए गए';

  @override
  String get productsOcrNoDetails => 'कोई उत्पाद विवरण नहीं मिला';

  @override
  String get productsOcrFailed => 'उत्पाद विवरण नहीं पढ़ा जा सका';

  @override
  String get productsImageTooLarge =>
      'चित्र 5 MB से बड़ा है। छोटा चित्र चुनें या और क्रॉप करें।';

  @override
  String productsMaxImagesReached(Object count) {
    return 'आप प्रति उत्पाद अधिकतम $count चित्र जोड़ सकते हैं। और जोड़ने के लिए कुछ हटाएँ।';
  }

  @override
  String productsSelectedButOnlyFit(Object selected, Object remaining) {
    return '$selected चुने गए, लेकिन केवल $remaining और आते हैं। बाकी छोड़े जा रहे हैं।';
  }

  @override
  String productsFileTooLarge(Object name) {
    return '$name: 5 MB से बड़ा';
  }

  @override
  String get productsUploadedPrefix => 'अपलोड किया गया';

  @override
  String get productsImageSingular => 'चित्र';

  @override
  String get productsImagePlural => 'चित्र';

  @override
  String get productsSkippedPrefix => 'छोड़ा गया';

  @override
  String get productsInvalidUrl => 'मान्य URL दर्ज करें';

  @override
  String get productsDiscardTitle => 'परिवर्तन छोड़ें?';

  @override
  String get productsDiscardMessage => 'आपके संपादन खो जाएँगे।';

  @override
  String get productsKeepEditing => 'संपादन जारी रखें';

  @override
  String get productsDiscard => 'छोड़ें';

  @override
  String get productsEditProduct => 'उत्पाद संपादित करें';

  @override
  String get productsReviews => 'समीक्षाएँ';

  @override
  String get productsScanLabel => 'लेबल स्कैन करें';

  @override
  String get productsSave => 'सहेजें';

  @override
  String get productsSectionBasics => 'मूल जानकारी';

  @override
  String get productsProductName => 'उत्पाद का नाम';

  @override
  String get productsNameHint => 'उदा. Boult Astra TWS ईयरबड्स';

  @override
  String get productsDescription => 'विवरण';

  @override
  String get productsDescriptionHint =>
      'यह क्या है इसके बारे में एक-दो पंक्तियाँ';

  @override
  String get productsBrand => 'ब्रांड';

  @override
  String get productsBrandHint => 'उदा. Boult — वैकल्पिक';

  @override
  String get productsSectionPrice => 'मूल्य';

  @override
  String get productsSellingPriceLabel => 'बिक्री मूल्य';

  @override
  String get productsSellingPriceHelper => 'ग्राहक जो चुकाता है';

  @override
  String get productsMrpHelper => 'काटा हुआ मूल्य';

  @override
  String get productsCostPrice => 'लागत मूल्य';

  @override
  String get productsCostPriceHelper => 'आप जो चुकाते हैं';

  @override
  String get productsGst => 'GST';

  @override
  String get productsOptional => 'वैकल्पिक';

  @override
  String get productsSectionIdentityStock => 'पहचान और स्टॉक';

  @override
  String get productsSkuHelper => 'आपका अपना उत्पाद कोड — अद्वितीय होना चाहिए';

  @override
  String get productsOpeningStock => 'प्रारंभिक स्टॉक';

  @override
  String get productsSectionMoreDetails => 'अधिक विवरण';

  @override
  String get productsMoreDetailsIntro =>
      'सभी वैकल्पिक। उत्पाद पृष्ठ को समृद्ध बनाने के लिए जितना चाहें जोड़ें — आप किसी भी समय वापस आ सकते हैं।';

  @override
  String get productsProductImages => 'उत्पाद चित्र';

  @override
  String get productsPickFromGallery => 'गैलरी';

  @override
  String get productsTakePhoto => 'कैमरा';

  @override
  String productsGalleryEmptyHint(Object count) {
    return 'एक साथ कई चित्र चुनने के लिए \"गैलरी से चुनें\" दबाएँ। प्रति उत्पाद अधिकतम $count।';
  }

  @override
  String productsGalleryCountHint(Object count, Object max) {
    return '$count/$max चित्र जोड़े गए।';
  }

  @override
  String get productsAddByImageLink => 'चित्र लिंक द्वारा जोड़ें';

  @override
  String get productsAddImageUrl => 'या चित्र URL पेस्ट करें';

  @override
  String get productsImageUrlHint => 'https://...';

  @override
  String get productsAddImage => 'चित्र जोड़ें';

  @override
  String get productsHighlightsTitle => 'मुख्य बातें';

  @override
  String get productsHighlightsSubtitle =>
      'ऊपर दिखाए जाने वाले संक्षिप्त बिक्री बिंदु';

  @override
  String get productsHighlightsIntro =>
      'उत्पाद पृष्ठ पर सबसे ऊपर दिखाए जाने वाले संक्षिप्त बुलेट बिंदु। अधिकतम 8।';

  @override
  String get productsSpecificationsTitle => 'विशिष्टताएँ';

  @override
  String get productsSpecificationsSubtitle =>
      'अनुभाग अनुसार समूहीकृत विस्तृत विशिष्टता शीट';

  @override
  String get productsSpecificationsIntro =>
      'विशेषताओं को अनुभाग अनुसार समूहित करें (उदा. \"डिस्प्ले\", \"कैमरा\")। प्रत्येक पंक्ति एक लेबल और एक मान है।';

  @override
  String get productsOffersTitle => 'ऑफ़र';

  @override
  String get productsOffersSubtitle => 'कूपन, EMI या एक्सचेंज ऑफ़र';

  @override
  String get productsOffersIntro =>
      'मूल्य के नीचे दिखाए जाने वाले बैंक, कूपन, EMI या एक्सचेंज ऑफ़र।';

  @override
  String get productsRichDescriptionTitle => 'समृद्ध उत्पाद विवरण';

  @override
  String get productsRichDescriptionSubtitle =>
      'हीरो चित्र, फ़ीचर, तुलना, गैलरी';

  @override
  String get productsRichDescriptionShort => 'समृद्ध विवरण';

  @override
  String get productsRichDescriptionIntro =>
      'उत्पाद पृष्ठ पर स्क्रॉल करने योग्य कहानी बनाएँ। अधिकतम 8 ब्लॉक जोड़ें और उन्हें क्रम में खींचें।';

  @override
  String get productsVariantsTitle => 'वेरिएंट';

  @override
  String get productsVariantsSubtitle => 'रंग, आकार और अन्य विकल्प';

  @override
  String get productsVariantsIntro =>
      'वैकल्पिक। अक्ष घोषित करें (रंग, आकार, …) और प्रत्येक संयोजन के लिए एक वेरिएंट जोड़ें। न करने पर एक डिफ़ॉल्ट वेरिएंट स्वतः बन जाता है।';

  @override
  String get productsTagsTitle => 'टैग';

  @override
  String get productsTagsSubtitle =>
      'कीवर्ड जो खरीदारों को इसे ढूँढने में मदद करते हैं';

  @override
  String get productsTagsIntro => 'अधिकतम 20। बेस्टसेलर, पर्यावरण-अनुकूल, आदि।';

  @override
  String get productsMoreAboutTitle => 'इस उत्पाद के बारे में अधिक';

  @override
  String get productsMoreAboutSubtitle => 'आपकी दुकान के अपने कस्टम फ़ील्ड';

  @override
  String get productsMoreAboutIntro =>
      'वारंटी, मॉडल नंबर या सामग्री जैसे दुकान-व्यापी फ़ील्ड — एक बार परिभाषित करें, हर उत्पाद पर पुनः उपयोग करें।';

  @override
  String get productsDone => 'हो गया';

  @override
  String get productsBarcodeHelper => 'पैकेज पर धारीदार कोड के नीचे की संख्या';

  @override
  String get productsHsnCodeHelper => 'चालानों के लिए कर वर्गीकरण कोड';

  @override
  String productsHsnRateFrom(String code) {
    return 'GST दर HSN $code से।';
  }

  @override
  String productsHsnRateFromHeading(String code) {
    return 'GST दर शीर्षक $code से अनुमानित — जाँच लें कि यह इस वस्तु पर लागू होती है।';
  }

  @override
  String get productsHsnRateUnknown =>
      'इस कोड के लिए कोई GST दर दर्ज नहीं है। कोड जाँचें, या दर स्वयं भरें।';

  @override
  String get productsLowStockThreshold => 'कम स्टॉक अलर्ट';

  @override
  String get productsLowStockThresholdHelper =>
      'स्टॉक इस स्तर तक गिरने पर हम उत्पाद को चिह्नित कर देंगे';

  @override
  String get productsAddTag => 'टैग जोड़ें';

  @override
  String get productsRemove => 'हटाएँ';

  @override
  String get productsAddHighlightHint => 'एक मुख्य बात जोड़ें…';

  @override
  String get productsAddSpecGroup => 'विशिष्टता समूह जोड़ें';

  @override
  String get productsGroupTitleLabel => 'समूह शीर्षक (उदा. डिस्प्ले)';

  @override
  String get productsRemoveGroup => 'समूह हटाएँ';

  @override
  String get productsTabLabel => 'टैब (वैकल्पिक — उदा. फ़ीचर और विशिष्टताएँ)';

  @override
  String get productsSpecLabelLabel => 'लेबल';

  @override
  String get productsSpecLabelHint => 'उदा. बॉक्स में';

  @override
  String get productsRemoveRow => 'पंक्ति हटाएँ';

  @override
  String get productsSpecValueLabel => 'मान';

  @override
  String get productsSpecValueHint =>
      'उदा. ईयरबड्स, चार्जिंग केस, केबल, मैनुअल';

  @override
  String get productsAddRow => 'पंक्ति जोड़ें';

  @override
  String get productsBankOffersNote =>
      'बैंक ऑफ़र प्लेटफ़ॉर्म-व्यापी हैं और केंद्रीय रूप से प्रबंधित होते हैं। यदि कोई प्लेटफ़ॉर्म ऑफ़र सक्रिय है तो ग्राहक इस उत्पाद के पृष्ठ पर HDFC / ICICI / SBI आदि देखेंगे।';

  @override
  String get productsAddOffer => 'ऑफ़र जोड़ें';

  @override
  String get productsOfferKind => 'प्रकार';

  @override
  String get productsOfferHeadline => 'शीर्षक';

  @override
  String get productsOfferHeadlineHint =>
      'उदा. कोड WELCOME के साथ ₹2000 की छूट';

  @override
  String get productsOfferDetail => 'विवरण (वैकल्पिक)';

  @override
  String get productsOfferCode => 'कोड (वैकल्पिक)';

  @override
  String get productsBlockHeroLabel => 'हीरो बैनर';

  @override
  String get productsBlockHeroHint => 'शीर्षक के साथ एक बड़ा चित्र';

  @override
  String get productsBlockFeatureLabel => 'फ़ीचर';

  @override
  String get productsBlockFeatureHint => 'शीर्षक + विवरण के बगल में चित्र';

  @override
  String get productsBlockComparisonLabel => 'तुलना तालिका';

  @override
  String get productsBlockComparisonHint => 'इसकी अन्य विकल्पों से तुलना करें';

  @override
  String get productsBlockGalleryLabel => 'गैलरी';

  @override
  String get productsBlockGalleryHint => 'कैप्शन के साथ चित्रों की एक पंक्ति';

  @override
  String get productsBlockTextLabel => 'टेक्स्ट';

  @override
  String get productsBlockTextHint => 'समृद्ध टेक्स्ट का एक अनुच्छेद';

  @override
  String get productsBlocksEmptyHint =>
      'एक समृद्ध उत्पाद कहानी बनाएँ जिसे खरीदार स्क्रॉल करें — शुरू करने के लिए एक ब्लॉक जोड़ें।';

  @override
  String productsBlockPosition(Object index, Object total) {
    return '$total में से $index';
  }

  @override
  String get productsMoveUp => 'ऊपर ले जाएँ';

  @override
  String get productsMoveDown => 'नीचे ले जाएँ';

  @override
  String get productsBannerImage => 'बैनर चित्र';

  @override
  String get productsHeadline => 'शीर्षक';

  @override
  String get productsSubtext => 'उप-पाठ (वैकल्पिक)';

  @override
  String get productsFeatureImage => 'फ़ीचर चित्र';

  @override
  String get productsImageOnThe => 'चित्र इस ओर ';

  @override
  String get productsSideLeft => 'बाएँ';

  @override
  String get productsSideRight => 'दाएँ';

  @override
  String get productsFieldTitle => 'शीर्षक';

  @override
  String productsImageN(Object index) {
    return 'चित्र $index';
  }

  @override
  String get productsCaption => 'कैप्शन (वैकल्पिक)';

  @override
  String get productsAddImageAction => 'चित्र जोड़ें';

  @override
  String get productsComparisonIntro =>
      'आप किसकी तुलना कर रहे हैं उसे नाम दें, फिर प्रत्येक फ़ीचर के लिए एक पंक्ति जोड़ें और हर कॉलम के नीचे एक सेल भरें।';

  @override
  String get productsColumns => 'कॉलम';

  @override
  String productsColumnNName(Object index) {
    return 'कॉलम $index नाम';
  }

  @override
  String get productsThisProductHint => 'यह उत्पाद';

  @override
  String get productsOtherCompetitorHint => 'अन्य / प्रतिस्पर्धी';

  @override
  String get productsRemoveColumn => 'कॉलम हटाएँ';

  @override
  String get productsAddColumn => 'कॉलम जोड़ें';

  @override
  String get productsRows => 'पंक्तियाँ';

  @override
  String get productsFeature => 'फ़ीचर';

  @override
  String get productsFeatureHint => 'उदा. बैटरी लाइफ़';

  @override
  String productsColumnN(Object index) {
    return 'कॉलम $index';
  }

  @override
  String get productsReplace => 'बदलें';

  @override
  String get productsUpload => 'अपलोड करें';

  @override
  String get productsHideLinkField => 'लिंक फ़ील्ड छिपाएँ';

  @override
  String get productsOrPasteLink => 'या एक लिंक पेस्ट करें';

  @override
  String get productsImageLinkUrl => 'चित्र लिंक (URL)';

  @override
  String get productsAxes => 'अक्ष';

  @override
  String get productsAddAxis => 'अक्ष जोड़ें (उदा. रंग, आकार)';

  @override
  String get productsVariantsLabel => 'वेरिएंट';

  @override
  String get productsAddVariant => 'वेरिएंट जोड़ें';

  @override
  String get productsAxisNameLabel => 'अक्ष नाम (उदा. रंग)';

  @override
  String productsValueN(Object index) {
    return 'मान $index';
  }

  @override
  String get productsAddValue => 'मान जोड़ें';

  @override
  String get productsAxisFallback => 'अक्ष';

  @override
  String get productsSellingShort => 'बिक्री';

  @override
  String get productsStockShort => 'स्टॉक';

  @override
  String get productsVariantImagesHint =>
      'इस सटीक वेरिएंट के लिए चित्र जोड़ें — यह किस रंग का दिखता है, कैसे फ़िट होता है। यह विकल्प चुनने वाले ग्राहक उत्पाद-स्तरीय गैलरी के बजाय इन्हें देखेंगे।';

  @override
  String get productsAddVariantImage => 'वेरिएंट चित्र जोड़ें';

  @override
  String get productsFromGallery => 'गैलरी से';

  @override
  String get productsTakePhotoMenu => 'फ़ोटो लें';

  @override
  String get productsAddShort => 'जोड़ें';

  @override
  String get productsAddPhotos => 'फ़ोटो जोड़ें';

  @override
  String get productsOutOfStockLabel => 'स्टॉक ख़त्म';

  @override
  String get productsReorderAt => 'पुनः ऑर्डर पर';

  @override
  String get productsInStockSuffix => 'स्टॉक में';

  @override
  String get productsOutSince => 'तब से समाप्त';

  @override
  String get productsLastIn => 'अंतिम इन:';

  @override
  String get productsCostPrefix => 'लागत';

  @override
  String get productsAboveMrp => 'M.R.P. से ऊपर';

  @override
  String get ordersTitle => 'ऑर्डर';

  @override
  String get ordersNoAccessTitle => 'ऑर्डर छिपे हैं';

  @override
  String get ordersTabPending => 'बाकी';

  @override
  String get ordersTabConfirmed => 'पक्के';

  @override
  String get ordersTabRejected => 'अस्वीकृत';

  @override
  String get ordersTabAll => 'सभी';

  @override
  String get ordersSearchHint => 'ग्राहक, आइटम या #id खोजें';

  @override
  String get ordersAnyDate => 'कोई भी तारीख';

  @override
  String get ordersItemUnit => 'आइटम';

  @override
  String get ordersItemsUnit => 'आइटम';

  @override
  String get ordersAllCaughtUp => 'सब पूरा हो गया';

  @override
  String get ordersAllCaughtUpHint => 'नए ऑर्डर यहाँ दिखेंगे।';

  @override
  String get ordersNoMatching => 'कोई मिलता-जुलता ऑर्डर नहीं';

  @override
  String get ordersNoMatchingHint => 'अलग खोज या तारीख सीमा आज़माएँ।';

  @override
  String get ordersNoneYet => 'अभी यहाँ कोई ऑर्डर नहीं';

  @override
  String get ordersNoneYetHint => 'ग्राहक जब ऑर्डर देंगे तो वे यहाँ दिखेंगे।';

  @override
  String get ordersError => 'कुछ गड़बड़ हो गई';

  @override
  String get ordersRetry => 'फिर से कोशिश करें';

  @override
  String ordersDetailTitle(Object id) {
    return 'ऑर्डर #$id';
  }

  @override
  String get ordersActionShare => 'ऑर्डर सारांश साझा करें';

  @override
  String get ordersManageWhat => 'ऑर्डर प्रबंधित करना';

  @override
  String get ordersDecline => 'अस्वीकार करें';

  @override
  String get ordersConfirmAndCreateInvoice => 'पक्का करें और चालान बनाएँ';

  @override
  String ordersInvoiceCreated(Object no) {
    return 'चालान $no बन गया';
  }

  @override
  String get ordersDeclinedToast => 'ऑर्डर अस्वीकृत';

  @override
  String get ordersShippingPosted => 'शिपिंग अपडेट दर्ज हुआ';

  @override
  String ordersStockPosted(Object name) {
    return '$name का स्टॉक दर्ज हुआ';
  }

  @override
  String get ordersCouldNotOpenApp => 'वह ऐप नहीं खुल सकी';

  @override
  String ordersWhatsappGreeting(Object name, Object id) {
    return 'नमस्ते $name, आपके ऑर्डर #$id के बारे में।';
  }

  @override
  String ordersEmailSubject(Object id) {
    return 'ऑर्डर #$id';
  }

  @override
  String ordersShareHeader(Object id, Object name) {
    return '$name का ऑर्डर #$id';
  }

  @override
  String get ordersJustNow => 'अभी-अभी';

  @override
  String ordersMinAgo(Object n) {
    return '$n मिनट पहले';
  }

  @override
  String ordersHrAgo(Object n) {
    return '$n घंटे पहले';
  }

  @override
  String ordersDayAgo(Object n) {
    return '$n दिन पहले';
  }

  @override
  String get ordersSummaryItemsLabel => 'आइटम';

  @override
  String get ordersSummaryQtyLabel => 'कुल मात्रा';

  @override
  String get ordersSummaryTotalLabel => 'अनुमानित';

  @override
  String ordersShortfallTitle(Object short, Object total) {
    return '$total में से $short आइटम स्टॉक में कम हैं';
  }

  @override
  String get ordersShortfallBody =>
      'अभी स्टॉक भरें या अस्वीकार करें — वरना चालान दर्ज नहीं होगा।';

  @override
  String get ordersRestock => 'स्टॉक भरें';

  @override
  String get ordersLinkedParty => 'जुड़ा पक्ष';

  @override
  String get ordersCall => 'कॉल करें';

  @override
  String get ordersWhatsapp => 'WhatsApp';

  @override
  String get ordersEmail => 'ईमेल';

  @override
  String get ordersCustomerNote => 'ग्राहक का नोट';

  @override
  String get ordersJourneyPlaced => 'दिया गया';

  @override
  String get ordersJourneyDeclined => 'अस्वीकृत';

  @override
  String get ordersJourneyCancelled => 'रद्द';

  @override
  String get ordersJourneyConfirmed => 'पक्का';

  @override
  String get ordersJourneyInvoiced => 'चालान बना';

  @override
  String get ordersJourneyPaid => 'भुगतान हुआ';

  @override
  String get ordersInactiveProduct => 'निष्क्रिय उत्पाद';

  @override
  String get ordersStockUnknown => 'स्टॉक अज्ञात';

  @override
  String ordersStockOk(Object ask, Object have, Object unit) {
    return 'माँगा $ask · स्टॉक में $have $unit';
  }

  @override
  String ordersStockShort(Object ask, Object have, Object short) {
    return 'माँगा $ask · स्टॉक में $have · कमी $short';
  }

  @override
  String get ordersTotalsSubtotal => 'उप-योग';

  @override
  String get ordersTotalsTax => 'कर';

  @override
  String get ordersTotalsDiscount => 'छूट';

  @override
  String get ordersTotalsTotal => 'कुल';

  @override
  String get ordersPartialFulfillFootnote =>
      'अगर आप आंशिक पूर्ति करते हैं तो अंतिम चालान अलग हो सकता है।';

  @override
  String ordersOpenInvoice(Object no) {
    return 'चालान $no खोलें';
  }

  @override
  String get ordersConfirmShortfallTitle =>
      'स्टॉक कम लग रहा है — फिर भी पक्का करें?';

  @override
  String get ordersConfirmOrderTitle => 'यह ऑर्डर पक्का करें?';

  @override
  String get ordersConfirmShortfallWarning =>
      'कुछ आइटम का स्टॉक ग्राहक की माँग से कम है। पक्का करते समय ड्राफ्ट चालान दर्ज नहीं होगा।';

  @override
  String get ordersConfirmOrderBody =>
      'इससे आइटम के लिए एक ड्राफ्ट बिक्री चालान बनता है। चालान पक्का करने पर ही स्टॉक घटेगा।';

  @override
  String get ordersNotYet => 'अभी नहीं';

  @override
  String get ordersConfirmOrder => 'ऑर्डर पक्का करें';

  @override
  String get ordersDeclineReasonOutOfStock => 'स्टॉक खत्म';

  @override
  String get ordersDeclineReasonClosed => 'आज बंद';

  @override
  String get ordersDeclineReasonPriceChanged => 'कीमत बदली';

  @override
  String get ordersDeclineReasonOther => 'अन्य';

  @override
  String get ordersDeclineOrderTitle => 'यह ऑर्डर अस्वीकार करें?';

  @override
  String get ordersDeclineOrderBody =>
      'ग्राहक को सूचित किया जाएगा। आप कारण बताते हुए नोट छोड़ सकते हैं।';

  @override
  String get ordersDeclineOrderNoteHint => 'कारण (वैकल्पिक)';

  @override
  String get ordersKeep => 'रखें';

  @override
  String get ordersDeclineOrder => 'ऑर्डर अस्वीकार करें';

  @override
  String get ordersShippingUpdates => 'शिपिंग अपडेट';

  @override
  String get ordersUpdateShipping => 'शिपिंग अपडेट करें';

  @override
  String get ordersNoShippingUpdates => 'अभी कोई शिपिंग अपडेट नहीं।';

  @override
  String get ordersMilestonePacked => 'पैक किया';

  @override
  String get ordersMilestoneShipped => 'भेजा गया';

  @override
  String get ordersMilestoneOutForDelivery => 'डिलीवरी के लिए निकला';

  @override
  String get ordersMilestoneDelivered => 'पहुँचाया गया';

  @override
  String get ordersMilestoneReturned => 'वापस किया';

  @override
  String get ordersShippingSheetBody =>
      'ग्राहक को अपने ऑर्डर पर ये अपडेट दिखते हैं। Delivered चुनने पर उनकी वापसी अवधि शुरू हो जाती है।';

  @override
  String get ordersCourierHint => 'कूरियर (वैकल्पिक), जैसे Delhivery';

  @override
  String get ordersAwbHint => 'AWB / ट्रैकिंग नंबर (वैकल्पिक)';

  @override
  String get ordersEtaHint => 'अनुमानित समय (वैकल्पिक)';

  @override
  String get ordersClearEta => 'अनुमानित समय हटाएँ';

  @override
  String get ordersNoteHint => 'नोट (वैकल्पिक)';

  @override
  String get ordersCancel => 'रद्द करें';

  @override
  String get ordersSaveUpdate => 'अपडेट सहेजें';

  @override
  String get ordersStockDraftPendingOne => '1 स्टॉक ड्राफ्ट बाकी';

  @override
  String ordersStockDraftPendingMany(Object count) {
    return '$count स्टॉक ड्राफ्ट बाकी';
  }

  @override
  String get ordersStockDraftHint =>
      'स्टॉक दर्ज करने के लिए पक्का करें — तब तक कमी बनी रहेगी।';

  @override
  String ordersDraftInvoiceNo(Object no) {
    return 'ड्राफ्ट चालान #$no';
  }

  @override
  String get ordersOpenDraft => 'ड्राफ्ट खोलें';

  @override
  String get ordersConfirm => 'पक्का करें';

  @override
  String get ordersHide => 'छिपाएँ';

  @override
  String get invoicesNavTitle => 'चालान';

  @override
  String get invoicesCreateTitle => 'चालान बनाएं';

  @override
  String get invoicesSearchHint => 'चालान नंबर, पार्टी, वेंडर खोजें';

  @override
  String get invoicesSearchTooltip => 'खोजें';

  @override
  String get invoicesFiltersTooltip => 'फ़िल्टर';

  @override
  String get invoicesFilterAll => 'सभी';

  @override
  String get invoicesFilterSales => 'बिक्री';

  @override
  String get invoicesFilterPurchases => 'खरीद';

  @override
  String get invoicesFilterDateRange => 'दिनांक सीमा';

  @override
  String get invoicesErrorTitle => 'कुछ गड़बड़ हो गई';

  @override
  String get invoicesRetry => 'पुनः प्रयास करें';

  @override
  String get invoicesEmptyTitle => 'कोई चालान नहीं मिला';

  @override
  String get invoicesEmptyBody => 'शुरू करने के लिए अपना पहला चालान बनाएं';

  @override
  String get invoicesGeneratingPdf => 'PDF बन रहा है...';

  @override
  String get invoicesItemUnit => 'वस्तु';

  @override
  String get invoicesItemsUnit => 'वस्तुएं';

  @override
  String get invoicesDownloadTooltip => 'चालान डाउनलोड करें';

  @override
  String get invoicesDocTaxInvoice => 'टैक्स चालान';

  @override
  String get invoicesDocBillOfSupply => 'बिल ऑफ सप्लाई';

  @override
  String get invoicesDocEstimate => 'अनुमान';

  @override
  String get invoicesDocProforma => 'प्रोफ़ॉर्मा';

  @override
  String get invoicesDocCreditNote => 'क्रेडिट नोट';

  @override
  String get invoicesDocDebitNote => 'डेबिट नोट';

  @override
  String get invoicesStatusDraft => 'ड्राफ़्ट';

  @override
  String get invoicesStatusConfirmed => 'पुष्ट';

  @override
  String get invoicesStatusCancelled => 'रद्द';

  @override
  String get invoicesFilterAllDocuments => 'सभी दस्तावेज़';

  @override
  String get invoicesFilterAnyStatus => 'कोई भी स्थिति';

  @override
  String get invoicesFiltersTitle => 'फ़िल्टर';

  @override
  String get invoicesDocumentTypeLabel => 'दस्तावेज़ का प्रकार';

  @override
  String get invoicesStatusLabel => 'स्थिति';

  @override
  String get invoicesClearAll => 'सभी हटाएं';

  @override
  String get invoicesApply => 'लागू करें';

  @override
  String get invoicesEditDraftTitle => 'ड्राफ़्ट संपादित करें';

  @override
  String get invoicesSaveAsDraft => 'ड्राफ़्ट के रूप में सहेजें';

  @override
  String get invoicesUpdateDraft => 'ड्राफ़्ट अपडेट करें';

  @override
  String get invoicesSaveAndConfirm => 'सहेजें और पुष्टि करें';

  @override
  String get invoicesUpdateAndConfirm => 'अपडेट करें और पुष्टि करें';

  @override
  String get invoicesInvoiceType => 'चालान का प्रकार';

  @override
  String get invoicesSaleInvoice => 'बिक्री चालान';

  @override
  String get invoicesPurchaseInvoice => 'खरीद चालान';

  @override
  String get invoicesCustomerInfo => 'ग्राहक की जानकारी';

  @override
  String get invoicesVendorInfo => 'वेंडर की जानकारी';

  @override
  String get invoicesSelectVendor => 'वेंडर चुनें';

  @override
  String get invoicesSelectParty => 'पार्टी चुनें';

  @override
  String get invoicesCustomerName => 'ग्राहक का नाम';

  @override
  String get invoicesPhone => 'फ़ोन';

  @override
  String get invoicesGstin => 'GSTIN';

  @override
  String get invoicesPlaceOfSupply => 'आपूर्ति का स्थान (राज्य)';

  @override
  String get invoicesPlaceOfSupplyHelper =>
      'खरीदार का राज्य — CGST/SGST या IGST तय करता है';

  @override
  String get invoicesSelectDash => '— चुनें —';

  @override
  String get invoicesInvoiceItems => 'चालान की वस्तुएं';

  @override
  String get invoicesSearchToAddProduct => 'जोड़ने के लिए उत्पाद खोजें';

  @override
  String get invoicesScanBarcode => 'बारकोड स्कैन करें';

  @override
  String get invoicesNoItemsYet => 'अभी तक कोई वस्तु नहीं जोड़ी गई';

  @override
  String get invoicesTotals => 'कुल योग';

  @override
  String get invoicesPricesIncludeGst => 'कीमतों में GST शामिल है';

  @override
  String get invoicesPricesInclusiveHint =>
      'दर्ज कीमतों में से टैक्स निकाला जाता है';

  @override
  String get invoicesPricesExclusiveHint =>
      'दर्ज कीमतों के ऊपर GST जोड़ा जाता है';

  @override
  String get invoicesSubtotal => 'उप-योग';

  @override
  String get invoicesDiscount => 'छूट';

  @override
  String get invoicesRoundOff => 'राउंड-ऑफ';

  @override
  String get invoicesGrandTotal => 'कुल योग';

  @override
  String get invoicesNote => 'टिप्पणी';

  @override
  String get invoicesChange => 'बदलें';

  @override
  String get invoicesQuantity => 'मात्रा';

  @override
  String get invoicesUnitPrice => 'इकाई मूल्य';

  @override
  String get invoicesTax => 'टैक्स';

  @override
  String get invoicesTotal => 'कुल';

  @override
  String get invoicesNeedsItems => 'कृपया कम से कम एक वस्तु जोड़ें';

  @override
  String get invoicesUpdatedAndConfirmed => 'चालान अपडेट और पुष्ट किया गया';

  @override
  String get invoicesSavedAsDraft => 'ड्राफ़्ट के रूप में सहेजा गया';

  @override
  String invoicesConfirmedNamed(Object invoiceNo) {
    return '$invoiceNo पुष्ट किया गया';
  }

  @override
  String get invoicesSavedDraftConfirmFailed =>
      'ड्राफ़्ट के रूप में सहेजा गया — पुष्टि विफल, कृपया समीक्षा करें।';

  @override
  String get invoicesDiscardChangesTitle => 'बदलाव छोड़ें?';

  @override
  String get invoicesDiscardChangesBody => 'आपके बदलाव खो जाएंगे।';

  @override
  String get invoicesKeepEditing => 'संपादन जारी रखें';

  @override
  String get invoicesDiscard => 'छोड़ें';

  @override
  String get invoicesErrorTitle2Unused => 'unused';

  @override
  String get invoicesPaymentModeOnline => 'ऑनलाइन';

  @override
  String get invoicesPaymentModeCash => 'नकद';

  @override
  String get invoicesPaymentModeCheque => 'चेक';

  @override
  String get invoicesPaymentModeCard => 'कार्ड';

  @override
  String get invoicesCouldNotOpenWhatsApp => 'WhatsApp नहीं खुल सका';

  @override
  String get invoicesConvertTitle => 'चालान में बदलें?';

  @override
  String invoicesConvertBody(Object invoiceNo) {
    return '$invoiceNo से एक नया टैक्स चालान बनाया जाएगा। अनुमान फ़ाइल में अपरिवर्तित रहेगा।';
  }

  @override
  String get invoicesCancel => 'रद्द करें';

  @override
  String get invoicesConvert => 'बदलें';

  @override
  String invoicesCancelledNamed(Object invoiceNo) {
    return '$invoiceNo रद्द किया गया';
  }

  @override
  String get invoicesCancelInvoice => 'चालान रद्द करें';

  @override
  String invoicesCancelConfirmBody(Object invoiceNo) {
    return '$invoiceNo रद्द करें? कोई स्टॉक नहीं हटेगा और चालान रद्द के रूप में चिह्नित होगा।';
  }

  @override
  String get invoicesKeepDraft => 'ड्राफ़्ट रखें';

  @override
  String get invoicesEdit => 'संपादित करें';

  @override
  String get invoicesShare => 'साझा करें';

  @override
  String get invoicesDelete => 'हटाएं';

  @override
  String invoicesDeleteConfirmBody(Object invoiceNo) {
    return '$invoiceNo हटाएं? इसे पूर्ववत नहीं किया जा सकता।';
  }

  @override
  String invoicesDeletedNamed(Object invoiceNo) {
    return '$invoiceNo हटाया गया';
  }

  @override
  String get invoicesCustomer => 'ग्राहक';

  @override
  String get invoicesVendor => 'वेंडर';

  @override
  String get invoicesAddress => 'पता';

  @override
  String get invoicesTaxAmount => 'टैक्स राशि';

  @override
  String get invoicesCess => 'सेस';

  @override
  String get invoicesReceived => 'प्राप्त';

  @override
  String get invoicesOutstanding => 'बकाया';

  @override
  String get invoicesPaymentsReceivedTitle => 'प्राप्त भुगतान';

  @override
  String get invoicesSendViaWhatsApp => 'WhatsApp से भेजें';

  @override
  String invoicesOpensChatWith(Object phone) {
    return '$phone के साथ चैट खोलता है';
  }

  @override
  String get invoicesPickChatToSend => 'भेजने के लिए एक चैट चुनें';

  @override
  String get invoicesConvertToInvoice => 'चालान में बदलें';

  @override
  String get invoicesConvertTileSubtitle => 'इस अनुमान से एक टैक्स चालान बनाएं';

  @override
  String get invoicesMarkAsPaid => 'भुगतान के रूप में चिह्नित करें';

  @override
  String get invoicesRecordReceiptSubtitle => 'इस चालान के लिए रसीद दर्ज करें';

  @override
  String get invoicesRecordPaymentSubtitle => 'इस बिल के लिए भुगतान दर्ज करें';

  @override
  String get invoicesPaymentRecorded => 'भुगतान दर्ज किया गया';

  @override
  String get invoicesConfirmInvoice => 'चालान की पुष्टि करें';

  @override
  String get invoicesIssueNoteAction => 'क्रेडिट / डेबिट नोट जारी करें';

  @override
  String get invoicesIssueNoteActionSubtitle =>
      'इस पुष्ट बिक्री को क्रेडिट या डेबिट नोट से समायोजित करें';

  @override
  String get invoicesIssueNoteTitle => 'नोट जारी करें';

  @override
  String get invoicesCreditNoteExplainer =>
      'ग्राहक की देय राशि घटाता है। लौटाया गया माल वापस स्टॉक में जोड़ा जा सकता है।';

  @override
  String get invoicesDebitNoteExplainer =>
      'ग्राहक से अतिरिक्त राशि वसूलता है — जैसे कम शुल्क का सुधार।';

  @override
  String get invoicesNoteReturnToStock => 'माल वापस स्टॉक में करें';

  @override
  String get invoicesNoteReason => 'कारण (वैकल्पिक)';

  @override
  String get invoicesNoteExtraPerUnit => 'प्रति इकाई अतिरिक्त';

  @override
  String get invoicesIssueCreditNote => 'क्रेडिट नोट जारी करें';

  @override
  String get invoicesIssueDebitNote => 'डेबिट नोट जारी करें';

  @override
  String get invoicesNoteSelectLines => 'नोट में कम से कम एक पंक्ति जोड़ें';

  @override
  String invoicesNoteSoldQty(Object qty) {
    return 'बेचा गया $qty';
  }

  @override
  String invoicesNoteIssued(Object noteNo) {
    return '$noteNo जारी किया गया';
  }

  @override
  String invoicesNoteAgainst(Object invoiceNo) {
    return '$invoiceNo के विरुद्ध';
  }

  @override
  String invoicesNoteApproxTotal(Object amount) {
    return 'अनुमानित कुल $amount';
  }

  @override
  String get partiesTitle => 'पार्टियाँ';

  @override
  String get partiesAddParty => 'पार्टी जोड़ें';

  @override
  String get partiesEditParty => 'पार्टी संपादित करें';

  @override
  String get partiesDeleteParty => 'पार्टी हटाएँ';

  @override
  String partiesDeletePartyConfirm(Object name) {
    return 'क्या आप वाकई इस पार्टी को हटाना चाहते हैं? \"$name\"?';
  }

  @override
  String get partiesPartyDeleted => 'पार्टी सफलतापूर्वक हटा दी गई';

  @override
  String get partiesSearchParties => 'पार्टियाँ खोजें...';

  @override
  String get partiesNoParties => 'कोई पार्टी नहीं मिली';

  @override
  String get partiesNoPartiesHint => 'अपनी पहली पार्टी जोड़ने के लिए + दबाएँ';

  @override
  String get partiesSelectParty => 'पार्टी चुनें';

  @override
  String get partiesNewParty => 'नई पार्टी';

  @override
  String get partiesPartyName => 'पार्टी का नाम';

  @override
  String get partiesContactName => 'संपर्क का नाम';

  @override
  String get partiesPhone => 'फ़ोन';

  @override
  String get partiesEmail => 'ईमेल';

  @override
  String get partiesGstin => 'GSTIN';

  @override
  String get partiesAddress => 'पता';

  @override
  String get partiesCity => 'शहर';

  @override
  String get partiesPinCode => 'PIN कोड';

  @override
  String get partiesState => 'राज्य';

  @override
  String get partiesSelectPlaceholder => '— चुनें —';

  @override
  String get partiesSave => 'सहेजें';

  @override
  String get partiesEdit => 'संपादित करें';

  @override
  String get partiesDelete => 'हटाएँ';

  @override
  String get partiesConfirm => 'पुष्टि करें';

  @override
  String get partiesFieldRequired => 'यह फ़ील्ड आवश्यक है';

  @override
  String partiesPartyUpdated(Object name) {
    return '$name अपडेट किया गया';
  }

  @override
  String partiesPartyAdded(Object name) {
    return '$name जोड़ा गया';
  }

  @override
  String get partiesCancelInvitationTitle => 'आमंत्रण रद्द करें';

  @override
  String get partiesCancelInvitationBody =>
      'इस लंबित आमंत्रण को रद्द करें? आप बाद में नया भेज सकते हैं।';

  @override
  String get partiesInvitationCancelled => 'आमंत्रण रद्द किया गया';

  @override
  String get partiesAlreadyLinked => 'पहले से जुड़ा हुआ';

  @override
  String get partiesInviteToShopxy => 'ShopXY पर आमंत्रित करें';

  @override
  String get partiesAddEmailFirst => 'पहले एक ईमेल जोड़ें';

  @override
  String partiesSentTo(Object email) {
    return '$email को भेजा गया';
  }

  @override
  String get partiesGstinLabel => 'GSTIN';

  @override
  String get partiesChallansUnit => 'चालान';

  @override
  String get partiesInvoicesUnit => 'इनवॉइस';

  @override
  String get partiesItemsUnit => 'आइटम';

  @override
  String get partiesBillsUnit => 'बिल';

  @override
  String get partiesInviteStatusInvited => 'आमंत्रित';

  @override
  String get partiesInviteStatusLinked => 'जुड़ा हुआ';

  @override
  String get partiesInviteStatusDeclined => 'अस्वीकृत';

  @override
  String get partiesInviteStatusCancelled => 'रद्द';

  @override
  String get partiesInviteStatusExpired => 'समाप्त';

  @override
  String get partiesPartyTitle => 'पार्टी';

  @override
  String get partiesRecordPayment => 'भुगतान दर्ज करें';

  @override
  String get partiesLedger => 'बहीखाता';

  @override
  String get partiesRecentInvoices => 'हाल के इनवॉइस';

  @override
  String get partiesRecentChallans => 'हाल के चालान';

  @override
  String get partiesNoActivityYet => 'अभी तक कोई गतिविधि नहीं।';

  @override
  String get partiesNetBilled => 'कुल बिल';

  @override
  String get partiesSales => 'बिक्री';

  @override
  String get partiesReturns => 'वापसी';

  @override
  String get partiesBalance => 'शेष';

  @override
  String get partiesBalanceShort => 'शेष';

  @override
  String get partiesNoOutstanding => 'कोई बकाया नहीं';

  @override
  String get partiesOwesYou => 'आपको देना है';

  @override
  String get partiesAdvanceCredit => 'अग्रिम / क्रेडिट';

  @override
  String get vendorsTitle => 'वेंडर';

  @override
  String get vendorsAddVendor => 'वेंडर जोड़ें';

  @override
  String get vendorsEditVendor => 'वेंडर संपादित करें';

  @override
  String get vendorsDeleteVendor => 'वेंडर हटाएं';

  @override
  String get vendorsDeleteVendorConfirm =>
      'क्या आप वाकई इस वेंडर को हटाना चाहते हैं?';

  @override
  String get vendorsVendorDeleted => 'वेंडर सफलतापूर्वक हटाया गया';

  @override
  String get vendorsSearchHint => 'वेंडर खोजें...';

  @override
  String get vendorsEmptyTitle => 'कोई वेंडर नहीं मिला';

  @override
  String get vendorsEmptyHint => 'अपना पहला वेंडर जोड़ने के लिए + दबाएं';

  @override
  String get vendorsVendorName => 'वेंडर का नाम';

  @override
  String get vendorsContactName => 'संपर्क व्यक्ति का नाम';

  @override
  String get vendorsPhone => 'फ़ोन';

  @override
  String get vendorsEmail => 'ईमेल';

  @override
  String get vendorsGstin => 'GSTIN';

  @override
  String get vendorsAddress => 'पता';

  @override
  String get vendorsCity => 'शहर';

  @override
  String get vendorsPinCode => 'पिन कोड';

  @override
  String get vendorsState => 'राज्य';

  @override
  String get vendorsStateSelect => '— चुनें —';

  @override
  String get vendorsSave => 'सहेजें';

  @override
  String get vendorsDelete => 'हटाएं';

  @override
  String get vendorsEdit => 'संपादित करें';

  @override
  String get vendorsConfirm => 'पुष्टि करें';

  @override
  String get vendorsFieldRequired => 'यह फ़ील्ड आवश्यक है';

  @override
  String get vendorsSelectVendor => 'वेंडर चुनें';

  @override
  String get vendorsNewVendor => 'नया वेंडर';

  @override
  String get vendorsTxnsUnit => 'लेन-देन';

  @override
  String get vendorsInvoicesUnit => 'इनवॉइस';

  @override
  String get vendorsCancelInviteTitle => 'निमंत्रण रद्द करें';

  @override
  String get vendorsCancelInviteMessage =>
      'क्या इस लंबित निमंत्रण को रद्द करें? आप बाद में नया भेज सकते हैं।';

  @override
  String get vendorsInviteCancelled => 'निमंत्रण रद्द किया गया';

  @override
  String get vendorsAlreadyLinked => 'पहले से जुड़ा हुआ';

  @override
  String get vendorsInviteToShopxy => 'ShopXY में आमंत्रित करें';

  @override
  String get vendorsAddEmailFirst => 'पहले एक ईमेल जोड़ें';

  @override
  String get vendorsCancelInvitation => 'निमंत्रण रद्द करें';

  @override
  String get vendorsSentTo => 'भेजा गया';

  @override
  String get vendorsInviteStatusInvited => 'आमंत्रित';

  @override
  String get vendorsInviteStatusLinked => 'जुड़ा हुआ';

  @override
  String get vendorsInviteStatusDeclined => 'अस्वीकृत';

  @override
  String get vendorsInviteStatusCancelled => 'रद्द किया गया';

  @override
  String get vendorsInviteStatusExpired => 'समय-सीमा समाप्त';

  @override
  String get vendorsDetailTitle => 'वेंडर';

  @override
  String get vendorsRecordPayment => 'भुगतान दर्ज करें';

  @override
  String get vendorsLedger => 'बही-खाता';

  @override
  String get vendorsRecentBills => 'हाल के बिल';

  @override
  String get vendorsRecentStockIn => 'हाल की स्टॉक-इन';

  @override
  String get vendorsNoActivity => 'अभी तक कोई गतिविधि नहीं।';

  @override
  String get vendorsLinked => 'जुड़ा हुआ';

  @override
  String get vendorsNetPurchased => 'कुल खरीद';

  @override
  String get vendorsBillsUnit => 'बिल';

  @override
  String get vendorsStockIns => 'स्टॉक-इन';

  @override
  String get vendorsLedgerRows => 'बही-खाता प्रविष्टियां';

  @override
  String get vendorsReturns => 'वापसी';

  @override
  String get vendorsItemUnit => 'आइटम';

  @override
  String get vendorsItemsUnit => 'आइटम';

  @override
  String get vendorsNoOutstanding => 'कोई बकाया नहीं';

  @override
  String get vendorsYouOwe => 'आपको देना है';

  @override
  String get vendorsAdvanceWithVendor => 'वेंडर के पास एडवांस';

  @override
  String get vendorsBalanceLabel => 'बैलेंस';

  @override
  String get vendorsBalShort => 'बैलेंस';

  @override
  String get profileNavProfile => 'प्रोफ़ाइल';

  @override
  String get profileSettings => 'सेटिंग्स';

  @override
  String get profileEditProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get profileAppTagline => 'स्मार्ट इन्वेंटरी प्रबंधन';

  @override
  String get profileMemberSince => 'सदस्य';

  @override
  String get profileManageBusiness => 'अपना व्यवसाय प्रबंधित करें';

  @override
  String get profileNavCategories => 'श्रेणियाँ';

  @override
  String get profileCategoriesSubtitle => 'उत्पाद श्रेणियाँ और समूहन';

  @override
  String get profileNavVendors => 'विक्रेता';

  @override
  String get profileVendorsSubtitle => 'जिनसे आप खरीदते हैं';

  @override
  String get profileNavParties => 'पार्टियाँ';

  @override
  String get profilePartiesSubtitle => 'जिन्हें आप बेचते हैं';

  @override
  String get profileOperations => 'संचालन';

  @override
  String get profileNavInvoices => 'इनवॉइस';

  @override
  String get profileInvoicesSubtitle => 'बिक्री, खरीद और क्रेडिट नोट';

  @override
  String get profileNavChallans => 'चालान';

  @override
  String get profileChallansSubtitle => 'बिना कीमत वाले डिलीवरी नोट';

  @override
  String get profileStockAdjustments => 'स्टॉक समायोजन';

  @override
  String get profileStockAdjustmentsSubtitle => 'क्षति, समाप्ति, कमी सुधार';

  @override
  String get profileReports => 'रिपोर्ट';

  @override
  String get profileReportsSubtitle => 'बिक्री, खरीद, GST और लाभ-हानि';

  @override
  String get profileFinishShopSetup => 'अपनी दुकान का सेटअप पूरा करें';

  @override
  String get profileFinishShopSetupBody =>
      'इनवॉइस सही छपें इसके लिए अपनी दुकान का नाम, GSTIN और राज्य जोड़ें।';

  @override
  String get profilePersonalDetails => 'व्यक्तिगत विवरण';

  @override
  String get profileNotAdded => 'नहीं जोड़ा गया';

  @override
  String get profileCopied => 'क्लिपबोर्ड पर कॉपी किया गया';

  @override
  String get profileFieldName => 'नाम';

  @override
  String get profileFieldPhoto => 'फ़ोटो';

  @override
  String get profileFieldPhone => 'फ़ोन';

  @override
  String get profileFieldShopName => 'दुकान का नाम';

  @override
  String get profileFieldAddress => 'पता';

  @override
  String get profileFieldCity => 'शहर';

  @override
  String get profileFieldState => 'राज्य';

  @override
  String get profileFieldStateCode => 'राज्य कोड';

  @override
  String get profileFieldPinCode => 'PIN कोड';

  @override
  String get profileFieldGstin => 'GSTIN';

  @override
  String get profileFieldPan => 'PAN';

  @override
  String get profileFieldUpiId => 'UPI ID';

  @override
  String get profileCompletionTitle => 'प्रोफ़ाइल पूर्ण';

  @override
  String get profileCompletionDetailsAdded => 'विवरण जोड़े गए।';

  @override
  String get profileCompleteIt => 'पूरा करें';

  @override
  String get profileWhatsLeft => 'क्या बाकी है';

  @override
  String get profileRoleOwner => 'मालिक';

  @override
  String get profileRoleManager => 'प्रबंधक';

  @override
  String get profileRoleStockist => 'स्टॉकिस्ट';

  @override
  String get profileRoleCashier => 'कैशियर';

  @override
  String get profileRoleStaff => 'स्टाफ़';

  @override
  String get profileChangePassword => 'पासवर्ड बदलें';

  @override
  String get profileCurrentPassword => 'वर्तमान पासवर्ड';

  @override
  String get profileNewPassword => 'नया पासवर्ड';

  @override
  String get profileConfirmNewPassword => 'नया पासवर्ड पुष्टि करें';

  @override
  String get profilePasswordHelper =>
      '8+ अक्षर, कम से कम एक अक्षर और एक अंक शामिल हों';

  @override
  String get profilePasswordMinLength => 'कम से कम 8 अक्षर होने चाहिए';

  @override
  String get profilePasswordNeedsLetter => 'एक अक्षर होना ज़रूरी है';

  @override
  String get profilePasswordNeedsNumber => 'एक अंक होना ज़रूरी है';

  @override
  String get profilePasswordsDoNotMatch => 'पासवर्ड मेल नहीं खाते';

  @override
  String get profilePasswordChanged =>
      'पासवर्ड बदल गया। मौजूदा सत्र रद्द कर दिए गए।';

  @override
  String get profileRequired => 'आवश्यक';

  @override
  String get profilePrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get profileTermsOfService => 'सेवा की शर्तें';

  @override
  String get profilePrivacyBody =>
      'ShopXY भारत के डिजिटल व्यक्तिगत डेटा संरक्षण अधिनियम, 2023 (DPDP) के तहत एक डेटा फ़िड्यूशरी है। यह सूचना बताती है कि हम क्या एकत्र करते हैं, क्यों, और आपके डेटा पर आपके क्या अधिकार हैं।\n\nहम क्या रखते हैं\nहम आपकी दुकान चलाने के लिए ज़रूरी न्यूनतम डेटा संग्रहीत करते हैं: खाता क्रेडेंशियल, आपके उत्पाद/विक्रेता/पार्टी रिकॉर्ड, आपके बनाए इनवॉइस और भुगतान, सूचना प्राथमिकताएँ, और सहमति के टाइमस्टैम्प। हम आपका डेटा नहीं बेचते और सेवा चलाने के लिए (होस्टिंग, त्रुटि निगरानी) या भारतीय कानून द्वारा अपेक्षित के अलावा इसे तीसरे पक्षों के साथ साझा नहीं करते।\n\nडेटा स्थानीयकरण\nआपका डेटा लागू RBI / क्षेत्रीय दिशानिर्देशों के अनुरूप भारत में स्थित सर्वरों पर संग्रहीत होता है। बैकअप एन्क्रिप्टेड होते हैं और उसी अधिकार-क्षेत्र में रखे जाते हैं।\n\nप्रतिधारण\nवित्तीय रिकॉर्ड — इनवॉइस, भुगतान और सहायक बहीखाते — कंपनी अधिनियम, 2013 (§128) और GST अधिनियम (§36) के अनुपालन के लिए कम से कम 8 वित्तीय वर्षों तक रखे जाते हैं। अन्य व्यक्तिगत डेटा केवल तब तक रखा जाता है जब तक आपका खाता सक्रिय है या सेवा प्रदान करने के लिए आवश्यक है।\n\nआपके अधिकार (DPDP §11 और §12)\nआपको अधिकार है कि आप (क) अपने व्यक्तिगत डेटा की प्रति प्राप्त करें, (ख) उसे सुधारें या अपडेट करें, (ग) सहमति वापस लें और मिटाने का अनुरोध करें, और (घ) अपनी ओर से कार्य करने के लिए किसी को नामित करें। सेटिंग्स > डेंजर ज़ोन स्क्रीन पर \"मेरा डेटा निर्यात करें\" (आपके खाते से जुड़ी हर पंक्ति का डाउनलोड करने योग्य JSON) और \"खाता हटाएँ\" (ग्राहक खातों के लिए तुरंत मिटाना; उन दुकान-मालिक खातों के लिए नियंत्रित मिटाना जिनकी बहियाँ अब भी 8-वर्षीय प्रतिधारण अवधि में हैं) उपलब्ध हैं।\n\nसहमति वापस लेना\nआप अपना खाता हटाकर या support@shopxy.app पर ईमेल करके किसी भी समय सहमति वापस ले सकते हैं। वापसी, वापसी से पहले कानूनी रूप से किए गए प्रसंस्करण पर पूर्वव्यापी रूप से लागू नहीं होती।\n\nशिकायत निवारण\nDPDP §13 के अनुसार एक प्रकाशित शिकायत संपर्क आवश्यक है। कृपया हमारे शिकायत अधिकारी से grievance@shopxy.app पर संपर्क करें। हम 48 घंटों के भीतर पावती देते हैं और एक महीने के भीतर समाधान का लक्ष्य रखते हैं; DPDP अधिनियम के तहत व्यक्तिगत-डेटा अनुरोध 15 दिनों के भीतर निपटाए जाते हैं। यदि समाधान न हो, तो आप भारत के डेटा संरक्षण बोर्ड से संपर्क कर सकते हैं।\n';

  @override
  String get profileTermsBody =>
      'ShopXY आपकी दुकान की इन्वेंटरी, इनवॉइस, भुगतान और ग्राहक संबंधों के प्रबंधन के लिए जैसा-है के आधार पर प्रदान किया जाता है। खाता बनाकर आप नीचे दी गई शर्तों से सहमत होते हैं।\n\n1. खाता अखंडता। पंजीकरण करते समय सटीक जानकारी दें और अपना पासवर्ड गोपनीय रखें — आपके खाते के अंतर्गत सभी गतिविधि के लिए आप ज़िम्मेदार हैं।\n\n2. वैध उपयोग। सेवा का उपयोग केवल वैध व्यावसायिक संचालन के लिए करें। कोई स्पैम नहीं, कोई स्क्रैपिंग नहीं, अन्य खातों से छेड़छाड़ या बिलिंग से बचने का कोई प्रयास नहीं।\n\n3. भारतीय कानून का अनुपालन। आप भारत के सभी लागू कर, GST और वाणिज्य कानूनों का पालन करेंगे। ShopXY दस्तावेज़ीकरण में सहायता करता है परंतु यह कानूनी या कर सलाह नहीं है।\n\n4. डेटा और सहमति। ShopXY का आपका उपयोग गोपनीयता नीति द्वारा भी शासित होता है, जो बताती है कि हम DPDP अधिनियम, 2023 के तहत व्यक्तिगत डेटा को कैसे संभालते हैं — जिसमें भारत में डेटा स्थानीयकरण, वित्तीय बहियों के लिए 8-वर्षीय प्रतिधारण अवधि (कंपनी अधिनियम §128 / GST §36), और ऐप-में सेटिंग्स स्क्रीन के माध्यम से अपना डेटा एक्सेस और हटाने के आपके अधिकार शामिल हैं।\n\n5. सेवा उपलब्धता। हम रखरखाव निर्धारित कर सकते हैं या सुविधाएँ अपडेट कर सकते हैं। महत्वपूर्ण बदलावों के लिए हम उचित सूचना देंगे।\n\n6. समाप्ति। हम उन खातों को निलंबित कर सकते हैं जो इन शर्तों का उल्लंघन करते हैं या जिन पर हमें उचित रूप से धोखाधड़ी की गतिविधि का संदेह होता है। आप सेटिंग्स > खाता हटाएँ के माध्यम से किसी भी समय अपना खाता बंद कर सकते हैं।\n\n7. शिकायतें। प्रश्न, शिकायतें या DPDP अनुरोध grievance@shopxy.app पर भेजे जा सकते हैं। शिकायत अधिकारी 48 घंटों के भीतर पावती देते हैं और एक महीने के भीतर जवाब देते हैं।\n';

  @override
  String get profileTakePhoto => 'फ़ोटो लें';

  @override
  String get profilePickFromGallery => 'गैलरी से चुनें';

  @override
  String get profileRemovePhoto => 'फ़ोटो हटाएँ';

  @override
  String get profileProfileUpdated => 'प्रोफ़ाइल अपडेट हो गई';

  @override
  String get profileName => 'नाम';

  @override
  String get profileNameMinLength => 'नाम कम से कम 2 अक्षर का होना चाहिए';

  @override
  String get profileNameTooLong => 'नाम बहुत लंबा है';

  @override
  String get profileEmail => 'ईमेल';

  @override
  String get profileEmailNotEditable => 'ईमेल बदलना अभी समर्थित नहीं है';

  @override
  String get profileShopDetails => 'दुकान का विवरण';

  @override
  String get profileShopDetailsHint =>
      'ये इनवॉइस और PDF पर दिखते हैं। GSTIN राज्य से मेल खाना चाहिए।';

  @override
  String get profileShopName => 'दुकान का नाम';

  @override
  String get profileShopAddress => 'दुकान का पता';

  @override
  String get profileCity => 'शहर';

  @override
  String get profilePinCode => 'PIN कोड';

  @override
  String get profileState => 'राज्य';

  @override
  String get profileSelectPlaceholder => '— चुनें —';

  @override
  String get profileGstin => 'GSTIN';

  @override
  String get profileGstEffectiveFrom => 'GST किस तारीख से लागू होगा';

  @override
  String get profileGstEffectiveFromHelper =>
      'आपके GST पंजीकरण प्रमाणपत्र पर दी गई तारीख। इस तारीख से पहले के इनवॉइस बिल ऑफ सप्लाई के रूप में जारी होंगे, उन पर टैक्स नहीं लगेगा।';

  @override
  String get profileGstEffectiveFromRequired =>
      'GST कब से लागू होगा, वह तारीख चुनें।';

  @override
  String get profileGstEffectiveSheetTitle => 'GST किस तारीख से लागू होगा?';

  @override
  String get profileGstEffectiveSheetBody =>
      'अपने GST पंजीकरण प्रमाणपत्र पर दी गई तारीख चुनें। इस तारीख से पहले के इनवॉइस बिल ऑफ सप्लाई के रूप में टैक्स-फ्री रहेंगे — आप इसे बाद में प्रोफाइल से कभी भी बदल सकते हैं।';

  @override
  String get profileGstEffectiveSheetDeclare => 'तारीख बताएं';

  @override
  String get profileGstEffectiveSheetSkip => 'अभी के लिए छोड़ें';

  @override
  String get profilePan => 'PAN';

  @override
  String get profileUpiId => 'UPI ID';

  @override
  String get profileSave => 'सहेजें';

  @override
  String get profileInvoiceSettingsTitle => 'इनवॉइस सेटिंग्स';

  @override
  String get profileInvoiceSettingsHint =>
      'टैक्स और भुगतान जानकारी जो आपके इनवॉइस और PDF पर दिखती है।';

  @override
  String get profileInvoiceSettingsSubtitle =>
      'GSTIN, PAN, GST तारीख और UPI ID';

  @override
  String get profileInvoiceSettingsPreviewTitle => 'सेव करने से पहले जांच लें';

  @override
  String get profileInvoiceSettingsPreviewBody =>
      'ये बदलाव आगे से आपके इनवॉइस पर लागू होंगे।';

  @override
  String get profileSectionInvoicing => 'इनवॉइसिंग';

  @override
  String get numberingEntryTitle => 'क्रमांकन';

  @override
  String get numberingEntrySubtitle => 'प्रीफ़िक्स, सफ़िक्स और क्रम';

  @override
  String get pdfTemplatesEntryTitle => 'टेम्पलेट';

  @override
  String get pdfTemplatesEntrySubtitle => 'अपने दस्तावेज़ों का रूप चुनें';

  @override
  String get pdfTemplatesTitle => 'इनवॉइस टेम्पलेट';

  @override
  String get pdfTemplatesPreview => 'पूर्वावलोकन';

  @override
  String get numberingTitle => 'इनवॉइस क्रमांकन';

  @override
  String get numberingSubtitle =>
      'हर दस्तावेज़ श्रृंखला का प्रीफ़िक्स, सफ़िक्स और क्रम अपनी पसंद के अनुसार सेट करें। जिस श्रृंखला में आपने बदलाव नहीं किया, वह अपने मौजूदा फ़ॉर्मेट में ही रहेगी।';

  @override
  String get numberingGroupInvoices => 'इनवॉइस';

  @override
  String get numberingGroupChallan => 'चालान';

  @override
  String get numberingGroupQuotation => 'कोटेशन';

  @override
  String get numberingCustomized => 'कस्टमाइज़्ड';

  @override
  String get numberingDefault => 'डिफ़ॉल्ट';

  @override
  String get numberingSeriesSaleInvoice => 'बिक्री इनवॉइस';

  @override
  String get numberingSeriesPurchaseInvoice => 'खरीद इनवॉइस';

  @override
  String get numberingSeriesEstimate => 'अनुमान / प्रोफ़ॉर्मा';

  @override
  String get numberingSeriesCreditNote => 'क्रेडिट नोट';

  @override
  String get numberingSeriesDebitNote => 'डेबिट नोट';

  @override
  String get numberingSeriesChallan => 'चालान';

  @override
  String get numberingSeriesQuotation => 'कोटेशन';

  @override
  String get numberingFieldPrefix => 'प्रीफ़िक्स';

  @override
  String get numberingFieldSuffix => 'सफ़िक्स';

  @override
  String get numberingFieldSeparator => 'सेपरेटर';

  @override
  String get numberingFieldSeparatorNone => 'कोई नहीं';

  @override
  String get numberingFieldPadding => 'अंक';

  @override
  String get numberingFieldResetYearly => 'रीसेट';

  @override
  String get numberingResetYearlyOn => 'हर वित्तीय वर्ष';

  @override
  String get numberingResetYearlyOff => 'कभी नहीं — गिनती जारी रखें';

  @override
  String get numberingResetYearlyHelper =>
      'इसे बंद करने से आगे की क्रम संख्या बदल जाती है — यह पुराने दस्तावेज़ों को दोबारा नंबर नहीं देता।';

  @override
  String get numberingPreviewLabel => 'आगामी नंबर';

  @override
  String get numberingAffectedNote =>
      'सिर्फ़ नए दस्तावेज़ों पर लागू होगा — जो नंबर पहले ही जारी हो चुके हैं वे कभी नहीं बदलेंगे।';

  @override
  String get numberingResetKeyWarning =>
      'यह रीसेट होने का तरीका बदलने से एक अलग काउंटर शुरू हो जाता है — अगला नंबर आपके पिछले नंबर से आगे नहीं बढ़ सकता।';

  @override
  String get numberingStartAtToggle => 'किसी खास नंबर से क्रमांकन शुरू करें';

  @override
  String get numberingStartAtHelper =>
      'किसी दूसरे सिस्टम से माइग्रेट करने के लिए। यह सिर्फ़ अगला नंबर सेट करता है — यह पुराने दस्तावेज़ों को दोबारा नंबर नहीं देता, और अगर आपने वह नंबर कहीं और पहले से इस्तेमाल किया है तो यह आपको रोकेगा नहीं।';

  @override
  String get numberingStartAtLabel => 'अगला नंबर';

  @override
  String get numberingStartAtConfirm => 'सेट करें';

  @override
  String get numberingErrorLoad => 'क्रमांकन सेटिंग्स लोड नहीं हो सकीं।';

  @override
  String get numberingErrorSave => 'क्रमांकन सेटिंग्स सहेजी नहीं जा सकीं।';

  @override
  String get numberingErrorInvalid => 'हाइलाइट किए गए फ़ील्ड को जांचें।';

  @override
  String get numberingErrorInvalidStartAt =>
      '0 से बड़ी एक पूर्ण संख्या दर्ज करें।';

  @override
  String get profileSectionAccount => 'खाता';

  @override
  String get profileChangePasswordSubtitle => 'अपने खाते का पासवर्ड अपडेट करें';

  @override
  String get profileSectionShopOperations => 'दुकान संचालन';

  @override
  String get profileShopOperations => 'दुकान संचालन';

  @override
  String get profileShopOperationsSubtitle =>
      'समय, अवकाश मोड, भुगतान, KYC, टीम';

  @override
  String get profileSectionAppearance => 'रूप-रंग';

  @override
  String get profileCurrency => 'मुद्रा';

  @override
  String get profileCurrencyIndianRupee => 'भारतीय रुपया (₹)';

  @override
  String get profileListDensity => 'सूची घनत्व';

  @override
  String get profileListDensityCompactDesc =>
      'सघन पंक्तियाँ — हर स्क्रीन पर अधिक उत्पाद।';

  @override
  String get profileListDensityComfortableDesc => 'आरामदायक दूरी (डिफ़ॉल्ट)।';

  @override
  String get profileDensityComfortable => 'आरामदायक';

  @override
  String get profileDensityCompact => 'सघन';

  @override
  String get profileNavigationStyle => 'नेविगेशन शैली';

  @override
  String get profileNavigationStyleSidebarDesc =>
      'बाईं ओर की रेल जिसमें गंतव्य लंबवत क्रम में हैं।';

  @override
  String get profileNavigationStyleBottomDesc => 'नीचे टैब बार (डिफ़ॉल्ट)।';

  @override
  String get profileNavStyleBottomBar => 'नीचे बार';

  @override
  String get profileNavStyleSidebar => 'साइडबार';

  @override
  String get profileSectionInventory => 'इन्वेंटरी';

  @override
  String get profileCustomFields => 'कस्टम फ़ील्ड';

  @override
  String get profileCustomFieldsHint =>
      'हर उत्पाद पर अतिरिक्त जानकारी ट्रैक करें';

  @override
  String get profileSectionNotifications => 'सूचनाएँ';

  @override
  String get profileEmailNotifications => 'ईमेल सूचनाएँ';

  @override
  String get profileEmailNotificationsSubtitle =>
      'कम-स्टॉक अलर्ट और साप्ताहिक सारांश';

  @override
  String get profileHapticFeedback => 'हैप्टिक फ़ीडबैक';

  @override
  String get profileHapticFeedbackSubtitle =>
      'नेविगेशन, मेनू टैप और स्क्रॉल किनारों पर वाइब्रेट करें';

  @override
  String get profilePreferenceSaveFailed => 'प्राथमिकता सहेजी नहीं जा सकी:';

  @override
  String get profileSectionAbout => 'बारे में';

  @override
  String get profileAppVersion => 'ऐप संस्करण';

  @override
  String get profileSectionDangerZone => 'डेंजर ज़ोन';

  @override
  String get profileExportMyData => 'मेरा डेटा निर्यात करें';

  @override
  String get profileExportMyDataSubtitle =>
      'अपने खाते से जुड़े हर रिकॉर्ड की JSON प्रति डाउनलोड करें।';

  @override
  String get profileExportFailed => 'निर्यात विफल:';

  @override
  String get profileDataExportShareText => 'आपका ShopXY डेटा निर्यात';

  @override
  String get profileDeleteAccount => 'खाता हटाएँ';

  @override
  String get profileDeleteAccountSubtitle =>
      'अपना खाता स्थायी रूप से मिटाएँ। पिछले 8 वर्षों के इनवॉइस वाले दुकान मालिकों को सहायता से संपर्क करना होगा (कंपनी अधिनियम / GST प्रतिधारण)।';

  @override
  String get profileDeleteAccountDialogBody =>
      'यह आपके खाते को स्थायी रूप से मिटा देता है और हर सत्र रद्द कर देता है। जिन मालिकों के इनवॉइस अब भी 8-वर्षीय कंपनी अधिनियम / GST प्रतिधारण अवधि में हैं, वे ऐप-में नहीं हटा सकते — नियंत्रित मिटाने के लिए support@shopxy.example पर संपर्क करें।';

  @override
  String get profileAccountDeleted => 'खाता हटा दिया गया';

  @override
  String get profileCancel => 'रद्द करें';

  @override
  String get profileDelete => 'हटाएँ';

  @override
  String get profileLogout => 'लॉग आउट';

  @override
  String get profileLogoutConfirm => 'क्या आप वाकई लॉग आउट करना चाहते हैं?';

  @override
  String get profileComingSoon => 'जल्द आ रहा है';

  @override
  String get notificationsTitle => 'सूचनाएं';

  @override
  String get notificationsTabInbox => 'इनबॉक्स';

  @override
  String get notificationsTabInvites => 'आमंत्रण';

  @override
  String get notificationsTabSent => 'भेजे गए';

  @override
  String get notificationsMarkAllRead => 'सभी को पढ़ा हुआ चिह्नित करें';

  @override
  String get notificationsInviteButton => 'आमंत्रित करें';

  @override
  String get notificationsInboxEmptyTitle => 'अभी कोई सूचना नहीं';

  @override
  String get notificationsInboxEmptyBody =>
      'जब कुछ होगा — जैसे किसी आमंत्रण का जवाब — तो वह आपको यहां दिखेगा।';

  @override
  String get notificationsIncomingEmptyTitle => 'कोई आमंत्रण नहीं';

  @override
  String get notificationsIncomingEmptyBody =>
      'जब कोई दूसरी दुकान आपको ग्राहक या सप्लायर के रूप में आमंत्रित करेगी, तो अनुरोध यहाँ आएगा।';

  @override
  String get notificationsOutgoingEmptyTitle =>
      'अभी तक कोई आमंत्रण नहीं भेजा गया';

  @override
  String get notificationsOutgoingEmptyBody =>
      'किसी ग्राहक या सप्लायर को आमंत्रित करें ताकि वे आपकी दुकान से जुड़ सकें।';

  @override
  String get notificationsAShop => 'एक दुकान';

  @override
  String get notificationsRolePartyCustomer => 'पार्टी (ग्राहक)';

  @override
  String get notificationsRoleVendorSupplier => 'वेंडर (सप्लायर)';

  @override
  String notificationsWantsToAddYou(Object role) {
    return 'आपको अपने $role के रूप में जोड़ना चाहते हैं';
  }

  @override
  String get notificationsDecline => 'अस्वीकार करें';

  @override
  String get notificationsAccept => 'स्वीकार करें';

  @override
  String get notificationsInvitationAccepted => 'आमंत्रण स्वीकार किया गया';

  @override
  String get notificationsInvitationDeclined => 'आमंत्रण अस्वीकार किया गया';

  @override
  String get notificationsRoleParty => 'पार्टी';

  @override
  String get notificationsRoleVendor => 'वेंडर';

  @override
  String get notificationsCancel => 'रद्द करें';

  @override
  String get notificationsInvitationCancelled => 'आमंत्रण रद्द किया गया';

  @override
  String get notificationsStatusPending => 'लंबित';

  @override
  String get notificationsStatusAccepted => 'स्वीकृत';

  @override
  String get notificationsStatusDeclined => 'अस्वीकृत';

  @override
  String get notificationsStatusCancelled => 'रद्द';

  @override
  String get notificationsStatusExpired => 'समाप्त';

  @override
  String get notificationsInvitationSent => 'आमंत्रण भेजा गया';

  @override
  String get notificationsSendInvitationTitle => 'आमंत्रण भेजें';

  @override
  String get notificationsInviteByEmail => 'ईमेल से आमंत्रित करें';

  @override
  String get notificationsInviteByEmailHelp =>
      'उन्हें आपका अनुरोध सूचनाओं में दिखेगा। अगर उनके पास अभी Shopxy खाता नहीं है, तो इस ईमेल से साइन अप करते ही यह दिख जाएगा।';

  @override
  String get notificationsCustomerName => 'ग्राहक का नाम';

  @override
  String get notificationsVendorName => 'वेंडर का नाम';

  @override
  String get notificationsRecipientEmail => 'प्राप्तकर्ता का ईमेल';

  @override
  String get notificationsMessageOptional => 'संदेश (वैकल्पिक)';

  @override
  String get notificationsMessageHint =>
      'नमस्ते! Shopxy पर आपका खाता जोड़ रहे हैं…';

  @override
  String get notificationsModeExisting => 'मौजूदा';

  @override
  String get notificationsModeNewContact => 'नया संपर्क';

  @override
  String get notificationsChooseParty => 'पार्टी चुनें';

  @override
  String get notificationsChooseVendor => 'वेंडर चुनें';

  @override
  String get notificationsSearchParties => 'पार्टियां खोजें…';

  @override
  String get notificationsSearchVendors => 'वेंडर खोजें…';

  @override
  String get notificationsNoContactsFound => 'कोई संपर्क नहीं मिला';

  @override
  String get notificationsInviteDetailsTitle => 'आमंत्रण विवरण';

  @override
  String get notificationsDetailRole => 'भूमिका';

  @override
  String get notificationsDetailSentOn => 'भेजा गया';

  @override
  String get notificationsDetailExpires => 'समाप्ति';

  @override
  String get notificationsDetailMessage => 'संदेश';

  @override
  String get notificationsCancelInvitation => 'आमंत्रण रद्द करें';

  @override
  String get invitationsTitle => 'आमंत्रण';

  @override
  String get menuDescInvitations =>
      'ग्राहकों और सप्लायर को अपनी दुकान से जोड़ें';

  @override
  String get invitationsTabReceived => 'प्राप्त';

  @override
  String get inviteWhoTitle => 'आप किसे आमंत्रित कर रहे हैं?';

  @override
  String get inviteRoleCustomer => 'एक ग्राहक';

  @override
  String get inviteRoleCustomerDesc =>
      'ताकि वे अपने बिल देख सकें और आपसे ऑर्डर कर सकें';

  @override
  String get inviteRoleSupplier => 'एक सप्लायर';

  @override
  String get inviteRoleSupplierDesc => 'ताकि वे आपको स्टॉक और बिल भेज सकें';

  @override
  String get inviteWordCustomer => 'ग्राहक';

  @override
  String get inviteWordSupplier => 'सप्लायर';

  @override
  String get inviteChange => 'बदलें';

  @override
  String get inviteContactTitle => 'कौन?';

  @override
  String get inviteContactHint => 'अपने संपर्क खोजें, या नया नाम लिखें';

  @override
  String inviteAddAsNew(Object name, Object role) {
    return '\"$name\" को नए $role के रूप में जोड़ें';
  }

  @override
  String inviteNewContactBadge(Object role) {
    return 'नया $role';
  }

  @override
  String get inviteEmailTitle => 'आमंत्रण कहाँ भेजें?';

  @override
  String get inviteEmailHelp =>
      'उन्हें यहाँ आमंत्रण मिलेगा। अगर उनका Shopxy खाता नहीं है, तो इस ईमेल से साइन अप करते ही यह दिख जाएगा।';

  @override
  String get inviteHintPickContact => 'चुनें कि आप किसे आमंत्रित कर रहे हैं';

  @override
  String get inviteHintNeedEmail => 'उनका ईमेल पता दर्ज करें';

  @override
  String get categoriesTitle => 'श्रेणियाँ';

  @override
  String get categoriesEmptyTitle => 'अभी कोई श्रेणी नहीं';

  @override
  String get categoriesEmptyHint => 'श्रेणी जोड़ने के लिए + दबाएँ';

  @override
  String get categoriesProductsEmptyTitle => 'इस श्रेणी में कोई उत्पाद नहीं';

  @override
  String categoriesProductsNoMatchTitle(Object name) {
    return '\"$name\" से मेल खाता कोई उत्पाद नहीं';
  }

  @override
  String categoriesProductsEmptySubtitle(Object name) {
    return 'उत्पाद संपादक से उत्पादों को \"$name\" में जोड़ें।';
  }

  @override
  String get categoriesProductsNoMatchSubtitle => 'छोटी या अलग खोज आज़माएँ।';

  @override
  String get categoriesProductUnit => 'उत्पाद';

  @override
  String get categoriesProductsUnit => 'उत्पाद';

  @override
  String get categoriesSearchProductsHint => 'उत्पाद खोजें';

  @override
  String get categoriesPickerTitle => 'श्रेणी चुनें';

  @override
  String get categoriesCancel => 'रद्द करें';

  @override
  String get categoriesClearSelection => 'चयन हटाएँ';

  @override
  String get categoriesError => 'कुछ गलत हो गया';

  @override
  String get categoriesNoMatch => 'उस खोज से मेल खाती कोई श्रेणी नहीं।';

  @override
  String get categoriesSubcategoriesUnit => 'उपश्रेणियाँ';

  @override
  String get couponsTitle => 'कूपन';

  @override
  String get couponsNewCoupon => 'नया कूपन';

  @override
  String get couponsEditCoupon => 'कूपन बदलें';

  @override
  String get couponsCreateCoupon => 'कूपन बनाएं';

  @override
  String get couponsSaveChanges => 'बदलाव सेव करें';

  @override
  String get couponsSaving => 'सेव हो रहा है…';

  @override
  String get couponsCancel => 'रद्द करें';

  @override
  String get couponsDeactivate => 'बंद करें';

  @override
  String get couponsRetry => 'दोबारा कोशिश करें';

  @override
  String couponsDeactivateConfirmTitle(Object code) {
    return '$code बंद करें?';
  }

  @override
  String get couponsDeactivateConfirmBody =>
      'खरीदारों को अब यह कूपन नहीं दिखेगा। पहले से हुए इस्तेमाल पर कोई असर नहीं पड़ेगा।';

  @override
  String get couponsEmptyBody =>
      'अभी कोई कूपन नहीं है। अपना पहला कूपन बनाने के लिए \"नया कूपन\" पर टैप करें।';

  @override
  String couponsPercentOff(Object value) {
    return '$value% छूट';
  }

  @override
  String couponsAmountOff(Object amount) {
    return '$amount छूट';
  }

  @override
  String get couponsStatusInactive => 'निष्क्रिय';

  @override
  String get couponsStatusExpired => 'समाप्त';

  @override
  String get couponsStatusExhausted => 'खत्म';

  @override
  String get couponsStatusLive => 'चालू';

  @override
  String get couponsBadgePublicAutoApplies => 'सार्वजनिक · अपने-आप लगेगा';

  @override
  String get couponsBadgeFirstOrderOnly => 'सिर्फ पहले ऑर्डर पर';

  @override
  String couponsValidityRedeemed(Object from, Object until, Object count) {
    return 'मान्य $from – $until · $count बार इस्तेमाल';
  }

  @override
  String get couponsFieldCode => 'कोड';

  @override
  String get couponsFieldTitle => 'शीर्षक';

  @override
  String get couponsFieldTitleHint => 'नए ग्राहक के लिए ऑफर';

  @override
  String get couponsFieldDescription => 'विवरण (वैकल्पिक)';

  @override
  String get couponsFieldType => 'प्रकार';

  @override
  String get couponsDiscountTypePercent => 'प्रतिशत छूट';

  @override
  String get couponsDiscountTypeFlat => 'सीधी ₹ छूट';

  @override
  String get couponsFieldPercentOff => '% छूट';

  @override
  String get couponsFieldAmountOff => '₹ छूट';

  @override
  String get couponsFieldMaxDiscount => 'अधिकतम छूट (₹) — % छूट की सीमा';

  @override
  String get couponsFieldMinOrder => 'न्यूनतम ऑर्डर (₹)';

  @override
  String get couponsDateFrom => 'से';

  @override
  String get couponsDateUntil => 'तक';

  @override
  String get couponsFieldPerUserLimit => 'प्रति-ग्राहक सीमा (0 = असीमित)';

  @override
  String get couponsFieldTotalCap => 'कुल सीमा (0 = असीमित)';

  @override
  String get couponsPublicTitle => 'सार्वजनिक — अपने-आप लगेगा';

  @override
  String get couponsPublicSubtitle =>
      'कोई भी इसे देख और इस्तेमाल कर सकता है। कार्ट मेल खाने पर चेकआउट में अपने-आप लग जाएगा — कोड टाइप करने की जरूरत नहीं। खास लोगों के साथ साझा किए गए निजी कोड के लिए इसे बंद रखें।';

  @override
  String get couponsFirstOrderTitle => 'सिर्फ पहले ऑर्डर पर';

  @override
  String get couponsFirstOrderSubtitle =>
      'इसे सिर्फ वे ग्राहक इस्तेमाल कर सकते हैं जिनका पहले कोई कन्फर्म ऑर्डर नहीं है। एक बार वाले वेलकम ऑफर के लिए \"प्रति-ग्राहक सीमा = 1\" के साथ इस्तेमाल करें।';

  @override
  String get couponsActiveTitle => 'सक्रिय';

  @override
  String get couponsActiveSubtitle =>
      'बंद होने पर खरीदारों को यह कूपन नहीं दिखेगा और वे इसे इस्तेमाल नहीं कर पाएंगे।';

  @override
  String get authWelcomeBack => 'वापसी पर स्वागत है';

  @override
  String get authLoginSubtitle =>
      'अपनी इन्वेंट्री, इनवॉइस और ग्राहकों को प्रबंधित करने के लिए साइन इन करें।';

  @override
  String get authLoginFooterPrompt => 'ShopXY पर नए हैं?';

  @override
  String get authCreateAccountCta => 'खाता बनाएं';

  @override
  String get authUsePinInstead =>
      'Google में समस्या? अपने रिकवरी पिन से साइन इन करें';

  @override
  String get authRecoveryPinSetupTitle => 'एक रिकवरी पिन सेट करें';

  @override
  String get authRecoveryPinSetupSubtitle =>
      'आपके खाते ने Google से साइन इन किया है, जो पासवर्ड का उपयोग नहीं करता। 4-6 अंकों का पिन चुनें ताकि अगर Google कभी उपलब्ध न हो तो भी आप साइन इन कर सकें। आप इसे बाद में सेटिंग्स में बदल सकते हैं।';

  @override
  String get authRecoveryPinLabel => 'पिन';

  @override
  String get authRecoveryPinConfirmLabel => 'पिन की पुष्टि करें';

  @override
  String get authRecoveryPinMismatch => 'पिन मेल नहीं खाते';

  @override
  String get authRecoveryPinInvalid => 'पिन 4-6 अंकों का होना चाहिए';

  @override
  String get authRecoveryPinSave => 'पिन सहेजें';

  @override
  String get authRecoveryPinLoginTitle => 'अपने रिकवरी पिन से साइन इन करें';

  @override
  String get authRecoveryPinLoginSubtitle =>
      'उन खातों के लिए जिन्होंने Google से साइन इन किया, जब Google स्वयं उपलब्ध न हो।';

  @override
  String get authEmail => 'ईमेल';

  @override
  String get authPassword => 'पासवर्ड';

  @override
  String get authFieldRequired => 'यह फ़ील्ड आवश्यक है';

  @override
  String get authInvalidEmail => 'एक मान्य ईमेल पता दर्ज करें';

  @override
  String get authSignIn => 'साइन इन करें';

  @override
  String get authLegalAgreePrefix => 'साइन इन करके आप हमारी ';

  @override
  String get authLegalTerms => 'शर्तों';

  @override
  String get authLegalAcknowledgeMid => ' से सहमत होते हैं और हमारी ';

  @override
  String get authLegalPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get authTroubleSigningIn => 'साइन इन करने में परेशानी? ';

  @override
  String get authContactSupport => 'सहायता से संपर्क करें';

  @override
  String get authContinueAs => 'इस रूप में जारी रखें';

  @override
  String get authRemoveThisAccount => 'इस खाते को हटाएं';

  @override
  String get authSavedAccounts => 'लॉग इन किए गए खाते';

  @override
  String authContinueAsName(String name) {
    return '$name के रूप में जारी रखें';
  }

  @override
  String get authPickAccountTitle => 'खाता चुनें';

  @override
  String get authPickAccountSubtitle =>
      'आप इस डिवाइस पर पहले से साइन इन हैं। जारी रखने के लिए किसी खाते पर टैप करें — पासवर्ड की ज़रूरत नहीं।';

  @override
  String get authUseAnotherAccount => 'दूसरा खाता इस्तेमाल करें';

  @override
  String get authRegisterTitle => 'अपना खाता बनाएं';

  @override
  String get authRegisterSubtitle =>
      'अपनी इन्वेंट्री, इनवॉइस और ग्राहकों को प्रबंधित करना शुरू करने के लिए अपना मर्चेंट खाता सेट करें।';

  @override
  String get authRegisterFooterPrompt => 'पहले से खाता है?';

  @override
  String get authAcceptTermsPrompt =>
      'जारी रखने के लिए कृपया सेवा की शर्तें और गोपनीयता नीति स्वीकार करें।';

  @override
  String get authYourName => 'आपका नाम';

  @override
  String get authNameTooShort => 'नाम कम से कम 2 अक्षरों का होना चाहिए';

  @override
  String get authShopName => 'दुकान का नाम';

  @override
  String get authShopNameHelper =>
      'मार्केटप्लेस में ग्राहकों को दिखाया जाता है। आप इसे बाद में बदल सकते हैं।';

  @override
  String get onboardingShopTitle => 'अपनी दुकान सेट करें';

  @override
  String get onboardingShopSubtitle =>
      'शुरू करने के लिए अपनी दुकान को एक नाम दें। आप इसे बाद में सेटिंग में बदल सकते हैं।';

  @override
  String get onboardingShopCta => 'जारी रखें';

  @override
  String get otpVerifyTitle => 'अपना ईमेल सत्यापित करें';

  @override
  String otpVerifySubtitle(String email) {
    return 'हमने $email पर भेजा गया 6-अंकों का कोड दर्ज करें।';
  }

  @override
  String get otpCodeLabel => 'सत्यापन कोड';

  @override
  String get otpVerifyCta => 'सत्यापित करें और जारी रखें';

  @override
  String get otpResend => 'कोड फिर से भेजें';

  @override
  String otpResendIn(int seconds) {
    return '$seconds सेकंड में फिर से भेजें';
  }

  @override
  String get otpNoCodePrompt => 'कोड नहीं मिला?';

  @override
  String get otpResent => 'एक नया कोड भेजा जा रहा है।';

  @override
  String get authPasswordHelper =>
      'कम से कम 10 अक्षर, जिनमें एक अक्षर और एक संख्या हो।';

  @override
  String get authConfirmPassword => 'पासवर्ड की पुष्टि करें';

  @override
  String get authPasswordsDoNotMatch => 'पासवर्ड मेल नहीं खाते';

  @override
  String get authIAcceptThe => 'मैं स्वीकार करता/करती हूं';

  @override
  String get authTermsOfService => 'सेवा की शर्तें';

  @override
  String get authPrivacyPolicy => 'गोपनीयता नीति';

  @override
  String get authCreateAccount => 'खाता बनाएं';

  @override
  String get authContinueWithGoogle => 'Google के साथ जारी रखें';

  @override
  String get authOrContinueWithEmail => 'या ईमेल के साथ जारी रखें';

  @override
  String get authHide => 'छिपाएं';

  @override
  String get authShow => 'दिखाएं';

  @override
  String get dashboardHiddenTitle => 'डैशबोर्ड छिपा हुआ है';

  @override
  String get dashboardHiddenMessage =>
      'आपकी भूमिका में डैशबोर्ड अवलोकन शामिल नहीं है। यदि आपको इसकी आवश्यकता है तो किसी मालिक से पूछें।';

  @override
  String get dashboardGreetingMorning => 'सुप्रभात';

  @override
  String get dashboardGreetingAfternoon => 'नमस्कार';

  @override
  String get dashboardGreetingEvening => 'शुभ संध्या';

  @override
  String dashboardGreetingWithName(Object greeting, Object name) {
    return '$greeting, $name';
  }

  @override
  String get dashboardYourShop => 'आपकी दुकान';

  @override
  String dashboardShopStatus(Object shop) {
    return 'यहाँ देखें $shop कैसा चल रहा है।';
  }

  @override
  String get dashboardPendingInviteOne =>
      'आपके पास 1 लंबित निमंत्रण है — समीक्षा करें और स्वीकार करें।';

  @override
  String dashboardPendingInviteMany(Object count) {
    return 'आपके पास $count लंबित निमंत्रण हैं — समीक्षा करें और स्वीकार करें।';
  }

  @override
  String get dashboardView => 'देखें';

  @override
  String get dashboardOperations => 'संचालन';

  @override
  String get dashboardGstThisMonth => 'इस महीने GST';

  @override
  String dashboardOutputTaxCollected(Object amount) {
    return '$amount आउटपुट कर एकत्र किया गया';
  }

  @override
  String get dashboardInventoryValue => 'इन्वेंट्री मूल्य';

  @override
  String get dashboardCostBasisOfStock => 'उपलब्ध स्टॉक का लागत आधार';

  @override
  String get dashboardOneSale => '1 बिक्री';

  @override
  String dashboardSalesCount(Object count) {
    return '$count बिक्री';
  }

  @override
  String dashboardOpenTillSince(Object time) {
    return 'खुला गल्ला · $time से';
  }

  @override
  String get dashboardNeedsAttention => 'ध्यान देने योग्य';

  @override
  String get dashboardAllCaughtUp =>
      'सब कुछ पूरा हो गया — अभी किसी कार्रवाई की आवश्यकता नहीं है।';

  @override
  String get dashboardOrdersToConfirm => 'पुष्टि करने योग्य ऑर्डर';

  @override
  String get dashboardReturnsToReview => 'समीक्षा योग्य वापसी';

  @override
  String get dashboardQuotesToPrice => 'मूल्य तय करने योग्य कोटेशन';

  @override
  String get dashboardDraftsToConfirm => 'पुष्टि करने योग्य ड्राफ्ट';

  @override
  String get dashboardOutOfStock => 'स्टॉक समाप्त';

  @override
  String get dashboardLowStock => 'कम स्टॉक';

  @override
  String get dashboardSales => 'बिक्री';

  @override
  String get dashboardNetProfit => 'शुद्ध लाभ';

  @override
  String dashboardMarginPct(Object pct) {
    return '$pct% मार्जिन';
  }

  @override
  String get dashboardReceivables => 'प्राप्य राशि';

  @override
  String get dashboardOnePartyOwesYou => '1 पार्टी पर आपका बकाया है';

  @override
  String dashboardPartiesOweYou(Object count) {
    return '$count पार्टियों पर आपका बकाया है';
  }

  @override
  String get dashboardPayables => 'देय राशि';

  @override
  String get dashboardOneVendorToPay => '1 विक्रेता को भुगतान करना है';

  @override
  String dashboardVendorsToPay(Object count) {
    return '$count विक्रेताओं को भुगतान करना है';
  }

  @override
  String get kpiDrawerRetry => 'पुनः प्रयास करें';

  @override
  String get kpiDrawerLoadError => 'लोड नहीं हो सका। कृपया पुनः प्रयास करें।';

  @override
  String get kpiDrawerSalesFilterHint => 'उत्पाद नाम या SKU से फ़िल्टर करें';

  @override
  String get kpiDrawerNoSales => 'इस अवधि में कोई बिक्री नहीं।';

  @override
  String get kpiDrawerNoMatch => 'आपके फ़िल्टर से कोई उत्पाद मेल नहीं खाता।';

  @override
  String kpiDrawerProductCount(Object count) {
    return '$count उत्पाद';
  }

  @override
  String kpiDrawerRevenue(Object value) {
    return 'राजस्व $value';
  }

  @override
  String kpiDrawerQtySold(Object qty, Object unit) {
    return '$qty $unit बिके';
  }

  @override
  String kpiDrawerShowingTop(Object count) {
    return 'शीर्ष $count दिखाए जा रहे हैं';
  }

  @override
  String get kpiDrawerUnnamedProduct => 'अनाम उत्पाद';

  @override
  String get kpiDrawerUnits => 'इकाइयाँ';

  @override
  String get kpiDrawerViewFullReports => 'पूरी रिपोर्ट देखें';

  @override
  String get kpiDrawerViewAllParties => 'सभी पार्टियाँ देखें';

  @override
  String get kpiDrawerViewAllVendors => 'सभी विक्रेता देखें';

  @override
  String get kpiDrawerNoReceivables => 'अभी आपका किसी पर बकाया नहीं है।';

  @override
  String get kpiDrawerNoPayables => 'अभी आप पर किसी का बकाया नहीं है।';

  @override
  String get kpiDrawerBilled => 'बिल किया गया';

  @override
  String get kpiDrawerReceived => 'प्राप्त';

  @override
  String get kpiDrawerPaid => 'भुगतान किया';

  @override
  String get kpiDrawerOutstanding => 'बकाया';

  @override
  String kpiDrawerDocCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString दस्तावेज़',
      one: '1 दस्तावेज़',
    );
    return '$_temp0';
  }

  @override
  String get dashboardSalesTrend => 'बिक्री रुझान';

  @override
  String get dashboardPrevious => 'पिछला';

  @override
  String get dashboardPurchases => 'खरीद';

  @override
  String get dashboardReturns => 'वापसी';

  @override
  String get dashboardGetShopReady => 'आइए आपकी दुकान तैयार करें';

  @override
  String get dashboardOnboardingSubtitle =>
      'ये चरण पूरे करें और आपका डैशबोर्ड लाइव आँकड़ों से भर जाएगा।';

  @override
  String dashboardStepsDone(Object done, Object total) {
    return '$done/$total पूर्ण';
  }

  @override
  String get dashboardAddFirstProductTitle => 'अपना पहला उत्पाद जोड़ें';

  @override
  String get dashboardAddFirstProductDesc =>
      'अपनी सूची बनाएं ताकि आप बिल बना सकें और स्टॉक ट्रैक कर सकें।';

  @override
  String get dashboardAddProduct => 'उत्पाद जोड़ें';

  @override
  String get dashboardCreateFirstInvoiceTitle => 'अपना पहला इनवॉइस बनाएं';

  @override
  String get dashboardCreateFirstInvoiceDesc =>
      'बिक्री का बिल बनाएं — GST आपके लिए संभाल लिया जाता है।';

  @override
  String get dashboardNewInvoice => 'नया इनवॉइस';

  @override
  String get dashboardAddCustomerTitle => 'ग्राहक जोड़ें';

  @override
  String get dashboardAddCustomerDesc =>
      'जानें किस पर आपका बकाया है और उन्हें इनवॉइस भेजें।';

  @override
  String get dashboardAddCustomer => 'ग्राहक जोड़ें';

  @override
  String get dashboardSetUpPayoutsTitle => 'भुगतान सेट अप करें';

  @override
  String get dashboardSetUpPayoutsDesc =>
      'ऑनलाइन ऑर्डर के लिए सेटलमेंट प्राप्त करें।';

  @override
  String get dashboardSetUp => 'सेट अप करें';

  @override
  String get dashboardAlertReorder => 'पुनः ऑर्डर करें';

  @override
  String get dashboardAlertFileGst => 'GST दाखिल करें';

  @override
  String get dashboardAlertViewReport => 'रिपोर्ट देखें';

  @override
  String get dashboardAlertOpenTill => 'गल्ला खोलें';

  @override
  String get dashboardDismiss => 'खारिज करें';

  @override
  String get dashboardRecentActivity => 'हाल की गतिविधि';

  @override
  String get dashboardNoRecentMovements => 'कोई हालिया स्टॉक गतिविधि नहीं।';

  @override
  String dashboardProductFallback(Object id) {
    return 'उत्पाद #$id';
  }

  @override
  String get dashboardTopCategories => 'शीर्ष श्रेणियाँ';

  @override
  String get dashboardTopProducts => 'शीर्ष उत्पाद';

  @override
  String get dashboardSlowMovers => 'धीमी बिकने वाली वस्तुएँ';

  @override
  String get dashboardSlowMoversHint =>
      'निष्क्रिय स्टॉक इकाइयों का हिस्सा — पूँजी जो नहीं चल रही।';

  @override
  String get dashboardExpandChart => 'चार्ट बड़ा करें';

  @override
  String dashboardUnitsValue(Object count) {
    return '$count इकाइयाँ';
  }

  @override
  String get dashboardSubjectCategorySales => 'श्रेणी बिक्री';

  @override
  String get dashboardSubjectProductSales => 'उत्पाद बिक्री';

  @override
  String get dashboardSubjectIdleStock => 'निष्क्रिय स्टॉक';

  @override
  String get dashboardNounCategories => 'श्रेणियाँ';

  @override
  String get dashboardNounProducts => 'उत्पाद';

  @override
  String get dashboardPieOther => 'अन्य';

  @override
  String get dashboardNoDataInPeriod => 'इस अवधि में अभी तक कोई डेटा नहीं है।';

  @override
  String get dashboardAboutThisChart => 'इस चार्ट के बारे में';

  @override
  String get dashboardTapSliceHint => 'विवरण के लिए किसी टुकड़े पर टैप करें।';

  @override
  String dashboardPieSummaryBase(
    Object total,
    Object count,
    Object noun,
    Object avg,
  ) {
    return '$count $noun में कुल $total (औसत $avg प्रत्येक)।';
  }

  @override
  String dashboardPieSummaryLead(Object label, Object pct, Object value) {
    return '$label $pct% ($value) के साथ अग्रणी है';
  }

  @override
  String dashboardPieSummaryAheadOf(Object label, Object pct) {
    return ', जो $label के $pct% से आगे है';
  }

  @override
  String dashboardPieSummaryTopK(Object k, Object pct, Object subject) {
    return 'शीर्ष $k $subject का $pct% बनाते हैं';
  }

  @override
  String dashboardPieSummaryTrails(Object label, Object pct) {
    return ', जबकि $label $pct% पर सबसे पीछे है';
  }

  @override
  String dashboardPieDetailTail(Object pct, Object subject) {
    return ', $subject का $pct%।';
  }

  @override
  String get dashboardPeriodToday => 'आज';

  @override
  String get dashboardPeriodWeek => '7 दिन';

  @override
  String get dashboardPeriodMonth => '30 दिन';

  @override
  String get dashboardDeltaNew => 'नया';

  @override
  String get shopSave => 'सहेजें';

  @override
  String get shopSaving => 'सहेजा जा रहा है…';

  @override
  String get shopSaveFailed => 'सहेजना विफल';

  @override
  String get shopCancel => 'रद्द करें';

  @override
  String get shopDelete => 'हटाएँ';

  @override
  String get shopRemove => 'हटाएँ';

  @override
  String get shopContinue => 'जारी रखें';

  @override
  String get shopBack => 'पीछे';

  @override
  String get shopRetry => 'पुनः प्रयास करें';

  @override
  String get shopTryAgain => 'फिर से प्रयास करें';

  @override
  String get shopDismiss => 'खारिज करें';

  @override
  String get shopEnabled => 'सक्षम';

  @override
  String get shopNotYetEnabled => 'अभी सक्षम नहीं';

  @override
  String get shopNotEnabledYet => 'अभी सक्षम नहीं';

  @override
  String get shopHoursTitle => 'समय और अवकाश मोड';

  @override
  String get shopHoursSaved => 'समय सहेजा गया';

  @override
  String get shopVacationMode => 'अवकाश मोड';

  @override
  String get shopVacationModeSubtitle =>
      'नए ऑर्डर रोकता है। मौजूदा ऑर्डर, स्टॉक और चालान हमेशा की तरह संपादित करने योग्य रहते हैं।';

  @override
  String get shopVacationMessageLabel =>
      'ग्राहकों को दिखाया जाने वाला संदेश (वैकल्पिक)';

  @override
  String get shopVacationMessageHint =>
      'उदा. 5 जून को वापस आएँगे। आपके धैर्य के लिए धन्यवाद!';

  @override
  String get shopOpeningHours => 'खुलने का समय';

  @override
  String get shopHoursHint =>
      'समय ग्राहकों के लिए एक संकेत है — समय के बाहर के ऑर्डर भी स्वीकार होते हैं।';

  @override
  String get shopDayClosed => 'बंद';

  @override
  String get shopDayMonday => 'सोमवार';

  @override
  String get shopDayTuesday => 'मंगलवार';

  @override
  String get shopDayWednesday => 'बुधवार';

  @override
  String get shopDayThursday => 'गुरुवार';

  @override
  String get shopDayFriday => 'शुक्रवार';

  @override
  String get shopDaySaturday => 'शनिवार';

  @override
  String get shopDaySunday => 'रविवार';

  @override
  String get shopOperationsTitle => 'दुकान संचालन';

  @override
  String get shopOpsHoursOnVacation => 'अवकाश पर — नए ऑर्डर रोके गए';

  @override
  String get shopOpsHoursSubtitle => 'खुलने का समय तय करें और नए ऑर्डर रोकें।';

  @override
  String get shopOnVacationBadge => 'अवकाश पर';

  @override
  String get shopPayoutsTitle => 'भुगतान और निपटान';

  @override
  String get shopKycTitle => 'KYC दस्तावेज़';

  @override
  String get shopOpsKycSubtitle =>
      'PAN, GSTIN प्रमाणपत्र, रद्द किया गया चेक। भुगतान शुरू होने से पहले आवश्यक।';

  @override
  String get shopComingSoonBadge => 'जल्द आ रहा है';

  @override
  String get shopTeamTitle => 'टीम और भूमिकाएँ';

  @override
  String get shopOpsTeamSubtitle =>
      'स्टाफ़ को आमंत्रित करें और तय करें कि हर व्यक्ति क्या देख और प्रबंधित कर सकता है।';

  @override
  String get shopOpsPayoutsLinkBank =>
      'अपनी बिक्री का निपटान पाने के लिए बैंक खाता जोड़ें।';

  @override
  String get shopOpsPayoutsResume =>
      'अपना भुगतान सेटअप फिर से शुरू करें — आपके पास एक सहेजा गया ड्राफ़्ट है।';

  @override
  String get shopOpsPayoutsSetUp =>
      'निपटान पाना शुरू करने के लिए अपना बैंक खाता सेट करें।';

  @override
  String get shopOpsPayoutsActive =>
      'सक्रिय — आपकी बिक्री आपके जुड़े बैंक खाते में निपटती है।';

  @override
  String get shopOpsPayoutsSubmitted =>
      'जमा किया गया — Razorpay आपके खाते की पुष्टि कर रहा है।';

  @override
  String get shopInProgressBadge => 'प्रगति पर';

  @override
  String get shopSetUpBadge => 'सेट करें';

  @override
  String get shopActiveBadge => 'सक्रिय';

  @override
  String get shopUnderReviewBadge => 'समीक्षाधीन';

  @override
  String get shopKycIntro =>
      'दस्तावेज़ अपलोड सत्यापित-विक्रेता बैज के साथ शुरू होंगे। तब तक, यहाँ सूचीबद्ध है कि आपसे क्या माँगा जाएगा ताकि आप पहले से तैयारी कर सकें। आपका भुगतान KYC \'भुगतान और निपटान\' में संभाला जाता है।';

  @override
  String get shopKycPanTitle => 'PAN कार्ड';

  @override
  String get shopKycPanSubtitle =>
      'मालिक या व्यवसाय का PAN। भुगतान के लिए आवश्यक।';

  @override
  String get shopKycGstinTitle => 'GSTIN प्रमाणपत्र';

  @override
  String get shopKycGstinSubtitle =>
      'यदि आपकी दुकान का GSTIN है, तो पंजीकरण प्रमाणपत्र अपलोड करें।';

  @override
  String get shopKycChequeTitle => 'रद्द किया गया चेक';

  @override
  String get shopKycChequeSubtitle =>
      'खाताधारक का नाम दिखाई देने वाला बैंक-जारी चेक। निपटान-खाते के स्वामित्व की पुष्टि करता है।';

  @override
  String get shopKycAadhaarTitle => 'आधार / पते का प्रमाण';

  @override
  String get shopKycAadhaarSubtitle =>
      'एकल-स्वामित्व वाली दुकानों के लिए। यदि आपके पास पहले से GSTIN है तो छोड़ दें।';

  @override
  String get shopKycPhotoTitle => 'दुकान / व्यवसाय की तस्वीर';

  @override
  String get shopKycPhotoSubtitle =>
      'वैकल्पिक। दुकान के सामने की तस्वीर विश्वास और सत्यापन समीक्षा में मदद करती है।';

  @override
  String get shopKycNotUploaded => 'अपलोड नहीं किया गया';

  @override
  String get shopKycUploadComingSoon => 'अपलोड (जल्द आ रहा है)';

  @override
  String get shopConnectExistingAccountTitle => 'मौजूदा खाता जोड़ें';

  @override
  String get shopConnectIntro =>
      'पहले से Razorpay से जुड़ा खाता है? उसे जोड़ने के लिए उसकी id पेस्ट करें — KYC दोबारा करने की ज़रूरत नहीं।';

  @override
  String get shopConnectAccountIdLabel => 'खाता id';

  @override
  String get shopConnectVerify => 'सत्यापित करें';

  @override
  String get shopConnectConfirmTitle => 'पुष्टि करें कि यह आपका खाता है';

  @override
  String get shopConnectFactAccount => 'खाता';

  @override
  String get shopConnectFactBusiness => 'व्यवसाय';

  @override
  String get shopConnectFactContact => 'संपर्क';

  @override
  String get shopConnectFactEmail => 'ईमेल';

  @override
  String get shopConnectFactKycStatus => 'KYC स्थिति';

  @override
  String get shopConnectFactPayouts => 'भुगतान';

  @override
  String get shopConnectPayoutsNotEnabledWarning =>
      'भुगतान अभी सक्षम नहीं हैं — आप इसे जोड़ सकते हैं, लेकिन जब तक Razorpay खाता सक्रिय नहीं करता, बिलिंग पर UPI बंद रहेगा।';

  @override
  String get shopConnectLinkAccount => 'यह खाता जोड़ें';

  @override
  String get shopPermissionView => 'देखें';

  @override
  String get shopPermissionManage => 'प्रबंधित करें';

  @override
  String get shopStartFromRole => 'किसी भूमिका से शुरू करें';

  @override
  String get shopCustomRole => 'कस्टम';

  @override
  String shopAccessManageable(Object count) {
    return 'पहुँच · $count प्रबंधित करने योग्य';
  }

  @override
  String get shopPermissionTrustHint =>
      'प्रबंधन में देखना शामिल है। भुगतान व KYC और टीम संवेदनशील हैं — इन्हें केवल भरोसेमंद लोगों को ही दें।';

  @override
  String get shopGiveRoleName => 'भूमिका को एक नाम दें';

  @override
  String get shopNewRole => 'नई भूमिका';

  @override
  String get shopEditRole => 'भूमिका संपादित करें';

  @override
  String get shopRoleNameLabel => 'भूमिका का नाम';

  @override
  String get shopRoleNameHint => 'उदा. वेयरहाउस लीड';

  @override
  String get shopRoleTemplatesHint =>
      'भूमिका बदलने पर सदस्यों की मौजूदा पहुँच बनी रहती है — भूमिकाएँ आपके द्वारा सौंपे गए टेम्पलेट हैं, लाइव लिंक नहीं।';

  @override
  String get shopPayoutsSubmittedSnack =>
      'जमा किया गया — Razorpay आपके खाते की पुष्टि करेगा।';

  @override
  String get shopConnectExisting => 'मौजूदा जोड़ें';

  @override
  String get shopStepBusiness => 'व्यवसाय';

  @override
  String get shopStepIdentity => 'पहचान';

  @override
  String get shopStepAddress => 'पता';

  @override
  String get shopStepBank => 'बैंक';

  @override
  String shopStepProgress(Object current, Object total, Object title) {
    return 'चरण $current / $total · $title';
  }

  @override
  String get shopSetUpPayouts => 'भुगतान सेट करें';

  @override
  String get shopFieldRequired => 'आवश्यक';

  @override
  String get shopInvalidEmail => 'अमान्य ईमेल';

  @override
  String get shopBusinessStepTitle => 'आपका व्यवसाय';

  @override
  String get shopBusinessStepSubtitle =>
      'वह कानूनी इकाई जो निपटान प्राप्त करती है।';

  @override
  String get shopLegalBusinessName => 'कानूनी व्यवसाय का नाम';

  @override
  String get shopDisplayName => 'प्रदर्शित नाम (वैकल्पिक)';

  @override
  String get shopDisplayNameHelper =>
      'ग्राहकों को दिखाया जाता है। डिफ़ॉल्ट रूप से कानूनी नाम।';

  @override
  String get shopContactPersonName => 'संपर्क व्यक्ति का नाम';

  @override
  String get shopEmail => 'ईमेल';

  @override
  String get shopPhone => 'फ़ोन';

  @override
  String get shopEnter10DigitNumber => '10 अंकों का नंबर दर्ज करें';

  @override
  String get shopBusinessType => 'व्यवसाय का प्रकार';

  @override
  String get shopBusinessTypeProprietorship => 'स्वामित्व';

  @override
  String get shopBusinessTypePartnership => 'साझेदारी';

  @override
  String get shopBusinessTypePrivateLimited => 'प्राइवेट लिमिटेड';

  @override
  String get shopBusinessTypePublicLimited => 'पब्लिक लिमिटेड';

  @override
  String get shopBusinessTypeLlp => 'LLP';

  @override
  String get shopBusinessTypeIndividual => 'व्यक्तिगत';

  @override
  String get shopBusinessTypeTrust => 'ट्रस्ट';

  @override
  String get shopBusinessTypeSociety => 'सोसाइटी';

  @override
  String get shopBusinessTypeNgo => 'NGO';

  @override
  String get shopBusinessCategory => 'व्यवसाय श्रेणी';

  @override
  String get shopCategoryEcommerce => 'ई-कॉमर्स / खुदरा';

  @override
  String get shopCategoryFood => 'खाद्य और पेय';

  @override
  String get shopCategoryServices => 'सेवाएँ';

  @override
  String get shopCategoryHealthcare => 'स्वास्थ्य सेवा';

  @override
  String get shopCategoryEducation => 'शिक्षा';

  @override
  String get shopCategoryOthers => 'अन्य';

  @override
  String get shopIdentityStepTitle => 'पहचान और कर';

  @override
  String get shopIdentityStepSubtitle =>
      'कर प्राधिकरण से सत्यापित। Razorpay को भेजा जाता है, इस ऐप में कभी संग्रहीत नहीं।';

  @override
  String get shopPanHelper => 'व्यवसाय या मालिक का PAN (उदा. AAACL1234C)।';

  @override
  String get shopInvalidPan => 'अमान्य PAN';

  @override
  String get shopGstinOptional => 'GSTIN (वैकल्पिक)';

  @override
  String get shopGstinHelper => 'यदि आपका व्यवसाय GST-पंजीकृत है तो जोड़ें।';

  @override
  String get shopInvalidGstin => 'अमान्य GSTIN';

  @override
  String get shopAddressStepTitle => 'पंजीकृत पता';

  @override
  String get shopAddressStepSubtitle => 'आपके व्यवसाय पंजीकरण पर दर्ज पता।';

  @override
  String get shopAddressLine1 => 'पता पंक्ति 1';

  @override
  String get shopAddressLine2 => 'पता पंक्ति 2 (वैकल्पिक)';

  @override
  String get shopCity => 'शहर';

  @override
  String get shopState => 'राज्य';

  @override
  String get shopSelectState => 'राज्य चुनें';

  @override
  String get shopPinCode => 'पिन कोड';

  @override
  String get shopEnter6DigitPin => '6 अंकों का पिन दर्ज करें';

  @override
  String get shopCountryIndia => 'देश: भारत';

  @override
  String get shopBankStepTitle => 'निपटान बैंक खाता';

  @override
  String get shopBankStepSubtitle =>
      'जहाँ आपके भुगतान पहुँचते हैं। सुरक्षित रूप से Razorpay को भेजा जाता है; यह ऐप आपके बैंक विवरण कभी संग्रहीत नहीं करता।';

  @override
  String get shopAccountHolderName => 'खाताधारक का नाम';

  @override
  String get shopBankAccountNumber => 'बैंक खाता संख्या';

  @override
  String get shopEnterValidAccountNumber => 'एक मान्य खाता संख्या दर्ज करें';

  @override
  String get shopInvalidIfsc => 'अमान्य IFSC';

  @override
  String get shopResumeTitle => 'जहाँ छोड़ा था वहीं से जारी रखें?';

  @override
  String shopResumeDraftUpTo(Object step) {
    return 'आपके पास $step चरण तक का सहेजा गया ड्राफ़्ट था।';
  }

  @override
  String get shopStartOver => 'फिर से शुरू करें';

  @override
  String get shopResume => 'जारी रखें';

  @override
  String get shopStatusActive => 'सक्रिय — भुगतान सक्षम';

  @override
  String get shopStatusNeedsClarification =>
      'कार्रवाई आवश्यक — Razorpay को और जानकारी चाहिए';

  @override
  String get shopStatusSuspended => 'निलंबित — सहायता से संपर्क करें';

  @override
  String get shopStatusUnderReview => 'Razorpay द्वारा समीक्षाधीन';

  @override
  String get shopStatusNotActivated =>
      'अभी सक्रिय नहीं — Razorpay पर KYC पूरा करें';

  @override
  String get shopStatusActivatedDesc =>
      'आपका निपटान खाता सत्यापित है। ऑर्डर और UPI भुगतान आपके बैंक में पहुँचेंगे।';

  @override
  String shopStatusNotEnabledDesc(Object status) {
    return 'यह खाता अभी भुगतान-सक्षम नहीं है (Razorpay स्थिति: $status)। Razorpay डैशबोर्ड में इसका Route KYC पूरा करें, फिर लाइव दोबारा जाँचने के लिए रिफ़्रेश दबाएँ।';
  }

  @override
  String get shopDetailAccountId => 'खाता ID';

  @override
  String get shopDetailName => 'नाम';

  @override
  String get shopDetailEmail => 'ईमेल';

  @override
  String get shopDetailBusinessType => 'व्यवसाय का प्रकार';

  @override
  String get shopDetailKycStatus => 'KYC स्थिति';

  @override
  String get shopDetailPayouts => 'भुगतान';

  @override
  String get shopRefreshFromRazorpay => 'Razorpay से रिफ़्रेश करें';

  @override
  String get shopImageTooLarge =>
      'छवि 5 MB से बड़ी है। छोटी छवि चुनें या अधिक क्रॉप करें।';

  @override
  String get shopImageUploadFailed => 'छवि अपलोड विफल';

  @override
  String get shopProfileSaved => 'दुकान प्रोफ़ाइल सहेजी गई';

  @override
  String get shopUnpublishTitle => 'दुकान अप्रकाशित करें?';

  @override
  String get shopUnpublishMessage =>
      'ग्राहक मार्केटप्लेस पर आपकी दुकान देखना बंद कर देंगे। आपका इन्वेंट्री और ऑर्डर अप्रभावित रहेंगे।';

  @override
  String get shopUnpublish => 'अप्रकाशित करें';

  @override
  String get shopNowLive => 'दुकान अब मार्केटप्लेस पर लाइव है';

  @override
  String get shopHiddenFromMarketplace => 'दुकान मार्केटप्लेस से छिपाई गई';

  @override
  String get shopPublishUpdateFailed => 'प्रकाशन स्थिति अपडेट करने में विफल';

  @override
  String get shopDiscardChangesTitle => 'परिवर्तन छोड़ें?';

  @override
  String get shopDiscardChangesMessage =>
      'आपके पास असहेजे संपादन हैं। अभी छोड़ने पर वे हट जाएँगे।';

  @override
  String get shopKeepEditing => 'संपादन जारी रखें';

  @override
  String get shopDiscard => 'छोड़ें';

  @override
  String get shopMyShopTitle => 'मेरी दुकान';

  @override
  String get shopNotFound => 'दुकान नहीं मिली';

  @override
  String shopLiveOnMarketplaceSlug(Object slug) {
    return 'मार्केटप्लेस पर लाइव · /$slug';
  }

  @override
  String get shopNotPublished => 'प्रकाशित नहीं';

  @override
  String get shopNameLabel => 'दुकान का नाम';

  @override
  String get shopNameHelper =>
      'मार्केटप्लेस पर दिखाया जाता है। नाम बदलने पर सार्वजनिक URL स्लग अपडेट होता है।';

  @override
  String get shopMin2Chars => 'कम से कम 2 अक्षर';

  @override
  String get shopMax80Chars => 'अधिकतम 80 अक्षर';

  @override
  String get shopTaglineLabel => 'टैगलाइन (वैकल्पिक)';

  @override
  String get shopTaglineHelper =>
      'आपकी दुकान के नाम के नीचे दिखने वाली एक पंक्ति।';

  @override
  String get shopLocationSection => 'स्थान';

  @override
  String get shopLocationSectionSubtitle =>
      'वैकल्पिक। आपके सार्वजनिक दुकान पेज पर \"यहाँ स्थित …\" पंक्ति दिखाता है।';

  @override
  String get shopPoliciesSection => 'नीतियाँ';

  @override
  String get shopPoliciesSectionSubtitle =>
      'ग्राहक इन्हें आपके दुकान पेज पर और हर उत्पाद पेज पर \"नीतियाँ\" पिल के रूप में देखते हैं। सादा टेक्स्ट। प्रत्येक अधिकतम 4 KB।';

  @override
  String get shopReturnPolicyLabel => 'वापसी नीति';

  @override
  String get shopReturnPolicyHint =>
      'उदा. अप्रयुक्त वस्तुओं पर 7-दिन की वापसी। मूल पैकेजिंग आवश्यक।';

  @override
  String get shopShippingPolicyLabel => 'शिपिंग नीति';

  @override
  String get shopShippingPolicyHint =>
      'उदा. बेंगलुरु से 24 घंटे में शिप। 3–5 कार्यदिवसों में डिलीवरी।';

  @override
  String get shopRefundPolicyLabel => 'धनवापसी नीति';

  @override
  String get shopRefundPolicyHint =>
      'उदा. धनवापसी 5 कार्यदिवसों के भीतर मूल भुगतान माध्यम में की जाती है।';

  @override
  String get shopReturnsCancellationSection => 'वापसी और रद्दीकरण';

  @override
  String get shopReturnsCancellationSubtitle =>
      'क्या ग्राहक ऑर्डर लौटा सकते हैं, धनवापसी कैसे की जाती है, और ऑर्डर कब तक रद्द किया जा सकता है।';

  @override
  String get shopAcceptReturns => 'वापसी स्वीकार करें';

  @override
  String get shopAcceptReturnsSubtitle =>
      'बंद होने पर, ग्राहक डिलीवरी के बाद वापसी का अनुरोध नहीं कर सकते।';

  @override
  String get shopReturnWindowLabel => 'वापसी अवधि (दिन)';

  @override
  String get shopReturnWindowHelper => '0 का अर्थ है कोई समय सीमा नहीं।';

  @override
  String get shopReturnWindowError =>
      '0 और 365 के बीच एक पूर्ण संख्या दर्ज करें';

  @override
  String get shopRefundMethodLabel => 'धनवापसी माध्यम';

  @override
  String get shopRefundMethodOriginal => 'मूल भुगतान माध्यम';

  @override
  String get shopRefundMethodReplacement => 'केवल प्रतिस्थापन';

  @override
  String get shopReturnPolicyNoteLabel => 'वापसी नीति टिप्पणी (वैकल्पिक)';

  @override
  String get shopReturnPolicyNoteHint =>
      'उदा. वस्तुएँ अप्रयुक्त और मूल पैकेजिंग में होनी चाहिए। वापसी शिपिंग खरीदार वहन करेगा।';

  @override
  String get shopCustomersCanCancelLabel => 'ग्राहक रद्द कर सकते हैं';

  @override
  String get shopCustomersCanCancelHelper =>
      'इस चरण के बाद उन्हें इसके बजाय डिलीवरी-पश्चात वापसी का उपयोग करना होगा।';

  @override
  String get shopCancelUntilConfirmed => 'जब तक मैं ऑर्डर की पुष्टि न करूँ';

  @override
  String get shopCancelUntilPacked => 'पैक होने तक';

  @override
  String get shopCancelUntilShipped => 'शिप होने तक (अनुशंसित)';

  @override
  String get shopCancelUntilDelivered => 'डिलीवर होने तक';

  @override
  String get shopAddBanner => 'बैनर जोड़ें';

  @override
  String get shopReplace => 'बदलें';

  @override
  String get shopLiveOnMarketplace => 'मार्केटप्लेस पर लाइव';

  @override
  String get shopNotPublishedYet => 'अभी प्रकाशित नहीं';

  @override
  String get shopPublishCardLiveDesc =>
      'ग्राहक आपकी दुकान और आपके प्रकाशित उत्पाद ढूँढ सकते हैं।';

  @override
  String get shopPublishCardHiddenDesc =>
      'अपना लोगो, बैनर और कम से कम एक उत्पाद तैयार होने पर इसे चालू करें।';

  @override
  String get shopInviteTeammate => 'एक साथी को आमंत्रित करें';

  @override
  String get shopInviteAccessTitle => 'आमंत्रण पहुँच';

  @override
  String get shopSendInvite => 'आमंत्रण भेजें';

  @override
  String shopInviteAccessSubtitle(Object email) {
    return 'चुनें कि $email क्या देख और प्रबंधित कर सकता है। आप इसे कभी भी बदल सकते हैं।';
  }

  @override
  String shopInvitationSentTo(Object email) {
    return '$email को आमंत्रण भेजा गया';
  }

  @override
  String get shopEditAccessTitle => 'पहुँच संपादित करें';

  @override
  String shopEditAccessSubtitle(Object name) {
    return 'तय करें कि $name वास्तव में क्या देख और प्रबंधित कर सकता है।';
  }

  @override
  String get shopAccessUpdated => 'पहुँच अपडेट की गई';

  @override
  String get shopRemoveFromTeamTitle => 'टीम से हटाएँ?';

  @override
  String shopRemoveFromTeamMessage(Object name) {
    return '$name की इस दुकान तक पहुँच तुरंत समाप्त हो जाएगी। आप उन्हें बाद में फिर से आमंत्रित कर सकते हैं।';
  }

  @override
  String get shopRemovedFromTeam => 'टीम से हटाया गया';

  @override
  String get shopRoleCreated => 'भूमिका बनाई गई';

  @override
  String get shopRoleSaved => 'भूमिका सहेजी गई';

  @override
  String shopDeleteRoleTitle(Object name) {
    return '“$name” हटाएँ?';
  }

  @override
  String get shopDeleteRoleMessage =>
      'यह भूमिका को पिकर से हटा देता है। जिन साथियों के पास यह पहले से है, उनकी मौजूदा पहुँच बनी रहती है।';

  @override
  String get shopRoleDeleted => 'भूमिका हटाई गई';

  @override
  String get shopInvitationCancelled => 'आमंत्रण रद्द किया गया';

  @override
  String get shopTeamViewOnlyBanner =>
      'आप टीम देख सकते हैं लेकिन बदल नहीं सकते। लोगों को आमंत्रित करने या कौन क्या करता है यह तय करने के लिए किसी मालिक से कहें।';

  @override
  String shopTeamSectionHeader(Object count) {
    return 'टीम · $count';
  }

  @override
  String shopPendingInvitesHeader(Object count) {
    return 'लंबित आमंत्रण · $count';
  }

  @override
  String shopRolesHeader(Object count) {
    return 'भूमिकाएँ · $count';
  }

  @override
  String get shopEditAccessMenu => 'पहुँच संपादित करें';

  @override
  String get shopRemoveFromTeamMenu => 'टीम से हटाएँ';

  @override
  String shopInvitedAsAwaitingReply(Object role) {
    return '$role के रूप में आमंत्रित · उत्तर की प्रतीक्षा';
  }

  @override
  String get shopBuiltIn => 'अंतर्निहित';

  @override
  String get shopRoleViewOnly => 'केवल देखें';

  @override
  String shopRoleAreaManageable(Object count) {
    return '$count क्षेत्र प्रबंधित करने योग्य';
  }

  @override
  String shopRoleAreasManageable(Object count) {
    return '$count क्षेत्र प्रबंधित करने योग्य';
  }

  @override
  String get shopEditRoleMenu => 'भूमिका संपादित करें';

  @override
  String get shopDeleteRoleMenu => 'भूमिका हटाएँ';

  @override
  String get shopInviteSheetSubtitle =>
      'एक समर्पित कार्य ईमेल का उपयोग करें — खरीदार खाते स्टाफ़ नहीं बन सकते। आप आगे उनकी पहुँच चुनेंगे।';

  @override
  String get shopEnterEmail => 'एक ईमेल दर्ज करें';

  @override
  String get shopEnterValidEmail => 'एक मान्य ईमेल दर्ज करें';

  @override
  String get shopChooseAccess => 'पहुँच चुनें';

  @override
  String get shopNotNow => 'अभी नहीं';

  @override
  String get shopJoinFallbackShop => 'एक दुकान';

  @override
  String get shopStaffRole => 'स्टाफ़';

  @override
  String get shopYoureInvitedToJoin =>
      'आपको जुड़ने के लिए आमंत्रित किया गया है';

  @override
  String get shopAsA => 'इस रूप में ';

  @override
  String get shopWhatYoullBeAbleToDo => 'आप क्या कर पाएँगे';

  @override
  String get shopLimitedAccess => 'सीमित पहुँच — विवरण के लिए मालिक से पूछें।';

  @override
  String get shopJoinTheTeam => 'टीम में शामिल हों';

  @override
  String shopJoinNamed(Object shop) {
    return '$shop में शामिल हों';
  }

  @override
  String get shopDeclineInvitation => 'आमंत्रण अस्वीकार करें';

  @override
  String get shopSheetFinishTitle => 'भुगतान सेटअप पूरा करें';

  @override
  String get shopSheetSetupTitle => 'भुगतान पाने के लिए भुगतान सेट करें';

  @override
  String get shopSheetFinishBody =>
      'आपने भुगतान सेट करना शुरू किया था — जहाँ छोड़ा था वहीं से जारी रखें। आपके सहेजे गए विवरण इस डिवाइस पर सुरक्षित रखे गए हैं।';

  @override
  String get shopSheetSetupBody =>
      'अपना निपटान बैंक खाता जोड़ें ताकि प्रत्येक ऑर्डर में आपका हिस्सा आप तक पहुँच सके। आपका पैसा ऑर्डर डिलीवर होने तक रोका जाता है, फिर आपके बैंक में निपटाया जाता है — आमतौर पर कुछ दिनों के भीतर।';

  @override
  String get shopSetUpNow => 'अभी सेट करें';

  @override
  String get shopLater => 'बाद में';

  @override
  String get cashierTitle => 'कैशियर';

  @override
  String get cashierRoleCashier => 'कैशियर';

  @override
  String cashierShiftClosedVariance(Object variance) {
    return 'शिफ्ट बंद · अंतर $variance';
  }

  @override
  String get cashierPastShiftsTitle => 'पिछली शिफ्ट · Z-रसीदें';

  @override
  String get cashierLoading => 'लोड हो रहा है…';

  @override
  String get cashierNoShiftsYet => 'अभी तक कोई शिफ्ट नहीं।';

  @override
  String cashierVarianceLabel(Object amount) {
    return 'अंतर $amount';
  }

  @override
  String get cashierShiftReportTitle => 'शिफ्ट रिपोर्ट (X)';

  @override
  String cashierSalesSummary(Object count, Object gross) {
    return '$count बिक्री · $gross सकल';
  }

  @override
  String get cashierOpeningFloat => 'शुरुआती फ्लोट';

  @override
  String get cashierCashSales => 'नकद बिक्री';

  @override
  String get cashierPayIns => 'जमा';

  @override
  String get cashierPayOuts => 'निकासी';

  @override
  String get cashierDrops => 'ड्रॉप';

  @override
  String get cashierRefunds => 'रिफंड';

  @override
  String get cashierExpectedInDrawer => 'दराज में अपेक्षित';

  @override
  String get cashierGstTaxable => 'GST कर योग्य';

  @override
  String cashierReturnsCount(Object count) {
    return 'वापसी ($count)';
  }

  @override
  String get cashierOpenShiftTitle => 'शिफ्ट खोलें';

  @override
  String get cashierOpenShiftHint => 'दराज गिनें और शुरुआती फ्लोट दर्ज करें।';

  @override
  String get cashierOpeningFloatField => 'शुरुआती फ्लोट ₹';

  @override
  String get cashierOpenShiftButton => 'शिफ्ट खोलें';

  @override
  String get cashierCashDrawerTitle => 'नकद दराज';

  @override
  String get cashierPayIn => 'जमा';

  @override
  String get cashierPayOut => 'निकासी';

  @override
  String get cashierDrop => 'ड्रॉप';

  @override
  String get cashierAmountField => 'राशि ₹';

  @override
  String get cashierReasonField => 'कारण (वैकल्पिक)';

  @override
  String get cashierRecordButton => 'दर्ज करें';

  @override
  String get cashierCloseShiftTitle => 'शिफ्ट बंद करें';

  @override
  String cashierExpectedInDrawerValue(Object amount) {
    return 'दराज में अपेक्षित: $amount';
  }

  @override
  String get cashierCountedCashField => 'गिनी गई नकदी ₹';

  @override
  String cashierVarianceValue(Object amount, Object status) {
    return 'अंतर: $amount $status';
  }

  @override
  String get cashierVarianceBalanced => '(संतुलित)';

  @override
  String get cashierVarianceOver => '(अधिक)';

  @override
  String get cashierVarianceShort => '(कम)';

  @override
  String get cashierNoteField => 'नोट (वैकल्पिक)';

  @override
  String get cashierCloseZReportButton => 'बंद करें और Z-रिपोर्ट';

  @override
  String get cashierReturnsTitle => 'वापसी';

  @override
  String get cashierOriginalInvoiceIdField => 'मूल इनवॉइस आईडी';

  @override
  String get cashierLookUpButton => 'खोजें';

  @override
  String cashierReturnableLine(Object qty, Object price) {
    return 'वापसी योग्य $qty · $price';
  }

  @override
  String get cashierEnterQuantityError => 'वापस करने के लिए मात्रा दर्ज करें।';

  @override
  String cashierCreditNoteCreated(Object no, Object amount) {
    return 'क्रेडिट नोट $no · $amount';
  }

  @override
  String get cashierProcessReturnButton => 'वापसी संसाधित करें';

  @override
  String get posTitle => 'पॉइंट ऑफ सेल';

  @override
  String get posFindItem => 'आइटम खोजें';

  @override
  String get posCashierTooltip => 'कैशियर (शिफ्ट · ड्रॉअर · रिटर्न)';

  @override
  String get posHold => 'होल्ड करें';

  @override
  String get posRecall => 'वापस लाएँ';

  @override
  String get posLogOut => 'लॉग आउट';

  @override
  String get posCashier => 'कैशियर';

  @override
  String get posOpenShiftToBill => 'बिलिंग शुरू करने के लिए शिफ्ट खोलें';

  @override
  String get posOpenShift => 'शिफ्ट खोलें';

  @override
  String get posScanFirstItem => 'पहला आइटम स्कैन करें।';

  @override
  String get posTotal => 'कुल';

  @override
  String get posBillDiscount => 'बिल छूट';

  @override
  String get posCheckout => 'चेकआउट';

  @override
  String get posLineDiscount => 'लाइन छूट';

  @override
  String get posNewItem => 'नया आइटम';

  @override
  String get posName => 'नाम';

  @override
  String get posSellingPrice => 'बिक्री मूल्य ₹';

  @override
  String get posGstPercentOptional => 'GST % (वैकल्पिक)';

  @override
  String get posOnHand => 'उपलब्ध स्टॉक';

  @override
  String get posCancel => 'रद्द करें';

  @override
  String get posAdd => 'जोड़ें';

  @override
  String get posSaleComplete => 'बिक्री पूर्ण';

  @override
  String get posInvoice => 'चालान';

  @override
  String get posPrint => 'प्रिंट करें';

  @override
  String get posDone => 'हो गया';

  @override
  String get posCouldNotGenerateReceipt => 'रसीद नहीं बनाई जा सकी';

  @override
  String posDiscountMax(Object max) {
    return 'छूट ₹ (अधिकतम $max)';
  }

  @override
  String get posApply => 'लागू करें';

  @override
  String get posDiscount => 'छूट ₹';

  @override
  String get posCollect => 'वसूल करें';

  @override
  String get posCustomerOptional => 'ग्राहक (वैकल्पिक)';

  @override
  String get posPhone => 'फ़ोन';

  @override
  String get posCashReceived => 'नकद प्राप्त ₹';

  @override
  String get posChangeDue => 'वापस देने योग्य';

  @override
  String get posCashDone => 'नकद — हो गया';

  @override
  String get posOtherTenders => 'अन्य भुगतान विकल्प';

  @override
  String get posOnline => 'ऑनलाइन';

  @override
  String get posPaymentFailedRetry =>
      'भुगतान विफल रहा। कृपया पुनः प्रयास करें।';

  @override
  String get posNoHeldBills => 'कोई होल्ड किया बिल नहीं।';

  @override
  String get posHeldBills => 'होल्ड किए बिल';

  @override
  String get posBill => 'बिल';

  @override
  String posItemCount(Object count) {
    return '$count आइटम';
  }

  @override
  String get posQuantity => 'मात्रा';

  @override
  String get posSet => 'सेट करें';

  @override
  String get posFindItemByNameSku => 'नाम / SKU से आइटम खोजें';

  @override
  String get posSearching => 'खोज रहे हैं…';

  @override
  String get posTypeToSearch => 'कैटलॉग खोजने के लिए टाइप करें।';

  @override
  String get posStock => 'स्टॉक';

  @override
  String posAddedItem(Object name) {
    return '$name जोड़ा गया';
  }

  @override
  String get posStatusLive => 'लाइव';

  @override
  String get posStatusConnecting => 'कनेक्ट हो रहा है';

  @override
  String get posStatusReconnecting => 'पुनः कनेक्ट हो रहा है';

  @override
  String get posStatusOffline => 'ऑफ़लाइन';

  @override
  String get bannersTitle => 'बैनर';

  @override
  String get bannersRefresh => 'रिफ़्रेश करें';

  @override
  String get bannersNewBanner => 'नया बैनर';

  @override
  String get bannersDeleteTitle => 'बैनर हटाएँ?';

  @override
  String bannersDeleteMessage(Object placement) {
    return 'यह बैनर $placement से हटा दिया जाएगा।';
  }

  @override
  String get bannersCancel => 'रद्द करें';

  @override
  String get bannersDelete => 'हटाएँ';

  @override
  String get bannersEmptyPlacement =>
      'इस प्लेसमेंट में अभी तक कोई बैनर नहीं है';

  @override
  String get bannersStatusLive => 'लाइव';

  @override
  String get bannersStatusScheduled => 'शेड्यूल किया गया';

  @override
  String get bannersStatusExpired => 'समाप्त';

  @override
  String get bannersStatusOff => 'बंद';

  @override
  String bannersSortOrder(Object order) {
    return 'क्रम $order';
  }

  @override
  String bannersProductCountOne(Object count) {
    return '$count उत्पाद';
  }

  @override
  String bannersProductCountOther(Object count) {
    return '$count उत्पाद';
  }

  @override
  String bannersWindowFrom(Object date) {
    return '$date से';
  }

  @override
  String bannersWindowUntil(Object date) {
    return '$date तक';
  }

  @override
  String get bannersImageUploadFailed => 'इमेज अपलोड विफल रहा';

  @override
  String get bannersImageTooLarge =>
      'इमेज 5 MB से बड़ी है। कोई छोटी इमेज चुनें या ज़्यादा कसकर क्रॉप करें।';

  @override
  String get bannersImageRequired => 'एक इमेज आवश्यक है';

  @override
  String get bannersSaveFailed => 'सेव विफल रहा';

  @override
  String bannersProductsSaveFailed(Object error) {
    return 'बैनर सेव हो गया, लेकिन उत्पाद विफल रहे: $error';
  }

  @override
  String get bannersAlreadyPinned => 'पहले से ही इस बैनर पर पिन किया गया है';

  @override
  String get bannersEditBanner => 'बैनर संपादित करें';

  @override
  String get bannersPlacement => 'प्लेसमेंट';

  @override
  String get bannersLink => 'लिंक';

  @override
  String get bannersSort => 'क्रम';

  @override
  String get bannersActive => 'सक्रिय';

  @override
  String get bannersActiveSubtitle =>
      'बंद होने पर, शेड्यूल की परवाह किए बिना छिपा रहता है';

  @override
  String get bannersSaving => 'सेव हो रहा है…';

  @override
  String get bannersSaveChanges => 'बदलाव सेव करें';

  @override
  String get bannersCreateBanner => 'बैनर बनाएँ';

  @override
  String get bannersUploadImage => 'इमेज अपलोड करें *';

  @override
  String get bannersReplaceImage => 'इमेज बदलें';

  @override
  String get bannersStarts => 'शुरू';

  @override
  String get bannersEnds => 'समाप्त';

  @override
  String get bannersProducts => 'उत्पाद';

  @override
  String get bannersAdd => 'जोड़ें';

  @override
  String get bannersSaveFirstHint => 'उत्पाद जोड़ने के लिए पहले बैनर सेव करें।';

  @override
  String get bannersAddProductsHint =>
      'वैकल्पिक छूट के साथ उत्पाद पिन करने के लिए “जोड़ें” पर टैप करें।';

  @override
  String get bannersNotSet => 'सेट नहीं है';

  @override
  String get bannersSearchProduct => 'उत्पाद का नाम या SKU खोजें';

  @override
  String get bannersSearchHint => 'खोजने के लिए 2 या अधिक अक्षर टाइप करें';

  @override
  String get challansTitle => 'चालान';

  @override
  String get challansSearchHint => 'चालान खोजें...';

  @override
  String get challansFilterAll => 'सभी';

  @override
  String get challansEmptyTitle => 'कोई चालान नहीं मिला';

  @override
  String get challansEmptySubtitle => 'चालान बनाने के लिए + दबाएँ';

  @override
  String get challansCreate => 'चालान बनाएँ';

  @override
  String get challansItemsLabel => 'आइटम';

  @override
  String get challansCancel => 'चालान रद्द करें';

  @override
  String get challansCancelConfirm =>
      'इस चालान को रद्द करें? इसे वापस नहीं किया जा सकता।';

  @override
  String get challansYes => 'हाँ';

  @override
  String get challansNo => 'नहीं';

  @override
  String get challansError => 'कुछ गलत हो गया';

  @override
  String get challansPartyName => 'पक्ष का नाम';

  @override
  String get challansPhone => 'फ़ोन';

  @override
  String get challansNote => 'टिप्पणी';

  @override
  String get challansLinkedInvoice => 'इनवॉइस';

  @override
  String get challansItemsHeader => 'चालान आइटम';

  @override
  String get challansEmptyItems => 'अभी तक कोई आइटम नहीं जोड़ा गया';

  @override
  String get challansConvertToInvoice => 'इनवॉइस में बदलें';

  @override
  String get challansAddAtLeastOne => 'कम से कम एक उत्पाद जोड़ें';

  @override
  String get challansDiscardTitle => 'बदलाव रद्द करें?';

  @override
  String get challansDiscardMessage => 'आपके बदलाव खो जाएँगे।';

  @override
  String get challansKeepEditing => 'संपादन जारी रखें';

  @override
  String get challansDiscard => 'रद्द करें';

  @override
  String get challansSubmit => 'जमा करें';

  @override
  String get challansPartyInfo => 'पक्ष की जानकारी';

  @override
  String get challansSelectParty => 'पक्ष चुनें';

  @override
  String get challansFieldRequired => 'यह फ़ील्ड आवश्यक है';

  @override
  String get challansAddProducts => 'उत्पाद जोड़ें';

  @override
  String get challansNoPricesHint => 'कीमतें पक्ष को दिखाई नहीं देतीं';

  @override
  String get challansSearchProducts => 'उत्पाद खोजें...';

  @override
  String get challansChange => 'बदलें';

  @override
  String get returnsTitle => 'रिटर्न';

  @override
  String get returnsTabOpen => 'खुले';

  @override
  String get returnsTabApproved => 'स्वीकृत';

  @override
  String get returnsTabReceived => 'प्राप्त';

  @override
  String get returnsTabRefunded => 'रिफंड किया';

  @override
  String get returnsTabAll => 'सभी';

  @override
  String returnsRowTitle(Object id, Object name) {
    return 'रिटर्न #$id · $name';
  }

  @override
  String get returnsItemCountOne => '1 वस्तु';

  @override
  String returnsItemCountOther(Object count) {
    return '$count वस्तुएं';
  }

  @override
  String get returnsRefundLabel => 'रिफंड';

  @override
  String get returnsEmpty => 'इस दृश्य में अभी कोई रिटर्न नहीं है।';

  @override
  String get returnsRetry => 'पुनः प्रयास करें';

  @override
  String get returnsStatusRequested => 'अनुरोधित';

  @override
  String get returnsStatusApproved => 'स्वीकृत';

  @override
  String get returnsStatusRejected => 'अस्वीकृत';

  @override
  String get returnsStatusCancelled => 'रद्द किया गया';

  @override
  String get returnsStatusPickedUp => 'उठा लिया गया';

  @override
  String get returnsStatusReceived => 'प्राप्त';

  @override
  String get returnsStatusRefunded => 'रिफंड किया गया';

  @override
  String returnsDetailTitle(Object id) {
    return 'रिटर्न #$id';
  }

  @override
  String get returnsNoteOptional => 'नोट (वैकल्पिक)';

  @override
  String get returnsNoteRequired => 'नोट आवश्यक है';

  @override
  String get returnsCancel => 'रद्द करें';

  @override
  String get returnsBuyerNote => 'खरीदार का नोट';

  @override
  String get returnsYourNote => 'आपका नोट';

  @override
  String returnsRefundedToOriginal(Object amount, Object name) {
    return '$name की मूल भुगतान विधि में $amount रिफंड किया गया';
  }

  @override
  String get returnsApproveTitle => 'रिटर्न स्वीकृत करें';

  @override
  String get returnsApprove => 'स्वीकृत करें';

  @override
  String get returnsApproveHint => 'खरीदार के लिए पिकअप निर्देश (वैकल्पिक)';

  @override
  String get returnsApprovedToast => 'रिटर्न स्वीकृत किया गया';

  @override
  String get returnsRejectTitle => 'रिटर्न अस्वीकृत करें';

  @override
  String get returnsReject => 'अस्वीकृत करें';

  @override
  String get returnsRejectHint => 'क्यों? खरीदार को दिखाया जाएगा';

  @override
  String get returnsRejectedToast => 'रिटर्न अस्वीकृत किया गया';

  @override
  String get returnsPickedUpToast => 'उठा लिया गया के रूप में चिह्नित';

  @override
  String get returnsReceivedToast => 'प्राप्त के रूप में चिह्नित';

  @override
  String returnsRefundConfirmTitle(Object amount) {
    return '$amount रिफंड करें?';
  }

  @override
  String get returnsRefundConfirmBody =>
      'यह खरीदार को उनकी मूल भुगतान विधि में रिफंड करता है। इस कार्रवाई को वापस नहीं लिया जा सकता।';

  @override
  String get returnsRefund => 'रिफंड करें';

  @override
  String get returnsRefundIssuedToast =>
      'मूल भुगतान विधि में रिफंड जारी किया गया';

  @override
  String returnsOrderSlice(Object orderId, Object sliceId) {
    return 'ऑर्डर #$orderId · स्लाइस #$sliceId';
  }

  @override
  String get returnsRefundPreview => 'रिफंड पूर्वावलोकन: ';

  @override
  String get returnsItems => 'वस्तुएं';

  @override
  String get returnsReasonDamaged => 'पहुंचने पर क्षतिग्रस्त';

  @override
  String get returnsReasonWrongItem => 'गलत वस्तु भेजी गई';

  @override
  String get returnsReasonNotAsDescribed => 'वर्णन के अनुसार नहीं';

  @override
  String get returnsReasonSizeFit => 'आकार / फिट की समस्या';

  @override
  String get returnsReasonChangedMind => 'खरीदार ने मन बदला';

  @override
  String get returnsReasonDefective => 'दोषपूर्ण / काम नहीं कर रहा';

  @override
  String get returnsReasonOther => 'अन्य';

  @override
  String get returnsTimeline => 'समयरेखा';

  @override
  String get returnsMarkPickedUp => 'उठा लिया गया के रूप में चिह्नित करें';

  @override
  String get returnsMarkReceived => 'प्राप्त के रूप में चिह्नित करें';

  @override
  String get adminActive => 'सक्रिय';

  @override
  String get adminCancel => 'रद्द करें';

  @override
  String get adminDelete => 'हटाएं';

  @override
  String get adminDeactivate => 'निष्क्रिय करें';

  @override
  String get adminCreate => 'बनाएं';

  @override
  String get adminSave => 'सहेजें';

  @override
  String get adminSaving => 'सहेजा जा रहा है…';

  @override
  String get adminSaveChanges => 'बदलाव सहेजें';

  @override
  String get adminSaveFailed => 'सहेजना विफल रहा';

  @override
  String get adminRefresh => 'रीफ़्रेश करें';

  @override
  String get adminRetry => 'फिर से कोशिश करें';

  @override
  String get adminNotSet => 'सेट नहीं है';

  @override
  String get adminPublished => 'प्रकाशित';

  @override
  String get adminDraft => 'ड्राफ़्ट';

  @override
  String get adminSortLabel => 'क्रम';

  @override
  String get adminImageTooLarge =>
      'इमेज 5 MB से बड़ी है। छोटी इमेज चुनें या और कसकर क्रॉप करें।';

  @override
  String get adminImageUploadFailed => 'इमेज अपलोड विफल रहा';

  @override
  String get adminReplaceImage => 'इमेज बदलें';

  @override
  String get adminLinkTargetHelper =>
      'category:slug | product:id | url:https://…';

  @override
  String get adminBankOffersTitle => 'बैंक ऑफ़र';

  @override
  String get adminBankOfferNew => 'नया ऑफ़र';

  @override
  String get adminBankOffersEmpty =>
      'अभी तक कोई बैंक ऑफ़र नहीं। पहला ऑफ़र बनाने के लिए \"नया ऑफ़र\" पर टैप करें।';

  @override
  String get adminBankOfferDeactivateTitle => 'ऑफ़र निष्क्रिय करें?';

  @override
  String get adminBankOfferDeactivateBody =>
      'ग्राहकों को यह ऑफ़र किसी भी PDP पर नहीं दिखेगा। आप इसे बाद में इस पेज से फिर से सक्रिय कर सकते हैं।';

  @override
  String adminBankOfferPercentOff(Object value) {
    return '$value% छूट';
  }

  @override
  String adminBankOfferAmountOff(Object value) {
    return '$value छूट';
  }

  @override
  String adminBankOfferMinOrder(Object value) {
    return 'न्यूनतम ऑर्डर $value';
  }

  @override
  String adminBankOfferCap(Object value) {
    return 'अधिकतम $value';
  }

  @override
  String adminBankOfferValidRange(Object from, Object until) {
    return 'मान्य $from – $until';
  }

  @override
  String get adminBankOfferEditTitle => 'बैंक ऑफ़र संपादित करें';

  @override
  String get adminBankOfferNewTitle => 'नया बैंक ऑफ़र';

  @override
  String get adminBankOfferBankLabel => 'बैंक';

  @override
  String get adminBankOfferCardTypeLabel => 'कार्ड प्रकार';

  @override
  String get adminBankOfferTypeLabel => 'प्रकार';

  @override
  String get adminBankOfferTypePercent => 'प्रतिशत छूट';

  @override
  String get adminBankOfferTypeFlat => 'फ़्लैट ₹ छूट';

  @override
  String get adminBankOfferPercentField => '% छूट';

  @override
  String get adminBankOfferAmountField => '₹ छूट';

  @override
  String get adminBankOfferMaxDiscountLabel => 'अधिकतम छूट (₹) — % छूट की सीमा';

  @override
  String get adminBankOfferMinOrderLabel =>
      'न्यूनतम ऑर्डर (₹) — पात्रता फ़िल्टर';

  @override
  String get adminBankOfferTermsLabel => 'शर्तें (वैकल्पिक)';

  @override
  String get adminBankOfferTermsHint =>
      'जैसे, नो-कॉस्ट EMI पर मान्य नहीं। Apple उत्पाद शामिल नहीं।';

  @override
  String adminBankOfferFrom(Object date) {
    return 'से  $date';
  }

  @override
  String adminBankOfferUntil(Object date) {
    return 'तक $date';
  }

  @override
  String get adminBankOfferActiveSubtitle =>
      'बंद होने पर, ऑफ़र किसी PDP पर कभी नहीं दिखता। इसका उपयोग ड्राफ़्ट रोकने या ऑफ़र को हटाए बिना जल्दी समाप्त करने के लिए करें।';

  @override
  String get adminBankOfferPdpPreview => 'PDP पूर्वावलोकन';

  @override
  String adminBankOfferPreviewCap(Object value) {
    return ' ₹$value तक';
  }

  @override
  String adminBankOfferPreviewPercent(
    Object discount,
    Object cap,
    Object target,
  ) {
    return '$target पर $discount% छूट$cap';
  }

  @override
  String adminBankOfferPreviewFlat(Object discount, Object target) {
    return '$target पर ₹$discount छूट';
  }

  @override
  String get adminBankOfferCreate => 'ऑफ़र बनाएं';

  @override
  String get adminBannersTitle => 'बैनर प्रबंधक';

  @override
  String get adminBannerNew => 'नया बैनर';

  @override
  String get adminBannerDeleteTitle => 'बैनर हटाएं?';

  @override
  String adminBannerDeleteBody(Object placement) {
    return 'यह बैनर $placement से हटा दिया जाएगा।';
  }

  @override
  String get adminBannerPlacementEmpty => 'इस स्थान पर अभी तक कोई बैनर नहीं';

  @override
  String adminBannerSort(Object value) {
    return 'क्रम $value';
  }

  @override
  String get adminBannerEditTitle => 'बैनर संपादित करें';

  @override
  String get adminBannerNewTitle => 'नया बैनर';

  @override
  String get adminBannerImageRequired => 'एक इमेज आवश्यक है';

  @override
  String get adminBannerPlacementLabel => 'स्थान';

  @override
  String get adminBannerLinkLabel => 'लिंक';

  @override
  String get adminBannerActiveSubtitle =>
      'बंद होने पर, शेड्यूल की परवाह किए बिना छिपा रहेगा';

  @override
  String get adminBannerCreate => 'बैनर बनाएं';

  @override
  String get adminBannerUploadImage => 'इमेज अपलोड करें *';

  @override
  String get adminBannerStarts => 'शुरू';

  @override
  String get adminBannerEnds => 'समाप्त';

  @override
  String get adminCategoryTaxonomyTitle => 'श्रेणी वर्गीकरण';

  @override
  String get adminCategoryRoot => 'मूल श्रेणी';

  @override
  String adminCategoryDeleteTitle(Object name) {
    return '\"$name\" हटाएं?';
  }

  @override
  String get adminCategoryDeleteBody =>
      'उप-श्रेणियां मूल में स्थानांतरित हो जाएंगी। इस श्रेणी के उत्पाद \"अवर्गीकृत\" में चले जाएंगे (लिंक शून्य हो जाएगा)।';

  @override
  String adminCategoryProductCount(Object value) {
    return '$value उत्पाद';
  }

  @override
  String get adminCategoryAddChild => 'उप-श्रेणी जोड़ें';

  @override
  String get adminCategoryNameRequired => 'नाम आवश्यक है';

  @override
  String get adminCategoryEditTitle => 'श्रेणी संपादित करें';

  @override
  String get adminCategoryNewTitle => 'नई श्रेणी';

  @override
  String get adminCategoryNameLabel => 'नाम *';

  @override
  String get adminCategoryNameHelper => 'स्लग इससे अपने आप बनता है।';

  @override
  String get adminCategoryDescriptionLabel => 'विवरण';

  @override
  String get adminCategoryImageUrlLabel => 'इमेज URL';

  @override
  String get adminCategoryImageUrlHelper => 'ग्राहक-पक्ष की गोल पक इमेज।';

  @override
  String get adminCategoryParentLabel => 'मूल श्रेणी';

  @override
  String get adminCategoryRootOption => '— मूल —';

  @override
  String get adminCollectionsTitle => 'संग्रह';

  @override
  String get adminCollectionNew => 'नया संग्रह';

  @override
  String get adminCollectionsEmpty => 'अभी तक कोई संग्रह नहीं';

  @override
  String get adminCollectionDeleteTitle => 'संग्रह हटाएं?';

  @override
  String adminCollectionDeleteBody(Object title) {
    return '\"$title\" और इसकी आइटम सूची हटा दी जाएगी।';
  }

  @override
  String adminCollectionItemCountOne(Object value) {
    return '$value आइटम';
  }

  @override
  String adminCollectionItemCountOther(Object value) {
    return '$value आइटम';
  }

  @override
  String get adminCollectionEditTitle => 'संग्रह संपादित करें';

  @override
  String get adminCollectionNewTitle => 'नया संग्रह';

  @override
  String get adminCollectionAddProduct => 'उत्पाद जोड़ें';

  @override
  String get adminCollectionTitleRequired => 'शीर्षक आवश्यक है';

  @override
  String get adminCollectionAlreadyAdded => 'पहले से ही इस संग्रह में है';

  @override
  String get adminCollectionTitleLabel => 'शीर्षक *';

  @override
  String get adminCollectionSlugLabel => 'स्लग';

  @override
  String get adminCollectionSlugHelper =>
      'शीर्षक से अपने आप बनाने के लिए खाली छोड़ें';

  @override
  String get adminCollectionEyebrowLabel => 'आइब्रो';

  @override
  String get adminCollectionEyebrowHelper => 'शीर्षक के ऊपर छोटा टेक्स्ट';

  @override
  String get adminCollectionSubtitleLabel => 'उपशीर्षक';

  @override
  String get adminCollectionCtaTextLabel => 'CTA टेक्स्ट';

  @override
  String get adminCollectionCtaTargetLabel => 'CTA लक्ष्य';

  @override
  String get adminCollectionBgColorLabel => 'बैकग्राउंड रंग (#hex)';

  @override
  String get adminCollectionBgColorHelper => 'वैकल्पिक — रेल में एक्सेंट सतह';

  @override
  String get adminCollectionPublishedSubtitle =>
      'ग्राहक ऐप पर खरीदारों को दिखाई देगा';

  @override
  String get adminCollectionItemsSection => 'आइटम';

  @override
  String get adminCollectionItemsHintNew =>
      'पहले संग्रह सहेजें, फिर + बटन से उत्पाद जोड़ें।';

  @override
  String get adminCollectionItemsHintEmpty =>
      'उत्पाद जोड़ने के लिए ऐप बार में + पर टैप करें।';

  @override
  String get adminCollectionCoverImage => 'कवर इमेज';

  @override
  String get adminCollectionReplaceCover => 'कवर बदलें';

  @override
  String get adminCollectionProductSearchLabel => 'उत्पाद नाम या SKU खोजें';

  @override
  String get adminCollectionProductSearchHint =>
      'खोजने के लिए 2+ अक्षर टाइप करें';

  @override
  String get adminShopsTitle => 'दुकान सत्यापन';

  @override
  String get adminShopsSearchHint => 'दुकान का नाम या स्लग खोजें';

  @override
  String get adminShopVerified => 'सत्यापित';

  @override
  String get adminShopDraft => 'ड्राफ़्ट';

  @override
  String get adminShopsEmpty => 'कोई दुकान नहीं मिली।';

  @override
  String get analyticsTitle => 'एनालिटिक्स';

  @override
  String get analyticsRefresh => 'रिफ़्रेश करें';

  @override
  String get analyticsByProduct => 'उत्पाद अनुसार';

  @override
  String get analyticsNoActiveProducts => 'अभी तक कोई सक्रिय उत्पाद नहीं';

  @override
  String get analyticsKpiImpressions => 'इंप्रेशन';

  @override
  String get analyticsKpiTaps => 'टैप';

  @override
  String get analyticsKpiViews => 'व्यूज़';

  @override
  String get analyticsKpiAddToCart => 'कार्ट में जोड़ा';

  @override
  String get analyticsKpiPurchases => 'खरीदारी';

  @override
  String get analyticsKpiWishlist => 'विशलिस्ट';

  @override
  String get analyticsKpiCtr => 'CTR';

  @override
  String get analyticsKpiCvr => 'CVR';

  @override
  String get analyticsColProduct => 'उत्पाद';

  @override
  String get analyticsColImpressions => 'इंप्र.';

  @override
  String get analyticsColTaps => 'टैप';

  @override
  String get analyticsColViews => 'व्यूज़';

  @override
  String get analyticsColAddToCart => 'ATC';

  @override
  String get analyticsColPurchases => 'खरीद';

  @override
  String get analyticsColCtr => 'CTR';

  @override
  String get analyticsColCvr => 'CVR';

  @override
  String get customFieldsTitle => 'कस्टम फ़ील्ड';

  @override
  String get customFieldsTemplates => 'टेम्पलेट';

  @override
  String get customFieldsAddField => 'फ़ील्ड जोड़ें';

  @override
  String get customFieldsAddSection => 'सेक्शन जोड़ें';

  @override
  String get customFieldsEditField => 'फ़ील्ड संपादित करें';

  @override
  String get customFieldsEditSection => 'सेक्शन संपादित करें';

  @override
  String get customFieldsArchive => 'आर्काइव';

  @override
  String customFieldsArchiveSectionTitle(Object name) {
    return '\"$name\" को आर्काइव करें?';
  }

  @override
  String get customFieldsArchiveSectionMessage =>
      'आर्काइव करने से सेक्शन छिप जाता है। इसकी फ़ील्ड जहाँ हैं वहीं रहती हैं और बाद में दोबारा असाइन की जा सकती हैं।';

  @override
  String customFieldsArchiveFieldTitle(Object name) {
    return '\"$name\" को आर्काइव करें?';
  }

  @override
  String get customFieldsArchiveFieldConfirm =>
      'इस फ़ील्ड को आर्काइव करें? मौजूदा वैल्यू हर प्रोडक्ट पर बनी रहेंगी, लेकिन नई फ़ील्ड नए प्रोडक्ट पर दिखना बंद हो जाएगी।';

  @override
  String get customFieldsEmptyTitle => 'अभी तक कोई कस्टम फ़ील्ड नहीं';

  @override
  String get customFieldsEmptyHint =>
      'वारंटी, मॉडल नंबर, मटेरियल जैसी फ़ील्ड बनाएँ — हर प्रोडक्ट पर दिखेंगी।';

  @override
  String get customFieldsBrowseTemplates => 'टेम्पलेट देखें';

  @override
  String get customFieldsTemplatesCalloutTitle =>
      'क्विक-स्टार्ट टेम्पलेट लगाएँ';

  @override
  String get customFieldsTemplatesCalloutSubtitle =>
      'इलेक्ट्रॉनिक्स, परिधान, लॉजिस्टिक्स, फ़ूड, वारंटी…';

  @override
  String customFieldsFieldCountOne(Object count) {
    return '$count फ़ील्ड';
  }

  @override
  String customFieldsFieldCountOther(Object count) {
    return '$count फ़ील्ड';
  }

  @override
  String get customFieldsNoSection => 'कोई सेक्शन नहीं';

  @override
  String customFieldsUngroupedCountOne(Object count) {
    return '$count बिना-समूह फ़ील्ड';
  }

  @override
  String customFieldsUngroupedCountOther(Object count) {
    return '$count बिना-समूह फ़ील्ड';
  }

  @override
  String customFieldsUnitInline(Object unit) {
    return '$unit में';
  }

  @override
  String customFieldsOptionCountOne(Object count) {
    return '$count विकल्प';
  }

  @override
  String customFieldsOptionCountOther(Object count) {
    return '$count विकल्प';
  }

  @override
  String get customFieldsSectionName => 'सेक्शन का नाम';

  @override
  String get customFieldsFieldRequired => 'यह फ़ील्ड आवश्यक है';

  @override
  String get customFieldsPickIcon => 'एक आइकन चुनें';

  @override
  String get customFieldsLoading => 'लोड हो रहा है...';

  @override
  String get customFieldsSave => 'सहेजें';

  @override
  String get customFieldsDropdownMinOptions =>
      'ड्रॉपडाउन के लिए कम से कम दो विकल्प जोड़ें।';

  @override
  String get customFieldsFieldName => 'फ़ील्ड का नाम';

  @override
  String get customFieldsFieldType => 'फ़ील्ड का प्रकार';

  @override
  String get customFieldsSectionOptional => 'सेक्शन (वैकल्पिक)';

  @override
  String get customFieldsUnitSuffix => 'यूनिट (वैकल्पिक)';

  @override
  String get customFieldsUnitSuffixHint => 'जैसे kg, days, GB';

  @override
  String get customFieldsOptions => 'विकल्प';

  @override
  String get customFieldsOptionsHint =>
      'हर पंक्ति में एक। ड्रॉपडाउन विकल्पों के लिए उपयोग होता है।';

  @override
  String get customFieldsTemplateApplied => 'टेम्पलेट लागू किया गया';

  @override
  String get customFieldsQuickStartTemplates => 'क्विक-स्टार्ट टेम्पलेट';

  @override
  String get customFieldsTemplatesSheetSubtitle =>
      'किसी भी टेम्पलेट पर टैप करके उसका सेक्शन और फ़ील्ड अपनी दुकान में जोड़ें।';

  @override
  String get customFieldsTemplatesUnavailable =>
      'टेम्पलेट उपलब्ध नहीं हैं। अपना कनेक्शन जाँचें और फिर से प्रयास करें।';

  @override
  String customFieldsTemplateFieldCount(Object count) {
    return '$count फ़ील्ड';
  }

  @override
  String get customFieldsPickDate => 'एक तारीख़ चुनें';

  @override
  String get paymentsCounterpartyParty => 'पार्टी';

  @override
  String get paymentsCounterpartyVendor => 'वेंडर';

  @override
  String get paymentsRecordReceiptTitle => 'रसीद दर्ज करें';

  @override
  String get paymentsRecordPaymentTitle => 'भुगतान दर्ज करें';

  @override
  String paymentsFromCounterparty(Object name) {
    return '$name से';
  }

  @override
  String paymentsToCounterparty(Object name) {
    return '$name को';
  }

  @override
  String get paymentsAmountLabel => 'राशि';

  @override
  String get paymentsAmountPositiveError => 'धनात्मक राशि दर्ज करें';

  @override
  String get paymentsModeLabel => 'माध्यम';

  @override
  String get paymentsUpiTransactionIdLabel => 'UPI लेनदेन आईडी';

  @override
  String get paymentsChequeNumberLabel => 'चेक नंबर';

  @override
  String get paymentsReferenceLabel => 'संदर्भ';

  @override
  String get paymentsDateLabel => 'तारीख';

  @override
  String get paymentsAllocatedToLabel => 'आवंटित';

  @override
  String get paymentsInvoiceLabel => 'इनवॉइस';

  @override
  String get paymentsAllocateToInvoiceTitle => 'किसी इनवॉइस में आवंटित करें';

  @override
  String get paymentsAllocateToInvoiceSubtitle => 'बंद = खाते में जमा';

  @override
  String paymentsNoInvoicesFound(Object name) {
    return 'इस $name के लिए कोई इनवॉइस नहीं मिली।';
  }

  @override
  String get paymentsPickInvoiceError => 'एक इनवॉइस चुनें';

  @override
  String get paymentsNoteOptionalLabel => 'नोट (वैकल्पिक)';

  @override
  String get paymentsSaveReceipt => 'रसीद सहेजें';

  @override
  String get paymentsSavePayment => 'भुगतान सहेजें';

  @override
  String reviewsTitle(Object name) {
    return 'समीक्षाएँ · $name';
  }

  @override
  String get reviewsLoadMore => 'और लोड करें';

  @override
  String get reviewsEmpty =>
      'अभी कोई समीक्षा नहीं — खरीदार जैसे ही समीक्षा देंगे, वह यहाँ दिखेगी।';

  @override
  String get reviewsNoneYet => 'अभी कोई समीक्षा नहीं';

  @override
  String get reviewsCountSingular => '1 समीक्षा';

  @override
  String reviewsCountPlural(Object count) {
    return '$count समीक्षाएँ';
  }

  @override
  String get reviewsCustomerFallback => 'ग्राहक';

  @override
  String get scanConsoleTitle => 'कंसोल पर स्कैन करें';

  @override
  String get scanConsoleClear => 'साफ़ करें';

  @override
  String scanConsoleClearFailed(Object error) {
    return 'साफ़ नहीं हो सका: $error';
  }

  @override
  String get scanConsoleEmpty =>
      'कैमरे को किसी उत्पाद के बारकोड या QR पर लक्षित करें।';

  @override
  String get scanConsoleConnected => 'कनेक्शन स्थापित हो गया';

  @override
  String scanConsoleWatching(Object count, Object sent) {
    return '$count कंसोल देख रहे हैं · $sent भेजे गए';
  }

  @override
  String get scanConsoleOpenWebHint =>
      'स्कैन लाइव देखने के लिए वेब पर स्कैन कंसोल खोलें';

  @override
  String get scanConsoleConnecting => 'कनेक्ट हो रहा है…';

  @override
  String get scanConsoleReconnecting => 'फिर से कनेक्ट हो रहा है…';

  @override
  String get scanConsoleNotConnected => 'कनेक्ट नहीं है';

  @override
  String get stockLedgerTitle => 'स्टॉक लेजर';

  @override
  String get stockLedgerEmptySubtitle =>
      'इस उत्पाद के लिए अभी तक कोई मूवमेंट दर्ज नहीं हुआ है।';

  @override
  String get stockLedgerReversalBadge => 'रिवर्सल';

  @override
  String stockLedgerByName(Object name) {
    return '$name द्वारा';
  }

  @override
  String stockLedgerBalance(Object qty) {
    return 'शेष: $qty';
  }

  @override
  String get stockLedgerViewSource => 'स्रोत देखें';

  @override
  String get stockSheetDraftCreated =>
      'ड्राफ्ट इनवॉइस बन गया — स्टॉक पोस्ट करने के लिए इसे Invoices टैब से कन्फर्म करें।';

  @override
  String stockSheetCurrentStock(Object qty, Object unit) {
    return 'वर्तमान स्टॉक: $qty $unit';
  }

  @override
  String get stockSheetPurchase => 'खरीद';

  @override
  String get stockSheetSale => 'बिक्री';

  @override
  String get stockSheetQuantity => 'मात्रा';

  @override
  String get stockSheetFieldRequired => 'यह फ़ील्ड आवश्यक है';

  @override
  String get stockSheetInvalidNumber => 'मान्य संख्या दर्ज करें';

  @override
  String get stockSheetUnitPrice => 'यूनिट कीमत';

  @override
  String get stockSheetCustomer => 'ग्राहक';

  @override
  String get stockSheetSearchParties =>
      'पार्टियाँ खोजें — डिफ़ॉल्ट रूप से Walk-in Customer';

  @override
  String get stockSheetClear => 'साफ़ करें';

  @override
  String get stockSheetSupplier => 'सप्लायर';

  @override
  String get stockSheetSupplierHint => 'सप्लायर-वार कीमत इतिहास ट्रैक करें';

  @override
  String get stockSheetSupplierAutocompleteHint =>
      'पिछले सप्लायर देखने के लिए टाइप करना शुरू करें';

  @override
  String get stockSheetNote => 'नोट';

  @override
  String get stockSheetConfirm => 'कन्फर्म करें';

  @override
  String get stockAdjTitle => 'स्टॉक समायोजन';

  @override
  String get stockAdjEmptyTitle => 'अभी तक कोई समायोजन नहीं';

  @override
  String get stockAdjEmptySubtitle =>
      'क्षति, समाप्त स्टॉक, या गिनती सुधार दर्ज करने के लिए + पर टैप करें।';

  @override
  String get stockAdjItemSingular => 'वस्तु';

  @override
  String get stockAdjItemPlural => 'वस्तुएं';

  @override
  String get stockAdjNewTitle => 'नया स्टॉक समायोजन';

  @override
  String get stockAdjSubmit => 'सबमिट करें';

  @override
  String get stockAdjAddAtLeastOne =>
      'समायोजित करने के लिए कम से कम एक वस्तु जोड़ें।';

  @override
  String get stockAdjDiscardTitle => 'बदलाव रद्द करें?';

  @override
  String get stockAdjDiscardMessage => 'आपके बदलाव खो जाएंगे।';

  @override
  String get stockAdjKeepEditing => 'संपादन जारी रखें';

  @override
  String get stockAdjDiscard => 'रद्द करें';

  @override
  String get stockAdjReasonSection => 'कारण';

  @override
  String get stockAdjProductsSection => 'उत्पाद';

  @override
  String get stockAdjReasonDamage => 'क्षतिग्रस्त';

  @override
  String get stockAdjReasonExpired => 'समाप्त';

  @override
  String get stockAdjReasonShrinkage => 'कमी';

  @override
  String get stockAdjReasonRecount => 'पुनर्गणना सुधार';

  @override
  String get stockAdjReasonOpening => 'प्रारंभिक शेष';

  @override
  String get stockAdjAddStock => 'स्टॉक जोड़ें';

  @override
  String get stockAdjRemoveStock => 'स्टॉक हटाएं';

  @override
  String get stockAdjNote => 'टिप्पणी';

  @override
  String get stockAdjSearchProducts => 'उत्पाद खोजें';

  @override
  String get stockAdjNoProductsAdded => 'अभी तक कोई उत्पाद नहीं जोड़ा गया।';

  @override
  String get stockAdjSearchToAdd =>
      'जिन उत्पादों को समायोजित करना है उन्हें जोड़ने के लिए ऊपर खोजें।';

  @override
  String get stockAdjAddsStock => 'स्टॉक में जोड़ता है';

  @override
  String get stockAdjReducesStock => 'स्टॉक से घटाता है';

  @override
  String get stockAdjPostAdjustment => 'समायोजन पोस्ट करें';

  @override
  String get sharedContactChangesRecentChanges => 'हाल के बदलाव';

  @override
  String get sharedContactChangesChangedSuffix => 'बदला गया';

  @override
  String get sharedContactChangesFieldName => 'नाम';

  @override
  String get sharedContactChangesFieldContactPerson => 'संपर्क व्यक्ति';

  @override
  String get sharedContactChangesFieldPhone => 'फ़ोन';

  @override
  String get sharedContactChangesFieldEmail => 'ईमेल';

  @override
  String get sharedContactChangesFieldAddress => 'पता';

  @override
  String get sharedContactChangesFieldCity => 'शहर';

  @override
  String get sharedContactChangesFieldState => 'राज्य';

  @override
  String get sharedContactChangesFieldStateCode => 'राज्य कोड';

  @override
  String get sharedContactChangesFieldPinCode => 'पिन कोड';

  @override
  String get sharedContactChangesFieldActive => 'सक्रिय';

  @override
  String get navDashboard => 'डैशबोर्ड';

  @override
  String get navProducts => 'उत्पाद';

  @override
  String get navOrders => 'ऑर्डर';

  @override
  String get navProfile => 'प्रोफ़ाइल';

  @override
  String get navCategories => 'श्रेणियाँ';

  @override
  String get navVendors => 'विक्रेता';

  @override
  String get navParties => 'पक्ष';

  @override
  String get navInvoices => 'इनवॉइस';

  @override
  String get navQuotations => 'कोटेशन';

  @override
  String get navChallans => 'चालान';

  @override
  String get navMyShop => 'मेरी दुकान';

  @override
  String get navTeamRoles => 'टीम और भूमिकाएँ';

  @override
  String get navBanners => 'बैनर';

  @override
  String get navCoupons => 'कूपन';

  @override
  String get navPointOfSale => 'पॉइंट ऑफ़ सेल';

  @override
  String get navCashier => 'कैशियर';

  @override
  String get navScanToConsole => 'कंसोल में स्कैन करें';

  @override
  String get navStockAdjustments => 'स्टॉक समायोजन';

  @override
  String get navReturns => 'रिटर्न';

  @override
  String get navReports => 'रिपोर्ट';

  @override
  String get navAnalytics => 'एनालिटिक्स';

  @override
  String get navBannerManager => 'बैनर मैनेजर';

  @override
  String get navCategoryTaxonomy => 'श्रेणी वर्गीकरण';

  @override
  String get navCollections => 'कलेक्शन';

  @override
  String get navBankOffers => 'बैंक ऑफ़र';

  @override
  String get navShopVerification => 'दुकान सत्यापन';

  @override
  String get navSectionManage => 'प्रबंधन';

  @override
  String get navSectionOperations => 'संचालन';

  @override
  String get navSectionPlatformAdmin => 'प्लेटफ़ॉर्म एडमिन';

  @override
  String get navMenu => 'मेनू';

  @override
  String get reportsTitle => 'रिपोर्ट';

  @override
  String get reportsRefresh => 'ताज़ा करें';

  @override
  String get reportsRetry => 'पुनः प्रयास करें';

  @override
  String get reportsPresetThisMonth => 'इस महीने';

  @override
  String get reportsPresetLast30Days => 'पिछले 30 दिन';

  @override
  String get reportsPresetThisFy => 'इस वित्तीय वर्ष';

  @override
  String get reportsTabSales => 'बिक्री';

  @override
  String get reportsTabPurchases => 'खरीद';

  @override
  String get reportsTabGst => 'GST';

  @override
  String get reportsTabPnl => 'लाभ-हानि';

  @override
  String get reportsTabCalculator => 'कैलकुलेटर';

  @override
  String get reportsNoActivityInRange => 'इस अवधि में कोई गतिविधि नहीं।';

  @override
  String reportsPace(Object perDay, Object projected) {
    return '≈ $perDay/दिन इस गति से · ~$projected 30 दिनों में';
  }

  @override
  String get reportsTotalSales => 'कुल बिक्री';

  @override
  String reportsSalesHelper(Object count, Object tax, Object net) {
    return '$count पुष्ट चालान · $tax GST · रिफंड के बाद शुद्ध $net';
  }

  @override
  String get reportsTopProducts => 'शीर्ष उत्पाद';

  @override
  String get reportsNoSalesInRange => 'इस अवधि में कोई बिक्री नहीं।';

  @override
  String reportsSoldCount(Object count) {
    return '$count बिके';
  }

  @override
  String get reportsTopCustomers => 'शीर्ष ग्राहक';

  @override
  String get reportsNoCustomersInRange => 'इस अवधि में कोई ग्राहक नहीं।';

  @override
  String reportsInvoiceCountOne(Object count) {
    return '$count चालान';
  }

  @override
  String reportsInvoiceCountOther(Object count) {
    return '$count चालान';
  }

  @override
  String get reportsTotalPurchases => 'कुल खरीद';

  @override
  String reportsPurchasesHelper(Object count, Object tax) {
    return '$count पुष्ट बिल · $tax GST';
  }

  @override
  String get reportsTopPurchasedProducts => 'शीर्ष खरीदे गए उत्पाद';

  @override
  String get reportsNoPurchasesInRange => 'इस अवधि में कोई खरीद नहीं।';

  @override
  String reportsBoughtCount(Object count) {
    return '$count खरीदे';
  }

  @override
  String get reportsTopVendors => 'शीर्ष विक्रेता';

  @override
  String get reportsNoVendorsInRange => 'इस अवधि में कोई विक्रेता नहीं।';

  @override
  String reportsBillCountOne(Object count) {
    return '$count बिल';
  }

  @override
  String reportsBillCountOther(Object count) {
    return '$count बिल';
  }

  @override
  String get reportsOutputGst => 'आउटपुट GST';

  @override
  String get reportsCollectedOnSales => 'बिक्री पर एकत्रित';

  @override
  String get reportsInputGstItc => 'इनपुट GST (ITC)';

  @override
  String get reportsPaidOnPurchases => 'खरीद पर चुकाया गया';

  @override
  String get reportsNetGstPayable => 'देय शुद्ध GST';

  @override
  String get reportsGstOwedNote => 'यह आपको कर प्राधिकरण को चुकाना है';

  @override
  String get reportsGstCreditCarriedNote => 'इनपुट क्रेडिट आगे ले जाया गया';

  @override
  String get reportsNetPayableByTaxHead => 'कर शीर्ष अनुसार देय शुद्ध';

  @override
  String get reportsTaxHeadNote =>
      'CGST + SGST राज्य के भीतर बिक्री पर लागू होते हैं; IGST अंतर-राज्यीय पर। शुद्ध राशि प्रत्येक शीर्ष के आउटपुट कर में से उसके अपने इनपुट क्रेडिट को घटाकर होती है।';

  @override
  String get reportsOutputGstByRate => 'दर अनुसार आउटपुट GST';

  @override
  String get reportsNoOutputGstInRange => 'इस अवधि में कोई आउटपुट GST नहीं।';

  @override
  String get reportsInputGstByRate => 'दर अनुसार इनपुट GST';

  @override
  String get reportsNoInputGstInRange => 'इस अवधि में कोई इनपुट GST नहीं।';

  @override
  String get reportsCess => 'उपकर';

  @override
  String get reportsOutputCess => 'आउटपुट उपकर';

  @override
  String get reportsInputCess => 'इनपुट उपकर';

  @override
  String get reportsNetCessPayable => 'देय शुद्ध उपकर';

  @override
  String get reportsCessNote =>
      'उपकर केवल उपकर के विरुद्ध समायोजित होता है, GST के विरुद्ध कभी नहीं।';

  @override
  String reportsOutputGstReturnsNote(Object amount) {
    return 'आउटपुट GST इस अवधि में रिफंड की गई वापसियों पर उलटी गई $amount राशि घटाकर दिखाया गया है।';
  }

  @override
  String get reportsColHead => 'शीर्ष';

  @override
  String get reportsColOutput => 'आउटपुट';

  @override
  String get reportsColItc => 'ITC';

  @override
  String get reportsColNet => 'शुद्ध';

  @override
  String get reportsColTotal => 'कुल';

  @override
  String get reportsColRate => 'दर';

  @override
  String get reportsColTaxable => 'कर योग्य';

  @override
  String get reportsHeadInterState => 'अंतर-राज्यीय';

  @override
  String get reportsHeadCentral => 'केंद्रीय';

  @override
  String get reportsHeadState => 'राज्य';

  @override
  String get reportsNetProfit => 'शुद्ध लाभ';

  @override
  String reportsGrossMargin(Object pct) {
    return 'सकल मार्जिन $pct%';
  }

  @override
  String get reportsRevenue => 'राजस्व';

  @override
  String get reportsCostOfGoodsSold => 'बेचे गए माल की लागत';

  @override
  String get reportsGrossProfit => 'सकल लाभ';

  @override
  String get reportsAdjustmentWriteoffs => 'समायोजन बट्टे-खाते';

  @override
  String get reportsNetProfitRow => 'शुद्ध लाभ';

  @override
  String get reportsHowThisIsCalculated => 'यह कैसे गणना की जाती है';

  @override
  String get reportsConfirmedSales => 'पुष्ट बिक्री';

  @override
  String get reportsConfirmedSalesBasis =>
      'पुष्ट बिक्री चालानों का कर योग्य मूल्य (GST रहित), क्रेडिट नोट घटाकर';

  @override
  String get reportsLessSalesReturns => 'घटाएँ: बिक्री वापसियाँ';

  @override
  String get reportsLessSalesReturnsBasis =>
      'रिफंड की गई वापसियों का GST रहित मूल्य, लौटाई गई मात्रा के अनुपात में';

  @override
  String get reportsRevenueA => 'राजस्व (A)';

  @override
  String get reportsGoodsSoldAtCost => 'बेचा गया माल, लागत पर';

  @override
  String get reportsGoodsSoldAtCostBasis =>
      'प्रत्येक बिक्री पुष्ट होने पर उपयोग की गई स्टॉक लागत परतें';

  @override
  String get reportsLessReturnedGoodsRestocked =>
      'घटाएँ: लौटाया गया माल पुनः स्टॉक में';

  @override
  String get reportsLessReturnedGoodsRestockedBasis =>
      'लौटाई गई वस्तुएँ उनकी उपयोग की गई लागत पर वापस इन्वेंटरी में डाली गईं';

  @override
  String get reportsCostOfGoodsSoldB => 'बेचे गए माल की लागत (B)';

  @override
  String get reportsGrossProfitAB => 'सकल लाभ (A − B)';

  @override
  String get reportsLessStockWriteoffs => 'घटाएँ: स्टॉक बट्टे-खाते';

  @override
  String get reportsLessStockWriteoffsBasis =>
      'इस अवधि में दर्ज क्षति, समाप्ति और कमी के स्टॉक समायोजन';

  @override
  String get reportsNetProfitFormula => 'शुद्ध लाभ (A − B − बट्टे-खाते)';

  @override
  String reportsPnlNote(Object pct) {
    return 'सकल मार्जिन $pct% = सकल लाभ ÷ राजस्व। प्रत्येक आँकड़ा इस अवधि में दर्ज पुष्ट चालानों, रिफंड की गई वापसियों और स्टॉक समायोजनों से जोड़ा गया है; अनुमान और प्रोफार्मा शामिल नहीं हैं।';
  }

  @override
  String get reportsProductsSold => 'बेचे गए उत्पाद';

  @override
  String reportsCountOfTotal(Object count, Object total) {
    return '$total में से $count';
  }

  @override
  String get reportsSearchByProductOrSku => 'उत्पाद या SKU से खोजें…';

  @override
  String reportsNoSoldProductsMatch(Object query) {
    return '“$query” से मेल खाता कोई बिका उत्पाद नहीं।';
  }

  @override
  String get reportsNoProductsSoldInRange =>
      'इस अवधि में कोई उत्पाद नहीं बिका।';

  @override
  String reportsSaleCountOne(Object count) {
    return '$count बिक्री';
  }

  @override
  String reportsSaleCountOther(Object count) {
    return '$count बिक्रियाँ';
  }

  @override
  String get reportsLoading => 'लोड हो रहा है…';

  @override
  String reportsLoadMore(Object count) {
    return 'और लोड करें ($count शेष)';
  }

  @override
  String reportsAllProductsShownOne(Object count) {
    return 'सभी $count उत्पाद दिखाया गया।';
  }

  @override
  String reportsAllProductsShownOther(Object count) {
    return 'सभी $count उत्पाद दिखाए गए।';
  }

  @override
  String get reportsProductFallback => 'उत्पाद';

  @override
  String get reportsNoSalesForProduct =>
      'इस उत्पाद के लिए कोई बिक्री नहीं मिली।';

  @override
  String get reportsCalcTitle => 'मूल्य निर्धारण और लाभ कैलकुलेटर';

  @override
  String get reportsCalcIntro =>
      'नीचे उत्पाद जोड़ें, फिर प्रति पंक्ति मात्रा, GST और छूट सेट करें — कुल, GST, लाभ और मार्जिन तुरंत अपडेट होते हैं।';

  @override
  String get reportsCalcNoProductsYet =>
      'अभी कोई उत्पाद नहीं — नीचे दी सूची से कुछ जोड़ें।';

  @override
  String get reportsCalcSupply => 'आपूर्ति';

  @override
  String get reportsCalcWithinState => 'राज्य के भीतर';

  @override
  String get reportsCalcInterState => 'अंतर-राज्यीय';

  @override
  String get reportsCalcDiscountIn => 'छूट किसमें';

  @override
  String get reportsCalcOverallDiscount => 'समग्र छूट';

  @override
  String get reportsCalcGrandTotalInclGst => 'कुल योग · GST सहित';

  @override
  String reportsCalcProductCountOne(Object count) {
    return '$count उत्पाद';
  }

  @override
  String reportsCalcProductCountOther(Object count) {
    return '$count उत्पाद';
  }

  @override
  String reportsCalcQtySummary(Object qty) {
    return ' · $qty मात्रा';
  }

  @override
  String reportsCalcDiscOff(Object amount) {
    return ' · $amount की छूट';
  }

  @override
  String get reportsCalcProfit => 'लाभ';

  @override
  String get reportsCalcMargin => 'मार्जिन';

  @override
  String get reportsCalcBlockTotal => 'कुल';

  @override
  String get reportsCalcGrossSubtotal => 'सकल उप-योग';

  @override
  String get reportsCalcHintInclGst => 'GST सहित';

  @override
  String get reportsCalcLineDiscounts => 'पंक्ति छूट';

  @override
  String get reportsCalcGrandTotalRow => 'कुल योग (GST सहित)';

  @override
  String get reportsCalcBlockGstInterState => 'GST · अंतर-राज्यीय';

  @override
  String get reportsCalcBlockGstWithinState => 'GST · राज्य के भीतर';

  @override
  String get reportsCalcSubtotal => 'उप-योग';

  @override
  String get reportsCalcHintTaxableExGst => 'कर योग्य, GST रहित';

  @override
  String get reportsCalcGstTotal => 'कुल GST';

  @override
  String get reportsCalcBlockProfit => 'लाभ';

  @override
  String get reportsCalcCostOfGoods => 'माल की लागत';

  @override
  String get reportsCalcRevenue => 'राजस्व';

  @override
  String get reportsCalcMarkup => 'मार्कअप';

  @override
  String get reportsCalcHintReturnOnCost => 'लागत पर प्रतिफल';

  @override
  String get reportsCalcProfitMargin => 'लाभ मार्जिन';

  @override
  String get reportsCalcQuotation => 'कोटेशन';

  @override
  String get reportsCalcStatusRequested => 'अनुरोधित';

  @override
  String get reportsCalcStatusSent => 'भेजा गया';

  @override
  String get reportsCalcStatusAccepted => 'स्वीकृत';

  @override
  String get reportsCalcStatusDeclined => 'अस्वीकृत';

  @override
  String get reportsCalcStatusCancelled => 'रद्द';

  @override
  String get reportsCalcStatusExpired => 'समाप्त';

  @override
  String get reportsCalcLoadQuotation => 'कोटेशन लोड करें';

  @override
  String get reportsCalcChooseCustomer => 'ग्राहक चुनें';

  @override
  String get reportsCalcDownload => 'डाउनलोड';

  @override
  String get reportsCalcSending => 'भेजा जा रहा है…';

  @override
  String get reportsCalcPriceAndSend => 'मूल्य लगाएँ और भेजें';

  @override
  String get reportsCalcSendQuotation => 'कोटेशन भेजें';

  @override
  String get reportsCalcNew => 'नया';

  @override
  String get reportsCalcNoteLabel => 'नोट (वैकल्पिक)';

  @override
  String get reportsCalcNoteHint => 'कोटेशन पर दिखाया जाएगा…';

  @override
  String get reportsCalcQuoteNote =>
      'डाउनलोड और भेजें दोनों कोटेशन को सहेजते हैं (PDF सहेजे गए कोटेशन से बनता है)। ग्राहक द्वारा अनुरोधित कोटेशन को मूल्य लगाकर वापस भेजा जाता है; अन्यथा एक नया कोटेशन चुने गए ग्राहक को जाता है। कुल राशियाँ GST सहित हैं — कोटेशन ऊपर दिए कुल योग से मेल खाता है।';

  @override
  String get reportsCalcYourProducts => 'आपके उत्पाद';

  @override
  String reportsCalcAddedCount(Object count) {
    return '$count जोड़े गए';
  }

  @override
  String get reportsCalcSearchByNameOrSku => 'नाम या SKU से खोजें…';

  @override
  String get reportsCalcLoadingProducts => 'आपके उत्पाद लोड हो रहे हैं…';

  @override
  String get reportsCalcNoProductsFound => 'कोई उत्पाद नहीं मिला।';

  @override
  String get reportsCalcEach => 'प्रति';

  @override
  String reportsCalcRemoveProduct(Object name) {
    return '$name हटाएँ';
  }

  @override
  String get reportsCalcQty => 'मात्रा';

  @override
  String get reportsCalcDisc => 'छूट';

  @override
  String get reportsCalcSearchByNumberOrCustomer => 'नंबर या ग्राहक से खोजें…';

  @override
  String get reportsCalcNoQuotationsYet => 'अभी कोई कोटेशन नहीं।';

  @override
  String get reportsCalcAddOneProduct =>
      'कम से कम एक उत्पाद मूल्य और मात्रा के साथ जोड़ें।';

  @override
  String get reportsCalcChooseCustomerFirst => 'पहले एक ग्राहक चुनें।';

  @override
  String reportsCalcQuoteSent(Object number, Object name) {
    return 'कोटेशन $number $name को भेजा गया।';
  }

  @override
  String get navHome => 'होम';

  @override
  String get menuDescMyShop => 'स्टोरफ़्रंट, समय और नीतियाँ';

  @override
  String get menuDescTeam => 'स्टाफ़ और उनकी अनुमतियाँ';

  @override
  String get menuDescCategories => 'उत्पाद श्रेणियाँ और समूहन';

  @override
  String get menuDescHsn =>
      'उत्पाद नाम से अपने आप भरा जाता है, दर सहेजी नहीं जाती';

  @override
  String get menuDescVendors => 'जिन आपूर्तिकर्ताओं से आप खरीदते हैं';

  @override
  String get menuDescParties => 'जिन ग्राहकों को आप बेचते हैं';

  @override
  String get menuDescBanners => 'स्टोरफ़्रंट होम बैनर';

  @override
  String get menuDescCoupons => 'छूट कोड और ऑफ़र';

  @override
  String get menuDescPos => 'तेज़ इन-स्टोर बिलिंग';

  @override
  String get menuDescCashier => 'त्वरित चेकआउट रजिस्टर';

  @override
  String get menuDescScan => 'आइटम को सेशन में स्कैन करें';

  @override
  String get menuDescQuotations => 'ग्राहकों के लिए मूल्य कोटेशन';

  @override
  String get menuDescChallans => 'बिना कीमत वाले डिलीवरी नोट';

  @override
  String get menuDescStockAdj => 'क्षति, समाप्ति और सुधार';

  @override
  String get menuDescReturns => 'ग्राहक रिटर्न और रिफंड';

  @override
  String get menuDescReports => 'बिक्री, खरीद, GST और लाभ-हानि';

  @override
  String get menuDescAnalytics => 'ट्रैफ़िक और प्रदर्शन';

  @override
  String get menuDescBannerManager => 'मार्केटप्लेस होम बैनर';

  @override
  String get menuDescCategoryTaxonomy => 'वैश्विक श्रेणी वृक्ष';

  @override
  String get menuDescCollections => 'क्यूरेटेड उत्पाद संग्रह';

  @override
  String get menuDescBankOffers => 'कार्ड और बैंक छूट';

  @override
  String get menuDescShopVerification => 'दुकानों की समीक्षा और सत्यापन';

  @override
  String get menuDescProfile => 'आपका खाता और दुकान';

  @override
  String get menuDescSettings => 'मुद्रा, थीम और भाषा';

  @override
  String get menuDescInvoiceSettings => 'GSTIN, PAN, GST तारीख और UPI ID';

  @override
  String get profileDevicesSessions => 'डिवाइस और सत्र';

  @override
  String get profileDevicesSessionsSubtitle =>
      'देखें कि आप कहाँ साइन इन हैं और डिवाइस साइन आउट करें';

  @override
  String get sessionsThisDevice => 'यह डिवाइस';

  @override
  String get sessionsSignOut => 'साइन आउट';

  @override
  String get sessionsSignOutOthers => 'अन्य सभी डिवाइस साइन आउट करें';

  @override
  String get sessionsSignedOut => 'साइन आउट किया गया।';

  @override
  String sessionsLastActive(String time) {
    return 'अंतिम सक्रिय $time';
  }

  @override
  String sessionsSignedInOn(String time) {
    return '$time को साइन इन किया';
  }

  @override
  String get sessionsEmpty => 'कोई सक्रिय सत्र नहीं।';

  @override
  String get timeJustNow => 'अभी';

  @override
  String timeMinutesAgo(int n) {
    return '$n मिनट पहले';
  }

  @override
  String timeHoursAgo(int n) {
    return '$n घंटे पहले';
  }

  @override
  String timeDaysAgo(int n) {
    return '$n दिन पहले';
  }

  @override
  String get productsHsnSuggestedFor => 'इस उत्पाद के लिए सुझाव';

  @override
  String get productsHsnNotThis => 'यह नहीं?';

  @override
  String get productsHsnSaved => 'आपके कोड में सहेजा गया';

  @override
  String productsHsnSaveShortcut(String name) {
    return '“$name” के लिए मेरा कोड सहेजें';
  }

  @override
  String get productsGstAwaitingCode => 'HSN कोड चुनें';

  @override
  String get productsGstFromRule => 'कीमत के आधार पर';

  @override
  String get productsGstFromOverride => 'आपका ओवरराइड';

  @override
  String productsGstRuleApplied(String price, String threshold) {
    return 'कीमत ₹$price, सीमा ₹$threshold।';
  }

  @override
  String productsGstManualDiverges(String code, String rate) {
    return 'यह HSN $code से अलग है, जो $rate% है। सुनिश्चित करें कि इसका आधार है।';
  }

  @override
  String get productsGstSetManually => 'दर स्वयं भरें';

  @override
  String get productsGstUseHsnRate => 'HSN कोड की दर लें';

  @override
  String get hsnCodesTitle => 'मेरे HSN कोड';

  @override
  String get hsnCodesSubtitle =>
      'आपके सहेजे हुए कोड और कोई भी दर जो आपने हमारी दर से अलग रखी है। सहेजे कोड सिर्फ़ वर्गीकरण तय करते हैं — GST दर हमेशा ताज़ा पढ़ी जाती है।';

  @override
  String get hsnRetry => 'फिर कोशिश करें';

  @override
  String get hsnSavedHeading => 'सहेजे कोड';

  @override
  String get hsnSavedBlurb =>
      'जब आप किसी उत्पाद पर इनमें से कोई शब्द लिखते हैं, हम यही कोड भर देते हैं। कोई दर सहेजी नहीं जाती, इसलिए ये पुराने नहीं पड़ते।';

  @override
  String get hsnSavedEmptyTitle => 'अभी कुछ सहेजा नहीं है';

  @override
  String get hsnSavedEmptyHint =>
      'किसी उत्पाद पर HSN कोड चुनें और “मेरा कोड बनाएँ” दबाएँ।';

  @override
  String get hsnSavedBrokenBadge => 'ध्यान चाहिए';

  @override
  String hsnSavedBrokenBanner(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString सहेजे कोड',
      one: '1 सहेजा कोड',
    );
    return '$_temp0 अब टैरिफ़ में नहीं है। इसका विकल्प आप चुनें — हम अंदाज़ा नहीं लगाएँगे।';
  }

  @override
  String hsnSavedUsedCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString बार इस्तेमाल',
      one: '1 बार इस्तेमाल',
    );
    return '$_temp0';
  }

  @override
  String get hsnActionChangeCode => 'कोड बदलें';

  @override
  String get hsnActionRemoveSaved => 'सहेजा कोड हटाएँ';

  @override
  String get hsnActionRemoveOverride => 'ओवरराइड हटाएँ';

  @override
  String hsnRepointTitle(String label) {
    return '“$label” का कोड बदलें';
  }

  @override
  String get hsnRepointBlurb =>
      'आपका शब्द वही रहेगा, बस वह दूसरे HSN कोड पर जाएगा। पहले से सहेजे उत्पाद अपनी बिल की गई दर पर बने रहते हैं।';

  @override
  String get hsnOverridesHeading => 'दर ओवरराइड';

  @override
  String get hsnOverridesBlurb =>
      'एक कोड पर आपकी बिलिंग दर, जो हमारी दर से अलग है, और आपके पूरे कैटलॉग पर लागू होती है। आपका दिया कारण ही ऑडिटर पूछेगा।';

  @override
  String get hsnOverridesEmpty =>
      'कोई ओवरराइड नहीं। हर कोड साझा टैरिफ़ की दर पर बिल होता है।';

  @override
  String get hsnOverridesAdd => 'जोड़ें';

  @override
  String hsnOverridesEffectiveFrom(String date) {
    return '$date से लागू';
  }

  @override
  String get hsnOverridesDialogTitle => 'GST दर ओवरराइड करें';

  @override
  String get hsnOverridesDialogBlurb =>
      'पहले कोड चुनें, ताकि आप देख सकें कि आप किस दर से हट रहे हैं।';

  @override
  String hsnOverridesPlatformRate(String code, String rate) {
    return '$code के लिए हमारी दर $rate% है।';
  }

  @override
  String get hsnOverridesRateLabel => 'आपकी GST दर (%)';

  @override
  String hsnOverridesDiverges(String code, String yours, String platform) {
    return 'आप $code पर $yours% बिल कर रहे हैं जबकि टैरिफ़ $platform% कहता है। यह इस कोड के हर उत्पाद और आगे के हर बिल पर लागू होगा।';
  }

  @override
  String get hsnOverridesReasonLabel => 'कारण';

  @override
  String get hsnOverridesReasonHelper =>
      'ज़रूरी है। बिना आधार वाला ओवरराइड टाइपिंग की गलती से अलग नहीं दिखता।';

  @override
  String get hsnOverridesConfirm => 'ओवरराइड सहेजें';
}
