class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.createdAt,
  });

  final int id;
  final String email;
  final String name;
  final String role;
  final DateTime createdAt;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as int,
        email: j['email'] as String,
        name: j['name'] as String,
        role: j['role'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  bool get isOwner => role == 'OWNER';
}
