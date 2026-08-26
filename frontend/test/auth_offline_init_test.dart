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

    final api = ApiClient(
      tm,
      httpClient: MockClient((_) async => http.Response('{"error":"nope"}', 401)),
    );
    final auth = AuthProvider(AuthRemoteDataSource(api), tm);

    await auth.init();

    expect(tm.accessToken, isNull, reason: 'a rejected session must be cleared');
    expect(auth.isAuthenticated, isFalse);
  });

  test('401 on /auth/me + unreachable refresh KEEPS the session', () async {
    final tm = TokenManager();
    await tm.saveTokens(accessToken: 'access-token', refreshToken: 'refresh-token');

    final api = ApiClient(
      tm,
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          throw const SocketException('network dropped mid-refresh');
        }
        return http.Response('{"error":"jwt expired"}', 401);
      }),
    );
    final auth = AuthProvider(AuthRemoteDataSource(api), tm);

    await auth.init();

    expect(
      tm.accessToken,
      isNotNull,
      reason: 'an unverifiable 401 is not proof the session is dead',
    );
    expect(store.containsKey('refresh_token'), isTrue,
        reason: 'the refresh token is what restores the next launch');
  });

  test('401 on /auth/me + a 5xx refresh KEEPS the session', () async {
    final tm = TokenManager();
    await tm.saveTokens(accessToken: 'access-token', refreshToken: 'refresh-token');

    final api = ApiClient(
      tm,
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          return http.Response('<html>502 Bad Gateway</html>', 502);
        }
        return http.Response('{"error":"jwt expired"}', 401);
      }),
    );
    final auth = AuthProvider(AuthRemoteDataSource(api), tm);

    await auth.init();

    expect(tm.accessToken, isNotNull);
    expect(store.containsKey('refresh_token'), isTrue);
  });

  test('a restart that CAN reach the server refreshes and restores silently',
      () async {
    final tm = TokenManager();
    await tm.saveTokens(accessToken: 'expired-token', refreshToken: 'refresh-token');

    var refreshed = false;
    final api = ApiClient(
      tm,
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/auth/refresh')) {
          refreshed = true;
          return http.Response(
            '{"accessToken":"new-access","refreshToken":"new-refresh"}',
            200,
          );
        }
        final auth = req.headers.entries
            .firstWhere(
              (e) => e.key.toLowerCase() == 'authorization',
              orElse: () => const MapEntry('', ''),
            )
            .value;
        if (auth == 'Bearer new-access') {
          return http.Response(
            '{"id":"1","email":"m@x.com","name":"M","role":"OWNER",'
            '"createdAt":"2026-01-01T00:00:00.000Z"}',
            200,
          );
        }
        return http.Response('{"error":"jwt expired"}', 401);
      }),
    );
    final auth = AuthProvider(AuthRemoteDataSource(api), tm);

    await auth.init();

    expect(refreshed, isTrue);
    expect(tm.accessToken, 'new-access', reason: 'rotated in place');
    expect(auth.isAuthenticated, isTrue,
        reason: 'the normal restart must not show a login screen');
  });
}
