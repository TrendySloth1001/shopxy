import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy_customer/features/auth/domain/entities/auth_user.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._dataSource, this._tokenManager);

  final AuthRemoteDataSource _dataSource;
  final TokenManager _tokenManager;

  /// Callbacks invoked by [clearAuth] to drop user-scoped state from
  /// other providers (orders, addresses, cart, …). Wired in main.dart
  /// at app start; lives here so we don't sprinkle that logic across
  /// `onUnauthorized` and `logout`.
  ///
  /// These run on EVERY session reset — including transient 401-refresh
  /// failures where the user is the same person about to log back in.
  /// For state that should ONLY drop on an explicit "I want to log out"
  /// gesture (e.g. the basket, persisted recently-viewed) use
  /// [_onExplicitLogoutCallbacks] instead.
  final List<VoidCallback> _onClearCallbacks = <VoidCallback>[];

  /// Callbacks invoked ONLY when the user explicitly signs out via
  /// [logout]. Cart, persisted preferences scoped to the previous
  /// session, etc.
  final List<VoidCallback> _onExplicitLogoutCallbacks = <VoidCallback>[];

  AuthUser? _user;
  bool _isLoading = true;

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  /// True once the boot token-check has settled and there's no signed-in
  /// user — i.e. the app is in public-browse mode. Distinct from
  /// `!isAuthenticated`, which is also true mid-boot (when we don't yet
  /// know). Screens use this to render sign-in CTAs without flashing
  /// them under the splash.
  bool get isGuest => !_isLoading && _user == null;

  /// Called on app start to restore session from stored tokens.
  Future<void> init() async {
    if (_tokenManager.accessToken == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      final me = await _dataSource.getMe();
      if (me.isOwner) {
        // Cross-app session: a merchant (OWNER) account's tokens must
        // not restore into the customer app. Drop them and boot to the
        // sign-in screen as a guest.
        await _tokenManager.clear();
      } else {
        _user = me;
      }
    } catch (_) {
      // Token invalid/expired and refresh also failed → force login
      await _tokenManager.clear();
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await _dataSource.login(email, password);
    if (result.user.isOwner) {
      // Merchant account — not allowed in the customer app. Discard the
      // freshly-issued tokens and surface a clear message; never set
      // `_user`, so no navigation into the customer shell occurs.
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

  Future<void> register(
    String name,
    String email,
    String password, {
    required bool acceptedTerms,
    required bool acceptedPrivacy,
  }) async {
    final result = await _dataSource.register(
      name,
      email,
      password,
      acceptedTerms: acceptedTerms,
      acceptedPrivacy: acceptedPrivacy,
    );
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
    // Explicit logout: run the broader cleanup that drops the basket
    // and any other session-scoped state we deliberately keep across
    // transient 401-refresh failures.
    for (final cb in _onClearCallbacks) {
      cb();
    }
    for (final cb in _onExplicitLogoutCallbacks) {
      cb();
    }
    notifyListeners();
  }

  /// Updates the user's display name. The data source returns the
  /// fresh AuthUser so we don't need a follow-up `getMe`.
  Future<void> updateName(String name) async {
    final fresh = await _dataSource.updateProfile(name: name);
    _user = fresh;
    notifyListeners();
  }

  /// Updates the user's avatar URL. Pass `null` to clear it (e.g. a
  /// future "Remove photo" button). The fresh AuthUser carries the
  /// new url so we can re-render without a follow-up GET.
  Future<void> updateAvatar(String? avatarUrl) async {
    final fresh = await _dataSource.updateProfile(
      avatarUrl: avatarUrl,
      clearAvatar: avatarUrl == null,
    );
    _user = fresh;
    notifyListeners();
  }

  /// Updates the user's phone number. P5 surface; lives here so the
  /// edit profile page has one save path. Pass null/empty to clear.
  Future<void> updatePhone(String? phoneNumber) async {
    final clean = phoneNumber?.trim();
    final fresh = await _dataSource.updateProfile(
      phoneNumber: (clean?.isEmpty ?? true) ? null : clean,
      clearPhone: clean == null || clean.isEmpty,
    );
    _user = fresh;
    notifyListeners();
  }

  /// Patches one or more notification preference flags. Only the
  /// passed-in values are sent; everything else stays put on the
  /// server. Returns the fresh AuthUser so the prefs page can pick up
  /// the new state without a follow-up GET.
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

  /// Register a callback that runs ONLY on explicit [logout], not on
  /// transient 401-refresh failure. Use for state we deliberately keep
  /// across a refresh hiccup (e.g. the cart).
  void registerOnExplicitLogout(VoidCallback callback) {
    _onExplicitLogoutCallbacks.add(callback);
  }

  /// Called by ApiClient when a refresh fails — forces re-login. Also
  /// resets user-scoped providers (orders, addresses, cart, etc.) so
  /// the next sign-in starts with a clean slate.
  ///
  /// Async so callers (e.g. main.dart's `onUnauthorized` wiring) can
  /// await the secure-storage delete before allowing a re-login that
  /// would otherwise race the still-pending write.
  Future<void> clearAuth() async {
    await _tokenManager.clear();
    _user = null;
    for (final cb in _onClearCallbacks) {
      cb();
    }
    notifyListeners();
  }
}
