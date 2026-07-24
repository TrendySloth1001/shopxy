import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy_customer/features/auth/domain/entities/auth_user.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';

/// Guards the cross-app login fix: a merchant (OWNER) account must never
/// be able to sign in to — or restore a session in — the customer app.
void main() {
  AuthUser user(String role) => AuthUser(
        id: '1',
        email: 'x@example.com',
        name: 'X',
        role: role,
        createdAt: DateTime(2026, 1, 1),
      );

  group('AuthProvider role gate', () {
    test('login rejects a merchant (OWNER) account', () async {
      final tokens = _FakeTokenManager();
      final provider =
          AuthProvider(_FakeAuthDataSource(loginUser: user('OWNER')), tokens);

      expect(
        () => provider.login('x@example.com', 'pw'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains(AppStrings.merchantAccountBlocked),
        )),
      );
      // The freshly-issued tokens are discarded and no session is set.
      await Future<void>.delayed(Duration.zero);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.user, isNull);
      expect(tokens.clearCount, greaterThan(0));
      expect(tokens.saved, isFalse);
    });

    test('login accepts a CUSTOMER account', () async {
      final tokens = _FakeTokenManager();
      final provider =
          AuthProvider(_FakeAuthDataSource(loginUser: user('CUSTOMER')), tokens);

      await provider.login('x@example.com', 'pw');

      expect(provider.isAuthenticated, isTrue);
      expect(provider.user?.role, 'CUSTOMER');
      expect(tokens.saved, isTrue);
    });

    test('init drops a restored OWNER session', () async {
      final tokens = _FakeTokenManager(accessToken: 'stale');
      final provider =
          AuthProvider(_FakeAuthDataSource(meUser: user('OWNER')), tokens);

      await provider.init();

      expect(provider.isAuthenticated, isFalse);
      expect(provider.isGuest, isTrue);
      expect(tokens.clearCount, greaterThan(0));
    });

    test('init restores a CUSTOMER session', () async {
      final tokens = _FakeTokenManager(accessToken: 'good');
      final provider =
          AuthProvider(_FakeAuthDataSource(meUser: user('CUSTOMER')), tokens);

      await provider.init();

      expect(provider.isAuthenticated, isTrue);
      expect(provider.user?.role, 'CUSTOMER');
    });
  });
}

class _FakeTokenManager extends TokenManager {
  _FakeTokenManager({String? accessToken}) : _access = accessToken;

  String? _access;
  int clearCount = 0;
  bool saved = false;

  @override
  String? get accessToken => _access;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    saved = true;
    _access = accessToken;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    _access = null;
  }

  @override
  Future<String?> getRefreshToken() async => null;
}

class _FakeAuthDataSource extends AuthRemoteDataSource {
  _FakeAuthDataSource({this.loginUser, this.meUser})
      : super(ApiClient(TokenManager()));

  final AuthUser? loginUser;
  final AuthUser? meUser;

  @override
  Future<AuthResult> login(String email, String password) async =>
      (user: loginUser!, accessToken: 'a', refreshToken: 'r');

  @override
  Future<AuthUser> getMe() async => meUser!;
}
