// Single source of truth for icons in this app (Hugeicons stroke-rounded).
//
// Every icon the app uses is named here exactly once. UI code renders
// `AppIcon(AppIcons.<name>)` (see app_icon.dart) and references the glyph
// only through `AppIcons.<name>`, so changing or retiring an icon is a
// one-line edit here.
//
// NOTE: the WhatsApp mark is intentionally NOT here — it comes from
// font_awesome as an FaIconData and renders via the FaIcon widget at its
// single call site (invoice_detail_page.dart).

import 'package:hugeicons/hugeicons.dart';

/// SVG glyph payload used across the app (a Hugeicons icon, `List<List>`).
typedef AppIconData = List<List<dynamic>>;

/// Central icon registry. See file header.
abstract final class AppIcons {
  static const AppIconData accountBalanceOutlined = HugeIcons.strokeRoundedBank;
  static const AppIconData accountBalanceRounded = HugeIcons.strokeRoundedBank;
  static const AppIconData accountBalanceWalletOutlined =
      HugeIcons.strokeRoundedWallet01;
  static const AppIconData accountBalanceWalletRounded =
      HugeIcons.strokeRoundedWallet01;
  static const AppIconData accountCircleOutlined =
      HugeIcons.strokeRoundedUserCircle;
  static const AppIconData accountTreeOutlined =
      HugeIcons.strokeRoundedHierarchy;
  static const AppIconData add = HugeIcons.strokeRoundedAdd01;
  static const AppIconData addAPhotoOutlined =
      HugeIcons.strokeRoundedImageAdd01;
  static const AppIconData addBoxOutlined = HugeIcons.strokeRoundedAddSquare;
  static const AppIconData addCircleOutline = HugeIcons.strokeRoundedAddCircle;
  static const AppIconData addCircleOutlineRounded =
      HugeIcons.strokeRoundedAddCircle;
  static const AppIconData addPhotoAlternateOutlined =
      HugeIcons.strokeRoundedImageAdd01;
  static const AppIconData addRounded = HugeIcons.strokeRoundedAdd01;
  static const AppIconData alternateEmail = HugeIcons.strokeRoundedAt;
  static const AppIconData alternateEmailRounded = HugeIcons.strokeRoundedAt;
  static const AppIconData apps = HugeIcons.strokeRoundedDashboardSquare01;
  static const AppIconData appsOutlined =
      HugeIcons.strokeRoundedDashboardSquare01;
  static const AppIconData archiveOutlined = HugeIcons.strokeRoundedArchive;
  static const AppIconData arrowBackIosNewRounded =
      HugeIcons.strokeRoundedArrowLeft01;
  static const AppIconData arrowBackRounded =
      HugeIcons.strokeRoundedArrowLeft01;
  static const AppIconData arrowDownwardRounded =
      HugeIcons.strokeRoundedArrowDown01;
  static const AppIconData arrowForwardIosRounded =
      HugeIcons.strokeRoundedArrowRight01;
  static const AppIconData arrowForwardRounded =
      HugeIcons.strokeRoundedArrowRight01;
  static const AppIconData arrowUpwardRounded =
      HugeIcons.strokeRoundedArrowUp01;
  static const AppIconData articleOutlined = HugeIcons.strokeRoundedNews;
  static const AppIconData assignmentOutlined =
      HugeIcons.strokeRoundedAssignments;
  static const AppIconData assignmentReturnOutlined =
      HugeIcons.strokeRoundedReturnRequest;
  static const AppIconData autoAwesomeRounded = HugeIcons.strokeRoundedSparkles;
  static const AppIconData badgeOutlined = HugeIcons.strokeRoundedIdentityCard;
  static const AppIconData badgeRounded = HugeIcons.strokeRoundedIdentityCard;
  static const AppIconData bakeryDiningRounded =
      HugeIcons.strokeRoundedCroissant;
  static const AppIconData barChartOutlined = HugeIcons.strokeRoundedBarChart;
  static const AppIconData batteryFullRounded =
      HugeIcons.strokeRoundedBatteryFull;
  static const AppIconData block = HugeIcons.strokeRoundedBlocked;
  static const AppIconData blockRounded = HugeIcons.strokeRoundedBlocked;
  static const AppIconData boltOutlined = HugeIcons.strokeRoundedFlash;
  static const AppIconData boltRounded = HugeIcons.strokeRoundedFlash;
  static const AppIconData brokenImageOutlined =
      HugeIcons.strokeRoundedImageNotFound01;
  static const AppIconData brokenImageRounded =
      HugeIcons.strokeRoundedImageNotFound01;
  static const AppIconData buildOutlined = HugeIcons.strokeRoundedWrench01;
  static const AppIconData buildRounded = HugeIcons.strokeRoundedWrench01;
  static const AppIconData businessRounded = HugeIcons.strokeRoundedBuilding02;
  static const AppIconData calculateOutlined =
      HugeIcons.strokeRoundedCalculator;
  static const AppIconData calendarTodayOutlined =
      HugeIcons.strokeRoundedCalendar01;
  static const AppIconData calendarTodayRounded =
      HugeIcons.strokeRoundedCalendar01;
  static const AppIconData callOutlined = HugeIcons.strokeRoundedCall;
  static const AppIconData callRounded = HugeIcons.strokeRoundedCall;
  static const AppIconData cameraAltOutlined = HugeIcons.strokeRoundedCamera01;
  static const AppIconData cameraAltRounded = HugeIcons.strokeRoundedCamera01;
  static const AppIconData cancelOutlined = HugeIcons.strokeRoundedCancelCircle;
  static const AppIconData cancelScheduleSendOutlined =
      HugeIcons.strokeRoundedSent;
  static const AppIconData cardGiftcardRounded =
      HugeIcons.strokeRoundedGiftCard;
  static const AppIconData categoryOutlined =
      HugeIcons.strokeRoundedDashboardSquare01;
  static const AppIconData categoryRounded =
      HugeIcons.strokeRoundedDashboardSquare01;
  static const AppIconData chairRounded = HugeIcons.strokeRoundedChair01;
  static const AppIconData chatBubbleOutline =
      HugeIcons.strokeRoundedBubbleChat;
  static const AppIconData chatRounded = HugeIcons.strokeRoundedChat;
  static const AppIconData check = HugeIcons.strokeRoundedTick02;
  static const AppIconData checkCircleOutline =
      HugeIcons.strokeRoundedCheckmarkCircle01;
  static const AppIconData checkCircleOutlineRounded =
      HugeIcons.strokeRoundedCheckmarkCircle01;
  static const AppIconData checkCircleRounded =
      HugeIcons.strokeRoundedCheckmarkCircle01;
  static const AppIconData checkRounded = HugeIcons.strokeRoundedTick02;
  static const AppIconData checkroomRounded = HugeIcons.strokeRoundedWardrobe01;
  static const AppIconData chevronRightRounded =
      HugeIcons.strokeRoundedArrowRight01;
  static const AppIconData circle = HugeIcons.strokeRoundedCircle;
  static const AppIconData circleOutlined = HugeIcons.strokeRoundedCircle;
  static const AppIconData cleaningServicesRounded =
      HugeIcons.strokeRoundedCleaningBucket;
  static const AppIconData close = HugeIcons.strokeRoundedCancel01;
  static const AppIconData closeRounded = HugeIcons.strokeRoundedCancel01;
  static const AppIconData cloudOffRounded = HugeIcons.strokeRoundedCloudOff;
  static const AppIconData collectionsBookmark = HugeIcons.strokeRoundedAlbum02;
  static const AppIconData collectionsBookmarkOutlined =
      HugeIcons.strokeRoundedAlbum02;
  static const AppIconData collectionsRounded = HugeIcons.strokeRoundedAlbum02;
  static const AppIconData compareArrowsRounded =
      HugeIcons.strokeRoundedExchange01;
  static const AppIconData computerRounded = HugeIcons.strokeRoundedComputer;
  static const AppIconData contactsOutlined =
      HugeIcons.strokeRoundedContactBook;
  static const AppIconData copyRounded = HugeIcons.strokeRoundedCopy01;
  static const AppIconData creditCardOutlined =
      HugeIcons.strokeRoundedCreditCard;
  static const AppIconData currencyRupeeRounded = HugeIcons.strokeRoundedRupee;
  static const AppIconData dashboardCustomizeOutlined =
      HugeIcons.strokeRoundedDashboardSquare02;
  static const AppIconData deleteForeverRounded =
      HugeIcons.strokeRoundedDelete02;
  static const AppIconData deleteOutline = HugeIcons.strokeRoundedDelete02;
  static const AppIconData deleteOutlineRounded =
      HugeIcons.strokeRoundedDelete02;
  static const AppIconData deleteSweepOutlined =
      HugeIcons.strokeRoundedDelete03;
  static const AppIconData densityMediumRounded = HugeIcons.strokeRoundedMenu01;
  static const AppIconData densitySmallRounded = HugeIcons.strokeRoundedMenu02;
  static const AppIconData descriptionOutlined = HugeIcons.strokeRoundedFile02;
  static const AppIconData descriptionRounded = HugeIcons.strokeRoundedFile02;
  static const AppIconData devicesOtherRounded =
      HugeIcons.strokeRoundedComputer;
  static const AppIconData devicesRounded = HugeIcons.strokeRoundedComputer;
  static const AppIconData diamondRounded = HugeIcons.strokeRoundedDiamond;
  static const AppIconData differenceRounded =
      HugeIcons.strokeRoundedExchange01;
  static const AppIconData directionsCarFilledRounded =
      HugeIcons.strokeRoundedCar01;
  static const AppIconData directionsWalkRounded =
      HugeIcons.strokeRoundedWalking;
  static const AppIconData documentScannerOutlined =
      HugeIcons.strokeRoundedScan;
  static const AppIconData doneAllRounded = HugeIcons.strokeRoundedTickDouble01;
  static const AppIconData downloadRounded = HugeIcons.strokeRoundedDownload01;
  static const AppIconData dragHandle = HugeIcons.strokeRoundedDragDrop;
  static const AppIconData ecoRounded = HugeIcons.strokeRoundedLeaf01;
  static const AppIconData editNoteRounded = HugeIcons.strokeRoundedNoteEdit;
  static const AppIconData editOutlined = HugeIcons.strokeRoundedPencilEdit01;
  static const AppIconData editRounded = HugeIcons.strokeRoundedPencilEdit01;
  static const AppIconData emailOutlined = HugeIcons.strokeRoundedMail01;
  static const AppIconData emailRounded = HugeIcons.strokeRoundedMail01;
  static const AppIconData errorOutline = HugeIcons.strokeRoundedAlertCircle;
  static const AppIconData errorOutlineRounded =
      HugeIcons.strokeRoundedAlertCircle;
  static const AppIconData event = HugeIcons.strokeRoundedCalendar01;
  static const AppIconData eventAvailable =
      HugeIcons.strokeRoundedCalendarCheckIn01;
  static const AppIconData eventBusyOutlined =
      HugeIcons.strokeRoundedCalendarRemove01;
  static const AppIconData eventBusyRounded =
      HugeIcons.strokeRoundedCalendarRemove01;
  static const AppIconData eventRounded = HugeIcons.strokeRoundedCalendar01;
  static const AppIconData expandMoreRounded =
      HugeIcons.strokeRoundedArrowDown01;
  static const AppIconData factCheckOutlined = HugeIcons.strokeRoundedCheckList;
  static const AppIconData factCheckRounded = HugeIcons.strokeRoundedCheckList;
  static const AppIconData factoryRounded = HugeIcons.strokeRoundedFactory;
  static const AppIconData featuredPlayListRounded =
      HugeIcons.strokeRoundedPlayList;
  static const AppIconData flashOnRounded = HugeIcons.strokeRoundedFlash;
  static const AppIconData folderOutlined = HugeIcons.strokeRoundedFolder01;
  static const AppIconData formatLineSpacingRounded =
      HugeIcons.strokeRoundedTextIndent;
  static const AppIconData formatPaintRounded =
      HugeIcons.strokeRoundedPaintBrush01;
  static const AppIconData formatQuoteRounded = HugeIcons.strokeRoundedQuoteUp;
  static const AppIconData gridViewRounded = HugeIcons.strokeRoundedGridView;
  static const AppIconData groupOutlined = HugeIcons.strokeRoundedUserGroup;
  static const AppIconData groups2Outlined =
      HugeIcons.strokeRoundedUserMultiple;
  static const AppIconData groupsOutlined = HugeIcons.strokeRoundedUserGroup;
  static const AppIconData groupsRounded = HugeIcons.strokeRoundedUserGroup;
  static const AppIconData handymanRounded = HugeIcons.strokeRoundedTools;
  static const AppIconData helpOutlineRounded =
      HugeIcons.strokeRoundedHelpCircle;
  static const AppIconData historyRounded = HugeIcons.strokeRoundedClock01;
  static const AppIconData homeOutlined = HugeIcons.strokeRoundedHome01;
  static const AppIconData homeRounded = HugeIcons.strokeRoundedHome01;
  static const AppIconData hourglassTopRounded =
      HugeIcons.strokeRoundedHourglass;
  static const AppIconData icecreamRounded = HugeIcons.strokeRoundedIceCream01;
  static const AppIconData imageNotSupportedOutlined =
      HugeIcons.strokeRoundedImageNotFound01;
  static const AppIconData imageOutlined = HugeIcons.strokeRoundedImage01;
  static const AppIconData imageRounded = HugeIcons.strokeRoundedImage01;
  static const AppIconData inboxOutlined = HugeIcons.strokeRoundedInbox;
  static const AppIconData inboxRounded = HugeIcons.strokeRoundedInbox;
  static const AppIconData infoOutline =
      HugeIcons.strokeRoundedInformationCircle;
  static const AppIconData infoOutlineRounded =
      HugeIcons.strokeRoundedInformationCircle;
  static const AppIconData infoRounded =
      HugeIcons.strokeRoundedInformationCircle;
  static const AppIconData inventory2Outlined = HugeIcons.strokeRoundedPackage;
  static const AppIconData inventory2Rounded = HugeIcons.strokeRoundedPackage;
  static const AppIconData inventoryOutlined = HugeIcons.strokeRoundedPackage;
  static const AppIconData inventoryRounded = HugeIcons.strokeRoundedPackage;
  static const AppIconData iosShareRounded = HugeIcons.strokeRoundedShare01;
  static const AppIconData kebabDiningRounded = HugeIcons.strokeRoundedBbqGrill;
  static const AppIconData keyboardArrowDownRounded =
      HugeIcons.strokeRoundedArrowDown01;
  static const AppIconData keyboardArrowUpRounded =
      HugeIcons.strokeRoundedArrowUp01;
  static const AppIconData kitchenRounded = HugeIcons.strokeRoundedRefrigerator;
  static const AppIconData labelOutline = HugeIcons.strokeRoundedLabel;
  static const AppIconData labelOutlineRounded = HugeIcons.strokeRoundedLabel;
  static const AppIconData labelRounded = HugeIcons.strokeRoundedLabel;
  static const AppIconData languageRounded = HugeIcons.strokeRoundedGlobe;
  static const AppIconData layersOutlined = HugeIcons.strokeRoundedLayers01;
  static const AppIconData linkRounded = HugeIcons.strokeRoundedLink01;
  static const AppIconData localCafeRounded = HugeIcons.strokeRoundedCoffee01;
  static const AppIconData localFloristRounded = HugeIcons.strokeRoundedFlower;
  static const AppIconData localGroceryStoreRounded =
      HugeIcons.strokeRoundedShoppingCart01;
  static const AppIconData localOfferOutlined = HugeIcons.strokeRoundedTag01;
  static const AppIconData localOfferRounded = HugeIcons.strokeRoundedTag01;
  static const AppIconData localShippingOutlined = HugeIcons.strokeRoundedTruck;
  static const AppIconData localShippingRounded = HugeIcons.strokeRoundedTruck;
  static const AppIconData locationCityOutlined = HugeIcons.strokeRoundedCity01;
  static const AppIconData locationOnOutlined =
      HugeIcons.strokeRoundedLocation01;
  static const AppIconData lockOpenRounded =
      HugeIcons.strokeRoundedSquareUnlock01;
  static const AppIconData lockOutlineRounded = HugeIcons.strokeRoundedLock;
  static const AppIconData lockRounded = HugeIcons.strokeRoundedLock;
  static const AppIconData loginRounded = HugeIcons.strokeRoundedLogin01;
  static const AppIconData logoutRounded = HugeIcons.strokeRoundedLogout01;
  static const AppIconData mailOutlineRounded = HugeIcons.strokeRoundedMail01;
  static const AppIconData mapOutlined = HugeIcons.strokeRoundedMaps;
  static const AppIconData markEmailUnreadOutlined =
      HugeIcons.strokeRoundedMail01;
  static const AppIconData markunreadMailboxOutlined =
      HugeIcons.strokeRoundedMailbox01;
  static const AppIconData medicationRounded = HugeIcons.strokeRoundedPill;
  static const AppIconData memoryRounded = HugeIcons.strokeRoundedCpu;
  static const AppIconData menuBookRounded = HugeIcons.strokeRoundedBookOpen01;
  static const AppIconData miscellaneousServicesRounded =
      HugeIcons.strokeRoundedTools;
  static const AppIconData moreVert = HugeIcons.strokeRoundedMoreVertical;
  static const AppIconData moreVertRounded =
      HugeIcons.strokeRoundedMoreVertical;
  static const AppIconData northEastRounded =
      HugeIcons.strokeRoundedArrowUpRight01;
  static const AppIconData notesRounded = HugeIcons.strokeRoundedNote01;
  static const AppIconData notificationsNoneRounded =
      HugeIcons.strokeRoundedNotification01;
  static const AppIconData openInNewRounded =
      HugeIcons.strokeRoundedLinkSquare01;
  static const AppIconData outboxOutlined = HugeIcons.strokeRoundedInboxUpload;
  static const AppIconData paletteOutlined = HugeIcons.strokeRoundedPaintBoard;
  static const AppIconData paletteRounded = HugeIcons.strokeRoundedPaintBoard;
  static const AppIconData pauseCircleOutlineRounded =
      HugeIcons.strokeRoundedPauseCircle;
  static const AppIconData paymentsOutlined = HugeIcons.strokeRoundedPayment01;
  static const AppIconData paymentsRounded = HugeIcons.strokeRoundedPayment01;
  static const AppIconData pendingOutlined = HugeIcons.strokeRoundedClock01;
  static const AppIconData peopleRounded = HugeIcons.strokeRoundedUserGroup;
  static const AppIconData percentRounded = HugeIcons.strokeRoundedPercent;
  static const AppIconData personAddAlt1Outlined =
      HugeIcons.strokeRoundedUserAdd01;
  static const AppIconData personAddAlt1Rounded =
      HugeIcons.strokeRoundedUserAdd01;
  static const AppIconData personAddOutlined = HugeIcons.strokeRoundedUserAdd01;
  static const AppIconData personOutline = HugeIcons.strokeRoundedUser;
  static const AppIconData personOutlineRounded = HugeIcons.strokeRoundedUser;
  static const AppIconData personRounded = HugeIcons.strokeRoundedUser;
  static const AppIconData personSearchRounded =
      HugeIcons.strokeRoundedUserSearch01;
  static const AppIconData petsRounded = HugeIcons.strokeRoundedBird;
  static const AppIconData phoneOutlined = HugeIcons.strokeRoundedCall;
  static const AppIconData phoneRounded = HugeIcons.strokeRoundedCall;
  static const AppIconData photoCameraOutlined =
      HugeIcons.strokeRoundedCamera01;
  static const AppIconData photoLibraryOutlined =
      HugeIcons.strokeRoundedAlbum02;
  static const AppIconData photoLibraryRounded = HugeIcons.strokeRoundedAlbum02;
  static const AppIconData placeOutlined = HugeIcons.strokeRoundedLocation01;
  static const AppIconData placeRounded = HugeIcons.strokeRoundedLocation01;
  static const AppIconData pointOfSaleOutlined =
      HugeIcons.strokeRoundedCreditCardPos;
  static const AppIconData pointOfSaleRounded =
      HugeIcons.strokeRoundedCreditCardPos;
  static const AppIconData powerRounded = HugeIcons.strokeRoundedPower;
  static const AppIconData powerSettingsNew = HugeIcons.strokeRoundedPowerOff;
  static const AppIconData printOutlined = HugeIcons.strokeRoundedPrinter;
  static const AppIconData public = HugeIcons.strokeRoundedGlobe;
  static const AppIconData publicOffOutlined = HugeIcons.strokeRoundedGlobeX;
  static const AppIconData qrCode2Outlined = HugeIcons.strokeRoundedQrCode;
  static const AppIconData qrCode2Rounded = HugeIcons.strokeRoundedQrCode;
  static const AppIconData qrCodeRounded = HugeIcons.strokeRoundedQrCode;
  static const AppIconData qrCodeScannerRounded =
      HugeIcons.strokeRoundedQrCodeScan;
  static const AppIconData receiptLong = HugeIcons.strokeRoundedInvoice;
  static const AppIconData receiptLongOutlined = HugeIcons.strokeRoundedInvoice;
  static const AppIconData receiptLongRounded = HugeIcons.strokeRoundedInvoice;
  static const AppIconData receiptOutlined =
      HugeIcons.strokeRoundedReceiptIndianRupee;
  static const AppIconData redoRounded = HugeIcons.strokeRoundedRedo;
  static const AppIconData refresh = HugeIcons.strokeRoundedRefresh;
  static const AppIconData refreshRounded = HugeIcons.strokeRoundedRefresh;
  static const AppIconData remove = HugeIcons.strokeRoundedRemove01;
  static const AppIconData removeCircleOutline =
      HugeIcons.strokeRoundedRemoveCircle;
  static const AppIconData removeCircleOutlineRounded =
      HugeIcons.strokeRoundedRemoveCircle;
  static const AppIconData removeRounded = HugeIcons.strokeRoundedRemove01;
  static const AppIconData replayRounded = HugeIcons.strokeRoundedReplay;
  static const AppIconData requestQuoteOutlined =
      HugeIcons.strokeRoundedInvoice;
  static const AppIconData restaurantRounded =
      HugeIcons.strokeRoundedRestaurant01;
  static const AppIconData restoreRounded = HugeIcons.strokeRoundedRotateLeft01;
  static const AppIconData reviewsOutlined = HugeIcons.strokeRoundedStar;
  static const AppIconData savingsOutlined = HugeIcons.strokeRoundedSavings;
  static const AppIconData scaleRounded = HugeIcons.strokeRoundedWeightScale;
  static const AppIconData scheduleRounded = HugeIcons.strokeRoundedClock01;
  static const AppIconData search = HugeIcons.strokeRoundedSearch01;
  static const AppIconData searchOffRounded =
      HugeIcons.strokeRoundedSearchRemove;
  static const AppIconData searchRounded = HugeIcons.strokeRoundedSearch01;
  static const AppIconData sellOutlined = HugeIcons.strokeRoundedSaleTag01;
  static const AppIconData sellRounded = HugeIcons.strokeRoundedSaleTag01;
  static const AppIconData sendRounded = HugeIcons.strokeRoundedSent;
  static const AppIconData settingsOutlined = HugeIcons.strokeRoundedSettings01;
  static const AppIconData settingsRounded = HugeIcons.strokeRoundedSettings01;
  static const AppIconData shareRounded = HugeIcons.strokeRoundedShare01;
  static const AppIconData shieldOutlined = HugeIcons.strokeRoundedShield01;
  static const AppIconData shieldRounded = HugeIcons.strokeRoundedShield01;
  static const AppIconData shoppingBagOutlined =
      HugeIcons.strokeRoundedShoppingBag01;
  static const AppIconData smartphoneRounded =
      HugeIcons.strokeRoundedSmartPhone01;
  static const AppIconData southWestRounded =
      HugeIcons.strokeRoundedArrowDownLeft01;
  static const AppIconData spaRounded = HugeIcons.strokeRoundedFlower;
  static const AppIconData sportsCricketRounded =
      HugeIcons.strokeRoundedCricketBat;
  static const AppIconData starHalfRounded = HugeIcons.strokeRoundedStarHalf;
  static const AppIconData starOutlineRounded = HugeIcons.strokeRoundedStar;
  static const AppIconData starRounded = HugeIcons.strokeRoundedStar;
  static const AppIconData storefrontOutlined = HugeIcons.strokeRoundedStore01;
  static const AppIconData storefrontRounded = HugeIcons.strokeRoundedStore01;
  static const AppIconData straightenRounded = HugeIcons.strokeRoundedRuler;
  static const AppIconData styleOutlined = HugeIcons.strokeRoundedShirt01;
  static const AppIconData summarizeOutlined =
      HugeIcons.strokeRoundedDocumentValidation;
  static const AppIconData swapHorizRounded = HugeIcons.strokeRoundedExchange01;
  static const AppIconData swapVertRounded = HugeIcons.strokeRoundedArrowUpDown;
  static const AppIconData syncProblemRounded =
      HugeIcons.strokeRoundedRefreshCwOff;
  static const AppIconData syncRounded = HugeIcons.strokeRoundedRefresh;
  static const AppIconData tableChartRounded = HugeIcons.strokeRoundedGridTable;
  static const AppIconData tagRounded = HugeIcons.strokeRoundedTag01;
  static const AppIconData textSnippetRounded = HugeIcons.strokeRoundedFile02;
  static const AppIconData textureRounded = HugeIcons.strokeRoundedGrid;
  static const AppIconData timelineRounded = HugeIcons.strokeRoundedTimeline;
  static const AppIconData timerOffOutlined = HugeIcons.strokeRoundedTimer01;
  static const AppIconData timerOutlined = HugeIcons.strokeRoundedTimer01;
  static const AppIconData toggleOnRounded = HugeIcons.strokeRoundedToggleOn;
  static const AppIconData toysRounded = HugeIcons.strokeRoundedToyBrick;
  static const AppIconData trendingUpRounded = HugeIcons.strokeRoundedTradeUp;
  static const AppIconData tune = HugeIcons.strokeRoundedPreferenceHorizontal;
  static const AppIconData tuneRounded =
      HugeIcons.strokeRoundedPreferenceHorizontal;
  static const AppIconData undoRounded = HugeIcons.strokeRoundedUndo;
  static const AppIconData unfoldMoreRounded =
      HugeIcons.strokeRoundedUnfoldMore;
  static const AppIconData uploadFileRounded =
      HugeIcons.strokeRoundedFileUpload;
  static const AppIconData uploadOutlined = HugeIcons.strokeRoundedUpload01;
  static const AppIconData uploadRounded = HugeIcons.strokeRoundedUpload01;
  static const AppIconData verifiedOutlined =
      HugeIcons.strokeRoundedCheckmarkBadge01;
  static const AppIconData verifiedRounded =
      HugeIcons.strokeRoundedCheckmarkBadge01;
  static const AppIconData verifiedUserOutlined =
      HugeIcons.strokeRoundedSecurityCheck;
  static const AppIconData verifiedUserRounded =
      HugeIcons.strokeRoundedSecurityCheck;
  static const AppIconData viewCarouselOutlined =
      HugeIcons.strokeRoundedCarouselHorizontal;
  static const AppIconData viewListRounded = HugeIcons.strokeRoundedListView;
  static const AppIconData viewSidebarRounded =
      HugeIcons.strokeRoundedViewSidebarLeft;
  static const AppIconData visibilityOffOutlined =
      HugeIcons.strokeRoundedViewOff;
  static const AppIconData visibilityOutlined = HugeIcons.strokeRoundedEye;
  static const AppIconData wallpaperRounded = HugeIcons.strokeRoundedImage01;
  static const AppIconData warningAmberRounded = HugeIcons.strokeRoundedAlert02;
  static const AppIconData widgetsRounded =
      HugeIcons.strokeRoundedDashboardSquare01;
  static const AppIconData workOutlineRounded =
      HugeIcons.strokeRoundedBriefcase01;
}
