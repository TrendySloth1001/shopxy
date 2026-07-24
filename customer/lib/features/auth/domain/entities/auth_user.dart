class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
    this.avatarUrl,
    this.phoneNumber,
    this.notifyOrders = true,
    this.notifyDeals = true,
    this.notifyAccount = true,
    this.notifyMessages = true,
    this.pushEnabled = true,
    this.smsEnabled = false,
  });

  final String id;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;
  final String? avatarUrl;
  final String? phoneNumber;
  /// Granular notification preferences. Per-category flags gate
  /// what gets sent at all; channel flags (push/sms) mute the
  /// entire transport regardless of the category preference.
  final bool notifyOrders;
  final bool notifyDeals;
  final bool notifyAccount;
  final bool notifyMessages;
  final bool pushEnabled;
  final bool smsEnabled;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'].toString(),
        email: j['email'] as String,
        name: j['name'] as String,
        role: j['role'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        avatarUrl: (j['avatarUrl'] as String?)?.trim().isEmpty == false
            ? (j['avatarUrl'] as String).trim()
            : null,
        phoneNumber: (j['phoneNumber'] as String?)?.trim().isEmpty == false
            ? (j['phoneNumber'] as String).trim()
            : null,
        notifyOrders: (j['notifyOrders'] as bool?) ?? true,
        notifyDeals: (j['notifyDeals'] as bool?) ?? true,
        notifyAccount: (j['notifyAccount'] as bool?) ?? true,
        notifyMessages: (j['notifyMessages'] as bool?) ?? true,
        pushEnabled: (j['pushEnabled'] as bool?) ?? true,
        smsEnabled: (j['smsEnabled'] as bool?) ?? false,
      );

  bool get isOwner => role == 'OWNER';
}
