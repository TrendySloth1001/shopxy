import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/addresses/domain/entities/user_address.dart';

/// Talks to `/me/addresses` (auth-only). The backend owns:
///   GET    /me/addresses
///   POST   /me/addresses
///   PATCH  /me/addresses/:id
///   POST   /me/addresses/:id/default
///   DELETE /me/addresses/:id
class AddressesRemoteDataSource {
  const AddressesRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<UserAddress>> list() async {
    final res = await _client.get('/me/addresses');
    if (res.statusCode == 401) return const [];
    if (res.statusCode != 200) {
      throw Exception('Failed to load addresses: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['data'] as List<dynamic>)
        .map((e) => UserAddress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserAddress> create(UserAddressInput input) async {
    final res = await _client.post('/me/addresses', body: input.toJson());
    if (res.statusCode != 201) {
      throw Exception('Failed to save address: ${res.body}');
    }
    return UserAddress.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<UserAddress> update(int id, UserAddressInput input) async {
    final res = await _client.patch('/me/addresses/$id', body: input.toJson());
    if (res.statusCode != 200) {
      throw Exception('Failed to update address: ${res.body}');
    }
    return UserAddress.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> setDefault(int id) async {
    final res = await _client.post('/me/addresses/$id/default');
    if (res.statusCode != 204) {
      throw Exception('Failed to set default: ${res.statusCode}');
    }
  }

  Future<void> delete(int id) async {
    final res = await _client.delete('/me/addresses/$id');
    if (res.statusCode != 204) {
      throw Exception('Failed to delete: ${res.statusCode}');
    }
  }
}
