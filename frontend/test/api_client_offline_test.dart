// Tests for ApiClient's offline behavior — now possible because the transport
// is an injected http.Client (MockClient here). Covers cache-first serve,
// offline fallback, write-invalidation, and the offline write-queue routing.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/core/network/offline/http_cache.dart';
import 'package:shopxy/core/network/offline/network_status.dart';
import 'package:shopxy/core/network/offline/offline_errors.dart';
import 'package:shopxy/core/network/offline/outbox.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tmp;
  late HttpCache cache;
  late Outbox outbox;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('api_client_offline');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => tmp.path,
    );
    cache = HttpCache();
    outbox = Outbox();
    await cache.init();
    await outbox.init();
  });
  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  ApiClient build(
    MockClient mock, {
    NetworkStatus? ns,
  }) => ApiClient(
    TokenManager(),
    cache: cache,
    networkStatus: ns ?? NetworkStatus(offlineDebounce: Duration.zero),
    outbox: outbox,
    httpClient: mock,
  );

  // Let fire-and-forget cache writes / invalidations (real temp-dir I/O) settle.
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 40));

  test('caches a live GET and serves it cache-first (no second network hit)',
      () async {
    var getCalls = 0;
    var fail = false;
    final client = build(MockClient((req) async {
      if (fail) throw const SocketException('offline');
      getCalls++;
      return http.Response('{"v":1}', 200);
    }));

    final first = await client.get('/products');
    expect(first.body, '{"v":1}');
    await settle();

    // Now the network is down — a cache-first read still returns the cached copy
    // and does NOT call the client again (fresh within staleAfter).
    fail = true;
    final second = await client.get('/products');
    expect(second.body, '{"v":1}');
    expect(getCalls, 1);
  });

  test('a cache MISS while offline rethrows and marks offline', () async {
    final ns = NetworkStatus(offlineDebounce: Duration.zero);
    final client = build(
      MockClient((req) async => throw const SocketException('offline')),
      ns: ns,
    );
    await expectLater(
      client.get('/products'),
      throwsA(isA<SocketException>()),
    );
    await settle();
    expect(ns.offline, isTrue);
  });

  test('a successful write invalidates the resource cache (re-fetched next GET)',
      () async {
    var getCalls = 0;
    final client = build(MockClient((req) async {
      if (req.method == 'GET') {
        getCalls++;
        return http.Response('{"v":$getCalls}', 200);
      }
      return http.Response('{}', 200); // PATCH ok
    }));

    await client.get('/parties'); // miss → live (getCalls=1), cached
    await settle();
    await client.patch('/parties/1', body: {'name': 'x'}); // invalidates 'parties'
    await settle();
    await client.get('/parties'); // cache gone → live again (getCalls=2)
    expect(getCalls, 2);
  });

  test('offline queueable write → queued exception + enqueued', () async {
    final client = build(
      MockClient((req) async => throw const SocketException('offline')),
    );
    await expectLater(
      client.patch('/parties/1', body: {'name': 'x'}),
      throwsA(isA<OfflineWriteQueuedException>()),
    );
    expect(outbox.pending('anon').length, 1);
    expect(outbox.pending('anon').single.path, '/parties/1');
  });

  test('offline non-queueable write → blocked, nothing enqueued', () async {
    final client = build(
      MockClient((req) async => throw const SocketException('offline')),
    );
    await expectLater(
      client.post('/invoices', body: {'confirm': true}),
      throwsA(isA<OfflineWriteBlockedException>()),
    );
    expect(outbox.pending('anon'), isEmpty);
  });
}
