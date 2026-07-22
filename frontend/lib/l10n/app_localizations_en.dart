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
  String get offlineBannerMessage => 'No network — showing saved data';

  @override
  String offlineSyncingMessage(int count) {
    return 'Syncing $count change(s)…';
  }

  @override
  String get noShopTitle => 'No shop linked yet';

  @override
  String get noShopBody =>
      'Ask a shop owner to invite you to their team, then sign in again to accept.';

  @override
  String get productsTitle => 'Products';

  @override
  String get productsSwitchToCardView => 'Switch to card view';

  @override
  String get productsSwitchToCompactView => 'Switch to compact view';

  @override
  String get productsGridView => 'Grid view';

  @override
  String get productsListView => 'List view';

  @override
  String get productsAddProduct => 'Add Product';

  @override
  String get productsHidden => 'Products hidden';

  @override
  String get productsSearchHint => 'Search products...';

  @override
  String get productsFilterAll => 'All';

  @override
  String get productsLowStock => 'Low Stock';

  @override
  String get productsOutOfStock => 'Out of Stock';

  @override
  String get productsCategoryPickerLabel => 'Category';

  @override
  String get productsAllStockedUpTitle => 'All stocked up';

  @override
  String get productsAllStockedUpHint =>
      'Nothing is running low right now. Nice work.';

  @override
  String get productsNoMatches => 'No matches';

  @override
  String get productsNoProducts => 'No products found';

  @override
  String get productsNoMatchesHint =>
      'Try clearing filters or searching for something else.';

  @override
  String get productsNoProductsHint => 'Tap + to add your first product';

  @override
  String get productsStockInAction => 'Stock in';

  @override
  String get productsStockOutAction => 'Stock out';

  @override
  String get productsNotFoundTitle => 'Product not found';

  @override
  String get productsNotFoundHint => 'Add it now with the scanned code';

  @override
  String get productsScanAgain => 'Scan again';

  @override
  String get productsScanQr => 'Scan QR / Barcode';

  @override
  String get productsScanHint => 'Point camera at QR or barcode';

  @override
  String get productsLoading => 'Loading...';

  @override
  String get productsSpecifications => 'Specifications';

  @override
  String get productsGenerateQr => 'Generate QR Code';

  @override
  String get productsClose => 'Close';

  @override
  String get productsListedOnMarketplace => 'Listed on the marketplace.';

  @override
  String get productsHiddenFromMarketplace => 'Hidden from the marketplace.';

  @override
  String get productsCouldntUpdateVisibility => 'Couldn\'t update visibility';

  @override
  String get productsDelete => 'Delete';

  @override
  String get productsDeleteConfirm => 'Delete this product?';

  @override
  String get productsDeleted => 'Product deleted';

  @override
  String get productsError => 'Something went wrong';

  @override
  String get productsDetailsTitle => 'Product Details';

  @override
  String get productsShare => 'Share';

  @override
  String get productsEdit => 'Edit';

  @override
  String get productsStockLedger => 'Stock ledger';

  @override
  String get productsStockLedgerHint => 'Every movement with source documents';

  @override
  String get productsPricingSection => 'PRICING';

  @override
  String get productsMrp => 'MRP';

  @override
  String get productsSellingPrice => 'Selling Price';

  @override
  String get productsPurchasePrice => 'Purchase Price';

  @override
  String get productsTaxPercent => 'Tax %';

  @override
  String get productsNone => 'None';

  @override
  String get productsProfitMargin => 'Profit Margin';

  @override
  String get productsDetailsSection => 'DETAILS';

  @override
  String get productsHsnCode => 'HSN Code';

  @override
  String get productsUnit => 'Unit';

  @override
  String get productsCategory => 'Category';

  @override
  String get productsCreated => 'Created';

  @override
  String get productsLastUpdated => 'Last updated';

  @override
  String get productsStatus => 'Status';

  @override
  String get productsActive => 'Active';

  @override
  String get productsInactive => 'Inactive';

  @override
  String get productsTagBestseller => 'Bestseller';

  @override
  String get productsTagEditorsPick => 'Editor\'s pick';

  @override
  String get productsTagNewArrival => 'New arrival';

  @override
  String get productsTagTrending => 'Trending';

  @override
  String get productsReviewSingular => 'review';

  @override
  String get productsReviewPlural => 'reviews';

  @override
  String get productsNoReviewsYet => 'No reviews yet';

  @override
  String get productsListedTitle => 'Listed on marketplace';

  @override
  String get productsNotListedTitle => 'Not listed';

  @override
  String get productsListedHint => 'Customers can find and buy this product.';

  @override
  String get productsNotListedHint => 'Visible to you only. Flip to publish.';

  @override
  String get productsPerformance => 'PERFORMANCE';

  @override
  String get productsLifetimeSold => 'Lifetime sold';

  @override
  String get productsSold30d => 'Sold (30d)';

  @override
  String get productsReviewsLabel => 'Reviews';

  @override
  String get productsLastActivity => 'LAST ACTIVITY';

  @override
  String get productsStockedIn => 'Stocked in';

  @override
  String get productsSold => 'Sold';

  @override
  String get productsVariantsSection => 'VARIANTS';

  @override
  String get productsDefaultVariant => 'Default';

  @override
  String get productsDefaultBadge => 'DEFAULT';

  @override
  String get productsInactiveBadge => 'INACTIVE';

  @override
  String get productsHighlightsSection => 'HIGHLIGHTS';

  @override
  String get productsProductSpecs => 'PRODUCT SPECS';

  @override
  String get productsCouponCopied => 'Coupon code copied';

  @override
  String get productsOffersSection => 'OFFERS';

  @override
  String get productsBlockHero => 'Hero';

  @override
  String get productsBlockFeature => 'Feature';

  @override
  String get productsBlockComparison => 'Comparison';

  @override
  String get productsBlockGallery => 'Gallery';

  @override
  String get productsBlockText => 'Text';

  @override
  String get productsColumnsUnit => 'columns';

  @override
  String get productsRowsUnit => 'rows';

  @override
  String get productsImagesUnit => 'images';

  @override
  String get productsRichContentSection => 'RICH CONTENT';

  @override
  String get productsTagsSection => 'TAGS';

  @override
  String get productsLowStockAlertAt => 'Low stock alert at';

  @override
  String get productsInStock => 'In Stock';

  @override
  String get productsSupplierPriceHistory => 'Supplier-wise Price History';

  @override
  String get productsNoSupplierHistory => 'No supplier stock-in history yet';

  @override
  String get productsUnknownSupplier => 'Unknown Supplier';

  @override
  String get productsVendor => 'Vendor';

  @override
  String get productsLatestPrice => 'Latest Price';

  @override
  String get productsAveragePrice => 'Average Price';

  @override
  String get productsTotalQuantityBought => 'Total Bought';

  @override
  String get productsPurchasesUnit => 'purchases';

  @override
  String get productsLastStockIn => 'Last Stock In';

  @override
  String get productsPolicy => 'Policy';

  @override
  String get productsRecentBuys => 'Recent Buys';

  @override
  String get productsQtyLabel => 'Qty';

  @override
  String get productsWeightedAverage => 'Weighted Avg';

  @override
  String get productsUseLatestPrice => 'Use Latest';

  @override
  String get productsKeepCurrentPrice => 'Keep Current';

  @override
  String get productsStockIn => 'Stock In';

  @override
  String get productsStockOut => 'Stock Out';

  @override
  String get productsCopiedSuffix => 'copied';

  @override
  String get productsSku => 'SKU';

  @override
  String get productsBarcode => 'Barcode';

  @override
  String get productsPendingDrafts => 'Pending drafts';

  @override
  String get productsPendingDraftsHint =>
      'Stock will move once these are confirmed.';

  @override
  String get productsCustomer => 'Customer';

  @override
  String get productsSale => 'Sale';

  @override
  String get productsPurchase => 'Purchase';

  @override
  String get productsPriceGstBreakdown => 'PRICE & GST BREAKDOWN';

  @override
  String get productsTaxableValue => 'Taxable value';

  @override
  String get productsPriceBeforeGst => 'price before GST';

  @override
  String get productsTotalGst => 'Total GST';

  @override
  String get productsSellingPriceInclGst => 'Selling price (incl. GST)';

  @override
  String get productsGstExplainer =>
      'Prices include GST. CGST + SGST shown for a sale within your state; a sale to another state is charged the same total as IGST.';

  @override
  String get productsReviewsSection => 'REVIEWS';

  @override
  String get productsNoReviewsBody =>
      'No reviews yet. Verified buyers can rate this product after a confirmed purchase.';

  @override
  String get productsRatingSingular => 'rating';

  @override
  String get productsRatingPlural => 'ratings';

  @override
  String get productsVerified => 'verified';

  @override
  String get productsSeeAllReviews => 'See all reviews';

  @override
  String productsDuplicateWarning(Object label) {
    return 'A product with that $label already exists — saving will not merge';
  }

  @override
  String get productsBarcodeLower => 'barcode';

  @override
  String get productsDroppedBlocksPrefix => 'Dropped';

  @override
  String get productsMalformedBlockSingular => 'malformed content block';

  @override
  String get productsMalformedBlockPlural => 'malformed content blocks';

  @override
  String get productsFieldRequired => 'This field is required';

  @override
  String get productsInvalidNumber => 'Enter a valid number';

  @override
  String get productsPriceMustBePositive => 'Price must be greater than 0';

  @override
  String get productsOcrApplied => 'Applied scan results';

  @override
  String get productsOcrNoDetails => 'No product details found';

  @override
  String get productsOcrFailed => 'Could not read product details';

  @override
  String get productsImageTooLarge =>
      'Image is larger than 5 MB. Pick a smaller image or crop tighter.';

  @override
  String productsMaxImagesReached(Object count) {
    return 'You can attach at most $count images per product. Remove some to add more.';
  }

  @override
  String productsSelectedButOnlyFit(Object selected, Object remaining) {
    return 'Selected $selected, but only $remaining more fit. Skipping the extras.';
  }

  @override
  String productsFileTooLarge(Object name) {
    return '$name: larger than 5 MB';
  }

  @override
  String get productsUploadedPrefix => 'Uploaded';

  @override
  String get productsImageSingular => 'image';

  @override
  String get productsImagePlural => 'images';

  @override
  String get productsSkippedPrefix => 'Skipped';

  @override
  String get productsInvalidUrl => 'Enter a valid URL';

  @override
  String get productsDiscardTitle => 'Discard changes?';

  @override
  String get productsDiscardMessage => 'Your edits will be lost.';

  @override
  String get productsKeepEditing => 'Keep editing';

  @override
  String get productsDiscard => 'Discard';

  @override
  String get productsEditProduct => 'Edit Product';

  @override
  String get productsReviews => 'Reviews';

  @override
  String get productsScanLabel => 'Scan label';

  @override
  String get productsSave => 'Save';

  @override
  String get productsSectionBasics => 'THE BASICS';

  @override
  String get productsProductName => 'Product Name';

  @override
  String get productsNameHint => 'e.g. Boult Astra TWS Earbuds';

  @override
  String get productsDescription => 'Description';

  @override
  String get productsDescriptionHint => 'A line or two about what it is';

  @override
  String get productsBrand => 'Brand';

  @override
  String get productsBrandHint => 'e.g. Boult — optional';

  @override
  String get productsSectionPrice => 'PRICE';

  @override
  String get productsSellingPriceLabel => 'Selling price';

  @override
  String get productsSellingPriceHelper => 'What the customer pays';

  @override
  String get productsMrpHelper => 'Strike-through price';

  @override
  String get productsCostPrice => 'Cost price';

  @override
  String get productsCostPriceHelper => 'What you pay';

  @override
  String get productsGst => 'GST';

  @override
  String get productsOptional => 'Optional';

  @override
  String get productsSectionIdentityStock => 'IDENTITY & STOCK';

  @override
  String get productsSkuHelper => 'Your own product code — must be unique';

  @override
  String get productsOpeningStock => 'Opening stock';

  @override
  String get productsSectionMoreDetails => 'MORE DETAILS';

  @override
  String get productsMoreDetailsIntro =>
      'All optional. Add as much as you like to make the product page richer — you can come back any time.';

  @override
  String get productsProductImages => 'Product Images';

  @override
  String get productsPickFromGallery => 'Gallery';

  @override
  String get productsTakePhoto => 'Camera';

  @override
  String productsGalleryEmptyHint(Object count) {
    return 'Tap \"Pick from gallery\" to select multiple images at once. Up to $count per product.';
  }

  @override
  String productsGalleryCountHint(Object count, Object max) {
    return '$count/$max images added.';
  }

  @override
  String get productsAddByImageLink => 'Add by image link';

  @override
  String get productsAddImageUrl => 'Or paste image URL';

  @override
  String get productsImageUrlHint => 'https://...';

  @override
  String get productsAddImage => 'Add Image';

  @override
  String get productsHighlightsTitle => 'Highlights';

  @override
  String get productsHighlightsSubtitle => 'Short selling points shown up top';

  @override
  String get productsHighlightsIntro =>
      'Short bullet points shown above the fold on the product page. Up to 8.';

  @override
  String get productsSpecificationsTitle => 'Specifications';

  @override
  String get productsSpecificationsSubtitle =>
      'Detailed spec sheet, grouped by section';

  @override
  String get productsSpecificationsIntro =>
      'Group attributes by section (e.g. \"Display\", \"Camera\"). Each row is a label and a value.';

  @override
  String get productsOffersTitle => 'Offers';

  @override
  String get productsOffersSubtitle => 'Coupon, EMI or exchange offers';

  @override
  String get productsOffersIntro =>
      'Bank, coupon, EMI or exchange offers shown beneath the price.';

  @override
  String get productsRichDescriptionTitle => 'Rich product description';

  @override
  String get productsRichDescriptionSubtitle =>
      'Hero image, features, comparison, gallery';

  @override
  String get productsRichDescriptionShort => 'Rich description';

  @override
  String get productsRichDescriptionIntro =>
      'Build the scrollable story on the product page. Add up to 8 blocks and drag them into order.';

  @override
  String get productsVariantsTitle => 'Variants';

  @override
  String get productsVariantsSubtitle => 'Colours, sizes and other options';

  @override
  String get productsVariantsIntro =>
      'Optional. Declare axes (Colour, Size, …) and add one variant per combination. A single default variant is created automatically when you don\'t.';

  @override
  String get productsTagsTitle => 'Tags';

  @override
  String get productsTagsSubtitle => 'Keywords that help shoppers find this';

  @override
  String get productsTagsIntro => 'Up to 20. Bestseller, Eco-friendly, etc.';

  @override
  String get productsCodesInventoryTitle => 'Codes & inventory';

  @override
  String get productsCodesInventorySubtitle =>
      'Barcode, HSN code, low-stock alert';

  @override
  String get productsMoreAboutTitle => 'More about this product';

  @override
  String get productsMoreAboutSubtitle => 'Your shop\'s own custom fields';

  @override
  String get productsMoreAboutIntro =>
      'Shop-wide fields like Warranty, Model number or Material — define them once, reuse on every product.';

  @override
  String get productsDone => 'Done';

  @override
  String get productsBarcodeHelper =>
      'The number under the striped code on the package';

  @override
  String get productsHsnCodeHelper => 'Tax classification code for invoices';

  @override
  String get productsLowStockThreshold => 'Low Stock Alert';

  @override
  String get productsLowStockThresholdHelper =>
      'We\'ll flag the product once stock drops to this';

  @override
  String get productsAddTag => 'Add tag';

  @override
  String get productsRemove => 'Remove';

  @override
  String get productsAddHighlightHint => 'Add a highlight…';

  @override
  String get productsAddSpecGroup => 'Add spec group';

  @override
  String get productsGroupTitleLabel => 'Group title (e.g. Display)';

  @override
  String get productsRemoveGroup => 'Remove group';

  @override
  String get productsTabLabel => 'Tab (optional — e.g. Features & Specs)';

  @override
  String get productsSpecLabelLabel => 'Label';

  @override
  String get productsSpecLabelHint => 'e.g. In the box';

  @override
  String get productsRemoveRow => 'Remove row';

  @override
  String get productsSpecValueLabel => 'Value';

  @override
  String get productsSpecValueHint =>
      'e.g. Earbuds, charging case, cable, manual';

  @override
  String get productsAddRow => 'Add row';

  @override
  String get productsBankOffersNote =>
      'Bank offers are platform-wide and managed centrally. Customers will still see HDFC / ICICI / SBI etc. on this product\'s page if a platform offer is active.';

  @override
  String get productsAddOffer => 'Add offer';

  @override
  String get productsOfferKind => 'Kind';

  @override
  String get productsOfferHeadline => 'Headline';

  @override
  String get productsOfferHeadlineHint => 'e.g. ₹2000 off with code WELCOME';

  @override
  String get productsOfferDetail => 'Detail (optional)';

  @override
  String get productsOfferCode => 'Code (optional)';

  @override
  String get productsBlockHeroLabel => 'Hero banner';

  @override
  String get productsBlockHeroHint => 'A big image with a headline';

  @override
  String get productsBlockFeatureLabel => 'Feature';

  @override
  String get productsBlockFeatureHint => 'Image beside a title + description';

  @override
  String get productsBlockComparisonLabel => 'Comparison table';

  @override
  String get productsBlockComparisonHint => 'Compare this vs other options';

  @override
  String get productsBlockGalleryLabel => 'Gallery';

  @override
  String get productsBlockGalleryHint => 'A row of images with captions';

  @override
  String get productsBlockTextLabel => 'Text';

  @override
  String get productsBlockTextHint => 'A paragraph of rich text';

  @override
  String get productsBlocksEmptyHint =>
      'Build a rich product story shoppers scroll through — add a block to start.';

  @override
  String productsBlockPosition(Object index, Object total) {
    return '$index of $total';
  }

  @override
  String get productsMoveUp => 'Move up';

  @override
  String get productsMoveDown => 'Move down';

  @override
  String get productsBannerImage => 'Banner image';

  @override
  String get productsHeadline => 'Headline';

  @override
  String get productsSubtext => 'Subtext (optional)';

  @override
  String get productsFeatureImage => 'Feature image';

  @override
  String get productsImageOnThe => 'Image on the ';

  @override
  String get productsSideLeft => 'Left';

  @override
  String get productsSideRight => 'Right';

  @override
  String get productsFieldTitle => 'Title';

  @override
  String productsImageN(Object index) {
    return 'Image $index';
  }

  @override
  String get productsCaption => 'Caption (optional)';

  @override
  String get productsAddImageAction => 'Add image';

  @override
  String get productsComparisonIntro =>
      'Name what you\'re comparing, then add a row for each feature and fill in a cell under every column.';

  @override
  String get productsColumns => 'Columns';

  @override
  String productsColumnNName(Object index) {
    return 'Column $index name';
  }

  @override
  String get productsThisProductHint => 'This product';

  @override
  String get productsOtherCompetitorHint => 'Other / competitor';

  @override
  String get productsRemoveColumn => 'Remove column';

  @override
  String get productsAddColumn => 'Add column';

  @override
  String get productsRows => 'Rows';

  @override
  String get productsFeature => 'Feature';

  @override
  String get productsFeatureHint => 'e.g. Battery life';

  @override
  String productsColumnN(Object index) {
    return 'Column $index';
  }

  @override
  String get productsReplace => 'Replace';

  @override
  String get productsUpload => 'Upload';

  @override
  String get productsHideLinkField => 'Hide link field';

  @override
  String get productsOrPasteLink => 'or paste a link';

  @override
  String get productsImageLinkUrl => 'Image link (URL)';

  @override
  String get productsAxes => 'Axes';

  @override
  String get productsAddAxis => 'Add axis (e.g. Colour, Size)';

  @override
  String get productsVariantsLabel => 'Variants';

  @override
  String get productsAddVariant => 'Add variant';

  @override
  String get productsAxisNameLabel => 'Axis name (e.g. Colour)';

  @override
  String productsValueN(Object index) {
    return 'Value $index';
  }

  @override
  String get productsAddValue => 'Add value';

  @override
  String get productsAxisFallback => 'Axis';

  @override
  String get productsSellingShort => 'Selling';

  @override
  String get productsStockShort => 'Stock';

  @override
  String get productsVariantImagesHint =>
      'Add images for this exact variant — what colour it looks like, how it fits. Customers picking this option will see these instead of the product-level gallery.';

  @override
  String get productsAddVariantImage => 'Add variant image';

  @override
  String get productsFromGallery => 'From gallery';

  @override
  String get productsTakePhotoMenu => 'Take photo';

  @override
  String get productsAddShort => 'Add';

  @override
  String get productsAddPhotos => 'Add photos';

  @override
  String get productsOutOfStockLabel => 'Out of stock';

  @override
  String get productsReorderAt => 'reorder at';

  @override
  String get productsInStockSuffix => 'in stock';

  @override
  String get productsOutSince => 'Out since';

  @override
  String get productsLastIn => 'Last in:';

  @override
  String get productsCostPrefix => 'cost';

  @override
  String get productsAboveMrp => 'above M.R.P.';

  @override
  String get ordersTitle => 'Orders';

  @override
  String get ordersNoAccessTitle => 'Orders hidden';

  @override
  String get ordersTabPending => 'Pending';

  @override
  String get ordersTabConfirmed => 'Confirmed';

  @override
  String get ordersTabRejected => 'Rejected';

  @override
  String get ordersTabAll => 'All';

  @override
  String get ordersSearchHint => 'Search customer, item or #id';

  @override
  String get ordersAnyDate => 'Any date';

  @override
  String get ordersItemUnit => 'item';

  @override
  String get ordersItemsUnit => 'items';

  @override
  String get ordersAllCaughtUp => 'All caught up';

  @override
  String get ordersAllCaughtUpHint => 'New orders will land here.';

  @override
  String get ordersNoMatching => 'No matching orders';

  @override
  String get ordersNoMatchingHint => 'Try a different search or date range.';

  @override
  String get ordersNoneYet => 'No orders here yet';

  @override
  String get ordersNoneYetHint =>
      'New orders will appear here when customers place them.';

  @override
  String get ordersError => 'Something went wrong';

  @override
  String get ordersRetry => 'Retry';

  @override
  String ordersDetailTitle(Object id) {
    return 'Order #$id';
  }

  @override
  String get ordersActionShare => 'Share order summary';

  @override
  String get ordersManageWhat => 'manage orders';

  @override
  String get ordersDecline => 'Decline';

  @override
  String get ordersConfirmAndCreateInvoice => 'Confirm & create invoice';

  @override
  String ordersInvoiceCreated(Object no) {
    return 'Invoice $no created';
  }

  @override
  String get ordersDeclinedToast => 'Order declined';

  @override
  String get ordersShippingPosted => 'Shipping update posted';

  @override
  String ordersStockPosted(Object name) {
    return '$name stock posted';
  }

  @override
  String get ordersCouldNotOpenApp => 'Could not open that app';

  @override
  String ordersWhatsappGreeting(Object name, Object id) {
    return 'Hi $name, regarding your order #$id.';
  }

  @override
  String ordersEmailSubject(Object id) {
    return 'Order #$id';
  }

  @override
  String ordersShareHeader(Object id, Object name) {
    return 'Order #$id from $name';
  }

  @override
  String get ordersJustNow => 'just now';

  @override
  String ordersMinAgo(Object n) {
    return '$n min ago';
  }

  @override
  String ordersHrAgo(Object n) {
    return '$n hr ago';
  }

  @override
  String ordersDayAgo(Object n) {
    return '$n days ago';
  }

  @override
  String get ordersSummaryItemsLabel => 'Items';

  @override
  String get ordersSummaryQtyLabel => 'Total qty';

  @override
  String get ordersSummaryTotalLabel => 'Estimated';

  @override
  String ordersShortfallTitle(Object short, Object total) {
    return '$short of $total items short on stock';
  }

  @override
  String get ordersShortfallBody =>
      'Restock now or decline — the invoice will fail to post otherwise.';

  @override
  String get ordersRestock => 'Restock';

  @override
  String get ordersLinkedParty => 'Linked party';

  @override
  String get ordersCall => 'Call';

  @override
  String get ordersWhatsapp => 'WhatsApp';

  @override
  String get ordersEmail => 'Email';

  @override
  String get ordersCustomerNote => 'Customer\'s note';

  @override
  String get ordersJourneyPlaced => 'Placed';

  @override
  String get ordersJourneyDeclined => 'Declined';

  @override
  String get ordersJourneyCancelled => 'Cancelled';

  @override
  String get ordersJourneyConfirmed => 'Confirmed';

  @override
  String get ordersJourneyInvoiced => 'Invoiced';

  @override
  String get ordersJourneyPaid => 'Paid';

  @override
  String get ordersInactiveProduct => 'Inactive product';

  @override
  String get ordersStockUnknown => 'Stock unknown';

  @override
  String ordersStockOk(Object ask, Object have, Object unit) {
    return 'Asked $ask · $have $unit in stock';
  }

  @override
  String ordersStockShort(Object ask, Object have, Object short) {
    return 'Asked $ask · in stock $have · short $short';
  }

  @override
  String get ordersTotalsSubtotal => 'Subtotal';

  @override
  String get ordersTotalsTax => 'Tax';

  @override
  String get ordersTotalsDiscount => 'Discount';

  @override
  String get ordersTotalsTotal => 'Total';

  @override
  String get ordersPartialFulfillFootnote =>
      'Final invoice may differ if you partial-fulfill.';

  @override
  String ordersOpenInvoice(Object no) {
    return 'Open invoice $no';
  }

  @override
  String get ordersConfirmShortfallTitle =>
      'Stock looks short — confirm anyway?';

  @override
  String get ordersConfirmOrderTitle => 'Confirm this order?';

  @override
  String get ordersConfirmShortfallWarning =>
      'Some items have less stock than the customer asked for. The draft invoice will fail to post when you try to confirm it.';

  @override
  String get ordersConfirmOrderBody =>
      'This creates a draft sale invoice for the items. Stock will move once you confirm the invoice.';

  @override
  String get ordersNotYet => 'Not yet';

  @override
  String get ordersConfirmOrder => 'Confirm order';

  @override
  String get ordersDeclineReasonOutOfStock => 'Out of stock';

  @override
  String get ordersDeclineReasonClosed => 'Closed today';

  @override
  String get ordersDeclineReasonPriceChanged => 'Price changed';

  @override
  String get ordersDeclineReasonOther => 'Other';

  @override
  String get ordersDeclineOrderTitle => 'Decline this order?';

  @override
  String get ordersDeclineOrderBody =>
      'The customer will be notified. You can leave a note explaining why.';

  @override
  String get ordersDeclineOrderNoteHint => 'Reason (optional)';

  @override
  String get ordersKeep => 'Keep';

  @override
  String get ordersDeclineOrder => 'Decline order';

  @override
  String get ordersShippingUpdates => 'Shipping updates';

  @override
  String get ordersUpdateShipping => 'Update shipping';

  @override
  String get ordersNoShippingUpdates => 'No shipping updates yet.';

  @override
  String get ordersMilestonePacked => 'Packed';

  @override
  String get ordersMilestoneShipped => 'Shipped';

  @override
  String get ordersMilestoneOutForDelivery => 'Out for delivery';

  @override
  String get ordersMilestoneDelivered => 'Delivered';

  @override
  String get ordersMilestoneReturned => 'Returned';

  @override
  String get ordersShippingSheetBody =>
      'The customer sees these updates on their order. Marking Delivered starts their return window.';

  @override
  String get ordersCourierHint => 'Courier (optional), e.g. Delhivery';

  @override
  String get ordersAwbHint => 'AWB / tracking number (optional)';

  @override
  String get ordersEtaHint => 'ETA (optional)';

  @override
  String get ordersClearEta => 'Clear ETA';

  @override
  String get ordersNoteHint => 'Note (optional)';

  @override
  String get ordersCancel => 'Cancel';

  @override
  String get ordersSaveUpdate => 'Save update';

  @override
  String get ordersStockDraftPendingOne => '1 stock draft pending';

  @override
  String ordersStockDraftPendingMany(Object count) {
    return '$count stock drafts pending';
  }

  @override
  String get ordersStockDraftHint =>
      'Confirm to post the stock — until then the shortfall stays.';

  @override
  String ordersDraftInvoiceNo(Object no) {
    return 'Draft invoice #$no';
  }

  @override
  String get ordersOpenDraft => 'Open draft';

  @override
  String get ordersConfirm => 'Confirm';

  @override
  String get ordersHide => 'Hide';

  @override
  String get invoicesNavTitle => 'Invoices';

  @override
  String get invoicesCreateTitle => 'Create Invoice';

  @override
  String get invoicesSearchHint => 'Search invoice no, party, vendor';

  @override
  String get invoicesFiltersTooltip => 'Filters';

  @override
  String get invoicesFilterAll => 'All';

  @override
  String get invoicesFilterSales => 'Sales';

  @override
  String get invoicesFilterPurchases => 'Purchases';

  @override
  String get invoicesErrorTitle => 'Something went wrong';

  @override
  String get invoicesRetry => 'Retry';

  @override
  String get invoicesEmptyTitle => 'No invoices found';

  @override
  String get invoicesEmptyBody => 'Create your first invoice to get started';

  @override
  String get invoicesGeneratingPdf => 'Generating PDF...';

  @override
  String get invoicesItemUnit => 'item';

  @override
  String get invoicesItemsUnit => 'items';

  @override
  String get invoicesDownloadTooltip => 'Download Invoice';

  @override
  String get invoicesDocTaxInvoice => 'Tax Invoice';

  @override
  String get invoicesDocBillOfSupply => 'Bill of Supply';

  @override
  String get invoicesDocEstimate => 'Estimate';

  @override
  String get invoicesDocProforma => 'Proforma';

  @override
  String get invoicesDocCreditNote => 'Credit Note';

  @override
  String get invoicesDocDebitNote => 'Debit Note';

  @override
  String get invoicesStatusDraft => 'Draft';

  @override
  String get invoicesStatusConfirmed => 'Confirmed';

  @override
  String get invoicesStatusCancelled => 'Cancelled';

  @override
  String get invoicesFilterAllDocuments => 'All documents';

  @override
  String get invoicesFilterAnyStatus => 'Any status';

  @override
  String get invoicesFiltersTitle => 'Filters';

  @override
  String get invoicesDocumentTypeLabel => 'Document type';

  @override
  String get invoicesStatusLabel => 'Status';

  @override
  String get invoicesClearAll => 'Clear all';

  @override
  String get invoicesApply => 'Apply';

  @override
  String get invoicesEditDraftTitle => 'Edit Draft';

  @override
  String get invoicesSaveAsDraft => 'Save as draft';

  @override
  String get invoicesUpdateDraft => 'Update draft';

  @override
  String get invoicesSaveAndConfirm => 'Save & confirm';

  @override
  String get invoicesUpdateAndConfirm => 'Update & confirm';

  @override
  String get invoicesInvoiceType => 'Invoice Type';

  @override
  String get invoicesSaleInvoice => 'Sale Invoice';

  @override
  String get invoicesPurchaseInvoice => 'Purchase Invoice';

  @override
  String get invoicesCustomerInfo => 'Customer Information';

  @override
  String get invoicesVendorInfo => 'Vendor Information';

  @override
  String get invoicesSelectVendor => 'Select vendor';

  @override
  String get invoicesSelectParty => 'Select party';

  @override
  String get invoicesCustomerName => 'Customer Name';

  @override
  String get invoicesPhone => 'Phone';

  @override
  String get invoicesGstin => 'GSTIN';

  @override
  String get invoicesPlaceOfSupply => 'Place of supply (state)';

  @override
  String get invoicesPlaceOfSupplyHelper =>
      'Buyer state — drives CGST/SGST vs IGST';

  @override
  String get invoicesSelectDash => '— Select —';

  @override
  String get invoicesInvoiceItems => 'Invoice Items';

  @override
  String get invoicesSearchToAddProduct => 'Search product to add';

  @override
  String get invoicesScanBarcode => 'Scan barcode';

  @override
  String get invoicesNoItemsYet => 'No items added yet';

  @override
  String get invoicesTotals => 'Totals';

  @override
  String get invoicesPricesIncludeGst => 'Prices include GST';

  @override
  String get invoicesPricesInclusiveHint =>
      'Tax is backed out of the entered prices';

  @override
  String get invoicesPricesExclusiveHint =>
      'GST is added on top of the entered prices';

  @override
  String get invoicesSubtotal => 'Subtotal';

  @override
  String get invoicesDiscount => 'Discount';

  @override
  String get invoicesRoundOff => 'Round-off';

  @override
  String get invoicesGrandTotal => 'Grand Total';

  @override
  String get invoicesNote => 'Note';

  @override
  String get invoicesChange => 'Change';

  @override
  String get invoicesQuantity => 'Quantity';

  @override
  String get invoicesUnitPrice => 'Unit Price';

  @override
  String get invoicesTax => 'Tax';

  @override
  String get invoicesTotal => 'Total';

  @override
  String get invoicesNeedsItems => 'Please add at least one item';

  @override
  String get invoicesUpdatedAndConfirmed => 'Invoice updated and confirmed';

  @override
  String get invoicesSavedAsDraft => 'Saved as draft';

  @override
  String invoicesConfirmedNamed(Object invoiceNo) {
    return '$invoiceNo confirmed';
  }

  @override
  String get invoicesSavedDraftConfirmFailed =>
      'Saved as draft — confirm failed, please review.';

  @override
  String get invoicesDiscardChangesTitle => 'Discard changes?';

  @override
  String get invoicesDiscardChangesBody => 'Your edits will be lost.';

  @override
  String get invoicesKeepEditing => 'Keep editing';

  @override
  String get invoicesDiscard => 'Discard';

  @override
  String get invoicesErrorTitle2Unused => 'unused';

  @override
  String get invoicesPaymentModeOnline => 'Online';

  @override
  String get invoicesPaymentModeCash => 'Cash';

  @override
  String get invoicesPaymentModeCheque => 'Cheque';

  @override
  String get invoicesPaymentModeCard => 'Card';

  @override
  String get invoicesCouldNotOpenWhatsApp => 'Could not open WhatsApp';

  @override
  String get invoicesConvertTitle => 'Convert to Invoice?';

  @override
  String invoicesConvertBody(Object invoiceNo) {
    return 'A new tax invoice will be created from $invoiceNo. The estimate stays on file unchanged.';
  }

  @override
  String get invoicesCancel => 'Cancel';

  @override
  String get invoicesConvert => 'Convert';

  @override
  String invoicesCancelledNamed(Object invoiceNo) {
    return '$invoiceNo cancelled';
  }

  @override
  String get invoicesCancelInvoice => 'Cancel Invoice';

  @override
  String invoicesCancelConfirmBody(Object invoiceNo) {
    return 'Cancel $invoiceNo? No stock will be moved and the invoice will be marked as cancelled.';
  }

  @override
  String get invoicesKeepDraft => 'Keep draft';

  @override
  String get invoicesEdit => 'Edit';

  @override
  String get invoicesShare => 'Share';

  @override
  String get invoicesDelete => 'Delete';

  @override
  String invoicesDeleteConfirmBody(Object invoiceNo) {
    return 'Delete $invoiceNo? This can\'t be undone.';
  }

  @override
  String invoicesDeletedNamed(Object invoiceNo) {
    return '$invoiceNo deleted';
  }

  @override
  String get invoicesCustomer => 'Customer';

  @override
  String get invoicesVendor => 'Vendor';

  @override
  String get invoicesAddress => 'Address';

  @override
  String get invoicesTaxAmount => 'Tax Amount';

  @override
  String get invoicesCess => 'Cess';

  @override
  String get invoicesReceived => 'Received';

  @override
  String get invoicesOutstanding => 'Outstanding';

  @override
  String get invoicesPaymentsReceivedTitle => 'Payments received';

  @override
  String get invoicesSendViaWhatsApp => 'Send via WhatsApp';

  @override
  String invoicesOpensChatWith(Object phone) {
    return 'Opens chat with $phone';
  }

  @override
  String get invoicesPickChatToSend => 'Pick a chat to send to';

  @override
  String get invoicesConvertToInvoice => 'Convert to Invoice';

  @override
  String get invoicesConvertTileSubtitle =>
      'Create a tax invoice from this estimate';

  @override
  String get invoicesMarkAsPaid => 'Mark as Paid';

  @override
  String get invoicesRecordReceiptSubtitle =>
      'Record a receipt for this invoice';

  @override
  String get invoicesRecordPaymentSubtitle => 'Record a payment for this bill';

  @override
  String get invoicesPaymentRecorded => 'Payment recorded';

  @override
  String get invoicesConfirmInvoice => 'Confirm Invoice';

  @override
  String get invoicesIssueNoteAction => 'Issue credit / debit note';

  @override
  String get invoicesIssueNoteActionSubtitle =>
      'Adjust this confirmed sale with a credit or debit note';

  @override
  String get invoicesIssueNoteTitle => 'Issue note';

  @override
  String get invoicesCreditNoteExplainer =>
      'Reduces what the customer owes. Returned goods can be put back into stock.';

  @override
  String get invoicesDebitNoteExplainer =>
      'Bills the customer an extra amount — e.g. correcting an undercharge.';

  @override
  String get invoicesNoteReturnToStock => 'Return goods to stock';

  @override
  String get invoicesNoteReason => 'Reason (optional)';

  @override
  String get invoicesNoteExtraPerUnit => 'Extra per unit';

  @override
  String get invoicesIssueCreditNote => 'Issue credit note';

  @override
  String get invoicesIssueDebitNote => 'Issue debit note';

  @override
  String get invoicesNoteSelectLines => 'Add at least one line to the note';

  @override
  String invoicesNoteSoldQty(Object qty) {
    return 'Sold $qty';
  }

  @override
  String invoicesNoteIssued(Object noteNo) {
    return '$noteNo issued';
  }

  @override
  String invoicesNoteAgainst(Object invoiceNo) {
    return 'Against $invoiceNo';
  }

  @override
  String invoicesNoteApproxTotal(Object amount) {
    return 'Approx. total $amount';
  }

  @override
  String get partiesTitle => 'Parties';

  @override
  String get partiesAddParty => 'Add Party';

  @override
  String get partiesEditParty => 'Edit Party';

  @override
  String get partiesDeleteParty => 'Delete Party';

  @override
  String partiesDeletePartyConfirm(Object name) {
    return 'Are you sure you want to delete this party? \"$name\"?';
  }

  @override
  String get partiesPartyDeleted => 'Party deleted successfully';

  @override
  String get partiesSearchParties => 'Search parties...';

  @override
  String get partiesNoParties => 'No parties found';

  @override
  String get partiesNoPartiesHint => 'Tap + to add your first party';

  @override
  String get partiesSelectParty => 'Select party';

  @override
  String get partiesNewParty => 'New party';

  @override
  String get partiesPartyName => 'Party Name';

  @override
  String get partiesContactName => 'Contact Name';

  @override
  String get partiesPhone => 'Phone';

  @override
  String get partiesEmail => 'Email';

  @override
  String get partiesGstin => 'GSTIN';

  @override
  String get partiesAddress => 'Address';

  @override
  String get partiesCity => 'City';

  @override
  String get partiesPinCode => 'PIN code';

  @override
  String get partiesState => 'State';

  @override
  String get partiesSelectPlaceholder => '— Select —';

  @override
  String get partiesSave => 'Save';

  @override
  String get partiesEdit => 'Edit';

  @override
  String get partiesDelete => 'Delete';

  @override
  String get partiesConfirm => 'Confirm';

  @override
  String get partiesFieldRequired => 'This field is required';

  @override
  String partiesPartyUpdated(Object name) {
    return '$name updated';
  }

  @override
  String partiesPartyAdded(Object name) {
    return '$name added';
  }

  @override
  String get partiesCancelInvitationTitle => 'Cancel invitation';

  @override
  String get partiesCancelInvitationBody =>
      'Cancel this pending invitation? You can send a new one later.';

  @override
  String get partiesInvitationCancelled => 'Invitation cancelled';

  @override
  String get partiesAlreadyLinked => 'Already linked';

  @override
  String get partiesInviteToShopxy => 'Invite to Shopxy';

  @override
  String get partiesAddEmailFirst => 'Add an email first';

  @override
  String partiesSentTo(Object email) {
    return 'Sent to $email';
  }

  @override
  String get partiesGstinLabel => 'GSTIN';

  @override
  String get partiesChallansUnit => 'challans';

  @override
  String get partiesInvoicesUnit => 'invoices';

  @override
  String get partiesItemsUnit => 'items';

  @override
  String get partiesBillsUnit => 'bills';

  @override
  String get partiesInviteStatusInvited => 'Invited';

  @override
  String get partiesInviteStatusLinked => 'Linked';

  @override
  String get partiesInviteStatusDeclined => 'Declined';

  @override
  String get partiesInviteStatusCancelled => 'Cancelled';

  @override
  String get partiesInviteStatusExpired => 'Expired';

  @override
  String get partiesPartyTitle => 'Party';

  @override
  String get partiesRecordPayment => 'Record payment';

  @override
  String get partiesLedger => 'Ledger';

  @override
  String get partiesRecentInvoices => 'Recent invoices';

  @override
  String get partiesRecentChallans => 'Recent challans';

  @override
  String get partiesNoActivityYet => 'No activity yet.';

  @override
  String get partiesNetBilled => 'Net billed';

  @override
  String get partiesSales => 'Sales';

  @override
  String get partiesReturns => 'Returns';

  @override
  String get partiesBalance => 'BALANCE';

  @override
  String get partiesBalanceShort => 'Bal';

  @override
  String get partiesNoOutstanding => 'No outstanding';

  @override
  String get partiesOwesYou => 'Owes you';

  @override
  String get partiesAdvanceCredit => 'Advance / credit';

  @override
  String get vendorsTitle => 'Vendors';

  @override
  String get vendorsAddVendor => 'Add Vendor';

  @override
  String get vendorsEditVendor => 'Edit Vendor';

  @override
  String get vendorsDeleteVendor => 'Delete Vendor';

  @override
  String get vendorsDeleteVendorConfirm =>
      'Are you sure you want to delete this vendor?';

  @override
  String get vendorsVendorDeleted => 'Vendor deleted successfully';

  @override
  String get vendorsSearchHint => 'Search vendors...';

  @override
  String get vendorsEmptyTitle => 'No vendors found';

  @override
  String get vendorsEmptyHint => 'Tap + to add your first vendor';

  @override
  String get vendorsVendorName => 'Vendor Name';

  @override
  String get vendorsContactName => 'Contact Name';

  @override
  String get vendorsPhone => 'Phone';

  @override
  String get vendorsEmail => 'Email';

  @override
  String get vendorsGstin => 'GSTIN';

  @override
  String get vendorsAddress => 'Address';

  @override
  String get vendorsCity => 'City';

  @override
  String get vendorsPinCode => 'PIN code';

  @override
  String get vendorsState => 'State';

  @override
  String get vendorsStateSelect => '— Select —';

  @override
  String get vendorsSave => 'Save';

  @override
  String get vendorsDelete => 'Delete';

  @override
  String get vendorsEdit => 'Edit';

  @override
  String get vendorsConfirm => 'Confirm';

  @override
  String get vendorsFieldRequired => 'This field is required';

  @override
  String get vendorsSelectVendor => 'Select vendor';

  @override
  String get vendorsNewVendor => 'New vendor';

  @override
  String get vendorsTxnsUnit => 'txns';

  @override
  String get vendorsInvoicesUnit => 'invoices';

  @override
  String get vendorsCancelInviteTitle => 'Cancel invitation';

  @override
  String get vendorsCancelInviteMessage =>
      'Cancel this pending invitation? You can send a new one later.';

  @override
  String get vendorsInviteCancelled => 'Invitation cancelled';

  @override
  String get vendorsAlreadyLinked => 'Already linked';

  @override
  String get vendorsInviteToShopxy => 'Invite to Shopxy';

  @override
  String get vendorsAddEmailFirst => 'Add an email first';

  @override
  String get vendorsCancelInvitation => 'Cancel invitation';

  @override
  String get vendorsSentTo => 'Sent to';

  @override
  String get vendorsInviteStatusInvited => 'Invited';

  @override
  String get vendorsInviteStatusLinked => 'Linked';

  @override
  String get vendorsInviteStatusDeclined => 'Declined';

  @override
  String get vendorsInviteStatusCancelled => 'Cancelled';

  @override
  String get vendorsInviteStatusExpired => 'Expired';

  @override
  String get vendorsDetailTitle => 'Vendor';

  @override
  String get vendorsRecordPayment => 'Record payment';

  @override
  String get vendorsLedger => 'Ledger';

  @override
  String get vendorsRecentBills => 'Recent bills';

  @override
  String get vendorsRecentStockIn => 'Recent stock-in';

  @override
  String get vendorsNoActivity => 'No activity yet.';

  @override
  String get vendorsLinked => 'Linked';

  @override
  String get vendorsNetPurchased => 'Net purchased';

  @override
  String get vendorsBillsUnit => 'bills';

  @override
  String get vendorsStockIns => 'Stock-ins';

  @override
  String get vendorsLedgerRows => 'Ledger rows';

  @override
  String get vendorsReturns => 'Returns';

  @override
  String get vendorsItemUnit => 'item';

  @override
  String get vendorsItemsUnit => 'items';

  @override
  String get vendorsNoOutstanding => 'No outstanding';

  @override
  String get vendorsYouOwe => 'You owe';

  @override
  String get vendorsAdvanceWithVendor => 'Advance with vendor';

  @override
  String get vendorsBalanceLabel => 'BALANCE';

  @override
  String get vendorsBalShort => 'Bal';

  @override
  String get profileNavProfile => 'Profile';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileEditProfile => 'Edit profile';

  @override
  String get profileAppTagline => 'Smart Inventory Management';

  @override
  String get profileMemberSince => 'Since';

  @override
  String get profileManageBusiness => 'Manage your business';

  @override
  String get profileNavCategories => 'Categories';

  @override
  String get profileCategoriesSubtitle => 'Product categories and grouping';

  @override
  String get profileNavVendors => 'Vendors';

  @override
  String get profileVendorsSubtitle => 'Suppliers you buy from';

  @override
  String get profileNavParties => 'Parties';

  @override
  String get profilePartiesSubtitle => 'Customers you sell to';

  @override
  String get profileOperations => 'Operations';

  @override
  String get profileNavInvoices => 'Invoices';

  @override
  String get profileInvoicesSubtitle => 'Sales, purchase and credit notes';

  @override
  String get profileNavChallans => 'Challans';

  @override
  String get profileChallansSubtitle => 'Delivery notes without prices';

  @override
  String get profileStockAdjustments => 'Stock adjustments';

  @override
  String get profileStockAdjustmentsSubtitle =>
      'Damage, expiry, shrinkage corrections';

  @override
  String get profileReports => 'Reports';

  @override
  String get profileReportsSubtitle => 'Sales, purchases, GST and P&L';

  @override
  String get profileFinishShopSetup => 'Finish setting up your shop';

  @override
  String get profileFinishShopSetupBody =>
      'Add your shop name, GSTIN and state so invoices print correctly.';

  @override
  String get profilePersonalDetails => 'Personal details';

  @override
  String get profileNotAdded => 'Not added';

  @override
  String get profileCopied => 'Copied to clipboard';

  @override
  String get profileFieldName => 'Name';

  @override
  String get profileFieldPhoto => 'Photo';

  @override
  String get profileFieldPhone => 'Phone';

  @override
  String get profileFieldShopName => 'Shop name';

  @override
  String get profileFieldAddress => 'Address';

  @override
  String get profileFieldCity => 'City';

  @override
  String get profileFieldState => 'State';

  @override
  String get profileFieldStateCode => 'State code';

  @override
  String get profileFieldPinCode => 'PIN code';

  @override
  String get profileFieldGstin => 'GSTIN';

  @override
  String get profileFieldPan => 'PAN';

  @override
  String get profileFieldUpiId => 'UPI ID';

  @override
  String get profileCompletionTitle => 'Profile complete';

  @override
  String get profileCompletionDetailsAdded => 'details added.';

  @override
  String get profileCompleteIt => 'Complete it';

  @override
  String get profileWhatsLeft => 'WHAT\'S LEFT';

  @override
  String get profileRoleOwner => 'Owner';

  @override
  String get profileRoleManager => 'Manager';

  @override
  String get profileRoleStockist => 'Stockist';

  @override
  String get profileRoleCashier => 'Cashier';

  @override
  String get profileRoleStaff => 'Staff';

  @override
  String get profileChangePassword => 'Change Password';

  @override
  String get profileCurrentPassword => 'Current Password';

  @override
  String get profileNewPassword => 'New Password';

  @override
  String get profileConfirmNewPassword => 'Confirm new password';

  @override
  String get profilePasswordHelper =>
      '8+ chars, must include a letter and a number';

  @override
  String get profilePasswordMinLength => 'Must be at least 8 characters';

  @override
  String get profilePasswordNeedsLetter => 'Must contain a letter';

  @override
  String get profilePasswordNeedsNumber => 'Must contain a number';

  @override
  String get profilePasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get profilePasswordChanged =>
      'Password changed. Existing sessions revoked.';

  @override
  String get profileRequired => 'Required';

  @override
  String get profilePrivacyPolicy => 'Privacy policy';

  @override
  String get profileTermsOfService => 'Terms of service';

  @override
  String get profilePrivacyBody =>
      'ShopXY is a Data Fiduciary under India\'s Digital Personal Data Protection Act, 2023 (DPDP). This notice explains what we collect, why, and the rights you have over your data.\n\nWhat we hold\nWe store the minimum data needed to run your shop: account credentials, your product/vendor/party records, invoices and payments you create, notification preferences, and consent timestamps. We do not sell your data and do not share it with third parties except as required to operate the service (hosting, error monitoring) or by Indian law.\n\nData localisation\nYour data is stored on servers located in India in line with applicable RBI / sector guidance. Backups are encrypted and held in the same jurisdiction.\n\nRetention\nFinancial records — invoices, payments and supporting ledgers — are retained for at least 8 financial years to comply with the Companies Act, 2013 (§128) and the GST Act (§36). Other personal data is retained only as long as your account is active or as required to provide the service.\n\nYour rights (DPDP §11 and §12)\nYou have the right to (a) access a copy of your personal data, (b) correct or update it, (c) withdraw consent and request erasure, and (d) nominate someone to act on your behalf. The Settings > Danger zone screen exposes \"Export my data\" (a downloadable JSON of every row tied to your account) and \"Delete account\" (immediate erasure for customer accounts; controlled erasure for shop-owner accounts whose books are still inside the 8-year retention window).\n\nConsent withdrawal\nYou may withdraw consent at any time by deleting your account or by emailing support@shopxy.app. Withdrawal does not apply retroactively to processing performed lawfully before withdrawal.\n\nGrievance redressal\nDPDP §13 requires a published grievance contact. Please reach our Grievance Officer at grievance@shopxy.app. We acknowledge within 48 hours and aim to resolve within one month; personal-data requests under the DPDP Act are addressed within 15 days. If unresolved, you may approach the Data Protection Board of India.\n';

  @override
  String get profileTermsBody =>
      'ShopXY is provided as-is for managing your shop\'s inventory, invoices, payments and customer relationships. By creating an account you agree to the terms below.\n\n1. Account integrity. Provide accurate information when registering and keep your password confidential — you are responsible for all activity under your account.\n\n2. Lawful use. Use the service only for legitimate business operations. No spam, no scraping, no attempts to compromise other accounts or to bypass billing.\n\n3. Compliance with Indian law. You will comply with all applicable tax, GST and commerce laws of India. ShopXY assists with documentation but does not constitute legal or tax advice.\n\n4. Data and consent. Your use of ShopXY is also governed by the Privacy Policy, which describes how we handle personal data under the DPDP Act, 2023 — including data localisation in India, an 8-year retention window for financial books (Companies Act §128 / GST §36), and your rights to access and delete your data via the in-app Settings screen.\n\n5. Service availability. We may schedule maintenance or update features. We will give reasonable notice for material changes.\n\n6. Termination. We may suspend accounts that violate these terms or that we reasonably suspect of fraudulent activity. You may close your account at any time via Settings > Delete account.\n\n7. Grievances. Questions, complaints or DPDP requests can be sent to grievance@shopxy.app. The Grievance Officer acknowledges within 48 hours and responds within one month.\n';

  @override
  String get profileTakePhoto => 'Take a photo';

  @override
  String get profilePickFromGallery => 'Pick from gallery';

  @override
  String get profileRemovePhoto => 'Remove photo';

  @override
  String get profileProfileUpdated => 'Profile updated';

  @override
  String get profileName => 'Name';

  @override
  String get profileNameMinLength => 'Name must be at least 2 characters';

  @override
  String get profileNameTooLong => 'Name too long';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileEmailNotEditable => 'Email changes are not supported yet';

  @override
  String get profileShopDetails => 'Shop details';

  @override
  String get profileShopDetailsHint =>
      'These appear on invoices and PDFs. GSTIN must match the state.';

  @override
  String get profileShopName => 'Shop name';

  @override
  String get profileShopAddress => 'Shop address';

  @override
  String get profileCity => 'City';

  @override
  String get profilePinCode => 'PIN code';

  @override
  String get profileState => 'State';

  @override
  String get profileSelectPlaceholder => '— Select —';

  @override
  String get profileGstin => 'GSTIN';

  @override
  String get profilePan => 'PAN';

  @override
  String get profileUpiId => 'UPI ID';

  @override
  String get profileSave => 'Save';

  @override
  String get profileSectionAccount => 'ACCOUNT';

  @override
  String get profileChangePasswordSubtitle =>
      'Update the password on your account';

  @override
  String get profileSectionShopOperations => 'SHOP OPERATIONS';

  @override
  String get profileShopOperations => 'Shop operations';

  @override
  String get profileShopOperationsSubtitle =>
      'Hours, vacation mode, payouts, KYC, team';

  @override
  String get profileSectionAppearance => 'APPEARANCE';

  @override
  String get profileCurrency => 'Currency';

  @override
  String get profileCurrencyIndianRupee => 'Indian Rupee (₹)';

  @override
  String get profileListDensity => 'List density';

  @override
  String get profileListDensityCompactDesc =>
      'Tighter rows — more products per screen.';

  @override
  String get profileListDensityComfortableDesc =>
      'Comfortable spacing (default).';

  @override
  String get profileDensityComfortable => 'Comfortable';

  @override
  String get profileDensityCompact => 'Compact';

  @override
  String get profileNavigationStyle => 'Navigation style';

  @override
  String get profileNavigationStyleSidebarDesc =>
      'Left-side rail with destinations stacked vertically.';

  @override
  String get profileNavigationStyleBottomDesc => 'Bottom tab bar (default).';

  @override
  String get profileNavStyleBottomBar => 'Bottom bar';

  @override
  String get profileNavStyleSidebar => 'Sidebar';

  @override
  String get profileSectionInventory => 'INVENTORY';

  @override
  String get profileCustomFields => 'Custom Fields';

  @override
  String get profileCustomFieldsHint =>
      'Track extra information on every product';

  @override
  String get profileSectionNotifications => 'NOTIFICATIONS';

  @override
  String get profileEmailNotifications => 'Email notifications';

  @override
  String get profileEmailNotificationsSubtitle =>
      'Low-stock alerts and weekly summary';

  @override
  String get profilePreferenceSaveFailed => 'Could not save preference:';

  @override
  String get profileSectionAbout => 'ABOUT';

  @override
  String get profileAppVersion => 'App version';

  @override
  String get profileSectionDangerZone => 'DANGER ZONE';

  @override
  String get profileExportMyData => 'Export my data';

  @override
  String get profileExportMyDataSubtitle =>
      'Download a JSON copy of every record tied to your account.';

  @override
  String get profileExportFailed => 'Export failed:';

  @override
  String get profileDataExportShareText => 'Your ShopXY data export';

  @override
  String get profileDeleteAccount => 'Delete account';

  @override
  String get profileDeleteAccountSubtitle =>
      'Permanently erase your account. Shop owners with invoices in the past 8 years must contact support (Companies Act / GST retention).';

  @override
  String get profileDeleteAccountDialogBody =>
      'This permanently erases your account and revokes every session. Owners whose invoices are still inside the 8-year Companies Act / GST retention window cannot delete in-app — contact support@shopxy.example for a controlled wipe.';

  @override
  String get profileAccountDeleted => 'Account deleted';

  @override
  String get profileCancel => 'Cancel';

  @override
  String get profileDelete => 'Delete';

  @override
  String get profileLogout => 'Log out';

  @override
  String get profileLogoutConfirm => 'Are you sure you want to log out?';

  @override
  String get profileComingSoon => 'Coming soon';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsTabInbox => 'Inbox';

  @override
  String get notificationsTabInvites => 'Invites';

  @override
  String get notificationsTabSent => 'Sent';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsInviteButton => 'Invite';

  @override
  String get notificationsInboxEmptyTitle => 'No notifications yet';

  @override
  String get notificationsInboxEmptyBody =>
      'When something happens — like an invitation reply — you\'ll see it here.';

  @override
  String get notificationsIncomingEmptyTitle => 'No invitations';

  @override
  String get notificationsIncomingEmptyBody =>
      'When a shop invites you as a party or vendor, you\'ll see the request here.';

  @override
  String get notificationsOutgoingEmptyTitle => 'No invitations sent yet';

  @override
  String get notificationsOutgoingEmptyBody =>
      'Tap the Invite button to invite a party or vendor by email.';

  @override
  String get notificationsAShop => 'A shop';

  @override
  String get notificationsRolePartyCustomer => 'Party (customer)';

  @override
  String get notificationsRoleVendorSupplier => 'Vendor (supplier)';

  @override
  String notificationsWantsToAddYou(Object role) {
    return 'wants to add you as their $role';
  }

  @override
  String get notificationsDecline => 'Decline';

  @override
  String get notificationsAccept => 'Accept';

  @override
  String get notificationsInvitationAccepted => 'Invitation accepted';

  @override
  String get notificationsInvitationDeclined => 'Invitation declined';

  @override
  String get notificationsRoleParty => 'Party';

  @override
  String get notificationsRoleVendor => 'Vendor';

  @override
  String get notificationsCancel => 'Cancel';

  @override
  String get notificationsInvitationCancelled => 'Invitation cancelled';

  @override
  String get notificationsStatusPending => 'Pending';

  @override
  String get notificationsStatusAccepted => 'Accepted';

  @override
  String get notificationsStatusDeclined => 'Declined';

  @override
  String get notificationsStatusCancelled => 'Cancelled';

  @override
  String get notificationsStatusExpired => 'Expired';

  @override
  String get notificationsInvitationSent => 'Invitation sent';

  @override
  String get notificationsSendInvitationTitle => 'Send invitation';

  @override
  String get notificationsInviteByEmail => 'Invite by email';

  @override
  String get notificationsInviteByEmailHelp =>
      'They will see your request under Notifications. If they don\'t have a Shopxy account yet, it shows up the moment they sign up with this email.';

  @override
  String get notificationsCustomerName => 'Customer name';

  @override
  String get notificationsVendorName => 'Vendor name';

  @override
  String get notificationsRecipientEmail => 'Recipient email';

  @override
  String get notificationsMessageOptional => 'Message (optional)';

  @override
  String get notificationsMessageHint => 'Hey! Linking your account on Shopxy…';

  @override
  String get notificationsModeExisting => 'Existing';

  @override
  String get notificationsModeNewContact => 'New contact';

  @override
  String get notificationsChooseParty => 'Choose party';

  @override
  String get notificationsChooseVendor => 'Choose vendor';

  @override
  String get notificationsSearchParties => 'Search parties…';

  @override
  String get notificationsSearchVendors => 'Search vendors…';

  @override
  String get notificationsNoContactsFound => 'No contacts found';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get categoriesEmptyTitle => 'No categories yet';

  @override
  String get categoriesEmptyHint => 'Tap + to add a category';

  @override
  String get categoriesProductsEmptyTitle => 'No products in this category';

  @override
  String categoriesProductsNoMatchTitle(Object name) {
    return 'No products match \"$name\"';
  }

  @override
  String categoriesProductsEmptySubtitle(Object name) {
    return 'Assign products to \"$name\" from the product editor.';
  }

  @override
  String get categoriesProductsNoMatchSubtitle =>
      'Try a shorter or different search.';

  @override
  String get categoriesProductUnit => 'product';

  @override
  String get categoriesProductsUnit => 'products';

  @override
  String get categoriesSearchProductsHint => 'Search products';

  @override
  String get categoriesPickerTitle => 'Select category';

  @override
  String get categoriesCancel => 'Cancel';

  @override
  String get categoriesClearSelection => 'Clear selection';

  @override
  String get categoriesError => 'Something went wrong';

  @override
  String get categoriesNoMatch => 'No categories match that search.';

  @override
  String get categoriesSubcategoriesUnit => 'subcategories';

  @override
  String get couponsTitle => 'Coupons';

  @override
  String get couponsNewCoupon => 'New coupon';

  @override
  String get couponsEditCoupon => 'Edit coupon';

  @override
  String get couponsCreateCoupon => 'Create coupon';

  @override
  String get couponsSaveChanges => 'Save changes';

  @override
  String get couponsSaving => 'Saving…';

  @override
  String get couponsCancel => 'Cancel';

  @override
  String get couponsDeactivate => 'Deactivate';

  @override
  String get couponsRetry => 'Retry';

  @override
  String couponsDeactivateConfirmTitle(Object code) {
    return 'Deactivate $code?';
  }

  @override
  String get couponsDeactivateConfirmBody =>
      'Buyers won\'t see this coupon anymore. Existing redemptions are unaffected.';

  @override
  String get couponsEmptyBody =>
      'No coupons yet. Tap \"New coupon\" to create your first one.';

  @override
  String couponsPercentOff(Object value) {
    return '$value% off';
  }

  @override
  String couponsAmountOff(Object amount) {
    return '$amount off';
  }

  @override
  String get couponsStatusInactive => 'Inactive';

  @override
  String get couponsStatusExpired => 'Expired';

  @override
  String get couponsStatusExhausted => 'Exhausted';

  @override
  String get couponsStatusLive => 'Live';

  @override
  String get couponsBadgePublicAutoApplies => 'Public · auto-applies';

  @override
  String get couponsBadgeFirstOrderOnly => 'First order only';

  @override
  String couponsValidityRedeemed(Object from, Object until, Object count) {
    return 'Valid $from – $until · $count redeemed';
  }

  @override
  String get couponsFieldCode => 'Code';

  @override
  String get couponsFieldTitle => 'Title';

  @override
  String get couponsFieldTitleHint => 'New user offer';

  @override
  String get couponsFieldDescription => 'Description (optional)';

  @override
  String get couponsFieldType => 'Type';

  @override
  String get couponsDiscountTypePercent => 'Percent off';

  @override
  String get couponsDiscountTypeFlat => 'Flat ₹ off';

  @override
  String get couponsFieldPercentOff => '% off';

  @override
  String get couponsFieldAmountOff => '₹ off';

  @override
  String get couponsFieldMaxDiscount => 'Max discount (₹) — caps the % off';

  @override
  String get couponsFieldMinOrder => 'Minimum order (₹)';

  @override
  String get couponsDateFrom => 'From';

  @override
  String get couponsDateUntil => 'Until';

  @override
  String get couponsFieldPerUserLimit => 'Per-user limit (0 = unlimited)';

  @override
  String get couponsFieldTotalCap => 'Total cap (0 = unlimited)';

  @override
  String get couponsPublicTitle => 'Public — auto-applies';

  @override
  String get couponsPublicSubtitle =>
      'Anyone can see and use it. Auto-applies at checkout when the cart matches — no code typing needed. Keep off for private codes shared with specific people.';

  @override
  String get couponsFirstOrderTitle => 'First-order only';

  @override
  String get couponsFirstOrderSubtitle =>
      'Restricts redemption to customers with no prior confirmed orders. Pair with \"per-user limit = 1\" for a single-shot welcome offer.';

  @override
  String get couponsActiveTitle => 'Active';

  @override
  String get couponsActiveSubtitle =>
      'When off, buyers won\'t see this coupon and can\'t redeem it.';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authLoginSubtitle =>
      'Sign in to manage your inventory, invoices and customers.';

  @override
  String get authLoginFooterPrompt => 'New to ShopXY?';

  @override
  String get authCreateAccountCta => 'Create an account';

  @override
  String get authGoogleComingSoon =>
      'Google sign-in is coming soon — please use your email for now.';

  @override
  String get authEmail => 'Email';

  @override
  String get authPassword => 'Password';

  @override
  String get authFieldRequired => 'This field is required';

  @override
  String get authInvalidEmail => 'Enter a valid email address';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authLegalAgreePrefix => 'By signing in you agree to our ';

  @override
  String get authLegalTerms => 'Terms';

  @override
  String get authLegalAcknowledgeMid => ' and acknowledge our ';

  @override
  String get authLegalPrivacyPolicy => 'Privacy Policy';

  @override
  String get authLegalCookieSuffix =>
      '. We use a strictly-necessary session cookie to keep you signed in.';

  @override
  String get authTroubleSigningIn => 'Trouble signing in? ';

  @override
  String get authContactSupport => 'Contact support';

  @override
  String get authComplianceLawsFormulas => 'Compliance, laws & formulas';

  @override
  String get authContinueAs => 'Continue as';

  @override
  String get authRemoveThisAccount => 'Remove this account';

  @override
  String get authRegisterTitle => 'Create your account';

  @override
  String get authRegisterSubtitle =>
      'Set up your merchant account to start managing your inventory, invoices and customers.';

  @override
  String get authRegisterFooterPrompt => 'Already have an account?';

  @override
  String get authAcceptTermsPrompt =>
      'Please accept the Terms of Service and Privacy Policy to continue.';

  @override
  String get authYourName => 'Your name';

  @override
  String get authNameTooShort => 'Name must be at least 2 characters';

  @override
  String get authShopName => 'Shop name';

  @override
  String get authShopNameHelper =>
      'Shown to customers in the marketplace. You can rename it later.';

  @override
  String get onboardingShopTitle => 'Set up your shop';

  @override
  String get onboardingShopSubtitle =>
      'Give your shop a name to get started. You can change it later in settings.';

  @override
  String get onboardingShopCta => 'Continue';

  @override
  String get otpVerifyTitle => 'Verify your email';

  @override
  String otpVerifySubtitle(String email) {
    return 'Enter the 6-digit code we sent to $email.';
  }

  @override
  String get otpCodeLabel => 'Verification code';

  @override
  String get otpVerifyCta => 'Verify & continue';

  @override
  String get otpResend => 'Resend code';

  @override
  String otpResendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get otpNoCodePrompt => 'Didn\'t get the code?';

  @override
  String get otpResent => 'A new code is on its way.';

  @override
  String get authPasswordHelper =>
      'At least 10 characters, with a letter and a number.';

  @override
  String get authConfirmPassword => 'Confirm Password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords do not match';

  @override
  String get authIAcceptThe => 'I accept the';

  @override
  String get authTermsOfService => 'Terms of Service';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authOrContinueWithEmail => 'or continue with email';

  @override
  String get authHide => 'Hide';

  @override
  String get authShow => 'Show';

  @override
  String get dashboardHiddenTitle => 'Dashboard hidden';

  @override
  String get dashboardHiddenMessage =>
      'Your role doesn\'t include the dashboard overview. Ask an owner if you need it.';

  @override
  String get dashboardGreetingMorning => 'Good morning';

  @override
  String get dashboardGreetingAfternoon => 'Good afternoon';

  @override
  String get dashboardGreetingEvening => 'Good evening';

  @override
  String dashboardGreetingWithName(Object greeting, Object name) {
    return '$greeting, $name';
  }

  @override
  String get dashboardYourShop => 'your shop';

  @override
  String dashboardShopStatus(Object shop) {
    return 'Here\'s how $shop is doing.';
  }

  @override
  String get dashboardPendingInviteOne =>
      'You have 1 pending invitation — review and accept.';

  @override
  String dashboardPendingInviteMany(Object count) {
    return 'You have $count pending invitations — review and accept.';
  }

  @override
  String get dashboardView => 'View';

  @override
  String get dashboardOperations => 'Operations';

  @override
  String get dashboardGstThisMonth => 'GST this month';

  @override
  String dashboardOutputTaxCollected(Object amount) {
    return '$amount output tax collected';
  }

  @override
  String get dashboardInventoryValue => 'Inventory value';

  @override
  String get dashboardCostBasisOfStock => 'Cost basis of stock on hand';

  @override
  String get dashboardOneSale => '1 sale';

  @override
  String dashboardSalesCount(Object count) {
    return '$count sales';
  }

  @override
  String dashboardOpenTillSince(Object time) {
    return 'Open till · since $time';
  }

  @override
  String get dashboardNeedsAttention => 'Needs attention';

  @override
  String get dashboardAllCaughtUp =>
      'You\'re all caught up — nothing needs action right now.';

  @override
  String get dashboardOrdersToConfirm => 'Orders to confirm';

  @override
  String get dashboardReturnsToReview => 'Returns to review';

  @override
  String get dashboardQuotesToPrice => 'Quotes to price';

  @override
  String get dashboardDraftsToConfirm => 'Drafts to confirm';

  @override
  String get dashboardOutOfStock => 'Out of stock';

  @override
  String get dashboardLowStock => 'Low stock';

  @override
  String get dashboardSales => 'Sales';

  @override
  String get dashboardNetProfit => 'Net profit';

  @override
  String dashboardMarginPct(Object pct) {
    return '$pct% margin';
  }

  @override
  String get dashboardReceivables => 'Receivables';

  @override
  String get dashboardOnePartyOwesYou => '1 party owes you';

  @override
  String dashboardPartiesOweYou(Object count) {
    return '$count parties owe you';
  }

  @override
  String get dashboardPayables => 'Payables';

  @override
  String get dashboardOneVendorToPay => '1 vendor to pay';

  @override
  String dashboardVendorsToPay(Object count) {
    return '$count vendors to pay';
  }

  @override
  String get kpiDrawerRetry => 'Retry';

  @override
  String get kpiDrawerLoadError => 'Could not load. Please try again.';

  @override
  String get kpiDrawerSalesFilterHint => 'Filter by product name or SKU';

  @override
  String get kpiDrawerNoSales => 'No sales in this period.';

  @override
  String get kpiDrawerNoMatch => 'No products match your filter.';

  @override
  String kpiDrawerProductCount(Object count) {
    return '$count products';
  }

  @override
  String kpiDrawerRevenue(Object value) {
    return 'Revenue $value';
  }

  @override
  String kpiDrawerQtySold(Object qty, Object unit) {
    return '$qty $unit sold';
  }

  @override
  String kpiDrawerShowingTop(Object count) {
    return 'Showing top $count';
  }

  @override
  String get kpiDrawerUnnamedProduct => 'Unnamed product';

  @override
  String get kpiDrawerUnits => 'units';

  @override
  String get kpiDrawerViewFullReports => 'View full reports';

  @override
  String get kpiDrawerViewAllParties => 'View all parties';

  @override
  String get kpiDrawerViewAllVendors => 'View all vendors';

  @override
  String get kpiDrawerNoReceivables => 'No one owes you right now.';

  @override
  String get kpiDrawerNoPayables => 'You don\'t owe anyone right now.';

  @override
  String get kpiDrawerBilled => 'Billed';

  @override
  String get kpiDrawerReceived => 'Received';

  @override
  String get kpiDrawerPaid => 'Paid';

  @override
  String get kpiDrawerOutstanding => 'Outstanding';

  @override
  String kpiDrawerDocCount(num count) {
    final intl.NumberFormat countNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString documents',
      one: '1 document',
    );
    return '$_temp0';
  }

  @override
  String get dashboardSalesTrend => 'Sales trend';

  @override
  String get dashboardPrevious => 'Previous';

  @override
  String get dashboardPurchases => 'Purchases';

  @override
  String get dashboardReturns => 'Returns';

  @override
  String get dashboardGetShopReady => 'Let\'s get your shop ready';

  @override
  String get dashboardOnboardingSubtitle =>
      'Finish these steps and your dashboard fills with live numbers.';

  @override
  String dashboardStepsDone(Object done, Object total) {
    return '$done/$total done';
  }

  @override
  String get dashboardAddFirstProductTitle => 'Add your first product';

  @override
  String get dashboardAddFirstProductDesc =>
      'Build your catalogue so you can bill and track stock.';

  @override
  String get dashboardAddProduct => 'Add product';

  @override
  String get dashboardCreateFirstInvoiceTitle => 'Create your first invoice';

  @override
  String get dashboardCreateFirstInvoiceDesc =>
      'Bill a sale — GST is handled for you.';

  @override
  String get dashboardNewInvoice => 'New invoice';

  @override
  String get dashboardAddCustomerTitle => 'Add a customer';

  @override
  String get dashboardAddCustomerDesc =>
      'Track who owes you and send them invoices.';

  @override
  String get dashboardAddCustomer => 'Add customer';

  @override
  String get dashboardSetUpPayoutsTitle => 'Set up payouts';

  @override
  String get dashboardSetUpPayoutsDesc =>
      'Receive settlements for online orders.';

  @override
  String get dashboardSetUp => 'Set up';

  @override
  String get dashboardAlertReorder => 'Reorder';

  @override
  String get dashboardAlertFileGst => 'File GST';

  @override
  String get dashboardAlertViewReport => 'View report';

  @override
  String get dashboardAlertOpenTill => 'Open till';

  @override
  String get dashboardDismiss => 'Dismiss';

  @override
  String get dashboardRecentActivity => 'Recent activity';

  @override
  String get dashboardNoRecentMovements => 'No recent stock movements.';

  @override
  String dashboardProductFallback(Object id) {
    return 'Product #$id';
  }

  @override
  String get dashboardTopCategories => 'Top categories';

  @override
  String get dashboardTopProducts => 'Top products';

  @override
  String get dashboardSlowMovers => 'Slow movers';

  @override
  String get dashboardSlowMoversHint =>
      'Share of idle in-stock units — capital that isn\'t moving.';

  @override
  String dashboardUnitsValue(Object count) {
    return '$count units';
  }

  @override
  String get dashboardSubjectCategorySales => 'category sales';

  @override
  String get dashboardSubjectProductSales => 'product sales';

  @override
  String get dashboardSubjectIdleStock => 'idle stock';

  @override
  String get dashboardNounCategories => 'categories';

  @override
  String get dashboardNounProducts => 'products';

  @override
  String get dashboardPieOther => 'Other';

  @override
  String get dashboardNoDataInPeriod => 'No data in this period yet.';

  @override
  String get dashboardAboutThisChart => 'About this chart';

  @override
  String get dashboardTapSliceHint => 'Tap a slice for its breakdown.';

  @override
  String dashboardPieSummaryBase(
    Object total,
    Object count,
    Object noun,
    Object avg,
  ) {
    return '$total across $count $noun (avg $avg each).';
  }

  @override
  String dashboardPieSummaryLead(Object label, Object pct, Object value) {
    return '$label leads with $pct% ($value)';
  }

  @override
  String dashboardPieSummaryAheadOf(Object label, Object pct) {
    return ', ahead of $label at $pct%';
  }

  @override
  String dashboardPieSummaryTopK(Object k, Object pct, Object subject) {
    return 'The top $k make up $pct% of $subject';
  }

  @override
  String dashboardPieSummaryTrails(Object label, Object pct) {
    return ', while $label trails at $pct%';
  }

  @override
  String dashboardPieDetailTail(Object pct, Object subject) {
    return ', $pct% of $subject.';
  }

  @override
  String get dashboardPeriodToday => 'Today';

  @override
  String get dashboardPeriodWeek => '7 days';

  @override
  String get dashboardPeriodMonth => '30 days';

  @override
  String get dashboardDeltaNew => 'New';

  @override
  String get shopSave => 'Save';

  @override
  String get shopSaving => 'Saving…';

  @override
  String get shopSaveFailed => 'Save failed';

  @override
  String get shopCancel => 'Cancel';

  @override
  String get shopDelete => 'Delete';

  @override
  String get shopRemove => 'Remove';

  @override
  String get shopContinue => 'Continue';

  @override
  String get shopBack => 'Back';

  @override
  String get shopRetry => 'Retry';

  @override
  String get shopTryAgain => 'Try again';

  @override
  String get shopDismiss => 'Dismiss';

  @override
  String get shopEnabled => 'Enabled';

  @override
  String get shopNotYetEnabled => 'Not yet enabled';

  @override
  String get shopNotEnabledYet => 'Not enabled yet';

  @override
  String get shopHoursTitle => 'Hours & vacation mode';

  @override
  String get shopHoursSaved => 'Hours saved';

  @override
  String get shopVacationMode => 'Vacation mode';

  @override
  String get shopVacationModeSubtitle =>
      'Blocks new orders. Existing orders, stock, and invoices stay editable as usual.';

  @override
  String get shopVacationMessageLabel =>
      'Message shown to customers (optional)';

  @override
  String get shopVacationMessageHint =>
      'e.g. Back on Jun 5. Thanks for your patience!';

  @override
  String get shopOpeningHours => 'OPENING HOURS';

  @override
  String get shopHoursHint =>
      'Hours are a hint to customers — orders outside hours still go through.';

  @override
  String get shopDayClosed => 'Closed';

  @override
  String get shopDayMonday => 'Monday';

  @override
  String get shopDayTuesday => 'Tuesday';

  @override
  String get shopDayWednesday => 'Wednesday';

  @override
  String get shopDayThursday => 'Thursday';

  @override
  String get shopDayFriday => 'Friday';

  @override
  String get shopDaySaturday => 'Saturday';

  @override
  String get shopDaySunday => 'Sunday';

  @override
  String get shopOperationsTitle => 'Shop operations';

  @override
  String get shopOpsHoursOnVacation => 'On vacation — new orders blocked';

  @override
  String get shopOpsHoursSubtitle => 'Set opening hours and pause new orders.';

  @override
  String get shopOnVacationBadge => 'On vacation';

  @override
  String get shopPayoutsTitle => 'Payouts & settlement';

  @override
  String get shopKycTitle => 'KYC documents';

  @override
  String get shopOpsKycSubtitle =>
      'PAN, GSTIN certificate, cancelled cheque. Required before payouts go live.';

  @override
  String get shopComingSoonBadge => 'Coming soon';

  @override
  String get shopTeamTitle => 'Team & roles';

  @override
  String get shopOpsTeamSubtitle =>
      'Invite staff and scope exactly what each person can view and manage.';

  @override
  String get shopOpsPayoutsLinkBank =>
      'Link a bank account to receive your sales settlements.';

  @override
  String get shopOpsPayoutsResume =>
      'Resume your payout setup — you have a saved draft.';

  @override
  String get shopOpsPayoutsSetUp =>
      'Set up your bank account to start receiving settlements.';

  @override
  String get shopOpsPayoutsActive =>
      'Active — your sales settle to your linked bank account.';

  @override
  String get shopOpsPayoutsSubmitted =>
      'Submitted — Razorpay is verifying your account.';

  @override
  String get shopInProgressBadge => 'In progress';

  @override
  String get shopSetUpBadge => 'Set up';

  @override
  String get shopActiveBadge => 'Active';

  @override
  String get shopUnderReviewBadge => 'Under review';

  @override
  String get shopKycIntro =>
      'Document uploads launch with the verified-seller badge. Until then, this lists what you\'ll be asked for so you can prepare ahead. Your payout KYC is handled in Payouts & settlement.';

  @override
  String get shopKycPanTitle => 'PAN card';

  @override
  String get shopKycPanSubtitle =>
      'Owner or business PAN. Required for payouts.';

  @override
  String get shopKycGstinTitle => 'GSTIN certificate';

  @override
  String get shopKycGstinSubtitle =>
      'If your shop has a GSTIN, upload the registration certificate.';

  @override
  String get shopKycChequeTitle => 'Cancelled cheque';

  @override
  String get shopKycChequeSubtitle =>
      'Bank-issued cheque with account holder name visible. Confirms settlement-account ownership.';

  @override
  String get shopKycAadhaarTitle => 'Aadhaar / address proof';

  @override
  String get shopKycAadhaarSubtitle =>
      'For sole-proprietor shops. Skip if you already have GSTIN on file.';

  @override
  String get shopKycPhotoTitle => 'Shop / business photo';

  @override
  String get shopKycPhotoSubtitle =>
      'Optional. Front-of-store photo helps trust + verification reviews.';

  @override
  String get shopKycNotUploaded => 'Not uploaded';

  @override
  String get shopKycUploadComingSoon => 'Upload (coming soon)';

  @override
  String get shopConnectExistingAccountTitle => 'Connect existing account';

  @override
  String get shopConnectIntro =>
      'Already have a Razorpay linked account? Paste its id to link it — no need to re-do KYC.';

  @override
  String get shopConnectAccountIdLabel => 'Account id';

  @override
  String get shopConnectVerify => 'Verify';

  @override
  String get shopConnectConfirmTitle => 'Confirm this is your account';

  @override
  String get shopConnectFactAccount => 'Account';

  @override
  String get shopConnectFactBusiness => 'Business';

  @override
  String get shopConnectFactContact => 'Contact';

  @override
  String get shopConnectFactEmail => 'Email';

  @override
  String get shopConnectFactKycStatus => 'KYC status';

  @override
  String get shopConnectFactPayouts => 'Payouts';

  @override
  String get shopConnectPayoutsNotEnabledWarning =>
      'Payouts aren\'t enabled yet — you can link it, but UPI at the till stays off until Razorpay activates the account.';

  @override
  String get shopConnectLinkAccount => 'Link this account';

  @override
  String get shopPermissionView => 'View';

  @override
  String get shopPermissionManage => 'Manage';

  @override
  String get shopStartFromRole => 'START FROM A ROLE';

  @override
  String get shopCustomRole => 'Custom';

  @override
  String shopAccessManageable(Object count) {
    return 'ACCESS · $count manageable';
  }

  @override
  String get shopPermissionTrustHint =>
      'Manage includes view. Payouts & KYC and Team are sensitive — grant them only to people you trust.';

  @override
  String get shopGiveRoleName => 'Give the role a name';

  @override
  String get shopNewRole => 'New role';

  @override
  String get shopEditRole => 'Edit role';

  @override
  String get shopRoleNameLabel => 'Role name';

  @override
  String get shopRoleNameHint => 'e.g. Warehouse Lead';

  @override
  String get shopRoleTemplatesHint =>
      'Members keep their current access when a role changes — roles are templates you assign, not live links.';

  @override
  String get shopPayoutsSubmittedSnack =>
      'Submitted — Razorpay will verify your account.';

  @override
  String get shopConnectExisting => 'Connect existing';

  @override
  String get shopStepBusiness => 'Business';

  @override
  String get shopStepIdentity => 'Identity';

  @override
  String get shopStepAddress => 'Address';

  @override
  String get shopStepBank => 'Bank';

  @override
  String shopStepProgress(Object current, Object total, Object title) {
    return 'Step $current of $total · $title';
  }

  @override
  String get shopSetUpPayouts => 'Set up payouts';

  @override
  String get shopFieldRequired => 'Required';

  @override
  String get shopInvalidEmail => 'Invalid email';

  @override
  String get shopBusinessStepTitle => 'Your business';

  @override
  String get shopBusinessStepSubtitle =>
      'The legal entity that receives settlements.';

  @override
  String get shopLegalBusinessName => 'Legal business name';

  @override
  String get shopDisplayName => 'Display name (optional)';

  @override
  String get shopDisplayNameHelper =>
      'Shown to customers. Defaults to the legal name.';

  @override
  String get shopContactPersonName => 'Contact person name';

  @override
  String get shopEmail => 'Email';

  @override
  String get shopPhone => 'Phone';

  @override
  String get shopEnter10DigitNumber => 'Enter a 10-digit number';

  @override
  String get shopBusinessType => 'Business type';

  @override
  String get shopBusinessTypeProprietorship => 'Proprietorship';

  @override
  String get shopBusinessTypePartnership => 'Partnership';

  @override
  String get shopBusinessTypePrivateLimited => 'Private Limited';

  @override
  String get shopBusinessTypePublicLimited => 'Public Limited';

  @override
  String get shopBusinessTypeLlp => 'LLP';

  @override
  String get shopBusinessTypeIndividual => 'Individual';

  @override
  String get shopBusinessTypeTrust => 'Trust';

  @override
  String get shopBusinessTypeSociety => 'Society';

  @override
  String get shopBusinessTypeNgo => 'NGO';

  @override
  String get shopBusinessCategory => 'Business category';

  @override
  String get shopCategoryEcommerce => 'E-commerce / Retail';

  @override
  String get shopCategoryFood => 'Food & Beverage';

  @override
  String get shopCategoryServices => 'Services';

  @override
  String get shopCategoryHealthcare => 'Healthcare';

  @override
  String get shopCategoryEducation => 'Education';

  @override
  String get shopCategoryOthers => 'Others';

  @override
  String get shopIdentityStepTitle => 'Identity & tax';

  @override
  String get shopIdentityStepSubtitle =>
      'Verified with the tax authority. Sent to Razorpay, never stored by this app.';

  @override
  String get shopPanHelper => 'Business or proprietor PAN (e.g. AAACL1234C).';

  @override
  String get shopInvalidPan => 'Invalid PAN';

  @override
  String get shopGstinOptional => 'GSTIN (optional)';

  @override
  String get shopGstinHelper => 'Add if your business is GST-registered.';

  @override
  String get shopInvalidGstin => 'Invalid GSTIN';

  @override
  String get shopAddressStepTitle => 'Registered address';

  @override
  String get shopAddressStepSubtitle =>
      'The address on your business registration.';

  @override
  String get shopAddressLine1 => 'Address line 1';

  @override
  String get shopAddressLine2 => 'Address line 2 (optional)';

  @override
  String get shopCity => 'City';

  @override
  String get shopState => 'State';

  @override
  String get shopSelectState => 'Select a state';

  @override
  String get shopPinCode => 'PIN code';

  @override
  String get shopEnter6DigitPin => 'Enter a 6-digit PIN';

  @override
  String get shopCountryIndia => 'Country: India';

  @override
  String get shopBankStepTitle => 'Settlement bank account';

  @override
  String get shopBankStepSubtitle =>
      'Where your payouts land. Sent securely to Razorpay; this app never stores your bank details.';

  @override
  String get shopAccountHolderName => 'Account holder name';

  @override
  String get shopBankAccountNumber => 'Bank account number';

  @override
  String get shopEnterValidAccountNumber => 'Enter a valid account number';

  @override
  String get shopInvalidIfsc => 'Invalid IFSC';

  @override
  String get shopResumeTitle => 'Continue where you left off?';

  @override
  String shopResumeDraftUpTo(Object step) {
    return 'You had a saved draft up to the $step step.';
  }

  @override
  String get shopStartOver => 'Start over';

  @override
  String get shopResume => 'Resume';

  @override
  String get shopStatusActive => 'Active — payouts enabled';

  @override
  String get shopStatusNeedsClarification =>
      'Action needed — Razorpay needs more info';

  @override
  String get shopStatusSuspended => 'Suspended — contact support';

  @override
  String get shopStatusUnderReview => 'Under review by Razorpay';

  @override
  String get shopStatusNotActivated =>
      'Not activated yet — finish KYC at Razorpay';

  @override
  String get shopStatusActivatedDesc =>
      'Your settlement account is verified. Order + UPI payouts will land in your bank.';

  @override
  String shopStatusNotEnabledDesc(Object status) {
    return 'This account is not payout-enabled yet (Razorpay status: $status). Finish its Route KYC in the Razorpay dashboard, then tap refresh to re-check live.';
  }

  @override
  String get shopDetailAccountId => 'Account ID';

  @override
  String get shopDetailName => 'Name';

  @override
  String get shopDetailEmail => 'Email';

  @override
  String get shopDetailBusinessType => 'Business type';

  @override
  String get shopDetailKycStatus => 'KYC status';

  @override
  String get shopDetailPayouts => 'Payouts';

  @override
  String get shopRefreshFromRazorpay => 'Refresh from Razorpay';

  @override
  String get shopImageTooLarge =>
      'Image is larger than 5 MB. Pick a smaller image or crop tighter.';

  @override
  String get shopImageUploadFailed => 'Image upload failed';

  @override
  String get shopProfileSaved => 'Shop profile saved';

  @override
  String get shopUnpublishTitle => 'Unpublish shop?';

  @override
  String get shopUnpublishMessage =>
      'Customers will stop seeing your shop on the marketplace. Your inventory and orders are unaffected.';

  @override
  String get shopUnpublish => 'Unpublish';

  @override
  String get shopNowLive => 'Shop is now live on the marketplace';

  @override
  String get shopHiddenFromMarketplace => 'Shop hidden from marketplace';

  @override
  String get shopPublishUpdateFailed => 'Failed to update publish state';

  @override
  String get shopDiscardChangesTitle => 'Discard changes?';

  @override
  String get shopDiscardChangesMessage =>
      'You have unsaved edits. Leaving now drops them.';

  @override
  String get shopKeepEditing => 'Keep editing';

  @override
  String get shopDiscard => 'Discard';

  @override
  String get shopMyShopTitle => 'My Shop';

  @override
  String get shopNotFound => 'Shop not found';

  @override
  String shopLiveOnMarketplaceSlug(Object slug) {
    return 'Live on marketplace · /$slug';
  }

  @override
  String get shopNotPublished => 'Not published';

  @override
  String get shopNameLabel => 'Shop name';

  @override
  String get shopNameHelper =>
      'Shown on the marketplace. Renaming updates the public URL slug.';

  @override
  String get shopMin2Chars => 'Min 2 characters';

  @override
  String get shopMax80Chars => 'Max 80 characters';

  @override
  String get shopTaglineLabel => 'Tagline (optional)';

  @override
  String get shopTaglineHelper => 'One-liner shown below your shop name.';

  @override
  String get shopLocationSection => 'Location';

  @override
  String get shopLocationSectionSubtitle =>
      'Optional. Surfaces a \"Based in …\" line on your public shop page.';

  @override
  String get shopPoliciesSection => 'Policies';

  @override
  String get shopPoliciesSectionSubtitle =>
      'Customers see these on your shop page and as a \"Policies\" pill on every PDP. Plain text. Up to 4 KB each.';

  @override
  String get shopReturnPolicyLabel => 'Return policy';

  @override
  String get shopReturnPolicyHint =>
      'e.g. 7-day return on unused items. Original packaging required.';

  @override
  String get shopShippingPolicyLabel => 'Shipping policy';

  @override
  String get shopShippingPolicyHint =>
      'e.g. Ships within 24 hours from Bengaluru. 3–5 business days delivery.';

  @override
  String get shopRefundPolicyLabel => 'Refund policy';

  @override
  String get shopRefundPolicyHint =>
      'e.g. Refunds processed within 5 business days to the original payment method.';

  @override
  String get shopReturnsCancellationSection => 'Returns & cancellation';

  @override
  String get shopReturnsCancellationSubtitle =>
      'Whether customers can return orders, how refunds are issued, and how late an order can be cancelled.';

  @override
  String get shopAcceptReturns => 'Accept returns';

  @override
  String get shopAcceptReturnsSubtitle =>
      'When off, customers can\'t request post-delivery returns.';

  @override
  String get shopReturnWindowLabel => 'Return window (days)';

  @override
  String get shopReturnWindowHelper => '0 means no time limit.';

  @override
  String get shopReturnWindowError => 'Enter a whole number between 0 and 365';

  @override
  String get shopRefundMethodLabel => 'Refund method';

  @override
  String get shopRefundMethodOriginal => 'Original payment method';

  @override
  String get shopRefundMethodReplacement => 'Replacement only';

  @override
  String get shopReturnPolicyNoteLabel => 'Return policy note (optional)';

  @override
  String get shopReturnPolicyNoteHint =>
      'e.g. Items must be unused and in original packaging. Buyer pays return shipping.';

  @override
  String get shopCustomersCanCancelLabel => 'Customers can cancel';

  @override
  String get shopCustomersCanCancelHelper =>
      'After this stage they must use a post-delivery return instead.';

  @override
  String get shopCancelUntilConfirmed => 'Until I confirm the order';

  @override
  String get shopCancelUntilPacked => 'Until packed';

  @override
  String get shopCancelUntilShipped => 'Until shipped (recommended)';

  @override
  String get shopCancelUntilDelivered => 'Until delivered';

  @override
  String get shopAddBanner => 'Add banner';

  @override
  String get shopReplace => 'Replace';

  @override
  String get shopLiveOnMarketplace => 'Live on marketplace';

  @override
  String get shopNotPublishedYet => 'Not published yet';

  @override
  String get shopPublishCardLiveDesc =>
      'Customers can find your shop and your published products.';

  @override
  String get shopPublishCardHiddenDesc =>
      'Toggle on once your logo, banner and at least one product are ready.';

  @override
  String get shopInviteTeammate => 'Invite a teammate';

  @override
  String get shopInviteAccessTitle => 'Invite access';

  @override
  String get shopSendInvite => 'Send invite';

  @override
  String shopInviteAccessSubtitle(Object email) {
    return 'Choose what $email can view and manage. You can change this anytime.';
  }

  @override
  String shopInvitationSentTo(Object email) {
    return 'Invitation sent to $email';
  }

  @override
  String get shopEditAccessTitle => 'Edit access';

  @override
  String shopEditAccessSubtitle(Object name) {
    return 'Set exactly what $name can view and manage.';
  }

  @override
  String get shopAccessUpdated => 'Access updated';

  @override
  String get shopRemoveFromTeamTitle => 'Remove from team?';

  @override
  String shopRemoveFromTeamMessage(Object name) {
    return '$name will lose access to this shop immediately. You can invite them again later.';
  }

  @override
  String get shopRemovedFromTeam => 'Removed from team';

  @override
  String get shopRoleCreated => 'Role created';

  @override
  String get shopRoleSaved => 'Role saved';

  @override
  String shopDeleteRoleTitle(Object name) {
    return 'Delete “$name”?';
  }

  @override
  String get shopDeleteRoleMessage =>
      'This removes the role from the picker. Teammates who already have it keep their current access.';

  @override
  String get shopRoleDeleted => 'Role deleted';

  @override
  String get shopInvitationCancelled => 'Invitation cancelled';

  @override
  String get shopTeamViewOnlyBanner =>
      'You can view the team but not change it. Ask an owner to invite people or adjust who does what.';

  @override
  String shopTeamSectionHeader(Object count) {
    return 'TEAM · $count';
  }

  @override
  String shopPendingInvitesHeader(Object count) {
    return 'PENDING INVITES · $count';
  }

  @override
  String shopRolesHeader(Object count) {
    return 'ROLES · $count';
  }

  @override
  String get shopEditAccessMenu => 'Edit access';

  @override
  String get shopRemoveFromTeamMenu => 'Remove from team';

  @override
  String shopInvitedAsAwaitingReply(Object role) {
    return 'Invited as $role · awaiting reply';
  }

  @override
  String get shopBuiltIn => 'Built-in';

  @override
  String get shopRoleViewOnly => 'View-only';

  @override
  String shopRoleAreaManageable(Object count) {
    return '$count area manageable';
  }

  @override
  String shopRoleAreasManageable(Object count) {
    return '$count areas manageable';
  }

  @override
  String get shopEditRoleMenu => 'Edit role';

  @override
  String get shopDeleteRoleMenu => 'Delete role';

  @override
  String get shopInviteSheetSubtitle =>
      'Use a dedicated work email — shopper accounts can\'t be staff. You\'ll pick their access next.';

  @override
  String get shopEnterEmail => 'Enter an email';

  @override
  String get shopEnterValidEmail => 'Enter a valid email';

  @override
  String get shopChooseAccess => 'Choose access';

  @override
  String get shopNotNow => 'Not now';

  @override
  String get shopJoinFallbackShop => 'A shop';

  @override
  String get shopStaffRole => 'Staff';

  @override
  String get shopYoureInvitedToJoin => 'You\'re invited to join';

  @override
  String get shopAsA => 'as a ';

  @override
  String get shopWhatYoullBeAbleToDo => 'WHAT YOU\'LL BE ABLE TO DO';

  @override
  String get shopLimitedAccess => 'Limited access — ask the owner for details.';

  @override
  String get shopJoinTheTeam => 'Join the team';

  @override
  String shopJoinNamed(Object shop) {
    return 'Join $shop';
  }

  @override
  String get shopDeclineInvitation => 'Decline invitation';

  @override
  String get shopSheetFinishTitle => 'Finish setting up payouts';

  @override
  String get shopSheetSetupTitle => 'Set up payouts to get paid';

  @override
  String get shopSheetFinishBody =>
      'You started setting up payouts — pick up right where you left off. Your saved details are kept securely on this device.';

  @override
  String get shopSheetSetupBody =>
      'Add your settlement bank account so your share of each order can reach you. Your money is held until the order is delivered, then settled to your bank — usually within a few days.';

  @override
  String get shopSetUpNow => 'Set up now';

  @override
  String get shopLater => 'Later';

  @override
  String get cashierTitle => 'Cashier';

  @override
  String get cashierRoleCashier => 'Cashier';

  @override
  String cashierShiftClosedVariance(Object variance) {
    return 'Shift closed · variance $variance';
  }

  @override
  String get cashierPastShiftsTitle => 'Past shifts · Z-receipts';

  @override
  String get cashierLoading => 'Loading…';

  @override
  String get cashierNoShiftsYet => 'No shifts yet.';

  @override
  String cashierVarianceLabel(Object amount) {
    return 'variance $amount';
  }

  @override
  String get cashierShiftReportTitle => 'Shift report (X)';

  @override
  String cashierSalesSummary(Object count, Object gross) {
    return '$count sales · $gross gross';
  }

  @override
  String get cashierOpeningFloat => 'Opening float';

  @override
  String get cashierCashSales => 'Cash sales';

  @override
  String get cashierPayIns => 'Pay-ins';

  @override
  String get cashierPayOuts => 'Pay-outs';

  @override
  String get cashierDrops => 'Drops';

  @override
  String get cashierRefunds => 'Refunds';

  @override
  String get cashierExpectedInDrawer => 'Expected in drawer';

  @override
  String get cashierGstTaxable => 'GST taxable';

  @override
  String cashierReturnsCount(Object count) {
    return 'Returns ($count)';
  }

  @override
  String get cashierOpenShiftTitle => 'Open a shift';

  @override
  String get cashierOpenShiftHint =>
      'Count the drawer and enter the opening float.';

  @override
  String get cashierOpeningFloatField => 'Opening float ₹';

  @override
  String get cashierOpenShiftButton => 'Open shift';

  @override
  String get cashierCashDrawerTitle => 'Cash drawer';

  @override
  String get cashierPayIn => 'Pay in';

  @override
  String get cashierPayOut => 'Pay out';

  @override
  String get cashierDrop => 'Drop';

  @override
  String get cashierAmountField => 'Amount ₹';

  @override
  String get cashierReasonField => 'Reason (optional)';

  @override
  String get cashierRecordButton => 'Record';

  @override
  String get cashierCloseShiftTitle => 'Close shift';

  @override
  String cashierExpectedInDrawerValue(Object amount) {
    return 'Expected in drawer: $amount';
  }

  @override
  String get cashierCountedCashField => 'Counted cash ₹';

  @override
  String cashierVarianceValue(Object amount, Object status) {
    return 'Variance: $amount $status';
  }

  @override
  String get cashierVarianceBalanced => '(balanced)';

  @override
  String get cashierVarianceOver => '(over)';

  @override
  String get cashierVarianceShort => '(short)';

  @override
  String get cashierNoteField => 'Note (optional)';

  @override
  String get cashierCloseZReportButton => 'Close & Z-report';

  @override
  String get cashierReturnsTitle => 'Returns';

  @override
  String get cashierOriginalInvoiceIdField => 'Original invoice id';

  @override
  String get cashierLookUpButton => 'Look up';

  @override
  String cashierReturnableLine(Object qty, Object price) {
    return 'returnable $qty · $price';
  }

  @override
  String get cashierEnterQuantityError => 'Enter a quantity to return.';

  @override
  String cashierCreditNoteCreated(Object no, Object amount) {
    return 'Credit note $no · $amount';
  }

  @override
  String get cashierProcessReturnButton => 'Process return';

  @override
  String get posTitle => 'Point of sale';

  @override
  String get posFindItem => 'Find item';

  @override
  String get posCashierTooltip => 'Cashier (shift · drawer · returns)';

  @override
  String get posHold => 'Hold';

  @override
  String get posRecall => 'Recall';

  @override
  String get posLogOut => 'Log out';

  @override
  String get posCashier => 'Cashier';

  @override
  String get posOpenShiftToBill => 'Open a shift to start billing';

  @override
  String get posOpenShift => 'Open shift';

  @override
  String get posScanFirstItem => 'Scan the first item.';

  @override
  String get posTotal => 'Total';

  @override
  String get posBillDiscount => 'Bill discount';

  @override
  String get posCheckout => 'Checkout';

  @override
  String get posLineDiscount => 'Line discount';

  @override
  String get posNewItem => 'New item';

  @override
  String get posName => 'Name';

  @override
  String get posSellingPrice => 'Selling price ₹';

  @override
  String get posGstPercentOptional => 'GST % (optional)';

  @override
  String get posOnHand => 'On hand';

  @override
  String get posCancel => 'Cancel';

  @override
  String get posAdd => 'Add';

  @override
  String get posSaleComplete => 'Sale complete';

  @override
  String get posInvoice => 'Invoice';

  @override
  String get posPrint => 'Print';

  @override
  String get posDone => 'Done';

  @override
  String get posCouldNotGenerateReceipt => 'Could not generate the receipt';

  @override
  String posDiscountMax(Object max) {
    return 'Discount ₹ (max $max)';
  }

  @override
  String get posApply => 'Apply';

  @override
  String get posDiscount => 'Discount ₹';

  @override
  String get posCollect => 'Collect';

  @override
  String get posCustomerOptional => 'Customer (optional)';

  @override
  String get posPhone => 'Phone';

  @override
  String get posCashReceived => 'Cash received ₹';

  @override
  String get posChangeDue => 'Change due';

  @override
  String get posCashDone => 'Cash — done';

  @override
  String get posOtherTenders => 'Other tenders';

  @override
  String get posOnline => 'Online';

  @override
  String get posPaymentFailedRetry => 'Payment failed. Please retry.';

  @override
  String get posNoHeldBills => 'No held bills.';

  @override
  String get posHeldBills => 'Held bills';

  @override
  String get posBill => 'Bill';

  @override
  String posItemCount(Object count) {
    return '$count item(s)';
  }

  @override
  String get posQuantity => 'Quantity';

  @override
  String get posSet => 'Set';

  @override
  String get posFindItemByNameSku => 'Find item by name / SKU';

  @override
  String get posSearching => 'Searching…';

  @override
  String get posTypeToSearch => 'Type to search the catalogue.';

  @override
  String get posStock => 'stock';

  @override
  String posAddedItem(Object name) {
    return 'Added $name';
  }

  @override
  String get posStatusLive => 'Live';

  @override
  String get posStatusConnecting => 'Connecting';

  @override
  String get posStatusReconnecting => 'Reconnecting';

  @override
  String get posStatusOffline => 'Offline';

  @override
  String get bannersTitle => 'Banners';

  @override
  String get bannersRefresh => 'Refresh';

  @override
  String get bannersNewBanner => 'New banner';

  @override
  String get bannersDeleteTitle => 'Delete banner?';

  @override
  String bannersDeleteMessage(Object placement) {
    return 'This banner will be removed from $placement.';
  }

  @override
  String get bannersCancel => 'Cancel';

  @override
  String get bannersDelete => 'Delete';

  @override
  String get bannersEmptyPlacement => 'No banners in this placement yet';

  @override
  String get bannersStatusLive => 'Live';

  @override
  String get bannersStatusScheduled => 'Scheduled';

  @override
  String get bannersStatusExpired => 'Expired';

  @override
  String get bannersStatusOff => 'Off';

  @override
  String bannersSortOrder(Object order) {
    return 'Sort $order';
  }

  @override
  String bannersProductCountOne(Object count) {
    return '$count product';
  }

  @override
  String bannersProductCountOther(Object count) {
    return '$count products';
  }

  @override
  String bannersWindowFrom(Object date) {
    return 'from $date';
  }

  @override
  String bannersWindowUntil(Object date) {
    return 'until $date';
  }

  @override
  String get bannersImageUploadFailed => 'Image upload failed';

  @override
  String get bannersImageTooLarge =>
      'Image is larger than 5 MB. Pick a smaller image or crop tighter.';

  @override
  String get bannersImageRequired => 'An image is required';

  @override
  String get bannersSaveFailed => 'Save failed';

  @override
  String bannersProductsSaveFailed(Object error) {
    return 'Banner saved, but products failed: $error';
  }

  @override
  String get bannersAlreadyPinned => 'Already pinned to this banner';

  @override
  String get bannersEditBanner => 'Edit banner';

  @override
  String get bannersPlacement => 'Placement';

  @override
  String get bannersLink => 'Link';

  @override
  String get bannersSort => 'Sort';

  @override
  String get bannersActive => 'Active';

  @override
  String get bannersActiveSubtitle => 'When off, hidden regardless of schedule';

  @override
  String get bannersSaving => 'Saving…';

  @override
  String get bannersSaveChanges => 'Save changes';

  @override
  String get bannersCreateBanner => 'Create banner';

  @override
  String get bannersUploadImage => 'Upload image *';

  @override
  String get bannersReplaceImage => 'Replace image';

  @override
  String get bannersStarts => 'Starts';

  @override
  String get bannersEnds => 'Ends';

  @override
  String get bannersProducts => 'Products';

  @override
  String get bannersAdd => 'Add';

  @override
  String get bannersSaveFirstHint => 'Save the banner first to add products.';

  @override
  String get bannersAddProductsHint =>
      'Tap “Add” to pin products with an optional discount.';

  @override
  String get bannersNotSet => 'Not set';

  @override
  String get bannersSearchProduct => 'Search product name or SKU';

  @override
  String get bannersSearchHint => 'Type 2+ characters to search';

  @override
  String get challansTitle => 'Challans';

  @override
  String get challansSearchHint => 'Search challans...';

  @override
  String get challansFilterAll => 'All';

  @override
  String get challansEmptyTitle => 'No challans found';

  @override
  String get challansEmptySubtitle => 'Tap + to create a challan';

  @override
  String get challansCreate => 'Create Challan';

  @override
  String get challansItemsLabel => 'items';

  @override
  String get challansCancel => 'Cancel Challan';

  @override
  String get challansCancelConfirm =>
      'Cancel this challan? This cannot be undone.';

  @override
  String get challansYes => 'Yes';

  @override
  String get challansNo => 'No';

  @override
  String get challansError => 'Something went wrong';

  @override
  String get challansPartyName => 'Party Name';

  @override
  String get challansPhone => 'Phone';

  @override
  String get challansNote => 'Note';

  @override
  String get challansLinkedInvoice => 'Invoice';

  @override
  String get challansItemsHeader => 'Challan Items';

  @override
  String get challansEmptyItems => 'No items added yet';

  @override
  String get challansConvertToInvoice => 'Convert to Invoice';

  @override
  String get challansAddAtLeastOne => 'Add at least one product';

  @override
  String get challansDiscardTitle => 'Discard changes?';

  @override
  String get challansDiscardMessage => 'Your edits will be lost.';

  @override
  String get challansKeepEditing => 'Keep editing';

  @override
  String get challansDiscard => 'Discard';

  @override
  String get challansSubmit => 'Submit';

  @override
  String get challansPartyInfo => 'Party Info';

  @override
  String get challansSelectParty => 'Select party';

  @override
  String get challansFieldRequired => 'This field is required';

  @override
  String get challansAddProducts => 'Add Products';

  @override
  String get challansNoPricesHint => 'Prices are not visible to the party';

  @override
  String get challansSearchProducts => 'Search products...';

  @override
  String get challansChange => 'Change';

  @override
  String get returnsTitle => 'Returns';

  @override
  String get returnsTabOpen => 'Open';

  @override
  String get returnsTabApproved => 'Approved';

  @override
  String get returnsTabReceived => 'Received';

  @override
  String get returnsTabRefunded => 'Refunded';

  @override
  String get returnsTabAll => 'All';

  @override
  String returnsRowTitle(Object id, Object name) {
    return 'Return #$id · $name';
  }

  @override
  String get returnsItemCountOne => '1 item';

  @override
  String returnsItemCountOther(Object count) {
    return '$count items';
  }

  @override
  String get returnsRefundLabel => 'Refund';

  @override
  String get returnsEmpty => 'No returns in this view yet.';

  @override
  String get returnsRetry => 'Retry';

  @override
  String get returnsStatusRequested => 'Requested';

  @override
  String get returnsStatusApproved => 'Approved';

  @override
  String get returnsStatusRejected => 'Rejected';

  @override
  String get returnsStatusCancelled => 'Cancelled';

  @override
  String get returnsStatusPickedUp => 'Picked up';

  @override
  String get returnsStatusReceived => 'Received';

  @override
  String get returnsStatusRefunded => 'Refunded';

  @override
  String returnsDetailTitle(Object id) {
    return 'Return #$id';
  }

  @override
  String get returnsNoteOptional => 'Note (optional)';

  @override
  String get returnsNoteRequired => 'Note required';

  @override
  String get returnsCancel => 'Cancel';

  @override
  String get returnsBuyerNote => 'Buyer note';

  @override
  String get returnsYourNote => 'Your note';

  @override
  String returnsRefundedToOriginal(Object amount, Object name) {
    return 'Refunded $amount to $name\'s original payment method';
  }

  @override
  String get returnsApproveTitle => 'Approve return';

  @override
  String get returnsApprove => 'Approve';

  @override
  String get returnsApproveHint =>
      'Pickup instructions for the buyer (optional)';

  @override
  String get returnsApprovedToast => 'Return approved';

  @override
  String get returnsRejectTitle => 'Reject return';

  @override
  String get returnsReject => 'Reject';

  @override
  String get returnsRejectHint => 'Why? Shown to the buyer';

  @override
  String get returnsRejectedToast => 'Return rejected';

  @override
  String get returnsPickedUpToast => 'Marked as picked up';

  @override
  String get returnsReceivedToast => 'Marked as received';

  @override
  String returnsRefundConfirmTitle(Object amount) {
    return 'Refund $amount?';
  }

  @override
  String get returnsRefundConfirmBody =>
      'This refunds the buyer to their original payment method. The action can\'t be undone.';

  @override
  String get returnsRefund => 'Refund';

  @override
  String get returnsRefundIssuedToast =>
      'Refund issued to original payment method';

  @override
  String returnsOrderSlice(Object orderId, Object sliceId) {
    return 'Order #$orderId · Slice #$sliceId';
  }

  @override
  String get returnsRefundPreview => 'Refund preview: ';

  @override
  String get returnsItems => 'Items';

  @override
  String get returnsReasonDamaged => 'Damaged on arrival';

  @override
  String get returnsReasonWrongItem => 'Wrong item sent';

  @override
  String get returnsReasonNotAsDescribed => 'Not as described';

  @override
  String get returnsReasonSizeFit => 'Size / fit issue';

  @override
  String get returnsReasonChangedMind => 'Buyer changed mind';

  @override
  String get returnsReasonDefective => 'Defective / not working';

  @override
  String get returnsReasonOther => 'Other';

  @override
  String get returnsTimeline => 'Timeline';

  @override
  String get returnsMarkPickedUp => 'Mark as picked up';

  @override
  String get returnsMarkReceived => 'Mark as received';

  @override
  String get adminActive => 'Active';

  @override
  String get adminCancel => 'Cancel';

  @override
  String get adminDelete => 'Delete';

  @override
  String get adminDeactivate => 'Deactivate';

  @override
  String get adminCreate => 'Create';

  @override
  String get adminSave => 'Save';

  @override
  String get adminSaving => 'Saving…';

  @override
  String get adminSaveChanges => 'Save changes';

  @override
  String get adminSaveFailed => 'Save failed';

  @override
  String get adminRefresh => 'Refresh';

  @override
  String get adminRetry => 'Retry';

  @override
  String get adminNotSet => 'Not set';

  @override
  String get adminPublished => 'Published';

  @override
  String get adminDraft => 'Draft';

  @override
  String get adminSortLabel => 'Sort';

  @override
  String get adminImageTooLarge =>
      'Image is larger than 5 MB. Pick a smaller image or crop tighter.';

  @override
  String get adminImageUploadFailed => 'Image upload failed';

  @override
  String get adminReplaceImage => 'Replace image';

  @override
  String get adminLinkTargetHelper =>
      'category:slug | product:id | url:https://…';

  @override
  String get adminBankOffersTitle => 'Bank offers';

  @override
  String get adminBankOfferNew => 'New offer';

  @override
  String get adminBankOffersEmpty =>
      'No bank offers yet. Tap \"New offer\" to curate the first one.';

  @override
  String get adminBankOfferDeactivateTitle => 'Deactivate offer?';

  @override
  String get adminBankOfferDeactivateBody =>
      'Customers won\'t see this offer on any PDP. You can re-activate it later from this page.';

  @override
  String adminBankOfferPercentOff(Object value) {
    return '$value% off';
  }

  @override
  String adminBankOfferAmountOff(Object value) {
    return '$value off';
  }

  @override
  String adminBankOfferMinOrder(Object value) {
    return 'min order $value';
  }

  @override
  String adminBankOfferCap(Object value) {
    return 'cap $value';
  }

  @override
  String adminBankOfferValidRange(Object from, Object until) {
    return 'Valid $from – $until';
  }

  @override
  String get adminBankOfferEditTitle => 'Edit bank offer';

  @override
  String get adminBankOfferNewTitle => 'New bank offer';

  @override
  String get adminBankOfferBankLabel => 'Bank';

  @override
  String get adminBankOfferCardTypeLabel => 'Card type';

  @override
  String get adminBankOfferTypeLabel => 'Type';

  @override
  String get adminBankOfferTypePercent => 'Percent off';

  @override
  String get adminBankOfferTypeFlat => 'Flat ₹ off';

  @override
  String get adminBankOfferPercentField => '% off';

  @override
  String get adminBankOfferAmountField => '₹ off';

  @override
  String get adminBankOfferMaxDiscountLabel =>
      'Max discount (₹) — caps the % off';

  @override
  String get adminBankOfferMinOrderLabel =>
      'Minimum order (₹) — eligibility filter';

  @override
  String get adminBankOfferTermsLabel => 'Terms (optional)';

  @override
  String get adminBankOfferTermsHint =>
      'e.g. Not valid on no-cost EMI. Excludes Apple products.';

  @override
  String adminBankOfferFrom(Object date) {
    return 'From  $date';
  }

  @override
  String adminBankOfferUntil(Object date) {
    return 'Until $date';
  }

  @override
  String get adminBankOfferActiveSubtitle =>
      'When off, the offer never decorates a PDP. Use this to park a draft or expire an offer early without deleting it.';

  @override
  String get adminBankOfferPdpPreview => 'PDP preview';

  @override
  String adminBankOfferPreviewCap(Object value) {
    return ' up to ₹$value';
  }

  @override
  String adminBankOfferPreviewPercent(
    Object discount,
    Object cap,
    Object target,
  ) {
    return '$discount% off$cap on $target';
  }

  @override
  String adminBankOfferPreviewFlat(Object discount, Object target) {
    return '₹$discount off on $target';
  }

  @override
  String get adminBankOfferCreate => 'Create offer';

  @override
  String get adminBannersTitle => 'Banner manager';

  @override
  String get adminBannerNew => 'New banner';

  @override
  String get adminBannerDeleteTitle => 'Delete banner?';

  @override
  String adminBannerDeleteBody(Object placement) {
    return 'This banner will be removed from $placement.';
  }

  @override
  String get adminBannerPlacementEmpty => 'No banners in this placement yet';

  @override
  String adminBannerSort(Object value) {
    return 'Sort $value';
  }

  @override
  String get adminBannerEditTitle => 'Edit banner';

  @override
  String get adminBannerNewTitle => 'New banner';

  @override
  String get adminBannerImageRequired => 'An image is required';

  @override
  String get adminBannerPlacementLabel => 'Placement';

  @override
  String get adminBannerLinkLabel => 'Link';

  @override
  String get adminBannerActiveSubtitle =>
      'When off, hidden regardless of schedule';

  @override
  String get adminBannerCreate => 'Create banner';

  @override
  String get adminBannerUploadImage => 'Upload image *';

  @override
  String get adminBannerStarts => 'Starts';

  @override
  String get adminBannerEnds => 'Ends';

  @override
  String get adminCategoryTaxonomyTitle => 'Category taxonomy';

  @override
  String get adminCategoryRoot => 'Root category';

  @override
  String adminCategoryDeleteTitle(Object name) {
    return 'Delete \"$name\"?';
  }

  @override
  String get adminCategoryDeleteBody =>
      'Children re-parent to root. Products in this category fall back to \"uncategorised\" (the link goes null).';

  @override
  String adminCategoryProductCount(Object value) {
    return '$value products';
  }

  @override
  String get adminCategoryAddChild => 'Add child';

  @override
  String get adminCategoryNameRequired => 'Name is required';

  @override
  String get adminCategoryEditTitle => 'Edit category';

  @override
  String get adminCategoryNewTitle => 'New category';

  @override
  String get adminCategoryNameLabel => 'Name *';

  @override
  String get adminCategoryNameHelper => 'Slug auto-derives from this.';

  @override
  String get adminCategoryDescriptionLabel => 'Description';

  @override
  String get adminCategoryImageUrlLabel => 'Image URL';

  @override
  String get adminCategoryImageUrlHelper => 'Customer-side circle puck image.';

  @override
  String get adminCategoryParentLabel => 'Parent';

  @override
  String get adminCategoryRootOption => '— Root —';

  @override
  String get adminCollectionsTitle => 'Collections';

  @override
  String get adminCollectionNew => 'New collection';

  @override
  String get adminCollectionsEmpty => 'No collections yet';

  @override
  String get adminCollectionDeleteTitle => 'Delete collection?';

  @override
  String adminCollectionDeleteBody(Object title) {
    return '\"$title\" and its item list will be removed.';
  }

  @override
  String adminCollectionItemCountOne(Object value) {
    return '$value item';
  }

  @override
  String adminCollectionItemCountOther(Object value) {
    return '$value items';
  }

  @override
  String get adminCollectionEditTitle => 'Edit collection';

  @override
  String get adminCollectionNewTitle => 'New collection';

  @override
  String get adminCollectionAddProduct => 'Add product';

  @override
  String get adminCollectionTitleRequired => 'Title is required';

  @override
  String get adminCollectionAlreadyAdded => 'Already in this collection';

  @override
  String get adminCollectionTitleLabel => 'Title *';

  @override
  String get adminCollectionSlugLabel => 'Slug';

  @override
  String get adminCollectionSlugHelper =>
      'Leave blank to auto-derive from title';

  @override
  String get adminCollectionEyebrowLabel => 'Eyebrow';

  @override
  String get adminCollectionEyebrowHelper => 'Tiny copy above title';

  @override
  String get adminCollectionSubtitleLabel => 'Subtitle';

  @override
  String get adminCollectionCtaTextLabel => 'CTA text';

  @override
  String get adminCollectionCtaTargetLabel => 'CTA target';

  @override
  String get adminCollectionBgColorLabel => 'BG color (#hex)';

  @override
  String get adminCollectionBgColorHelper =>
      'Optional — accent surface in rails';

  @override
  String get adminCollectionPublishedSubtitle =>
      'Visible to shoppers on the customer app';

  @override
  String get adminCollectionItemsSection => 'Items';

  @override
  String get adminCollectionItemsHintNew =>
      'Save the collection first, then add products from the + button.';

  @override
  String get adminCollectionItemsHintEmpty =>
      'Tap + in the app bar to add products.';

  @override
  String get adminCollectionCoverImage => 'Cover image';

  @override
  String get adminCollectionReplaceCover => 'Replace cover';

  @override
  String get adminCollectionProductSearchLabel => 'Search product name or SKU';

  @override
  String get adminCollectionProductSearchHint => 'Type 2+ characters to search';

  @override
  String get adminShopsTitle => 'Shop verification';

  @override
  String get adminShopsSearchHint => 'Search by shop name or slug';

  @override
  String get adminShopVerified => 'Verified';

  @override
  String get adminShopDraft => 'draft';

  @override
  String get adminShopsEmpty => 'No shops found.';

  @override
  String get analyticsTitle => 'Analytics';

  @override
  String get analyticsRefresh => 'Refresh';

  @override
  String get analyticsByProduct => 'By product';

  @override
  String get analyticsNoActiveProducts => 'No active products yet';

  @override
  String get analyticsKpiImpressions => 'Impressions';

  @override
  String get analyticsKpiTaps => 'Taps';

  @override
  String get analyticsKpiViews => 'Views';

  @override
  String get analyticsKpiAddToCart => 'Add to cart';

  @override
  String get analyticsKpiPurchases => 'Purchases';

  @override
  String get analyticsKpiWishlist => 'Wishlist';

  @override
  String get analyticsKpiCtr => 'CTR';

  @override
  String get analyticsKpiCvr => 'CVR';

  @override
  String get analyticsColProduct => 'Product';

  @override
  String get analyticsColImpressions => 'Imp';

  @override
  String get analyticsColTaps => 'Taps';

  @override
  String get analyticsColViews => 'Views';

  @override
  String get analyticsColAddToCart => 'ATC';

  @override
  String get analyticsColPurchases => 'Buys';

  @override
  String get analyticsColCtr => 'CTR';

  @override
  String get analyticsColCvr => 'CVR';

  @override
  String get customFieldsTitle => 'Custom Fields';

  @override
  String get customFieldsTemplates => 'Templates';

  @override
  String get customFieldsAddField => 'Add field';

  @override
  String get customFieldsAddSection => 'Add section';

  @override
  String get customFieldsEditField => 'Edit field';

  @override
  String get customFieldsEditSection => 'Edit section';

  @override
  String get customFieldsArchive => 'Archive';

  @override
  String customFieldsArchiveSectionTitle(Object name) {
    return 'Archive \"$name\"?';
  }

  @override
  String get customFieldsArchiveSectionMessage =>
      'Archiving hides the section. Its fields stay where they are and can be reassigned later.';

  @override
  String customFieldsArchiveFieldTitle(Object name) {
    return 'Archive \"$name\"?';
  }

  @override
  String get customFieldsArchiveFieldConfirm =>
      'Archive this field? Existing values stay on each product, but the field stops appearing on new ones.';

  @override
  String get customFieldsEmptyTitle => 'No custom fields yet';

  @override
  String get customFieldsEmptyHint =>
      'Define fields like Warranty, Model Number, Material — visible on every product.';

  @override
  String get customFieldsBrowseTemplates => 'Browse templates';

  @override
  String get customFieldsTemplatesCalloutTitle =>
      'Stamp a quick-start template';

  @override
  String get customFieldsTemplatesCalloutSubtitle =>
      'Electronics, Apparel, Logistics, Food, Warranty…';

  @override
  String customFieldsFieldCountOne(Object count) {
    return '$count field';
  }

  @override
  String customFieldsFieldCountOther(Object count) {
    return '$count fields';
  }

  @override
  String get customFieldsNoSection => 'No section';

  @override
  String customFieldsUngroupedCountOne(Object count) {
    return '$count ungrouped field';
  }

  @override
  String customFieldsUngroupedCountOther(Object count) {
    return '$count ungrouped fields';
  }

  @override
  String customFieldsUnitInline(Object unit) {
    return 'in $unit';
  }

  @override
  String customFieldsOptionCountOne(Object count) {
    return '$count option';
  }

  @override
  String customFieldsOptionCountOther(Object count) {
    return '$count options';
  }

  @override
  String get customFieldsSectionName => 'Section name';

  @override
  String get customFieldsFieldRequired => 'This field is required';

  @override
  String get customFieldsPickIcon => 'Pick an icon';

  @override
  String get customFieldsLoading => 'Loading...';

  @override
  String get customFieldsSave => 'Save';

  @override
  String get customFieldsDropdownMinOptions =>
      'Add at least two options for a dropdown.';

  @override
  String get customFieldsFieldName => 'Field name';

  @override
  String get customFieldsFieldType => 'Field type';

  @override
  String get customFieldsSectionOptional => 'Section (optional)';

  @override
  String get customFieldsUnitSuffix => 'Unit (optional)';

  @override
  String get customFieldsUnitSuffixHint => 'e.g. kg, days, GB';

  @override
  String get customFieldsOptions => 'Options';

  @override
  String get customFieldsOptionsHint =>
      'One per line. Used for dropdown choices.';

  @override
  String get customFieldsTemplateApplied => 'Template applied';

  @override
  String get customFieldsQuickStartTemplates => 'Quick-start templates';

  @override
  String get customFieldsTemplatesSheetSubtitle =>
      'Tap any template to add its section and fields to your shop.';

  @override
  String get customFieldsTemplatesUnavailable =>
      'Templates unavailable. Check your connection and try again.';

  @override
  String customFieldsTemplateFieldCount(Object count) {
    return '$count fields';
  }

  @override
  String get customFieldsPickDate => 'Pick a date';

  @override
  String get paymentsCounterpartyParty => 'party';

  @override
  String get paymentsCounterpartyVendor => 'vendor';

  @override
  String get paymentsRecordReceiptTitle => 'Record receipt';

  @override
  String get paymentsRecordPaymentTitle => 'Record payment';

  @override
  String paymentsFromCounterparty(Object name) {
    return 'From $name';
  }

  @override
  String paymentsToCounterparty(Object name) {
    return 'To $name';
  }

  @override
  String get paymentsAmountLabel => 'Amount';

  @override
  String get paymentsAmountPositiveError => 'Enter a positive amount';

  @override
  String get paymentsModeLabel => 'Mode';

  @override
  String get paymentsUpiTransactionIdLabel => 'UPI transaction id';

  @override
  String get paymentsChequeNumberLabel => 'Cheque number';

  @override
  String get paymentsReferenceLabel => 'Reference';

  @override
  String get paymentsDateLabel => 'Date';

  @override
  String get paymentsAllocatedToLabel => 'Allocated to';

  @override
  String get paymentsInvoiceLabel => 'Invoice';

  @override
  String get paymentsAllocateToInvoiceTitle => 'Allocate to an invoice';

  @override
  String get paymentsAllocateToInvoiceSubtitle => 'Off = on-account credit';

  @override
  String paymentsNoInvoicesFound(Object name) {
    return 'No invoices found for this $name.';
  }

  @override
  String get paymentsPickInvoiceError => 'Pick an invoice';

  @override
  String get paymentsNoteOptionalLabel => 'Note (optional)';

  @override
  String get paymentsSaveReceipt => 'Save receipt';

  @override
  String get paymentsSavePayment => 'Save payment';

  @override
  String reviewsTitle(Object name) {
    return 'Reviews · $name';
  }

  @override
  String get reviewsLoadMore => 'Load more';

  @override
  String get reviewsEmpty =>
      'No reviews yet — they\'ll show up here once buyers leave one.';

  @override
  String get reviewsNoneYet => 'No reviews yet';

  @override
  String get reviewsCountSingular => '1 review';

  @override
  String reviewsCountPlural(Object count) {
    return '$count reviews';
  }

  @override
  String get reviewsCustomerFallback => 'Customer';

  @override
  String get scanConsoleTitle => 'Scan to console';

  @override
  String get scanConsoleClear => 'Clear';

  @override
  String scanConsoleClearFailed(Object error) {
    return 'Could not clear: $error';
  }

  @override
  String get scanConsoleEmpty => 'Point the camera at a product barcode or QR.';

  @override
  String get scanConsoleConnected => 'Connection established';

  @override
  String scanConsoleWatching(Object count, Object sent) {
    return '$count consoles watching · $sent sent';
  }

  @override
  String get scanConsoleOpenWebHint =>
      'Open the Scan console on the web to see scans live';

  @override
  String get scanConsoleConnecting => 'Connecting…';

  @override
  String get scanConsoleReconnecting => 'Reconnecting…';

  @override
  String get scanConsoleNotConnected => 'Not connected';

  @override
  String get stockLedgerTitle => 'Stock Ledger';

  @override
  String get stockLedgerEmptySubtitle =>
      'No movements recorded for this product yet.';

  @override
  String get stockLedgerReversalBadge => 'Reversal';

  @override
  String stockLedgerByName(Object name) {
    return 'by $name';
  }

  @override
  String stockLedgerBalance(Object qty) {
    return 'Bal: $qty';
  }

  @override
  String get stockLedgerViewSource => 'View source';

  @override
  String get stockSheetDraftCreated =>
      'Draft invoice created — confirm it from the Invoices tab to post stock.';

  @override
  String stockSheetCurrentStock(Object qty, Object unit) {
    return 'Current stock: $qty $unit';
  }

  @override
  String get stockSheetPurchase => 'Purchase';

  @override
  String get stockSheetSale => 'Sale';

  @override
  String get stockSheetQuantity => 'Quantity';

  @override
  String get stockSheetFieldRequired => 'This field is required';

  @override
  String get stockSheetInvalidNumber => 'Enter a valid number';

  @override
  String get stockSheetUnitPrice => 'Unit price';

  @override
  String get stockSheetCustomer => 'Customer';

  @override
  String get stockSheetSearchParties =>
      'Search parties — defaults to Walk-in Customer';

  @override
  String get stockSheetClear => 'Clear';

  @override
  String get stockSheetSupplier => 'Supplier';

  @override
  String get stockSheetSupplierHint => 'Track supplier-wise price history';

  @override
  String get stockSheetSupplierAutocompleteHint =>
      'Start typing to see previous suppliers';

  @override
  String get stockSheetNote => 'Note';

  @override
  String get stockSheetConfirm => 'Confirm';

  @override
  String get stockAdjTitle => 'Stock adjustments';

  @override
  String get stockAdjEmptyTitle => 'No adjustments yet';

  @override
  String get stockAdjEmptySubtitle =>
      'Tap + to record damage, expired stock, or a count correction.';

  @override
  String get stockAdjItemSingular => 'item';

  @override
  String get stockAdjItemPlural => 'items';

  @override
  String get stockAdjNewTitle => 'New stock adjustment';

  @override
  String get stockAdjSubmit => 'Submit';

  @override
  String get stockAdjAddAtLeastOne => 'Add at least one item to adjust.';

  @override
  String get stockAdjDiscardTitle => 'Discard changes?';

  @override
  String get stockAdjDiscardMessage => 'Your edits will be lost.';

  @override
  String get stockAdjKeepEditing => 'Keep editing';

  @override
  String get stockAdjDiscard => 'Discard';

  @override
  String get stockAdjReasonSection => 'REASON';

  @override
  String get stockAdjProductsSection => 'PRODUCTS';

  @override
  String get stockAdjReasonDamage => 'Damaged';

  @override
  String get stockAdjReasonExpired => 'Expired';

  @override
  String get stockAdjReasonShrinkage => 'Shrinkage';

  @override
  String get stockAdjReasonRecount => 'Recount correction';

  @override
  String get stockAdjReasonOpening => 'Opening balance';

  @override
  String get stockAdjAddStock => 'Add stock';

  @override
  String get stockAdjRemoveStock => 'Remove stock';

  @override
  String get stockAdjNote => 'Note';

  @override
  String get stockAdjSearchProducts => 'Search products';

  @override
  String get stockAdjNoProductsAdded => 'No products added yet.';

  @override
  String get stockAdjPostAdjustment => 'Post adjustment';

  @override
  String get sharedContactChangesRecentChanges => 'Recent changes';

  @override
  String get sharedContactChangesChangedSuffix => 'changed';

  @override
  String get sharedContactChangesFieldName => 'Name';

  @override
  String get sharedContactChangesFieldContactPerson => 'Contact person';

  @override
  String get sharedContactChangesFieldPhone => 'Phone';

  @override
  String get sharedContactChangesFieldEmail => 'Email';

  @override
  String get sharedContactChangesFieldAddress => 'Address';

  @override
  String get sharedContactChangesFieldCity => 'City';

  @override
  String get sharedContactChangesFieldState => 'State';

  @override
  String get sharedContactChangesFieldStateCode => 'State code';

  @override
  String get sharedContactChangesFieldPinCode => 'PIN code';

  @override
  String get sharedContactChangesFieldActive => 'Active';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navProducts => 'Products';

  @override
  String get navOrders => 'Orders';

  @override
  String get navProfile => 'Profile';

  @override
  String get navCategories => 'Categories';

  @override
  String get navVendors => 'Vendors';

  @override
  String get navParties => 'Parties';

  @override
  String get navInvoices => 'Invoices';

  @override
  String get navQuotations => 'Quotations';

  @override
  String get navChallans => 'Challans';

  @override
  String get navMyShop => 'My Shop';

  @override
  String get navTeamRoles => 'Team & roles';

  @override
  String get navBanners => 'Banners';

  @override
  String get navCoupons => 'Coupons';

  @override
  String get navPointOfSale => 'Point of sale';

  @override
  String get navCashier => 'Cashier';

  @override
  String get navScanToConsole => 'Scan to console';

  @override
  String get navStockAdjustments => 'Stock adjustments';

  @override
  String get navReturns => 'Returns';

  @override
  String get navReports => 'Reports';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navBannerManager => 'Banner manager';

  @override
  String get navCategoryTaxonomy => 'Category taxonomy';

  @override
  String get navCollections => 'Collections';

  @override
  String get navBankOffers => 'Bank offers';

  @override
  String get navShopVerification => 'Shop verification';

  @override
  String get navSectionManage => 'Manage';

  @override
  String get navSectionOperations => 'Operations';

  @override
  String get navSectionPlatformAdmin => 'Platform admin';

  @override
  String get navMenu => 'Menu';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get reportsRefresh => 'Refresh';

  @override
  String get reportsRetry => 'Retry';

  @override
  String get reportsPresetThisMonth => 'This month';

  @override
  String get reportsPresetLast30Days => 'Last 30 days';

  @override
  String get reportsPresetThisFy => 'This FY';

  @override
  String get reportsTabSales => 'Sales';

  @override
  String get reportsTabPurchases => 'Purchases';

  @override
  String get reportsTabGst => 'GST';

  @override
  String get reportsTabPnl => 'P&L';

  @override
  String get reportsTabCalculator => 'Calculator';

  @override
  String get reportsNoActivityInRange => 'No activity in this range.';

  @override
  String reportsPace(Object perDay, Object projected) {
    return '≈ $perDay/day at this pace · ~$projected over 30 days';
  }

  @override
  String get reportsTotalSales => 'TOTAL SALES';

  @override
  String reportsSalesHelper(Object count, Object tax, Object net) {
    return '$count confirmed invoices · $tax GST · net $net after refunds';
  }

  @override
  String get reportsTopProducts => 'TOP PRODUCTS';

  @override
  String get reportsNoSalesInRange => 'No sales in this range.';

  @override
  String reportsSoldCount(Object count) {
    return '$count sold';
  }

  @override
  String get reportsTopCustomers => 'TOP CUSTOMERS';

  @override
  String get reportsNoCustomersInRange => 'No customers in this range.';

  @override
  String reportsInvoiceCountOne(Object count) {
    return '$count invoice';
  }

  @override
  String reportsInvoiceCountOther(Object count) {
    return '$count invoices';
  }

  @override
  String get reportsTotalPurchases => 'TOTAL PURCHASES';

  @override
  String reportsPurchasesHelper(Object count, Object tax) {
    return '$count confirmed bills · $tax GST';
  }

  @override
  String get reportsTopPurchasedProducts => 'TOP PURCHASED PRODUCTS';

  @override
  String get reportsNoPurchasesInRange => 'No purchases in this range.';

  @override
  String reportsBoughtCount(Object count) {
    return '$count bought';
  }

  @override
  String get reportsTopVendors => 'TOP VENDORS';

  @override
  String get reportsNoVendorsInRange => 'No vendors in this range.';

  @override
  String reportsBillCountOne(Object count) {
    return '$count bill';
  }

  @override
  String reportsBillCountOther(Object count) {
    return '$count bills';
  }

  @override
  String get reportsOutputGst => 'OUTPUT GST';

  @override
  String get reportsCollectedOnSales => 'Collected on sales';

  @override
  String get reportsInputGstItc => 'INPUT GST (ITC)';

  @override
  String get reportsPaidOnPurchases => 'Paid on purchases';

  @override
  String get reportsNetGstPayable => 'NET GST PAYABLE';

  @override
  String get reportsGstOwedNote => 'You owe this to the tax authority';

  @override
  String get reportsGstCreditCarriedNote => 'Input credit carried forward';

  @override
  String get reportsNetPayableByTaxHead => 'NET PAYABLE BY TAX HEAD';

  @override
  String get reportsTaxHeadNote =>
      'CGST + SGST apply to in-state sales; IGST to inter-state. Net is each head’s output tax minus its own input credit.';

  @override
  String get reportsOutputGstByRate => 'OUTPUT GST BY RATE';

  @override
  String get reportsNoOutputGstInRange => 'No output GST in this range.';

  @override
  String get reportsInputGstByRate => 'INPUT GST BY RATE';

  @override
  String get reportsNoInputGstInRange => 'No input GST in this range.';

  @override
  String get reportsCess => 'CESS';

  @override
  String get reportsOutputCess => 'Output cess';

  @override
  String get reportsInputCess => 'Input cess';

  @override
  String get reportsNetCessPayable => 'Net cess payable';

  @override
  String get reportsCessNote =>
      'Cess is set off only against cess, never against GST.';

  @override
  String reportsOutputGstReturnsNote(Object amount) {
    return 'Output GST is shown net of $amount reversed on refunded returns in this period.';
  }

  @override
  String get reportsColHead => 'HEAD';

  @override
  String get reportsColOutput => 'OUTPUT';

  @override
  String get reportsColItc => 'ITC';

  @override
  String get reportsColNet => 'NET';

  @override
  String get reportsColTotal => 'TOTAL';

  @override
  String get reportsColRate => 'RATE';

  @override
  String get reportsColTaxable => 'TAXABLE';

  @override
  String get reportsHeadInterState => 'Inter-state';

  @override
  String get reportsHeadCentral => 'Central';

  @override
  String get reportsHeadState => 'State';

  @override
  String get reportsNetProfit => 'NET PROFIT';

  @override
  String reportsGrossMargin(Object pct) {
    return 'Gross margin $pct%';
  }

  @override
  String get reportsRevenue => 'Revenue';

  @override
  String get reportsCostOfGoodsSold => 'Cost of goods sold';

  @override
  String get reportsGrossProfit => 'Gross profit';

  @override
  String get reportsAdjustmentWriteoffs => 'Adjustment write-offs';

  @override
  String get reportsNetProfitRow => 'Net profit';

  @override
  String get reportsHowThisIsCalculated => 'HOW THIS IS CALCULATED';

  @override
  String get reportsConfirmedSales => 'Confirmed sales';

  @override
  String get reportsConfirmedSalesBasis =>
      'Taxable value (ex-GST) of confirmed sale invoices, less credit notes';

  @override
  String get reportsLessSalesReturns => 'Less: sales returns';

  @override
  String get reportsLessSalesReturnsBasis =>
      'Ex-GST value of refunded returns, pro-rated by returned quantity';

  @override
  String get reportsRevenueA => 'Revenue (A)';

  @override
  String get reportsGoodsSoldAtCost => 'Goods sold, at cost';

  @override
  String get reportsGoodsSoldAtCostBasis =>
      'Stock cost layers consumed when each sale was confirmed';

  @override
  String get reportsLessReturnedGoodsRestocked =>
      'Less: returned goods restocked';

  @override
  String get reportsLessReturnedGoodsRestockedBasis =>
      'Returned items put back into inventory at their consumed cost';

  @override
  String get reportsCostOfGoodsSoldB => 'Cost of goods sold (B)';

  @override
  String get reportsGrossProfitAB => 'Gross profit (A − B)';

  @override
  String get reportsLessStockWriteoffs => 'Less: stock write-offs';

  @override
  String get reportsLessStockWriteoffsBasis =>
      'Damage, expiry and shrinkage stock adjustments dated in this range';

  @override
  String get reportsNetProfitFormula => 'Net profit (A − B − write-offs)';

  @override
  String reportsPnlNote(Object pct) {
    return 'Gross margin $pct% = gross profit ÷ revenue. Every figure is summed from confirmed invoices, refunded returns and stock adjustments dated in this range; estimates and proformas are excluded.';
  }

  @override
  String get reportsProductsSold => 'PRODUCTS SOLD';

  @override
  String reportsCountOfTotal(Object count, Object total) {
    return '$count of $total';
  }

  @override
  String get reportsSearchByProductOrSku => 'Search by product or SKU…';

  @override
  String reportsNoSoldProductsMatch(Object query) {
    return 'No sold products match “$query”.';
  }

  @override
  String get reportsNoProductsSoldInRange => 'No products sold in this range.';

  @override
  String reportsSaleCountOne(Object count) {
    return '$count sale';
  }

  @override
  String reportsSaleCountOther(Object count) {
    return '$count sales';
  }

  @override
  String get reportsLoading => 'Loading…';

  @override
  String reportsLoadMore(Object count) {
    return 'Load more ($count left)';
  }

  @override
  String reportsAllProductsShownOne(Object count) {
    return 'All $count product shown.';
  }

  @override
  String reportsAllProductsShownOther(Object count) {
    return 'All $count products shown.';
  }

  @override
  String get reportsProductFallback => 'Product';

  @override
  String get reportsNoSalesForProduct => 'No sales found for this product.';

  @override
  String get reportsCalcTitle => 'Pricing & profit calculator';

  @override
  String get reportsCalcIntro =>
      'Add products below, then set quantity, GST and discount per line — totals, GST, profit and margin update live.';

  @override
  String get reportsCalcNoProductsYet =>
      'No products yet — add some from the list below.';

  @override
  String get reportsCalcSupply => 'Supply';

  @override
  String get reportsCalcWithinState => 'Within state';

  @override
  String get reportsCalcInterState => 'Inter-state';

  @override
  String get reportsCalcDiscountIn => 'Discount in';

  @override
  String get reportsCalcOverallDiscount => 'Overall discount';

  @override
  String get reportsCalcGrandTotalInclGst => 'GRAND TOTAL · INCL. GST';

  @override
  String reportsCalcProductCountOne(Object count) {
    return '$count product';
  }

  @override
  String reportsCalcProductCountOther(Object count) {
    return '$count products';
  }

  @override
  String reportsCalcQtySummary(Object qty) {
    return ' · $qty qty';
  }

  @override
  String reportsCalcDiscOff(Object amount) {
    return ' · $amount off';
  }

  @override
  String get reportsCalcProfit => 'Profit';

  @override
  String get reportsCalcMargin => 'Margin';

  @override
  String get reportsCalcBlockTotal => 'TOTAL';

  @override
  String get reportsCalcGrossSubtotal => 'Gross subtotal';

  @override
  String get reportsCalcHintInclGst => 'incl. GST';

  @override
  String get reportsCalcLineDiscounts => 'Line discounts';

  @override
  String get reportsCalcGrandTotalRow => 'Grand total (incl. GST)';

  @override
  String get reportsCalcBlockGstInterState => 'GST · INTER-STATE';

  @override
  String get reportsCalcBlockGstWithinState => 'GST · WITHIN STATE';

  @override
  String get reportsCalcSubtotal => 'Subtotal';

  @override
  String get reportsCalcHintTaxableExGst => 'taxable, ex-GST';

  @override
  String get reportsCalcGstTotal => 'GST total';

  @override
  String get reportsCalcBlockProfit => 'PROFIT';

  @override
  String get reportsCalcCostOfGoods => 'Cost of goods';

  @override
  String get reportsCalcRevenue => 'Revenue';

  @override
  String get reportsCalcMarkup => 'Markup';

  @override
  String get reportsCalcHintReturnOnCost => 'return on cost';

  @override
  String get reportsCalcProfitMargin => 'Profit margin';

  @override
  String get reportsCalcQuotation => 'QUOTATION';

  @override
  String get reportsCalcStatusRequested => 'Requested';

  @override
  String get reportsCalcStatusSent => 'Sent';

  @override
  String get reportsCalcStatusAccepted => 'Accepted';

  @override
  String get reportsCalcStatusDeclined => 'Declined';

  @override
  String get reportsCalcStatusCancelled => 'Cancelled';

  @override
  String get reportsCalcStatusExpired => 'Expired';

  @override
  String get reportsCalcLoadQuotation => 'Load a quotation';

  @override
  String get reportsCalcChooseCustomer => 'Choose customer';

  @override
  String get reportsCalcDownload => 'Download';

  @override
  String get reportsCalcSending => 'Sending…';

  @override
  String get reportsCalcPriceAndSend => 'Price & send';

  @override
  String get reportsCalcSendQuotation => 'Send quotation';

  @override
  String get reportsCalcNew => 'New';

  @override
  String get reportsCalcNoteLabel => 'Note (optional)';

  @override
  String get reportsCalcNoteHint => 'Shown on the quotation…';

  @override
  String get reportsCalcQuoteNote =>
      'Download and Send both save the quotation (the PDF is generated from a saved quote). A customer-requested quote is priced & sent back; otherwise a new one goes to the chosen customer. Totals are GST-inclusive — the quote matches the grand total above.';

  @override
  String get reportsCalcYourProducts => 'YOUR PRODUCTS';

  @override
  String reportsCalcAddedCount(Object count) {
    return '$count added';
  }

  @override
  String get reportsCalcSearchByNameOrSku => 'Search by name or SKU…';

  @override
  String get reportsCalcLoadingProducts => 'Loading your products…';

  @override
  String get reportsCalcNoProductsFound => 'No products found.';

  @override
  String get reportsCalcEach => 'each';

  @override
  String reportsCalcRemoveProduct(Object name) {
    return 'Remove $name';
  }

  @override
  String get reportsCalcQty => 'Qty';

  @override
  String get reportsCalcDisc => 'Disc';

  @override
  String get reportsCalcSearchByNumberOrCustomer =>
      'Search by number or customer…';

  @override
  String get reportsCalcNoQuotationsYet => 'No quotations yet.';

  @override
  String get reportsCalcAddOneProduct =>
      'Add at least one product with a price and quantity.';

  @override
  String get reportsCalcChooseCustomerFirst => 'Choose a customer first.';

  @override
  String reportsCalcQuoteSent(Object number, Object name) {
    return 'Quotation $number sent to $name.';
  }

  @override
  String get navHome => 'Home';

  @override
  String get menuDescMyShop => 'Storefront, hours and policies';

  @override
  String get menuDescTeam => 'Staff and their permissions';

  @override
  String get menuDescCategories => 'Product categories and grouping';

  @override
  String get menuDescVendors => 'Suppliers you buy from';

  @override
  String get menuDescParties => 'Customers you sell to';

  @override
  String get menuDescBanners => 'Storefront home banners';

  @override
  String get menuDescCoupons => 'Discount codes and offers';

  @override
  String get menuDescPos => 'Fast in-store billing';

  @override
  String get menuDescCashier => 'Quick checkout register';

  @override
  String get menuDescScan => 'Scan items into a session';

  @override
  String get menuDescQuotations => 'Price quotes for customers';

  @override
  String get menuDescChallans => 'Delivery notes without prices';

  @override
  String get menuDescStockAdj => 'Damage, expiry and corrections';

  @override
  String get menuDescReturns => 'Customer returns and refunds';

  @override
  String get menuDescReports => 'Sales, purchases, GST and P&L';

  @override
  String get menuDescAnalytics => 'Traffic and performance';

  @override
  String get menuDescBannerManager => 'Marketplace home banners';

  @override
  String get menuDescCategoryTaxonomy => 'Global category tree';

  @override
  String get menuDescCollections => 'Curated product collections';

  @override
  String get menuDescBankOffers => 'Card and bank discounts';

  @override
  String get menuDescShopVerification => 'Review and verify shops';

  @override
  String get menuDescProfile => 'Your account and shop';

  @override
  String get menuDescSettings => 'Currency, theme and language';

  @override
  String get profileDevicesSessions => 'Devices & sessions';

  @override
  String get profileDevicesSessionsSubtitle =>
      'See where you\'re signed in and sign out devices';

  @override
  String get sessionsThisDevice => 'This device';

  @override
  String get sessionsSignOut => 'Sign out';

  @override
  String get sessionsSignOutOthers => 'Sign out all other devices';

  @override
  String get sessionsSignedOut => 'Signed out.';

  @override
  String sessionsLastActive(String time) {
    return 'Last active $time';
  }

  @override
  String sessionsSignedInOn(String time) {
    return 'Signed in $time';
  }

  @override
  String get sessionsEmpty => 'No active sessions.';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int n) {
    return '${n}m ago';
  }

  @override
  String timeHoursAgo(int n) {
    return '${n}h ago';
  }

  @override
  String timeDaysAgo(int n) {
    return '${n}d ago';
  }
}
