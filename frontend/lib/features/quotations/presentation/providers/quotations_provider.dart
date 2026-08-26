import 'package:flutter/foundation.dart';
import 'package:shopxy/features/quotations/data/datasources/quotations_remote_data_source.dart';
import 'package:shopxy/features/quotations/domain/entities/quotation.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class QuotationsProvider extends ChangeNotifier {
  QuotationsProvider(this._ds);
  final QuotationsRemoteDataSource _ds;

  List<Quotation> _items = const [];
  bool _loading = false;
  String? _error;
  bool _submitting = false;

  List<Quotation> get items => _items;
  bool get isLoading => _loading;
  String? get error => _error;
  bool get isSubmitting => _submitting;

  void reset() {
    _items = const [];
    _loading = false;
    _error = null;
    _submitting = false;
    notifyListeners();
  }

  Future<void> load({String? status}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _items = await _ds.list(status: status);
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<Quotation> create({
    required String partyId,
    required List<Map<String, dynamic>> items,
    String? note,
    String? placeOfSupplyStateCode,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      final q = await _ds.create(
        partyId: partyId,
        items: items,
        note: note,
        placeOfSupplyStateCode: placeOfSupplyStateCode,
      );
      return q;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> cancel(String id) async {
    final updated = await _ds.cancel(id);
    _items = [
      for (final q in _items) if (q.id == id) updated else q,
    ];
    notifyListeners();
  }

  Future<Quotation> respond(
    String id, {
    required List<Map<String, dynamic>> items,
    String? note,
    String? placeOfSupplyStateCode,
  }) async {
    _submitting = true;
    notifyListeners();
    try {
      final q = await _ds.respond(
        id,
        items: items,
        note: note,
        placeOfSupplyStateCode: placeOfSupplyStateCode,
      );
      _items = [
        for (final x in _items) if (x.id == id) q else x,
      ];
      return q;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  Future<void> declineRequest(String id, {String? declineNote}) async {
    final updated = await _ds.declineRequest(id, declineNote: declineNote);
    _items = [
      for (final q in _items) if (q.id == id) updated else q,
    ];
    notifyListeners();
  }
}
