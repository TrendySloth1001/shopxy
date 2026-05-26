import 'package:flutter/material.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy/features/auth/domain/entities/auth_user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._dataSource, this._tokenManager);

  final AuthRemoteDataSource _dataSource;
  final TokenManager _tokenManager;

  /// Callbacks invoked by [clearAuth] / [logout] to drop user-scoped
  /// state held by other providers (products, orders, invoices, …).
  /// Wired in main.dart at app start so cached lists from user A
  /// don't leak into user B's view when they sign in on the same
  /// device.
  final List<VoidCallback> _onClearCallbacks = <VoidCallback>[];

  AuthUser? _user;
  bool _isLoading = true;

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  /// Called on app start to restore session from stored tokens.
  Future<void> init() async {
    if (_tokenManager.accessToken == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      _user = await _dataSource.getMe();
    } catch (_) {
      // Token invalid/expired and refresh also failed → force login
      await _tokenManager.clear();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await _dataSource.login(email, password);
    await _tokenManager.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    _user = result.user;
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    final result = await _dataSource.register(name, email, password);
    await _tokenManager.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    _user = result.user;
    notifyListeners();
  }

  Future<void> logout() async {
    final rt = await _tokenManager.getRefreshToken();
    if (rt != null) {
      try {
        await _dataSource.logout(rt);
      } catch (_) {}
    }
    await _tokenManager.clear();
    _user = null;
    for (final cb in _onClearCallbacks) {
      cb();
    }
    notifyListeners();
  }

  /// Register a callback to run whenever auth is cleared (transient
  /// 401-refresh failure OR explicit logout). Used by main.dart to
  /// reset every per-user provider so user A's data never appears in
  /// user B's session on the same device.
  void registerOnClear(VoidCallback callback) {
    _onClearCallbacks.add(callback);
  }

  Future<void> updateProfile({
    String? name,
    bool? emailNotifications,
    String? shopName,
    String? shopAddress,
    String? shopCity,
    String? shopState,
    String? shopStateCode,
    String? shopPinCode,
    String? shopGstin,
    String? shopPan,
    String? upiVpa,
  }) async {
    final updated = await _dataSource.updateProfile(
      name: name,
      emailNotifications: emailNotifications,
      shopName: shopName,
      shopAddress: shopAddress,
      shopCity: shopCity,
      shopState: shopState,
      shopStateCode: shopStateCode,
      shopPinCode: shopPinCode,
      shopGstin: shopGstin,
      shopPan: shopPan,
      upiVpa: upiVpa,
    );
    _user = updated;
    notifyListeners();
  }

  Future<void> changePassword(String current, String next) async {
    await _dataSource.changePassword(current, next);
  }

  /// DPDP right-to-access — returns the JSON bytes so the caller can
  /// hand them to the share sheet / file system without an extra
  /// encode-decode round trip.
  Future<List<int>> exportData() => _dataSource.exportData();

  /// DPDP right-to-erasure. On success clears the local session so the
  /// app returns to the login page — the backend has already revoked
  /// every refresh token by deleting the user row.
  Future<void> deleteAccount(String currentPassword) async {
    await _dataSource.deleteAccount(currentPassword);
    await _tokenManager.clear();
    _user = null;
    // Same fan-out as logout — the registered providers (Products,
    // Invoices, Shop, …) must drop the deleted account's cached lists
    // so the LoginPage that follows doesn't briefly show their data.
    for (final cb in _onClearCallbacks) {
      cb();
    }
    notifyListeners();
  }

  /// Called by ApiClient when a refresh fails — forces re-login.
  ///
  /// Returns the [Future] from the token clear so callers in `main()`
  /// that need to know the storage write has finished can await it
  /// (the storage delete is async; without awaiting, a rapid re-login
  /// can race the still-pending delete).
  Future<void> clearAuth() async {
    await _tokenManager.clear();
    _user = null;
    for (final cb in _onClearCallbacks) {
      cb();
    }
    notifyListeners();
  }
}
