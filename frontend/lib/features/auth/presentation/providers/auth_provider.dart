import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shopxy/core/auth/remembered_accounts.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/network/offline/offline_errors.dart';
import 'package:shopxy/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy/features/auth/domain/entities/auth_user.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_strings.dart';

class AuthProvider extends ChangeNotifier with WidgetsBindingObserver {
  AuthProvider(this._dataSource, this._tokenManager) {
    WidgetsBinding.instance.addObserver(this);
  }

  final AuthRemoteDataSource _dataSource;
  final TokenManager _tokenManager;
  final RememberedAccountsStore _rememberStore = RememberedAccountsStore();

  final List<VoidCallback> _onClearCallbacks = <VoidCallback>[];

  AuthUser? _user;
  bool _isLoading = true;

  bool _gstEffectiveDatePromptDismissed = false;

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  bool get shouldPromptGstEffectiveDate =>
      _user != null &&
      _user!.registrationType == 'REGULAR' &&
      (_user!.shopGstin?.isNotEmpty ?? false) &&
      _user!.gstEffectiveFrom == null &&
      !_gstEffectiveDatePromptDismissed;

  void dismissGstEffectiveDatePrompt() {
    if (_gstEffectiveDatePromptDismissed) return;
    _gstEffectiveDatePromptDismissed = true;
    notifyListeners();
  }

