import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/payments/data/models/payment_dto.dart';
import 'package:shopxy/features/payments/domain/entities/payment.dart';

class PaymentsRemoteDataSource {
  const PaymentsRemoteDataSource(this._client);
  final ApiClient _client;

  /// POST /payments. `type` is RECEIPT for party receipts or PAYMENT for
  /// vendor payouts. Exactly one of partyId / vendorId must be set.
  Future<Payment> createPayment({
    required String type,
    required double amount,
    required String mode,
    String? modeReference,
    DateTime? paymentDate,
    String? partyId,
    String? vendorId,
    String? invoiceId,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'amount': amount,
      'mode': mode,
      if (modeReference != null && modeReference.isNotEmpty)
        'modeReference': modeReference,
      if (paymentDate != null) 'paymentDate': paymentDate.toIso8601String(),
      'partyId': ?partyId,
      'vendorId': ?vendorId,
      'invoiceId': ?invoiceId,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final res = await _client.post('/payments', body: body);
    if (res.statusCode != 201) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(decoded['error'] ?? 'Failed to record payment');
    }
    return PaymentDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<Payment>> listPayments({
    String? partyId,
    String? vendorId,
    String? invoiceId,
    int page = 1,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'partyId': ?partyId,
      'vendorId': ?vendorId,
      'invoiceId': ?invoiceId,
    };
    final res = await _client.get('/payments', queryParameters: params);
    if (res.statusCode != 200) {
      throw Exception('Failed to load payments');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return data
        .map((e) => PaymentDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deletePayment(String id) async {
    final res = await _client.delete('/payments/$id');
    if (res.statusCode != 204) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to delete payment');
    }
  }

  Future<Ledger> getPartyLedger(String partyId) async {
    final res = await _client.get('/parties/$partyId/ledger');
    if (res.statusCode != 200) {
      throw Exception('Failed to load ledger');
    }
    return PaymentDto.ledgerFromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }

  Future<Ledger> getVendorLedger(String vendorId) async {
    final res = await _client.get('/vendors/$vendorId/ledger');
    if (res.statusCode != 200) {
      throw Exception('Failed to load ledger');
    }
    return PaymentDto.ledgerFromJson(
      jsonDecode(res.body) as Map<String, dynamic>,
    );
  }
}
