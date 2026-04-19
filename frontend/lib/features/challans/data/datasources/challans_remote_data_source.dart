import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/challans/data/models/challan_dto.dart';
import 'package:shopxy/features/challans/domain/entities/challan.dart';

class ChallansRemoteDataSource {
  const ChallansRemoteDataSource(this._client);
  final ApiClient _client;

  Future<Challan> createChallan(Map<String, dynamic> data) async {
    final response = await _client.post('/challans', body: data);
    return ChallanDto.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<({List<Challan> challans, int total})> listChallans({
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final response = await _client.get('/challans', queryParameters: params);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List;
    final pagination = body['pagination'] as Map<String, dynamic>;

    return (
      challans: data.map((e) => ChallanDto.fromJson(e as Map<String, dynamic>)).toList(),
      total: pagination['total'] as int,
    );
  }

  Future<Challan> getChallanById(int id) async {
    final response = await _client.get('/challans/$id');
    return ChallanDto.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> cancelChallan(int id) async {
    await _client.patch('/challans/$id/cancel', body: {});
  }

  Future<Map<String, dynamic>> convertToInvoice(
    int id,
    Map<String, dynamic> data,
  ) async {
    final response = await _client.post('/challans/$id/convert', body: data);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
