// Unit tests for the offline connectivity signal (NetworkStatus). The debounce
// is the risk surface: a single dropped request must NOT flash the banner, but
// a real outage must, and a success must clear it immediately.

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
      ns.markOnline(); // a request succeeded before the timer fired
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
}
