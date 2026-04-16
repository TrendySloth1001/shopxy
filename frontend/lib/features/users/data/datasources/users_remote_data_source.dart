import 'dart:convert';

import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/users/data/models/user_dto.dart';

class UsersRemoteDataSource {
  UsersRemoteDataSource(this._client);

  final ApiClient _client;

  Future<List<UserDto>> fetchUsers() async {
    final response = await _client.get('/users');
    if (response.statusCode != 200) {
      throw Exception('Failed to load users');
    }

    final data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => UserDto.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
