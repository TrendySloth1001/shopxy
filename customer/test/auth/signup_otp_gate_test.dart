import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy_customer/features/auth/domain/entities/auth_user.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';

void main() {
  group('signup OTP gate', () {
    test('register returns pending and does NOT create a session', () async {
      final tokens = _FakeTokenManager();
      final provider = AuthProvider(_FakeAuthDataSource(), tokens);

      final result = await provider.register(
        'Buyer',
        'buyer@example.com',
        'pw',
        acceptedTerms: true,
        acceptedPrivacy: true,
      );

      expect(result, isA<RegisterPending>());
      expect((result as RegisterPending).email, 'buyer@example.com');
      expect(provider.isAuthenticated, isFalse);
      expect(provider.user, isNull);
      expect(tokens.saved, isFalse);
    });

    test('verifying the code is what signs the user in', () async {
      final tokens = _FakeTokenManager();
      final ds = _FakeAuthDataSource();
      final provider = AuthProvider(ds, tokens);

      await provider.register(
        'Buyer',
        'buyer@example.com',
        'pw',
        acceptedTerms: true,
        acceptedPrivacy: true,
      );
      await provider.verifyEmail('buyer@example.com', '123456');

      expect(provider.isAuthenticated, isTrue);
      expect(provider.user?.role, 'CUSTOMER');
      expect(tokens.saved, isTrue);
      expect(ds.verifiedWith, '123456');
    });

    test('a rejected code leaves the user signed out', () async {
      final tokens = _FakeTokenManager();
      final provider = AuthProvider(_FakeAuthDataSource(rejectOtp: true), tokens);

      await expectLater(
        provider.verifyEmail('buyer@example.com', '000000'),
        throwsA(isA<Exception>()),
      );

      expect(provider.isAuthenticated, isFalse);
      expect(provider.user, isNull);
      expect(tokens.saved, isFalse);
    });

    test('a dev backend that signs up directly still signs in', () async {
      final tokens = _FakeTokenManager();
      final provider =
          AuthProvider(_FakeAuthDataSource(directSignIn: true), tokens);

      final result = await provider.register(
        'Buyer',
        'buyer@example.com',
        'pw',
        acceptedTerms: true,
        acceptedPrivacy: true,
      );

      expect(result, isA<RegisterSignedIn>());
      expect(provider.isAuthenticated, isTrue);
      expect(tokens.saved, isTrue);
    });
  });

  group('AuthProvider.register', () {
    test('forwards the DPDP consent literals to the data source', () async {
      final ds = _FakeAuthDataSource();
      final provider = AuthProvider(ds, _FakeTokenManager());

      await provider.register(
        'Buyer',
        'buyer@example.com',
        'pw',
        acceptedTerms: true,
        acceptedPrivacy: true,
      );

      expect(ds.sawTerms, isTrue);
      expect(ds.sawPrivacy, isTrue);
    });
  });
}

class _FakeTokenManager extends TokenManager {
  _FakeTokenManager({String? accessToken}) : _access = accessToken;

  String? _access;
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
  Future<void> clear() async => _access = null;

  @override
  Future<String?> getRefreshToken() async => null;
}

class _FakeAuthDataSource extends AuthRemoteDataSource {
  _FakeAuthDataSource({this.rejectOtp = false, this.directSignIn = false})
      : super(ApiClient(TokenManager()));

  final bool rejectOtp;
  final bool directSignIn;

  String? verifiedWith;
  bool sawTerms = false;
  bool sawPrivacy = false;

  AuthUser get _user => AuthUser(
        id: '1',
        email: 'buyer@example.com',
        name: 'Buyer',
        role: 'CUSTOMER',
        createdAt: DateTime(2026, 1, 1),
      );

  @override
  Future<RegisterResponse> register(
    String name,
    String email,
    String password, {
    required bool acceptedTerms,
    required bool acceptedPrivacy,
  }) async {
    sawTerms = acceptedTerms;
    sawPrivacy = acceptedPrivacy;
    if (directSignIn) {
      return (
        pending: false,
        email: email,
        session: (user: _user, accessToken: 'a', refreshToken: 'r'),
      );
    }
    return (pending: true, email: email, session: null);
  }

  @override
  Future<AuthResult> verifyEmail(String email, String otp) async {
    verifiedWith = otp;
    if (rejectOtp) throw Exception('That code is incorrect. Try again.');
    return (user: _user, accessToken: 'a', refreshToken: 'r');
  }

  @override
  Future<AuthUser> getMe({bool bypassCache = false}) async => _user;
}
