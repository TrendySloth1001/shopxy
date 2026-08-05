import 'package:flutter/foundation.dart';
import 'package:shopxy/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:shopxy/features/reports/domain/entities/sales_report.dart';
import 'package:shopxy/shared/utils/error_text.dart';

enum ReportKind { sales, purchases, gst, pnl }

class ReportsProvider extends ChangeNotifier {
  ReportsProvider(this._ds);
  final ReportsRemoteDataSource _ds;

  // Default to the last 30 days; users can re-pick via the date selector.
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  DateTime get from => _from;
  DateTime get to => _to;

  ReportKind _kind = ReportKind.sales;
  ReportKind get kind => _kind;

  bool _loading = false;
  bool get isLoading => _loading;
  String? _error;
  String? get error => _error;

  SalesReport? _sales;
  PurchasesReport? _purchases;
  GstReport? _gst;
  PnlReport? _pnl;

  SalesReport? get sales => _sales;
  PurchasesReport? get purchases => _purchases;
  GstReport? get gst => _gst;
  PnlReport? get pnl => _pnl;

  /// Drops cached report data on logout — these are financial figures
  /// (sales/GST/P&L), so the next account on this device must never see
  /// the previous shop's numbers flash on screen.
  void reset() {
    _sales = null;
    _purchases = null;
    _gst = null;
    _pnl = null;
    _loading = false;
    _error = null;
    notifyListeners();
  }

  void setRange(DateTime from, DateTime to) {
    _from = from;
    _to = to;
    notifyListeners();
    load();
  }

  void setKind(ReportKind kind) {
    if (_kind == kind) return;
    _kind = kind;
    notifyListeners();
    if (_currentIsLoaded(kind)) return;
    load();
  }

  bool _currentIsLoaded(ReportKind k) {
    switch (k) {
      case ReportKind.sales:
        return _sales != null;
      case ReportKind.purchases:
        return _purchases != null;
      case ReportKind.gst:
        return _gst != null;
      case ReportKind.pnl:
        return _pnl != null;
    }
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      switch (_kind) {
        case ReportKind.sales:
          _sales = await _ds.sales(_from, _to);
          break;
        case ReportKind.purchases:
          _purchases = await _ds.purchases(_from, _to);
          break;
        case ReportKind.gst:
          _gst = await _ds.gst(_from, _to);
          break;
        case ReportKind.pnl:
          _pnl = await _ds.pnl(_from, _to);
          break;
      }
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Force a refresh of the currently selected report.
  Future<void> refresh() async {
    switch (_kind) {
      case ReportKind.sales:
        _sales = null;
        break;
      case ReportKind.purchases:
        _purchases = null;
        break;
      case ReportKind.gst:
        _gst = null;
        break;
      case ReportKind.pnl:
        _pnl = null;
        break;
    }
    await load();
  }
}
