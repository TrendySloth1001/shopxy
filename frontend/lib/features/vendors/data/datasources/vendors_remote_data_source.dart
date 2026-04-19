import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/vendors/data/models/vendor_dto.dart';
import 'package:shopxy/features/vendors/domain/entities/vendor.dart';

class VendorsRemoteDataSource {
  const VendorsRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<Vendor>> getVendors({
    String? search,
    bool activeOnly = true,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (!activeOnly) 'active': 'false',
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final res = await _client.get('/vendors', queryParameters: params);
    if (res.statusCode != 200) throw Exception('Failed to load vendors: ${res.statusCode}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;
    return data.map((e) => VendorDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Vendor> getVendorById(int id) async {
    final res = await _client.get('/vendors/$id');
    if (res.statusCode != 200) throw Exception('Vendor not found');
    return VendorDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Vendor> createVendor({
    required String name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? gstin,
  }) async {
    final res = await _client.post(
      '/vendors',
      body: VendorDto.toCreateJson(
        name: name,
        contactName: contactName,
        phone: phone,
        email: email,
        address: address,
        gstin: gstin,
      ),
    );
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to create vendor');
    }
    return VendorDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Vendor> updateVendor(int id, Map<String, dynamic> data) async {
    final res = await _client.patch('/vendors/$id', body: data);
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to update vendor');
    }
    return VendorDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteVendor(int id) async {
    final res = await _client.delete('/vendors/$id');
    if (res.statusCode != 204) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to delete vendor');
    }
  }
}
