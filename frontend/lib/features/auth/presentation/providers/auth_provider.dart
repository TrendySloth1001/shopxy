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
    // Re-pull /auth/me when the app returns to the foreground so a
    // permission/role change the owner made while the staffer was away
    // is reflected (hidden/locked controls update) WITHOUT a re-login.
    WidgetsBinding.instance.addObserver(this);
  }

  final AuthRemoteDataSource _dataSource;
  final TokenManager _tokenManager;
  final RememberedAccountsStore _rememberStore = RememberedAccountsStore();

  /// Callbacks invoked by [clearAuth] / [logout] to drop user-scoped
  /// state held by other providers (products, orders, invoices, …).
  /// Wired in main.dart at app start so cached lists from user A
  /// don't leak into user B's view when they sign in on the same
  /// device.
  final List<VoidCallback> _onClearCallbacks = <VoidCallback>[];

  AuthUser? _user;
  bool _isLoading = true;

  /// True once the merchant dismisses the startup GST-effective-date nudge
  /// (see [showGstEffectiveDateSheet] from the dashboard) — kept for the
  /// rest of the session so it doesn't re-prompt on every rebuild. Reset on
  /// logout/401 alongside everything else, mirroring
  /// `LinkedAccountProvider._promptDismissed`.
  bool _gstEffectiveDatePromptDismissed = false;

  AuthUser? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;

  /// Whether the dashboard should nudge the merchant to declare their GST
  /// effective date — a REGULAR shop with a GSTIN on file but no date yet
  /// (either a pre-feature legacy shop, or one that skipped the sheet in
  /// edit-profile). COMPOSITION/UNREGISTERED shops never charge GST, so
  /// they're never nudged regardless of whether a GSTIN is on file.
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

  /// Called on app start to restore session from stored tokens.
  Future<void> init() async {
    if (_tokenManager.accessToken == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    try {
      // /auth/me is cached, so offline this returns the last-known profile and
      // the app boots into the shell instead of the login screen.
      final me = await _dataSource.getMe();
      if (!me.isOwner) {
        // Cross-app session: a customer account's tokens must not
        // restore into the merchant app. Drop them and boot to login.
        await _tokenManager.clear();
      } else {
        _user = me;
      }
    } catch (_) {
      // Deliberately does NOT clear the session, for any error.
      //
      // Deciding "the session is dead" here is not possible: `getMe` throws a
      // bare Exception('Session expired') for every non-200, so a 401 that came
      // back only because the *refresh* couldn't reach the server is
      // indistinguishable from one the server truly rejected. Treating both as
      // fatal is what signed merchants out on every restart — the access token
      // expires between launches, the refresh times out on a flaky network, and
      // the 401 that ApiClient returns precisely so we DON'T log out was being
      // read as proof that we should.
      //
      // Nothing is lost by staying quiet. `ApiClient._tryRefresh` already
      // clears the tokens itself when the server definitively refuses (401/403
      // on the refresh, or no refresh token at all) and fires `onUnauthorized`;
      // and `_RefreshOutcome.unavailable` deliberately keeps them. Both
      // verdicts are already correct one layer down. This layer's only job is
      // to not overrule them.
      //
      // Worst case on a launch we can't verify: no cached identity, so the user
      // sees the login screen this once — with the session still on disk, so
      // the next reachable launch restores it silently.
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await _dataSource.login(email, password);
    if (!result.user.isOwner) {
      // Customer account — not allowed in the merchant app. Discard the
      // freshly-issued tokens and surface a clear message; never set
      // `_user`, so the auth gate stays on the login screen.
      await _tokenManager.clear();
      throw Exception(AppStrings.customerAccountBlocked);
    }
    await _tokenManager.saveTokens(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    );
    // Re-fetch via /auth/me so the user carries shopRole/shopId (the
    // login response doesn't include them) — the auth gate routes on it.
    // Bypass cache: see _applySession for why a fresh sign-in shouldn't
    // serve a stale cached profile from a previous session as this user.
    _user = await _dataSource.getMe(bypassCache: true);
    await _rememberThisDevice();
    notifyListeners();
  }

  /// Sign in with a verified Google ID token. Returns whether this account
  /// still needs to set up its recovery PIN (new signups always do) — the
  /// caller routes to the setup screen when true. [_AuthGate]-equivalent
  /// callers should prefer `_user!.needsRecoveryPinSetup` after this
  /// resolves, since that's what survives an app restart; this return
  /// value is just to avoid an extra round-trip for the immediate redirect.
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

  /// Set (or replace) the recovery PIN used to sign in if Google is ever
  /// unreachable.
  Future<void> setRecoveryPin(String pin) async {
    await _dataSource.setRecoveryPin(pin);
    // Refresh so `_user.recoveryPinSetAt` reflects the change immediately —
    // the auth gate reads it to stop showing the setup screen. Bypass
    // cache for the same reason as refreshUser().
    _user = await _dataSource.getMe(bypassCache: true);
    notifyListeners();
  }

  /// Fallback sign-in for Google-only accounts when Google itself isn't
  /// reachable.
  Future<void> loginWithRecoveryPin(String email, String pin) async {
    final result = await _dataSource.loginWithRecoveryPin(email, pin);
    if (!result.user.isOwner) {
      await _tokenManager.clear();
      throw Exception(AppStrings.customerAccountBlocked);
    }
    await _applySession(result);
  }

  /// Start registration. Returns [RegisterPending] when the backend emailed an
  /// OTP (the UI must collect it via [verifyEmail]), or [RegisterSignedIn] when
  /// the account was created directly (OTP infra unavailable) and the session
  /// is already applied.
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

  /// Confirm the signup OTP → creates the account server-side and signs in.
  Future<void> verifyEmail(String email, String otp) async {
    await _applySession(await _dataSource.verifyEmail(email, otp));
  }

  /// Re-send the signup verification code.
  Future<void> resendOtp(String email) => _dataSource.resendOtp(email);

  // ── Sessions / devices ──────────────────────────────────────────────
  Future<List<SessionInfo>> listSessions() => _dataSource.listSessions();
  Future<void> revokeSession(String id) => _dataSource.revokeSession(id);
  Future<int> revokeOtherSessions() => _dataSource.revokeOtherSessions();

  /// Persist a fresh session and load the user — shared by register-fallback,
  /// OTP verification and (implicitly) the login paths.
  Future<void> _applySession(AuthResult session) async {
    await _tokenManager.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    // Bypass cache: this device may hold a stale cached profile from a
    // previous session as this same user (e.g. cached before they'd
    // finished onboarding a shop) — a fresh sign-in should always reflect
    // current server state, not a leftover snapshot.
    _user = await _dataSource.getMe(bypassCache: true);
    await _rememberThisDevice();
    notifyListeners();
  }

  // ── Device-remember: one-tap return sign-in ──────────────────────────

  /// Best-effort: mint + store a device-remember credential for [_user] so
  /// they can one-tap back in after a normal logout. Never blocks sign-in.
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
      // Remembering is a convenience — a failure must not affect sign-in, so
      // this stays swallowed. But it must not be *silent*: this failing for
      // every user (the remember_tokens table was missing, so /auth/remember
      // 500'd) looked identical to the feature not existing, because the login
      // picker renders nothing on an empty list. One debug line is the
      // difference between "no widget on the login screen" and a diagnosis.
      debugPrint('remember-device: could not save this account — $e');
    }
  }

  /// Accounts to show on the login picker (profiles only; no tokens).
  Future<List<RememberedAccount>> rememberedAccounts() => _rememberStore.list();

  /// One-tap sign-in using a stored device-remember credential. On a dead
  /// credential the card is dropped and the error surfaced for a password login.
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
      // Only forget the credential when the SERVER refused it. A transport
      // failure means we never got an answer, and deleting on "couldn't ask"
      // is destructive in a way the session wipe isn't: the card is gone for
      // good, and the merchant has to do a full password login to earn it back.
      // One tap while the network is flaky used to cost exactly that.
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
    // Persist the rotated credential + freshest profile.
    await _rememberStore.save(
      RememberedAccount(
        id: result.user.id,
        name: result.user.name,
        email: result.user.email,
        avatarUrl: result.user.avatarUrl,
      ),
      result.rememberToken,
    );
    // See _applySession — a fresh sign-in shouldn't serve a stale cached
    // profile from a previous session as this user.
    _user = await _dataSource.getMe(bypassCache: true);
    notifyListeners();
  }

  /// "Remove this account" — revoke server-side (best effort) + drop locally.
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

  /// Re-fetch the current user (e.g. after accepting a team invite, so
  /// shopRole/shopId update and the auth gate re-routes into the app).
  /// Bypasses the cache — the whole point of calling this is to see a
  /// write that just happened, not a pre-write snapshot that hasn't hit
  /// its background-revalidation window yet. (Root cause of a stuck
  /// "Set up your shop" screen after a successful create: this used to go
  /// through the cache-first path like every other GET, and the shop
  /// creation only invalidates the "me" cache tag, not "auth" — the
  /// unrelated tag /auth/me's cached response actually lives under.)
  Future<void> refreshUser() async {
    _user = await _dataSource.getMe(bypassCache: true);
    notifyListeners();
  }

  /// Cooldown for the manual "refresh access" button so it can't be used
  /// to hammer /auth/me. The automatic version-header sync is unaffected
  /// (it only fires on an actual change).
  static const refreshCooldown = AppDurations.snackbarLong;
  DateTime? _lastManualRefresh;

  /// Remaining cooldown before another manual refresh is allowed.
  Duration get refreshCooldownRemaining {
    final at = _lastManualRefresh;
    if (at == null) return Duration.zero;
    final left = refreshCooldown - DateTime.now().difference(at);
    return left.isNegative ? Duration.zero : left;
  }

  /// User-triggered permission re-check (the reload button). Rate-limited
  /// by [refreshCooldown]; returns false (and does nothing) if still
  /// cooling down.
  Future<bool> manualRefresh() async {
    if (refreshCooldownRemaining > Duration.zero) return false;
    _lastManualRefresh = DateTime.now();
    await refreshUser();
    return true;
  }

  /// Last-seen permissions version from the `X-Shop-Perms` response
  /// header. Lets us detect a change made elsewhere on the very next
  /// request and re-sync the gated UI without a re-login.
  String? _permsVersion;
  bool _resyncing = false;

  /// Called by ApiClient on every authenticated response. When the
  /// version changes (owner edited this account's role/permissions) we
  /// transparently refetch /auth/me — the UI rebuilds with the new
  /// access. First value just seeds the baseline.
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
      // Best-effort: pick up any permission change made while away. If
      // the account was *removed* (tokens revoked), getMe → 401 → the
      // ApiClient's refresh fails → clearAuth, which correctly logs out.
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

  /// Convenience wrapper used by the avatar tile on Edit Profile.
  /// Pass `null` to clear the photo, a URL to set it.
  Future<void> updateAvatar(String? avatarUrl) =>
      updateProfile(avatarUrl: avatarUrl, clearAvatar: avatarUrl == null);

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
    _gstEffectiveDatePromptDismissed = false;
    for (final cb in _onClearCallbacks) {
      cb();
    }
    notifyListeners();
  }
}

/// Outcome of [AuthProvider.register]: either the backend emailed a
/// verification code (collect it via [AuthProvider.verifyEmail]) or, when the
/// OTP infra is down, it created the account and applied the session directly.
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
