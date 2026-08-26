import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy_customer/features/auth/domain/entities/auth_user.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._dataSource, this._tokenManager);

  final AuthRemoteDataSource _dataSource;
  final TokenManager _tokenManager;

  final List<VoidCallback> _onClearCallbacks = <VoidCallback>[];

  final List<VoidCallback> _onExplicitLogoutCallbacks = <VoidCallback>[];

  AuthUser? _user;
  bool _isLoading = true;

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  bool get isGuest => !_isLoading && _user == null;

  Future<void> init() async {
    if (_tokenManager.accessToken == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      final me = await _dataSource.getMe();
      if (me.isOwner) {
        await _tokenManager.clear();
      } else {
        _user = me;
      }
    } catch (_) {
      await _tokenManager.clear();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await _dataSource.login(email, password);
    if (result.user.isOwner) {
      await _tokenManager.clear();
      throw Exception(AppStrings.merchantAccountBlocked);
    }
    await _tokenManager.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    _user = result.user;
    notifyListeners();
  }

  Future<RegisterResult> register(
    String name,
    String email,
    String password, {
    required bool acceptedTerms,
    required bool acceptedPrivacy,
  }) async {
    final res = await _dataSource.register(
      name,
      email,
      password,
      acceptedTerms: acceptedTerms,
      acceptedPrivacy: acceptedPrivacy,
    );
    if (res.pending) return RegisterPending(res.email);
    await _applySession(res.session!);
    return const RegisterSignedIn();
  }

  Future<void> verifyEmail(String email, String otp) async {
    await _applySession(await _dataSource.verifyEmail(email, otp));
  }

  Future<void> resendOtp(String email) => _dataSource.resendOtp(email);

  Future<void> _applySession(AuthResult session) async {
    await _tokenManager.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    _user = session.user;
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
    for (final cb in _onExplicitLogoutCallbacks) {
      cb();
    }
    notifyListeners();
  }

  Future<void> updateName(String name) async {
    final fresh = await _dataSource.updateProfile(name: name);
    _user = fresh;
    notifyListeners();
  }

  Future<void> updateAvatar(String? avatarUrl) async {
    final fresh = await _dataSource.updateProfile(
      avatarUrl: avatarUrl,
      clearAvatar: avatarUrl == null,
    );
    _user = fresh;
    notifyListeners();
  }

  Future<void> updatePhone(String? phoneNumber) async {
    final clean = phoneNumber?.trim();
    final fresh = await _dataSource.updateProfile(
      phoneNumber: (clean?.isEmpty ?? true) ? null : clean,
      clearPhone: clean == null || clean.isEmpty,
    );
    _user = fresh;
    notifyListeners();
  }

  Future<void> updateNotificationPrefs({
    bool? notifyOrders,
    bool? notifyDeals,
    bool? notifyAccount,
    bool? notifyMessages,
    bool? pushEnabled,
    bool? smsEnabled,
  }) async {
    final fresh = await _dataSource.updateProfile(
      notifyOrders: notifyOrders,
      notifyDeals: notifyDeals,
      notifyAccount: notifyAccount,
      notifyMessages: notifyMessages,
      pushEnabled: pushEnabled,
      smsEnabled: smsEnabled,
    );
    _user = fresh;
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _dataSource.changePassword(currentPassword, newPassword);

  void registerOnClear(VoidCallback callback) {
    _onClearCallbacks.add(callback);
  }

  void registerOnExplicitLogout(VoidCallback callback) {
    _onExplicitLogoutCallbacks.add(callback);
  }

  Future<void> clearAuth() async {
    await _tokenManager.clear();
    _user = null;
    for (final cb in _onClearCallbacks) {
      cb();
    }
    notifyListeners();
  }
}

sealed class RegisterResult {
  const RegisterResult();
}

class RegisterPending extends RegisterResult {
  const RegisterPending(this.email);
  final String email;
}

class RegisterSignedIn extends RegisterResult {
  const RegisterSignedIn();
}
