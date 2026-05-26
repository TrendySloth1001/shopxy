import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy_customer/features/auth/domain/entities/auth_user.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._dataSource, this._tokenManager);

  final AuthRemoteDataSource _dataSource;
  final TokenManager _tokenManager;

  /// Callbacks invoked by [clearAuth] to drop user-scoped state from
  /// other providers (orders, addresses, cart, …). Wired in main.dart
  /// at app start; lives here so we don't sprinkle that logic across
  /// `onUnauthorized` and `logout`.
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
    notifyListeners();
  }

  /// Updates the user's display name. The data source returns the
  /// fresh AuthUser so we don't need a follow-up `getMe`.
  Future<void> updateName(String name) async {
    final fresh = await _dataSource.updateProfile(name: name);
    _user = fresh;
    notifyListeners();
  }

  /// Wraps the password-change endpoint. Surfaces backend errors so
  /// the caller can render them inline.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _dataSource.changePassword(currentPassword, newPassword);

  /// Register a callback to run whenever the auth state is cleared
  /// (refresh failure, explicit logout). Used to reset user-scoped
  /// providers without coupling AuthProvider to their concrete types.
  void registerOnClear(VoidCallback callback) {
    _onClearCallbacks.add(callback);
  }

  /// Called by ApiClient when a refresh fails — forces re-login. Also
  /// resets user-scoped providers (orders, addresses, cart, etc.) so
  /// the next sign-in starts with a clean slate.
  void clearAuth() {
    _tokenManager.clear();
    _user = null;
    for (final cb in _onClearCallbacks) {
      cb();
    }
    notifyListeners();
  }
}
