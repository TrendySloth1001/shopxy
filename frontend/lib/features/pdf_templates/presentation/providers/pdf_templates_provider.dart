import 'package:flutter/foundation.dart';

import 'package:shopxy/features/pdf_templates/data/datasources/pdf_templates_remote_data_source.dart';
import 'package:shopxy/features/pdf_templates/domain/entities/pdf_template.dart';
import 'package:shopxy/shared/utils/error_text.dart';

/// Owns the read-only catalog of ~7 preset PDF templates (id/name/
/// description). The shop's CURRENT selection lives on [Shop.pdfTemplateId]
/// and is read/saved through `ShopProvider` — this provider only fetches
/// the catalog, so a new preset shows up without an app release.
class PdfTemplatesProvider extends ChangeNotifier {
  PdfTemplatesProvider(this._ds);
  final PdfTemplatesRemoteDataSource _ds;

  List<PdfTemplate> _templates = const [];
  bool _isLoading = false;
  String? _error;
  bool _hasLoadedOnce = false;

  List<PdfTemplate> get templates => _templates;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasLoadedOnce => _hasLoadedOnce;

  void reset() {
    _templates = const [];
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
      final list = await _ds.list();
      list.sort((a, b) => a.order.compareTo(b.order));
      _templates = list;
      _hasLoadedOnce = true;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
