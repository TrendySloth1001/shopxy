import 'package:flutter/foundation.dart';

import 'package:shopxy/features/invoice_numbering/data/datasources/invoice_numbering_remote_data_source.dart';
import 'package:shopxy/features/invoice_numbering/domain/entities/numbering_scheme.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class InvoiceNumberingProvider extends ChangeNotifier {
  InvoiceNumberingProvider(this._ds);
  final InvoiceNumberingRemoteDataSource _ds;

  List<NumberingScheme> _schemes = const [];
  bool _isLoading = false;
  String? _error;
  bool _hasLoadedOnce = false;

  List<NumberingScheme> get schemes => _schemes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLoadedOnce => _hasLoadedOnce;

  void reset() {
    _schemes = const [];
    _isLoading = false;
    _error = null;
    _hasLoadedOnce = false;
    notifyListeners();
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _schemes = await _ds.list();
      _hasLoadedOnce = true;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _replace(NumberingScheme updated) {
    _schemes = [
      for (final s in _schemes)
        if (s.series == updated.series) updated else s,
    ];
    notifyListeners();
  }

  Future<NumberingScheme> save(
    NumberingSeries series,
    Map<String, dynamic> patch,
  ) async {
    final updated = await _ds.update(series, patch);
    _replace(updated);
    return updated;
  }

  Future<NumberingScheme> setNextNumber(
    NumberingSeries series,
    int startAt,
  ) async {
    final updated = await _ds.setNextNumber(series, startAt);
    _replace(updated);
    return updated;
  }
}
