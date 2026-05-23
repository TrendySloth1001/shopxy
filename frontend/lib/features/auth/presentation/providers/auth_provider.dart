import 'package:flutter/material.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy/features/auth/domain/entities/auth_user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._dataSource, this._tokenManager);

  final AuthRemoteDataSource _dataSource;
  final TokenManager _tokenManager;

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
    notifyListeners();
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
    notifyListeners();
  }

  /// Called by ApiClient when a refresh fails — forces re-login.
  void clearAuth() {
    _tokenManager.clear();
    _user = null;
    notifyListeners();
  }
}
