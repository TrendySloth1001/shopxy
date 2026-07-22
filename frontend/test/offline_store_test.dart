// Persistence + per-user isolation tests for the offline SSOT stores
// (HttpCache + Outbox). path_provider is mocked to a temp dir via its method
// channel so the on-disk logic runs for real without a device.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy/core/network/offline/http_cache.dart';
import 'package:shopxy/core/network/offline/outbox.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('offline_test');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => tmp.path,
    );
  });

  tearDown(() async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  group('HttpCache', () {
    test('write/read round-trips a body', () async {
      final cache = HttpCache();
      await cache.init();
      final key = cache.keyFor(userId: '1', method: 'GET', path: '/products');
      await cache.write(
        key: key,
        userId: '1',
        tag: 'products',
        body: '{"data":[1,2]}',
        statusCode: 200,
      );
      final r = await cache.read(key);
      expect(r?.body, '{"data":[1,2]}');
      expect(r?.statusCode, 200);
    });

    test('keys are isolated per user', () async {
      final cache = HttpCache();
      await cache.init();
      final a = cache.keyFor(userId: '1', method: 'GET', path: '/products');
      final b = cache.keyFor(userId: '2', method: 'GET', path: '/products');
      expect(a, isNot(b));
    });

    test('keys are deterministic (order-independent query)', () async {
      final cache = HttpCache();
      await cache.init();
      final a = cache.keyFor(
        userId: '1',
        method: 'GET',
        path: '/x',
        query: {'b': '2', 'a': '1'},
      );
      final b = cache.keyFor(
        userId: '1',
        method: 'GET',
        path: '/x',
        query: {'a': '1', 'b': '2'},
      );
      expect(a, b);
    });

    test('invalidateTag drops only that resource group', () async {
      final cache = HttpCache();
      await cache.init();
      final p = cache.keyFor(userId: '1', method: 'GET', path: '/parties');
      final i = cache.keyFor(userId: '1', method: 'GET', path: '/invoices');
      await cache.write(
        key: p,
        userId: '1',
        tag: 'parties',
        body: 'p',
        statusCode: 200,
      );
      await cache.write(
        key: i,
        userId: '1',
        tag: 'invoices',
        body: 'i',
        statusCode: 200,
      );
      await cache.invalidateTag('1', 'parties');
      expect(await cache.read(p), isNull);
      expect((await cache.read(i))?.body, 'i');
    });

    test('wipe clears everything', () async {
      final cache = HttpCache();
      await cache.init();
      final k = cache.keyFor(userId: '1', method: 'GET', path: '/products');
      await cache.write(
        key: k,
        userId: '1',
        tag: 'products',
        body: 'x',
        statusCode: 200,
      );
      await cache.wipe();
      expect(await cache.read(k), isNull);
    });
  });

  group('Outbox', () {
    test('enqueue/pending/remove is FIFO and per-user', () async {
      final ob = Outbox();
      await ob.init();
      await ob.enqueue(
        userId: '1',
        method: 'PATCH',
        path: '/parties/1',
        body: '{"name":"A"}',
      );
      await ob.enqueue(
        userId: '1',
        method: 'PATCH',
        path: '/parties/2',
        body: '{"name":"B"}',
      );
      await ob.enqueue(userId: '2', method: 'PATCH', path: '/vendors/1');

      expect(ob.pending('1').length, 2);
      expect(ob.pending('2').length, 1);
      expect(ob.pending('1').first.path, '/parties/1'); // FIFO order
      expect(ob.pendingCount.value, 3);

      await ob.remove(ob.pending('1').first.id);
      expect(ob.pending('1').length, 1);
      expect(ob.pending('1').first.path, '/parties/2');
    });

    test('survives a reload (persisted to disk)', () async {
      final ob1 = Outbox();
      await ob1.init();
      await ob1.enqueue(userId: '7', method: 'PUT', path: '/me/shop', body: '{}');

      final ob2 = Outbox(); // fresh instance, same temp dir
      await ob2.init();
      expect(ob2.pending('7').length, 1);
      expect(ob2.pending('7').first.method, 'PUT');
    });

    test('wipe clears the queue', () async {
      final ob = Outbox();
      await ob.init();
      await ob.enqueue(userId: '1', method: 'PATCH', path: '/parties/1');
      await ob.wipe();
      expect(ob.pending('1'), isEmpty);
      expect(ob.pendingCount.value, 0);
    });

    test('caps the queue at maxEntries, dropping oldest', () async {
      final ob = Outbox(maxEntries: 3);
      await ob.init();
      for (var i = 0; i < 5; i++) {
        await ob.enqueue(userId: '1', method: 'PATCH', path: '/parties/$i');
      }
      final pend = ob.pending('1');
      expect(pend.length, 3);
      expect(pend.first.path, '/parties/2'); // oldest two dropped
      expect(pend.last.path, '/parties/4');
    });
  });
}
