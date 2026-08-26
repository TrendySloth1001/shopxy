import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shopxy/core/network/offline/network_status.dart';
import 'package:shopxy/core/network/offline/outbox.dart';
import 'package:shopxy/core/network/offline/outbox_processor.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('outbox_proc');
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

  Future<Outbox> seed(List<String> paths, {String user = '1'}) async {
    final ob = Outbox();
    await ob.init();
    for (final p in paths) {
      await ob.enqueue(userId: user, method: 'PATCH', path: p, body: '{}');
    }
    return ob;
  }

  OutboxProcessor proc(
    Outbox ob,
    NetworkStatus ns,
    Future<http.Response> Function(OutboxEntry) replay, {
    int maxAttempts = 5,
    String user = '1',
  }) => OutboxProcessor(
    outbox: ob,
    networkStatus: ns,
    currentUserId: () => user,
    replay: replay,
    maxAttempts: maxAttempts,
  );

  test('2xx drops the entry', () async {
    final ob = await seed(['/parties/1']);
    final calls = <String>[];
    final p = proc(ob, NetworkStatus(), (e) async {
      calls.add(e.path);
      return http.Response('', 200);
    });
    await p.drain();
    expect(calls, ['/parties/1']);
    expect(ob.pending('1'), isEmpty);
  });

  test('4xx drops the entry (server wins)', () async {
    final ob = await seed(['/parties/1']);
    final p = proc(ob, NetworkStatus(), (e) async => http.Response('', 409));
    await p.drain();
    expect(ob.pending('1'), isEmpty);
  });

  test('a 5xx entry does NOT block the entries behind it', () async {
    final ob = await seed(['/parties/1', '/parties/2']);
    final seen = <String>[];
    final p = proc(ob, NetworkStatus(), (e) async {
      seen.add(e.path);
      return http.Response('', e.path.endsWith('/1') ? 500 : 200);
    });
    await p.drain();
    expect(seen, ['/parties/1', '/parties/2']);
    expect(ob.pending('1').map((e) => e.path), ['/parties/1']);
    expect(ob.pending('1').single.attempts, 1);
  });

  test('a persistently 5xx entry is dropped after maxAttempts', () async {
    final ob = await seed(['/parties/1']);
    final p = proc(
      ob,
      NetworkStatus(),
      (e) async => http.Response('', 503),
      maxAttempts: 3,
    );
    await p.drain();
    expect(ob.pending('1').single.attempts, 1);
    await p.drain();
    await p.drain();
    expect(ob.pending('1'), isEmpty);
  });

  test('a thrown network error stops the pass; entries retry later', () async {
    final ob = await seed(['/parties/1', '/parties/2']);
    var calls = 0;
    final p = proc(ob, NetworkStatus(), (e) async {
      calls++;
      throw const SocketException('down');
    });
    await p.drain();
    expect(calls, 1);
    expect(ob.pending('1').length, 2);
  });

  test('does nothing while offline or for an anonymous user', () async {
    final obOffline = await seed(['/parties/1']);
    final offline = NetworkStatus(offlineDebounce: Duration.zero)..markOffline();
    await Future<void>.delayed(Duration.zero);
    var calls = 0;
    await proc(obOffline, offline, (e) async {
      calls++;
      return http.Response('', 200);
    }).drain();
    expect(calls, 0);

    final obAnon = await seed(['/parties/1'], user: '9');
    await proc(
      obAnon,
      NetworkStatus(),
      (e) async {
        calls++;
        return http.Response('', 200);
      },
      user: 'anon',
    ).drain();
    expect(calls, 0);
  });

  test('start() drains immediately when online', () async {
    final ob = await seed(['/parties/1']);
    var called = false;
    proc(ob, NetworkStatus(), (e) async {
      called = true;
      return http.Response('', 200);
    }).start();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(called, isTrue);
  });
}