  Future<void> init() async {
    if (_tokenManager.accessToken == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      final me = await _dataSource.getMe();
      if (!me.isOwner) {
        await _tokenManager.clear();
      } else {
        _user = me;
      }
    } catch (_) {
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await _dataSource.login(email, password);
    if (!result.user.isOwner) {
      await _tokenManager.clear();
      throw Exception(AppStrings.customerAccountBlocked);
    }
    await _tokenManager.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    _user = await _dataSource.getMe(bypassCache: true);
    await _rememberThisDevice();
    notifyListeners();
  }

  Future<bool> loginWithGoogle(String idToken) async {
    final result = await _dataSource.googleAuth(idToken);
    if (!result.user.isOwner) {
      await _tokenManager.clear();
      throw Exception(AppStrings.customerAccountBlocked);
    }
    await _applySession((
      user: result.user,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    ));
    return result.needsPinSetup;
  }

  Future<void> setRecoveryPin(String pin) async {
    await _dataSource.setRecoveryPin(pin);
    _user = await _dataSource.getMe(bypassCache: true);
    notifyListeners();
  }

  Future<void> loginWithRecoveryPin(String email, String pin) async {
    final result = await _dataSource.loginWithRecoveryPin(email, pin);
    if (!result.user.isOwner) {
      await _tokenManager.clear();
      throw Exception(AppStrings.customerAccountBlocked);
    }
    await _applySession(result);
  }

  Future<RegisterResult> register(
    String name,
    String email,
    String password, {
    String? shopName,
  }) async {
    final res = await _dataSource.register(
      name,
      email,
      password,
      shopName: shopName,
    );
    if (res.pending) return RegisterPending(res.email);
    await _applySession(res.session!);
    return const RegisterSignedIn();
  }

  Future<void> verifyEmail(String email, String otp) async {
    await _applySession(await _dataSource.verifyEmail(email, otp));
  }

  Future<void> resendOtp(String email) => _dataSource.resendOtp(email);

  Future<List<SessionInfo>> listSessions() => _dataSource.listSessions();
  Future<void> revokeSession(String id) => _dataSource.revokeSession(id);
  Future<int> revokeOtherSessions() => _dataSource.revokeOtherSessions();

  Future<void> _applySession(AuthResult session) async {
    await _tokenManager.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    _user = await _dataSource.getMe(bypassCache: true);
    await _rememberThisDevice();
    notifyListeners();
  }

  Future<void> _rememberThisDevice() async {
    final u = _user;
    if (u == null) return;
    try {
      final token = await _dataSource.issueRememberToken(
        label: '${defaultTargetPlatform.name} merchant',
      );
      await _rememberStore.save(
        RememberedAccount(
          id: u.id,
          name: u.name,
          email: u.email,
          avatarUrl: u.avatarUrl,
        ),
        token,
      );
    } catch (e) {
      debugPrint('remember-device: could not save this account — $e');
    }
  }

  Future<List<RememberedAccount>> rememberedAccounts() => _rememberStore.list();

  Future<void> loginWithRemembered(String id) async {
    final token = await _rememberStore.tokenFor(id);
    if (token == null) {
      await _rememberStore.remove(id);
      throw Exception('This saved sign-in is no longer available');
    }
    final RememberLoginResult result;
    try {
      result = await _dataSource.rememberLogin(token);
    } catch (e) {
      if (!isTransportError(e)) {
        await _rememberStore.remove(id);
      }
      rethrow;
    }
    if (!result.user.isOwner) {
      await _tokenManager.clear();
      await _rememberStore.remove(id);
      throw Exception(AppStrings.customerAccountBlocked);
    }
    await _tokenManager.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    await _rememberStore.save(
      RememberedAccount(
        id: result.user.id,
        name: result.user.name,
        email: result.user.email,
        avatarUrl: result.user.avatarUrl,
      ),
      result.rememberToken,
    );
    _user = await _dataSource.getMe(bypassCache: true);
    notifyListeners();
  }

  Future<void> forgetRemembered(String id) async {
    final token = await _rememberStore.tokenFor(id);
    if (token != null) {
      try {
        await _dataSource.forgetRemember(token);
      } catch (_) {}
    }
    await _rememberStore.remove(id);
    notifyListeners();
  }

  Future<void> refreshUser() async {
    _user = await _dataSource.getMe(bypassCache: true);
    notifyListeners();
  }

  static const refreshCooldown = AppDurations.snackbarLong;
  DateTime? _lastManualRefresh;

  Duration get refreshCooldownRemaining {
    final at = _lastManualRefresh;
    if (at == null) return Duration.zero;
    final left = refreshCooldown - DateTime.now().difference(at);
    return left.isNegative ? Duration.zero : left;
  }

  Future<bool> manualRefresh() async {
    if (refreshCooldownRemaining > Duration.zero) return false;
    _lastManualRefresh = DateTime.now();
    await refreshUser();
    return true;
  }

  String? _permsVersion;
  bool _resyncing = false;

  void notePermsVersion(String version) {
    if (_user == null) return;
    if (_permsVersion == null) {
      _permsVersion = version;
      return;
    }
    if (version == _permsVersion || _resyncing) return;
    _permsVersion = version;
    _resyncing = true;
    refreshUser().whenComplete(() => _resyncing = false).catchError((_) {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isAuthenticated) {
      refreshUser().catchError((_) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    _gstEffectiveDatePromptDismissed = false;
    for (final cb in _onClearCallbacks) {
      cb();
    }
    notifyListeners();
  }

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
    String? gstEffectiveFrom,
    String? shopPan,
    String? upiVpa,
    String? avatarUrl,
    bool clearAvatar = false,
    String? phoneNumber,
    bool clearPhone = false,
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
      gstEffectiveFrom: gstEffectiveFrom,
      shopPan: shopPan,
      upiVpa: upiVpa,
      avatarUrl: avatarUrl,
      clearAvatar: clearAvatar,
      phoneNumber: phoneNumber,
      clearPhone: clearPhone,
    );
    _user = updated;
    notifyListeners();
  }

  Future<void> updateAvatar(String? avatarUrl) =>
      updateProfile(avatarUrl: avatarUrl, clearAvatar: avatarUrl == null);

  Future<void> changePassword(String current, String next) async {
    await _dataSource.changePassword(current, next);
  }

  Future<List<int>> exportData() => _dataSource.exportData();

  Future<void> deleteAccount(String currentPassword) async {
    await _dataSource.deleteAccount(currentPassword);
    await _tokenManager.clear();
    _user = null;
    for (final cb in _onClearCallbacks) {
      cb();
    }
    notifyListeners();
  }

  Future<void> clearAuth() async {
    await _tokenManager.clear();
    _user = null;
    _gstEffectiveDatePromptDismissed = false;
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
