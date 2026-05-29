import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/caution/domain/entities/caution_txn.dart';

/// Talks to the caution endpoints nested under a party:
///   GET  /parties/:id/caution
///   POST /parties/:id/caution/deposit
///   POST /parties/:id/caution/refund
///   POST /parties/:id/caution/adjust
class CautionRemoteDataSource {
  const CautionRemoteDataSource(this._client);
  final ApiClient _client;

  /// Prisma `Decimal` columns arrive as JSON strings — funnel money through
  /// this so a stray `String is not num` cast can't happen.
  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static CautionTxn _txnFromJson(Map<String, dynamic> j) {
    return CautionTxn(
      id: j['id'] as int,
      type: j['type'] as String,
      amount: _d(j['amount']),
      mode: j['mode'] as String?,
      modeReference: j['modeReference'] as String?,
      receiptNo: j['receiptNo'] as String?,
      gstTreatment: j['gstTreatment'] as String?,
      note: j['note'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
      invoiceId: j['invoiceId'] as int?,
      invoiceNo: j['invoiceNo'] as String?,
    );
  }

  static CautionRequest _requestFromJson(Map<String, dynamic> j) {
    final party = j['party'] as Map<String, dynamic>?;
    final basketRaw = j['basket'] as List<dynamic>?;
    return CautionRequest(
      id: j['id'] as int,
      partyId: j['partyId'] as int,
      partyName: (party?['name'] as String?) ?? 'Customer',
      amount: _d(j['amount']),
      mode: j['mode'] as String?,
      modeReference: j['modeReference'] as String?,
      note: j['note'] as String?,
      status: j['status'] as String,
      reviewNote: j['reviewNote'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
      basketValue: j['basketValue'] == null ? null : _d(j['basketValue']),
      basket: (basketRaw ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((b) => CautionBasketLine(
                name: (b['name'] as String?) ?? 'Item',
                sku: b['sku'] as String?,
                qty: _d(b['qty']),
                unitPrice: _d(b['unitPrice']),
                lineTotal: _d(b['lineTotal']),
              ))
          .toList(),
    );
  }

  Future<CautionHistory> getHistory(int partyId, {int page = 1, int limit = 50}) async {
    final res = await _client.get(
      '/parties/$partyId/caution',
      queryParameters: {'page': '$page', 'limit': '$limit'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load caution ledger');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>;
    return CautionHistory(
      balance: _d(body['balance']),
      entries: data
          .map((e) => _txnFromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Take a deposit (`DEPOSIT`) or pay one back (`REFUND`). Returns the new
  /// held balance.
  Future<double> record({
    required int partyId,
    required String type,
    required double amount,
    required String mode,
    String? modeReference,
    String? note,
  }) async {
    assert(type == 'DEPOSIT' || type == 'REFUND');
    final path = type == 'DEPOSIT' ? 'deposit' : 'refund';
    final body = <String, dynamic>{
      'amount': amount,
      'mode': mode,
      if (modeReference != null && modeReference.isNotEmpty)
        'modeReference': modeReference,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final res = await _client.post('/parties/$partyId/caution/$path', body: body);
    if (res.statusCode != 201) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(decoded['error'] ?? 'Failed to record caution');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return _d(decoded['balance']);
  }

  /// Set off caution against an invoice. Returns the new held balance.
  Future<double> adjust({
    required int partyId,
    required int invoiceId,
    required double amount,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'invoiceId': invoiceId,
      'amount': amount,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final res = await _client.post('/parties/$partyId/caution/adjust', body: body);
    if (res.statusCode != 201) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(decoded['error'] ?? 'Failed to adjust caution');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return _d(decoded['balance']);
  }

  /// Forfeit (keep) part of the deposit on the party's default. Returns the
  /// new held balance. [gstTreatment] is 'NONE' or 'SUPPLY'.
  Future<double> forfeit({
    required int partyId,
    required double amount,
    required String gstTreatment,
    String? note,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'gstTreatment': gstTreatment,
      if (note != null && note.isNotEmpty) 'note': note,
    };
    final res = await _client.post('/parties/$partyId/caution/forfeit', body: body);
    if (res.statusCode != 201) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(decoded['error'] ?? 'Failed to forfeit caution');
    }
    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    return _d(decoded['balance']);
  }

  /// Shop-wide caution-request inbox. Defaults to PENDING server-side.
  Future<List<CautionRequest>> listShopRequests({String status = 'PENDING'}) async {
    final res = await _client.get(
      '/caution-requests',
      queryParameters: {'status': status, 'limit': '50'},
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load caution requests');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>)
        .map((e) => _requestFromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CautionRequest> approveRequest(int partyId, int requestId) async {
    final res =
        await _client.post('/parties/$partyId/caution-requests/$requestId/approve');
    if (res.statusCode != 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(decoded['error'] ?? 'Failed to approve request');
    }
    return _requestFromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<CautionRequest> rejectRequest(
    int partyId,
    int requestId, {
    String? reviewNote,
  }) async {
    final body = <String, dynamic>{
      if (reviewNote != null && reviewNote.isNotEmpty) 'reviewNote': reviewNote,
    };
    final res = await _client.post(
      '/parties/$partyId/caution-requests/$requestId/reject',
      body: body,
    );
    if (res.statusCode != 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(decoded['error'] ?? 'Failed to reject request');
    }
    return _requestFromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
