import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopxy/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._dataSource);
  final DashboardRemoteDataSource _dataSource;

  /// Persisted selected window — same key/behaviour as merchant-web's
  /// `sx_dashboard_period` localStorage entry, so the app reopens on the
  /// last window the merchant used (not always "today").
  static const _periodKey = 'sx_dashboard_period';

  DashboardStats? _stats;
  bool _isLoading = false; // first load (no data yet)
  bool _isRefreshing = false; // period change / manual refresh
  String? _error;
  DashboardPeriod _period = DashboardPeriod.today;

  DashboardStats? get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;
  DashboardPeriod get period => _period;

  /// Restore the last-used window from storage, then load. Call once on
  /// first mount instead of [loadStats] so the dashboard opens on the same
  /// period the merchant left it (matching web/desktop).
  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_periodKey);
      if (saved != null) _period = DashboardPeriod.fromName(saved);
    } catch (_) {
      // keep the default period on any storage error
    }
    await loadStats();
  }

  /// Switch the rolling window and refetch. No-op if already selected.
  Future<void> changePeriod(DashboardPeriod period) async {
    if (period == _period) return;
    _period = period;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_periodKey, period.query);
    } catch (_) {
      // persistence is best-effort
    }
    await loadStats();
  }

  Future<void> loadStats() async {
    // A first load (no data yet) shows the skeleton; subsequent loads dim
    // the period-scoped sections instead of blanking the screen.
    if (_stats == null) {
      _isLoading = true;
    } else {
      _isRefreshing = true;
    }
    _error = null;
    notifyListeners();

    try {
      _stats = await _dataSource.getStats(_period);
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      _isRefreshing = false;
      notifyListeners();
    }
  }
}
