class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.isPlatformAdmin = false,
    this.shopRole,
    this.shopRoleName,
    this.shopPermissions = const [],
    required this.emailNotifications,
    required this.createdAt,
    this.shopName,
    this.shopAddress,
    this.shopCity,
    this.shopState,
    this.shopStateCode,
    this.shopPinCode,
    this.shopGstin,
    this.gstEffectiveFrom,
    this.shopPan,
    this.upiVpa,
    this.avatarUrl,
    this.phoneNumber,
    this.googleId,
    this.recoveryPinSetAt,
  });

  final String id;
  final String email;
  final String name;
  final String role;

  /// Platform-wide curation privilege (banners, taxonomy, collections).
  /// Independent of role — flag any user via DB to grant it.
  final bool isPlatformAdmin;

  /// The caller's position within their shop's team (OWNER, MANAGER,
  /// STOCKIST, CASHIER). Null for accounts not on any team (e.g. a
  /// customer account, or an owner whose shop predates membership).
  /// Surfaced on /auth/me; gates role-sensitive UI like the Team screen.
  final String? shopRole;

  /// Human label of the caller's role — a TeamRole name ("Cashier",
  /// "Warehouse Lead", …). Preferred over [shopRole] for display.
  final String? shopRoleName;

  /// Granted rights as `area:action` strings (see shop_capabilities
  /// .dart). Empty for OWNER (their role bypasses every gate) and for
  /// non-team accounts. Surfaced on /auth/me.
  final List<String> shopPermissions;
  final bool emailNotifications;
  final DateTime createdAt;
  // Shop profile — surfaced on /auth/me and editable via PATCH /auth/me.
  // All optional so legacy users without a shop set up still load cleanly.
  final String? shopName;
  final String? shopAddress;
  final String? shopCity;
  final String? shopState;
  final String? shopStateCode;
  final String? shopPinCode;
  final String? shopGstin;

  /// Calendar date (YYYY-MM-DD) GST starts applying — null = ungated
  /// (pre-feature behaviour). See backend `gstEffectiveFrom` on `User`.
  final String? gstEffectiveFrom;
  final String? shopPan;
  final String? upiVpa;

  /// Profile photo URL (upload-service path). Null = initial fallback.
  final String? avatarUrl;

  /// Merchant phone number, editable from Edit Profile.
  final String? phoneNumber;

  /// Not a secret — Google's stable per-account `sub`, useless without also
  /// owning that Google account. Presence means this account has no
  /// password (Google-only accounts get a random, unusable one server-side
  /// — see backend `safeUserSelect`). Combined with [recoveryPinSetAt] this
  /// is how [needsRecoveryPinSetup] gates every protected screen.
  final String? googleId;

  /// Timestamp only (never the PIN or its hash) — presence means the
  /// recovery PIN is already set up.
  final DateTime? recoveryPinSetAt;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
    id: j['id'].toString(),
    email: j['email'] as String,
    name: j['name'] as String,
    role: j['role'] as String,
    isPlatformAdmin: (j['isPlatformAdmin'] as bool?) ?? false,
    shopRole: j['shopRole'] as String?,
    shopRoleName: j['shopRoleName'] as String?,
    shopPermissions:
        (j['shopPermissions'] as List?)?.cast<String>() ?? const [],
    emailNotifications: (j['emailNotifications'] as bool?) ?? true,
    createdAt: DateTime.parse(j['createdAt'] as String),
    shopName: j['shopName'] as String?,
    shopAddress: j['shopAddress'] as String?,
    shopCity: j['shopCity'] as String?,
    shopState: j['shopState'] as String?,
    shopStateCode: j['shopStateCode'] as String?,
    shopPinCode: j['shopPinCode'] as String?,
    shopGstin: j['shopGstin'] as String?,
    // Backend sends a full ISO datetime for the underlying Date column —
    // this app only ever needs the calendar-date part.
    gstEffectiveFrom: (j['gstEffectiveFrom'] as String?)?.substring(0, 10),
    shopPan: j['shopPan'] as String?,
    upiVpa: j['upiVpa'] as String?,
    avatarUrl: (j['avatarUrl'] as String?)?.trim().isEmpty == false
        ? (j['avatarUrl'] as String).trim()
        : null,
    phoneNumber: (j['phoneNumber'] as String?)?.trim().isEmpty == false
        ? (j['phoneNumber'] as String).trim()
        : null,
    googleId: j['googleId'] as String?,
    recoveryPinSetAt: j['recoveryPinSetAt'] != null
        ? DateTime.parse(j['recoveryPinSetAt'] as String)
        : null,
  );

  bool get isOwner => role == 'OWNER';

  /// True when this account owns the shop (vs invited staff). Gates the
  /// team-management actions on the Team & roles screen.
  bool get isShopOwner => shopRole == 'OWNER';

  /// True for a Google-linked account that hasn't set a recovery PIN yet —
  /// takes priority over every other post-auth gate (shop onboarding,
  /// team-join) since it's the only way back in if Google is ever
  /// unreachable.
  bool get needsRecoveryPinSetup =>
      googleId != null && recoveryPinSetAt == null;

  AuthUser copyWith({
    String? name,
    bool? emailNotifications,
    String? shopName,
    String? shopAddress,
    String? shopCity,
    String? shopState,
    String? shopStateCode,
    String? shopPinCode,
    String? shopGstin,
    String? gstEffectiveFrom,
    String? shopPan,
    String? upiVpa,
    String? avatarUrl,
    String? phoneNumber,
  }) => AuthUser(
    id: id,
    email: email,
    name: name ?? this.name,
    role: role,
    isPlatformAdmin: isPlatformAdmin,
    shopRole: shopRole,
    shopRoleName: shopRoleName,
    shopPermissions: shopPermissions,
    emailNotifications: emailNotifications ?? this.emailNotifications,
    createdAt: createdAt,
    shopName: shopName ?? this.shopName,
    shopAddress: shopAddress ?? this.shopAddress,
    shopCity: shopCity ?? this.shopCity,
    shopState: shopState ?? this.shopState,
    shopStateCode: shopStateCode ?? this.shopStateCode,
    shopPinCode: shopPinCode ?? this.shopPinCode,
    shopGstin: shopGstin ?? this.shopGstin,
    gstEffectiveFrom: gstEffectiveFrom ?? this.gstEffectiveFrom,
    shopPan: shopPan ?? this.shopPan,
    upiVpa: upiVpa ?? this.upiVpa,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    phoneNumber: phoneNumber ?? this.phoneNumber,
  );
}
