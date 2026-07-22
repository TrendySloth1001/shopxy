class AppStrings {
  // App
  static const String appName = 'Shopxy';
  static const String appTagline = 'Smart Inventory Management';

  // Navigation
  static const String navDashboard = 'Dashboard';
  static const String navProducts = 'Products';
  static const String navCategories = 'Categories';
  static const String navInvoices = 'Invoices';
  static const String navQuotations = 'Quotations';
  static const String navOrders = 'Orders';
  static const String navVendors = 'Vendors';
  static const String navMore = 'More';
  static const String navProfile = 'Profile';

  // Profile / Settings
  static const String settings = 'Settings';
  static const String editProfile = 'Edit profile';
  static const String account = 'Account';
  static const String preferences = 'Preferences';
  static const String about = 'About';
  static const String appVersion = 'App version';
  static const String privacyPolicy = 'Privacy policy';
  static const String termsOfService = 'Terms of service';
  static const String appearance = 'Appearance';
  static const String theme = 'Theme';
  static const String themeLight = 'Light';
  static const String themeDark = 'Dark';
  static const String themeSystem = 'Follow system';
  static const String currency = 'Currency';
  static const String language = 'Language';
  static const String notifications = 'Notifications';
  static const String comingSoon = 'Coming soon';
  static const String roleOwner = 'Owner';
  static const String roleStaff = 'Staff';
  static const String memberSince = 'Member since';

  // Dashboard
  static const String categories = 'Categories';
  static const String lowStock = 'Low Stock';
  static const String outOfStock = 'Out of Stock';
  static const String inStock = 'In Stock';
  static const String stockValue = 'Stock Value';
  static const String greetingMorning = 'Good morning';
  static const String greetingAfternoon = 'Good afternoon';
  static const String greetingEvening = 'Good evening';
  static const String dashboardSubtitle = "Here's how your shop is doing today.";
  static const String inventoryValueEyebrow = 'INVENTORY VALUE';
  static const String inventoryValueHint =
      'Estimated value of stock currently on hand.';
  static const String statProducts = 'Products';
  static const String statActive = 'Active';
  static const String statCategories = 'Categories';
  static const String stockPulseEyebrow = 'STOCK PULSE';
  static const String stockPulseHealthy = 'healthy';
  static const String stockPulseInGoodStock = 'in good stock';
  static const String stockPulseLow = 'low stock';
  static const String stockPulseOut = 'out of stock';
  static const String pendingDraftsEyebrow = 'PENDING DRAFTS';
  static const String draftsStockNotDeducted = 'Stock has not been deducted yet.';
  static const String recentActivityEyebrow = 'RECENT ACTIVITY';
  static const String noRecentActivity =
      'No stock movements yet. Your recent in/out activity will appear here.';
  static const String pendingInvitationTitle = 'You have a pending invitation';

  // Filters (shared)
  static const String filterAll = 'All';
  static const String noMatches = 'No matches';
  static const String noMatchesHint =
      'Try clearing filters or searching for something else.';
  static const String searchInvoices = 'Search invoice no, party, vendor';
  static const String invoiceTypeSale = 'Sales';
  static const String invoiceTypePurchase = 'Purchases';

  // Products
  static const String addProduct = 'Add Product';
  static const String editProduct = 'Edit Product';
  static const String productDetails = 'Product Details';
  static const String searchProducts = 'Search products...';
  static const String noProducts = 'No products found';
  static const String noProductsHint = 'Tap + to add your first product';
  static const String uncategorised = 'Uncategorised';
  static const String allStockedUpTitle = 'All stocked up';
  static const String allStockedUpHint =
      'Nothing is running low right now. Nice work.';
  static const String stockLedger = 'Stock ledger';
  static const String stockLedgerHint = 'Every movement with source documents';
  static const String profitMargin = 'Profit Margin';
  static const String created = 'Created';
  static const String selectCategory = 'Select category';
  static const String searchCategories = 'Search categories...';
  static const String clearSelection = 'Clear selection';
  static const String noCategoriesMatch = 'No categories match that search.';
  static const String categoryPickerLabel = 'Category';

  // Custom fields
  static const String customFields = 'Custom Fields';
  static const String customFieldsHint =
      'Track extra information on every product';
  static const String customFieldsEmptyTitle = 'No custom fields yet';
  static const String customFieldsEmptyHint =
      'Define fields like Warranty, Model Number, Material — visible on every product.';
  static const String addCustomField = 'Add field';
  static const String editCustomField = 'Edit field';
  static const String fieldName = 'Field name';
  static const String fieldType = 'Field type';
  static const String fieldOptions = 'Options';
  static const String fieldOptionsHint =
      'One per line. Used for dropdown choices.';
  static const String unitSuffix = 'Unit (optional)';
  static const String unitSuffixHint = 'e.g. kg, days, GB';
  static const String specifications = 'Specifications';
  static const String moreAboutThisProduct = 'More about this product';
  static const String archive = 'Archive';
  static const String archiveCustomFieldConfirm =
      'Archive this field? Existing values stay on each product, but the field stops appearing on new ones.';
  static const String deleteProductConfirm = 'Delete this product?';
  static const String productDeleted = 'Product deleted';
  static const String scanLabel = 'Scan label';
  static const String productImages = 'Product Images';
  static const String addImageUrl = 'Or paste image URL';
  static const String imageUrlHint = 'https://...';
  static const String addImage = 'Add Image';
  static const String pickFromGallery = 'Gallery';
  static const String takePhoto = 'Camera';
  static const String uploadingImage = 'Uploading...';
  static const String sectionBasicInfo = 'Basic Information';
  static const String sectionPricing = 'Pricing';
  static const String sectionStock = 'Stock';
  static const String none = 'None';

  // Product fields
  static const String productName = 'Product Name';
  static const String description = 'Description';
  static const String sku = 'SKU';
  static const String barcode = 'Barcode';
  static const String hsnCode = 'HSN Code';
  static const String mrp = 'MRP';
  static const String sellingPrice = 'Selling Price';
  static const String purchasePrice = 'Purchase Price';
  static const String taxPercent = 'Tax %';
  static const String stockQuantity = 'Stock Quantity';
  static const String lowStockThreshold = 'Low Stock Alert';
  static const String unit = 'Unit';
  static const String category = 'Category';

  // Categories
  static const String addCategory = 'Add Category';
  static const String editCategory = 'Edit Category';
  static const String noCategories = 'No categories yet';
  static const String noCategoriesHint = 'Tap + to add a category';
  static const String categoryName = 'Category Name';
  static const String categoryDeleted = 'Category deleted';

  // Vendors
  static const String addVendor = 'Add Vendor';
  static const String editVendor = 'Edit Vendor';
  static const String deleteVendor = 'Delete Vendor';
  static const String deleteVendorConfirm =
      'Are you sure you want to delete this vendor?';
  static const String vendorDeleted = 'Vendor deleted successfully';
  static const String searchVendors = 'Search vendors...';
  static const String noVendors = 'No vendors found';
  static const String noVendorsHint = 'Tap + to add your first vendor';
  static const String vendorName = 'Vendor Name';
  static const String contactName = 'Contact Name';
  static const String phone = 'Phone';
  static const String email = 'Email';
  static const String gstin = 'GSTIN';
  static const String address = 'Address';
  static const String vendor = 'Vendor';
  static const String selectVendor = 'Select vendor';
  static const String newVendor = 'New vendor';

  // Parties
  static const String navParties = 'Parties';
  static const String addParty = 'Add Party';
  static const String editParty = 'Edit Party';
  static const String deleteParty = 'Delete Party';
  static const String deletePartyConfirm =
      'Are you sure you want to delete this party?';
  static const String partyDeleted = 'Party deleted successfully';
  static const String searchParties = 'Search parties...';
  static const String noParties = 'No parties found';
  static const String noPartiesHint = 'Tap + to add your first party';
  static const String party = 'Party';
  static const String selectParty = 'Select party';
  static const String newParty = 'New party';

  // Invoices
  static const String createInvoice = 'Create Invoice';
  static const String invoiceType = 'Invoice Type';
  static const String saleInvoice = 'Sale Invoice';
  static const String purchaseInvoice = 'Purchase Invoice';
  static const String customer = 'Customer';
  static const String customerName = 'Customer Name';
  static const String customerInfo = 'Customer Information';
  static const String vendorInfo = 'Vendor Information';
  static const String invoiceNeedsItems = 'Please add at least one item';
  static const String searchToAddProduct = 'Search product to add';
  static const String noItemsYet = 'No items added yet';
  static const String invoiceItems = 'Invoice Items';
  static const String subtotal = 'Subtotal';
  static const String tax = 'Tax';
  static const String taxAmount = 'Tax Amount';
  static const String discount = 'Discount';
  static const String totals = 'Totals';
  static const String total = 'Total';
  static const String generatingPdf = 'Generating PDF...';
  static const String downloadInvoice = 'Download Invoice';
  static const String confirmInvoice = 'Confirm Invoice';
  static const String cancelInvoice = 'Cancel Invoice';
  static const String noInvoices = 'No invoices found';
  static const String noInvoicesHint =
      'Create your first invoice to get started';

  // Stock
  static const String stockIn = 'Stock In';
  static const String stockOut = 'Stock Out';
  static const String adjustment = 'Adjustment';
  static const String quantity = 'Quantity';
  static const String unitPrice = 'Unit Price';
  static const String supplier = 'Supplier';
  static const String purchasePriceRule = 'Purchase Price Rule';
  static const String keepCurrentPrice = 'Keep Current';
  static const String useLatestPrice = 'Use Latest';
  static const String weightedAverage = 'Weighted Avg';
  static const String nextPurchasePrice = 'Next Purchase Price';
  static const String currentPurchasePrice = 'Current Purchase Price';
  static const String supplierHint = 'Track supplier-wise price history';
  static const String supplierPriceHistory = 'Supplier-wise Price History';
  static const String noSupplierHistory = 'No supplier stock-in history yet';
  static const String latestPrice = 'Latest Price';
  static const String averagePrice = 'Average Price';
  static const String lastStockIn = 'Last Stock In';
  static const String policy = 'Policy';
  static const String recentBuys = 'Recent Buys';
  static const String unknownSupplier = 'Unknown Supplier';
  static const String totalQuantityBought = 'Total Bought';
  static const String transactions = 'purchases';
  static const String supplierAutocompleteHint =
      'Start typing to see previous suppliers';
  static const String note = 'Note';
  static const String stockUpdated = 'Stock updated successfully';
  static const String insufficientStock = 'Insufficient stock';

  // QR
  static const String scanQr = 'Scan QR / Barcode';
  static const String generateQr = 'Generate QR Code';
  static const String productNotFound = 'Product not found for this code';
  static const String productNotFoundTitle = 'Product not found';
  static const String productNotFoundHint = 'Add it now with the scanned code';
  static const String scanAgain = 'Scan again';
  static const String scanHint = 'Point camera at QR or barcode';

  // OCR
  static const String ocrApplied = 'Applied scan results';
  static const String ocrNoDetails = 'No product details found';
  static const String ocrFailed = 'Could not read product details';

  // Challans
  static const String navChallans = 'Challans';
  static const String createChallan = 'Create Challan';
  static const String challanPartyInfo = 'Party Info';
  static const String challanAddProducts = 'Add Products';
  static const String challanItems = 'Challan Items';
  static const String challanNoItems = 'Add at least one product';
  static const String challanEmptyItems = 'No items added yet';
  static const String challanNoPricesHint = 'Prices are not visible to the party';
  static const String challansTapCreate = 'Tap + to create a challan';
  static const String noChallans = 'No challans found';
  static const String convertToInvoice = 'Convert to Invoice';
  static const String cancelChallan = 'Cancel Challan';
  static const String cancelChallanConfirm = 'Cancel this challan? This cannot be undone.';
  static const String challanLinkedInvoice = 'Invoice';
  static const String partyName = 'Party Name';
  static const String searchChallans = 'Search challans...';
  static const String items = 'items';
  static const String all = 'All';
  static const String submit = 'Submit';
  static const String yes = 'Yes';
  static const String no = 'No';

  // Actions
  static const String save = 'Save';
  static const String cancel = 'Cancel';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String retry = 'Retry';
  static const String confirm = 'Confirm';

  // Orders
  static const String orders = 'Orders';
  static const String confirmOrder = 'Confirm order';
  static const String confirmAndCreateInvoice = 'Confirm & create invoice';
  static const String declineOrder = 'Decline order';
  static const String confirmOrderTitle = 'Confirm this order?';
  static const String confirmOrderBody =
      'This creates a draft sale invoice for the items. Stock will move once you confirm the invoice.';
  static const String declineOrderTitle = 'Decline this order?';
  static const String declineOrderBody =
      'The customer will be notified. You can leave a note explaining why.';
  static const String declineOrderNoteHint = 'Reason (optional)';
  static const String inboxSearchHint = 'Search customer, item or #id';
  static const String tabAll = 'All';
  static const String tabPending = 'Pending';
  static const String tabConfirmed = 'Confirmed';
  static const String tabRejected = 'Rejected';
  static const String allCaughtUp = 'All caught up';
  static const String allCaughtUpHint = 'New orders will land here.';
  static const String noOrdersYet = 'No orders here yet';
  static const String stockShortfall = 'Low stock';
  static const String inactiveProduct = 'Inactive product';

  // Order detail
  static const String orderLinkedParty = 'Linked party';
  static const String orderRestock = 'Restock';
  static const String orderTotalsSubtotal = 'Subtotal';
  static const String orderTotalsTax = 'Tax';
  static const String orderTotalsDiscount = 'Discount';
  static const String orderTotalsTotal = 'Total';
  static const String orderCustomerNote = "Customer's note";
  static const String orderPartialFulfillFootnote =
      'Final invoice may differ if you partial-fulfill.';
  static const String orderJourneyPlaced = 'Placed';
  static const String orderJourneyConfirmed = 'Confirmed';
  static const String orderJourneyInvoiced = 'Invoiced';
  static const String orderJourneyPaid = 'Paid';
  static const String orderSummaryItemsLabel = 'Items';
  static const String orderSummaryQtyLabel = 'Total qty';
  static const String orderSummaryTotalLabel = 'Estimated';
  static const String orderActionShare = 'Share order summary';
  static const String orderDeclineReasonOutOfStock = 'Out of stock';
  static const String orderDeclineReasonClosed = 'Closed today';
  static const String orderDeclineReasonPriceChanged = 'Price changed';
  static const String orderDeclineReasonOther = 'Other';
  static const String orderStockUnknown = 'Stock unknown';

  // States
  static const String loading = 'Loading...';
  static const String error = 'Something went wrong';
  static const String noData = 'No data available';

  // Validation
  static const String fieldRequired = 'This field is required';
  static const String invalidNumber = 'Enter a valid number';
  static const String invalidUrl = 'Enter a valid URL';
  static const String priceMustBePositive = 'Price must be greater than 0';

  // Auth
  static const String welcomeBack = 'Welcome back';
  static const String loginSubtitle = 'Sign in to your Shopxy account';
  // Shown when a customer account tries to sign in here — the merchant
  // app is for shop owners only.
  static const String customerAccountBlocked =
      'This is a customer account. Please use the Shopxy customer app to sign in.';
  static const String registerTitle = 'Create your account';
  static const String registerSubtitle = 'Start managing your inventory';
  static const String createAccount = 'Create Account';
  static const String login = 'Log in';
  static const String register = 'Register';
  static const String logout = 'Log out';
  static const String logoutConfirm = 'Are you sure you want to log out?';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';
  static const String fullName = 'Full Name';
  static const String currentPassword = 'Current Password';
  static const String newPassword = 'New Password';
  static const String changePassword = 'Change Password';
  static const String noAccount = "Don't have an account?";
  static const String haveAccount = 'Already have an account?';
  static const String profile = 'Profile';
  static const String passwordHint = 'At least 8 characters, 1 letter and 1 number';

  // Auth validation
  static const String invalidEmail = 'Enter a valid email address';
  static const String passwordTooShort = 'Password must be at least 10 characters';
  static const String passwordNeedsLetter = 'Password must contain at least one letter';
  static const String passwordNeedsNumber = 'Password must contain at least one number';
  static const String passwordsDoNotMatch = 'Passwords do not match';
  static const String nameTooShort = 'Name must be at least 2 characters';

  // Currency
  static const String currencySymbol = '₹';
}
