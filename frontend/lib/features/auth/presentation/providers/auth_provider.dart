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

  /// Called by ApiClient when a refresh fails — forces re-login.
  void clearAuth() {
    _tokenManager.clear();
    _user = null;
    notifyListeners();
  }
}
