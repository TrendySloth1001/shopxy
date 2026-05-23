class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.emailNotifications,
    required this.createdAt,
    this.shopName,
    this.shopAddress,
    this.shopCity,
    this.shopState,
    this.shopStateCode,
    this.shopPinCode,
    this.shopGstin,
    this.shopPan,
    this.upiVpa,
  });

  final int id;
  final String email;
  final String name;
  final String role;
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
  final String? shopPan;
  final String? upiVpa;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as int,
        email: j['email'] as String,
        name: j['name'] as String,
        role: j['role'] as String,
        emailNotifications: (j['emailNotifications'] as bool?) ?? true,
        createdAt: DateTime.parse(j['createdAt'] as String),
        shopName: j['shopName'] as String?,
        shopAddress: j['shopAddress'] as String?,
        shopCity: j['shopCity'] as String?,
        shopState: j['shopState'] as String?,
        shopStateCode: j['shopStateCode'] as String?,
        shopPinCode: j['shopPinCode'] as String?,
        shopGstin: j['shopGstin'] as String?,
        shopPan: j['shopPan'] as String?,
        upiVpa: j['upiVpa'] as String?,
      );

  bool get isOwner => role == 'OWNER';

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
    String? shopPan,
    String? upiVpa,
  }) =>
      AuthUser(
        id: id,
        email: email,
        name: name ?? this.name,
        role: role,
        emailNotifications: emailNotifications ?? this.emailNotifications,
        createdAt: createdAt,
        shopName: shopName ?? this.shopName,
        shopAddress: shopAddress ?? this.shopAddress,
        shopCity: shopCity ?? this.shopCity,
        shopState: shopState ?? this.shopState,
        shopStateCode: shopStateCode ?? this.shopStateCode,
        shopPinCode: shopPinCode ?? this.shopPinCode,
        shopGstin: shopGstin ?? this.shopGstin,
        shopPan: shopPan ?? this.shopPan,
        upiVpa: upiVpa ?? this.upiVpa,
      );
}
