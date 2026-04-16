import 'package:shopxy/features/users/domain/entities/user.dart';

class UserDto {
  UserDto({required this.id, required this.email, this.name});

  final int id;
  final String email;
  final String? name;

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: json['id'] as int,
      email: json['email'] as String,
      name: json['name'] as String?,
    );
  }

  User toEntity() {
    return User(id: id, email: email, name: name);
  }
}
