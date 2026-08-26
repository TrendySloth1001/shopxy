import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/addresses/domain/entities/user_address.dart';

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

  Future<UserAddress> update(String id, UserAddressInput input) async {
    final res = await _client.patch('/me/addresses/$id', body: input.toJson());
    if (res.statusCode != 200) {
      throw Exception('Failed to update address: ${res.body}');
    }
    return UserAddress.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> setDefault(String id) async {
    final res = await _client.post('/me/addresses/$id/default');
    if (res.statusCode != 204) {
      throw Exception('Failed to set default: ${res.statusCode}');
    }
  }

  Future<void> delete(String id) async {
    final res = await _client.delete('/me/addresses/$id');
    if (res.statusCode != 204) {
      throw Exception('Failed to delete: ${res.statusCode}');
    }
  }
}
