class AppSizes {
  // Spacing
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;
  static const double massive = 64;

  // Border radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusButton = 14;
  static const double radiusInput = 14;
  static const double radiusDialog = 20;
  static const double radiusFull = 100;

  // Icon sizes
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;
  static const double iconHuge = 48;

  // Card
  static const double cardElevation = 0;
  static const double cardPadding = 16;

  // Bottom sheet
  static const double bottomSheetRadius = 24;

  // App bar
  static const double appBarHeight = 56;

  // FAB
  static const double fabSize = 56;

  // Product image
  static const double productThumbSize = 48;
  static const double productImageSize = 120;

  // QR code
  static const double qrCodeSize = 200;

  // ── Component sizes ──────────────────────────────────
  // Recurring values that sit *off* the spacing scale on purpose: fixed
  // component dimensions, not padding. Added so widespread patterns
  // (FAB clearance, drag handles, avatars, hero panels) stop being raw
  // literals. See design.md §3.

  /// Scroll-list bottom inset so the last row clears a FloatingActionButton.
  static const double fabClearance = 96;

  /// Bottom-sheet drag-handle pill dimensions.
  static const double handleWidth = 36;
  static const double handleHeight = 4;

  /// Micro corner radius — drag-handle pills, chart bars, tiny badges.
  /// Below radiusSm (8); reproduces the 2px rounding those primitives use.
  static const double radiusXs = 2;

  /// Avatars / icon chips / thumbnails that fall between spacing tokens.
  static const double avatarXs = 36;
  static const double avatarSm = 40;
  static const double avatarMd = 56;

  /// Minimum comfortable tap target (icon-only buttons, grid cells).
  static const double tapTargetMin = 44;

  /// GlassHero panel height + illustration size for detail/create pages.
  static const double heroHeightSm = 160;
  static const double heroHeightMd = 180;
  static const double heroIllustration = 130;
}
