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
    this.registrationType,
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

  final bool isPlatformAdmin;

  final String? shopRole;

  final String? shopRoleName;

  final List<String> shopPermissions;
  final bool emailNotifications;
  final DateTime createdAt;
  final String? shopName;
  final String? shopAddress;
  final String? shopCity;
  final String? shopState;
  final String? shopStateCode;
  final String? shopPinCode;
  final String? shopGstin;

  final String? registrationType;

  final String? gstEffectiveFrom;
  final String? shopPan;
  final String? upiVpa;

  final String? avatarUrl;

  final String? phoneNumber;

  final String? googleId;

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
    registrationType: j['registrationType'] as String?,
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

  bool get isShopOwner => shopRole == 'OWNER';

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
