import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/parties/data/models/party_dto.dart';
import 'package:shopxy/features/parties/data/models/party_overview_dto.dart';
import 'package:shopxy/features/parties/domain/entities/party.dart';
import 'package:shopxy/features/parties/domain/entities/party_overview.dart';

class PartiesRemoteDataSource {
  const PartiesRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<Party>> getParties({
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
    final res = await _client.get('/parties', queryParameters: params);
    if (res.statusCode != 200) throw Exception('Failed to load parties: ${res.statusCode}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;
    return data.map((e) => PartyDto.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Party> getPartyById(String id) async {
    final res = await _client.get('/parties/$id');
    if (res.statusCode != 200) throw Exception('Party not found');
    return PartyDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<PartyOverview> getPartyOverview(String id) async {
    final res = await _client.get('/parties/$id/overview');
    if (res.statusCode != 200) throw Exception('Party not found');
    return PartyOverviewDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Party> createParty({
    required String name,
    String? contactName,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? stateCode,
    String? pinCode,
    String? panNumber,
    String? gstin,
  }) async {
    final res = await _client.post(
      '/parties',
      body: PartyDto.toCreateJson(
        name: name,
        contactName: contactName,
        phone: phone,
        email: email,
        address: address,
        city: city,
        state: state,
        stateCode: stateCode,
        pinCode: pinCode,
        panNumber: panNumber,
        gstin: gstin,
      ),
    );
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to create party');
    }
    return PartyDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Party> updateParty(String id, Map<String, dynamic> data) async {
    final res = await _client.patch('/parties/$id', body: data);
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to update party');
    }
    return PartyDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteParty(String id) async {
    final res = await _client.delete('/parties/$id');
    if (res.statusCode != 204) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to delete party');
    }
  }
}
