// Regression test for the reported bug: going offline logged the user out and
// the session ended. AuthProvider.init() must NOT clear the stored tokens on a
// transport (offline) failure — only on a definitive server rejection.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // In-memory stand-in for the secure-storage plugin channel.
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> store;

  setUp(() {
    store = {};
    binding.defaultBinaryMessenger.setMockMethodCallHandler(secure, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      switch (call.method) {
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return store[args['key'] as String];
        case 'delete':
          store.remove(args['key'] as String);
          return null;
        case 'containsKey':
          return store.containsKey(args['key'] as String);
        default:
          return null;
      }
    });
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(secure, null);
  });

  test('offline init keeps the session (does not clear tokens)', () async {
    final tm = TokenManager();
    await tm.saveTokens(accessToken: 'access-token', refreshToken: 'refresh-token');

    // Transport is down: every request throws like a real offline device.
    final api = ApiClient(
      tm,
      httpClient: MockClient((_) async => throw const SocketException('offline')),
    );
    final auth = AuthProvider(AuthRemoteDataSource(api), tm);

    await auth.init();

    expect(tm.accessToken, isNotNull, reason: 'session must survive offline');
    expect(store.containsKey('refresh_token'), isTrue);
    expect(auth.isAuthenticated, isFalse, reason: 'no cached identity this launch');
  });

  test('a server rejection (401) DOES clear the session', () async {
    final tm = TokenManager();
    await tm.saveTokens(accessToken: 'access-token', refreshToken: 'refresh-token');

    // Server answers 401 to both /auth/me and the refresh attempt → real expiry.
    final api = ApiClient(
      tm,
      httpClient: MockClient((_) async => http.Response('{"error":"nope"}', 401)),
    );
    final auth = AuthProvider(AuthRemoteDataSource(api), tm);

    await auth.init();

    expect(tm.accessToken, isNull, reason: 'a rejected session must be cleared');
    expect(auth.isAuthenticated, isFalse);
  });
}
