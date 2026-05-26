import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/wallet/domain/wallet_entry.dart';

class WalletRemoteDataSource {
  const WalletRemoteDataSource(this._client);
  final ApiClient _client;

  Future<WalletSnapshot> snapshot() async {
    final res = await _client.get('/me/wallet');
    if (res.statusCode != 200) {
      throw Exception('Failed to load wallet (${res.statusCode})');
    }
    return WalletSnapshot.fromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}
