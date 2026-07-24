import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/stock_adjustments/domain/entities/stock_adjustment.dart';

class StockAdjustmentsRemoteDataSource {
  const StockAdjustmentsRemoteDataSource(this._client);
  final ApiClient _client;

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static StockAdjustmentItem _itemFromJson(Map<String, dynamic> json) {
    return StockAdjustmentItem(
      id: json['id'].toString(),
      productId: json['productId'].toString(),
      productName: json['productName'] as String,
      productSku: json['productSku'] as String,
      unit: json['unit'] as String? ?? 'PCS',
      quantity: _toDouble(json['quantity']),
      unitCost: json['unitCost'] != null ? _toDouble(json['unitCost']) : null,
      note: json['note'] as String?,
    );
  }

  static StockAdjustment _fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List?)
            ?.map((e) => _itemFromJson(e as Map<String, dynamic>))
            .toList() ??
        const <StockAdjustmentItem>[];
    final createdBy = json['createdBy'] as Map<String, dynamic>?;
    final countMap = json['_count'] as Map<String, dynamic>?;
    return StockAdjustment(
      id: json['id'].toString(),
      adjustmentNo: json['adjustmentNo'] as String,
      reasonCode: json['reasonCode'] as String,
      direction: json['direction'] as String,
      note: json['note'] as String?,
      createdByName: createdBy?['name'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: items,
      itemCount: countMap?['items'] as int? ?? items.length,
    );
  }

  Future<List<StockAdjustment>> list({String? reasonCode, int page = 1, int limit = 50}) async {
    final params = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (reasonCode != null) params['reasonCode'] = reasonCode;
    final response = await _client.get('/stock-adjustments', queryParameters: params);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List;
    return data.map((e) => _fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<StockAdjustment> getById(String id) async {
    final response = await _client.get('/stock-adjustments/$id');
    return _fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<StockAdjustment> create({
    required String reasonCode,
    String? direction,
    String? note,
    required List<({String productId, double quantity, double? unitCost, String? note})> items,
  }) async {
    final body = <String, dynamic>{
      'reasonCode': reasonCode,
      'direction': ?direction,
      if (note != null && note.isNotEmpty) 'note': note,
      'items': items
          .map((i) => {
                'productId': i.productId,
                'quantity': i.quantity,
                if (i.unitCost != null) 'unitCost': i.unitCost,
                if (i.note != null && i.note!.isNotEmpty) 'note': i.note,
              })
          .toList(),
    };
    final response = await _client.post('/stock-adjustments', body: body);
    return _fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
