import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shopxy_customer/core/network/api_client.dart';

/// Batched event ingest for the customer marketplace.
///
/// Calls into the `/v1/events` endpoint introduced in Phase 5. The
/// server expects up to 100 events per batch and deduplicates on
/// `clientUuid`, so a retried POST is a no-op. We batch on two
/// triggers: when the in-memory queue crosses [_batchSize] OR when
/// the debounce timer fires. Either way, the user only pays the
/// round-trip occasionally rather than per-impression.
class TrackingService {
  TrackingService(this._client);
  final ApiClient _client;

  static const int _batchSize = 20;
  static const Duration _flushDelay = Duration(seconds: 2);
  final Random _rand = Random();

  final List<_Event> _queue = [];
  Timer? _flushTimer;
  bool _flushing = false;

  void recordImpression(String productId, {String source = 'home', String? sessionId}) =>
      _enqueue('IMPRESSION', productId, source: source, sessionId: sessionId);
  void recordTap(String productId, {String source = 'home', String? sessionId}) =>
      _enqueue('TAP', productId, source: source, sessionId: sessionId);
  void recordView(String productId, {String source = 'pdp', String? sessionId}) =>
      _enqueue('VIEW', productId, source: source, sessionId: sessionId);
  void recordWishlistAdd(String productId, {String source = 'pdp'}) =>
      _enqueue('WISHLIST_ADD', productId, source: source);
  void recordAddToCart(String productId, {String source = 'pdp'}) =>
      _enqueue('ADD_TO_CART', productId, source: source);

  void _enqueue(
    String eventType,
    String productId, {
    required String source,
    String? sessionId,
  }) {
    _queue.add(_Event(
      clientUuid: _uuid(),
      eventType: eventType,
      productId: productId,
      occurredAt: DateTime.now().toUtc(),
      sessionId: sessionId,
      source: source,
    ));
    if (_queue.length >= _batchSize) {
      _flushTimer?.cancel();
      _flush();
    } else {
      _flushTimer ??= Timer(_flushDelay, _flush);
    }
  }

  /// Flush pending events. Safe to call directly (e.g. on app backgrounding).
  /// Errors are swallowed — analytics is best-effort and we never want a
  /// network blip to surface to the user.
  Future<void> flush() => _flush();

  Future<void> _flush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    // Snapshot + clear up front so newly-enqueued events don't get
    // lost if the POST hangs and a second flush trigger fires.
    final batch = _queue.take(100).toList();
    _queue.removeRange(0, batch.length);
    try {
      final body = {
        'events': batch.map((e) => e.toJson()).toList(),
      };
      await _client.post('/v1/events', body: body);
    } catch (_) {
      // Re-queue on failure so retries pick them up on the next flush.
      _queue.insertAll(0, batch);
    } finally {
      _flushing = false;
      if (_queue.length >= _batchSize) _flush();
    }
  }

  String _uuid() {
    // RFC-4122 v4 (random) — enough for `clientUuid` idempotency on the
    // server. Avoids pulling in a `uuid` dep for one call site.
    final bytes = List<int>.generate(16, (_) => _rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

class _Event {
  _Event({
    required this.clientUuid,
    required this.eventType,
    required this.productId,
    required this.occurredAt,
    required this.source,
    this.sessionId,
  });
  final String clientUuid;
  final String eventType;
  final String productId;
  final DateTime occurredAt;
  final String source;
  final String? sessionId;

  Map<String, dynamic> toJson() => {
        'clientUuid': clientUuid,
        'eventType': eventType,
        'productId': productId,
        'occurredAt': occurredAt.toIso8601String(),
        'source': source,
        if (sessionId != null) 'sessionId': sessionId,
      };
}

/// Hook the JSON encoder uses on `_Event` instances — keeps the
/// `_flush` body lean. Public so tests can construct an instance and
/// verify the shape.
String encodeEventBatch(List<Map<String, dynamic>> events) =>
    jsonEncode({'events': events});
