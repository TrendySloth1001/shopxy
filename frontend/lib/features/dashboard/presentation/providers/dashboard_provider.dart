import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopxy/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider(this._dataSource);
  final DashboardRemoteDataSource _dataSource;

  static const _periodKey = 'sx_dashboard_period';

  DashboardStats? _stats;
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _error;
  DashboardPeriod _period = DashboardPeriod.today;

  DashboardStats? get stats => _stats;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get error => _error;
  DashboardPeriod get period => _period;

  Future<void> bootstrap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_periodKey);
      if (saved != null) _period = DashboardPeriod.fromName(saved);
    } catch (_) {
    }
    await loadStats();
  }

  Future<void> changePeriod(DashboardPeriod period) async {
    if (period == _period) return;
    _period = period;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_periodKey, period.query);
    } catch (_) {
    }
    await loadStats();
  }

  Future<void> loadStats() async {
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
