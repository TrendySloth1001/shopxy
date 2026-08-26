import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy/core/network/offline/network_status.dart';

void main() {
  test('starts online', () {
    expect(NetworkStatus().online, isTrue);
  });

  test('a single failure does not flip to offline before the debounce', () {
    fakeAsync((async) {
      final ns = NetworkStatus(offlineDebounce: const Duration(seconds: 2));
      var notified = 0;
      ns.addListener(() => notified++);

      ns.markOffline();
      async.elapse(const Duration(milliseconds: 500));
      expect(ns.online, isTrue, reason: 'still within debounce window');
      expect(notified, 0);

      async.elapse(const Duration(seconds: 2));
      expect(ns.offline, isTrue, reason: 'debounce elapsed → offline');
      expect(notified, 1);
    });
  });

  test('a success during the debounce window cancels the offline flip', () {
    fakeAsync((async) {
      final ns = NetworkStatus(offlineDebounce: const Duration(seconds: 2));
      ns.markOffline();
      async.elapse(const Duration(milliseconds: 500));
      ns.markOnline();
      async.elapse(const Duration(seconds: 5));
      expect(ns.online, isTrue);
    });
  });

  test('markOnline clears an established offline state immediately', () {
    fakeAsync((async) {
      final ns = NetworkStatus(offlineDebounce: const Duration(seconds: 1));
      ns.markOffline();
      async.elapse(const Duration(seconds: 2));
      expect(ns.offline, isTrue);

      var notified = 0;
      ns.addListener(() => notified++);
      ns.markOnline();
      expect(ns.online, isTrue);
      expect(notified, 1);
    });
  });

  test('with no probe, offline is permanent — the bug this guards', () {
    fakeAsync((async) {
      final ns = NetworkStatus(offlineDebounce: const Duration(seconds: 1));
      ns.markOffline();
      async.elapse(const Duration(minutes: 10));
      expect(ns.offline, isTrue);
    });
  });

  test('probes on a backoff and recovers on its own once reachable', () {
    fakeAsync((async) {
      var reachable = false;
      var probes = 0;
      final ns = NetworkStatus(
        offlineDebounce: const Duration(seconds: 1),
        firstProbeDelay: const Duration(seconds: 2),
        maxProbeDelay: const Duration(seconds: 30),
        probe: () async {
          probes++;
          return reachable;
        },
      );

      ns.markOffline();
      async.elapse(const Duration(seconds: 1));
      expect(ns.offline, isTrue);
      expect(probes, 0, reason: 'first probe waits out the initial delay');

      async.elapse(const Duration(seconds: 3));
      expect(probes, greaterThan(0));
      expect(ns.offline, isTrue, reason: 'still unreachable');

      final afterFirst = probes;
      async.elapse(const Duration(seconds: 4));
      expect(probes - afterFirst, lessThanOrEqualTo(2));

      reachable = true;
      async.elapse(const Duration(seconds: 60));
      expect(ns.online, isTrue, reason: 'recovered without a user action');
    });
  });

  test('stops probing once online — no polling on the happy path', () {
    fakeAsync((async) {
      var probes = 0;
      final ns = NetworkStatus(
        offlineDebounce: const Duration(seconds: 1),
        firstProbeDelay: const Duration(seconds: 2),
        probe: () async {
          probes++;
          return true;
        },
      );

      ns.markOffline();
      async.elapse(const Duration(seconds: 10));
      expect(ns.online, isTrue);
      final settled = probes;

      async.elapse(const Duration(minutes: 5));
      expect(probes, settled, reason: 'an online app must never poll');
    });
  });

  test('a throwing probe reschedules instead of giving up', () {
    fakeAsync((async) {
      var probes = 0;
      final ns = NetworkStatus(
        offlineDebounce: const Duration(seconds: 1),
        firstProbeDelay: const Duration(seconds: 2),
        probe: () async {
          probes++;
          throw Exception('SocketException');
        },
      );

      ns.markOffline();
      async.elapse(const Duration(seconds: 30));
      expect(probes, greaterThan(1));
      expect(ns.offline, isTrue);
    });
  });

  test('probeNow short-circuits the backoff (app resumed)', () {
    fakeAsync((async) {
      var reachable = false;
      final ns = NetworkStatus(
        offlineDebounce: const Duration(seconds: 1),
        firstProbeDelay: const Duration(seconds: 2),
        maxProbeDelay: const Duration(seconds: 30),
        probe: () async => reachable,
      );

      ns.markOffline();
      async.elapse(const Duration(minutes: 3));
      expect(ns.offline, isTrue);

      reachable = true;
      ns.probeNow();
      async.elapse(const Duration(milliseconds: 50));
      expect(ns.online, isTrue, reason: 'must not wait out a 30s ceiling');
    });
  });

  test('probeNow does nothing while online', () {
    fakeAsync((async) {
      var probes = 0;
      final ns = NetworkStatus(probe: () async {
        probes++;
        return true;
      });
      ns.probeNow();
      async.elapse(const Duration(seconds: 5));
      expect(probes, 0);
    });
  });
}
