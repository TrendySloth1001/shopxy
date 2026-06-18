import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shopxy/core/config/app_config.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/pos/data/pos_models.dart';
import 'package:shopxy/features/pos/data/pos_remote_data_source.dart';

enum PosConnStatus { connecting, live, reconnecting, offline }

class _QueuedScan {
  _QueuedScan(this.opId, this.code);
  final String opId;
  final String code;
}

/// Drives one POS sale on the phone: opens a sale, mirrors the
/// server-authoritative cart, and stays live across devices over the
/// scan-console WebSocket (role=console). Scans/edits go over REST (which adds
/// to the shared cart); the socket sends a version nudge and we re-fetch the
/// snapshot. The server is the source of truth.
class PosSaleClient extends ChangeNotifier {
  PosSaleClient(ApiClient client) : _ds = PosRemoteDataSource(client);

  final PosRemoteDataSource _ds;

  PosConnStatus _status = PosConnStatus.connecting;
  PosConnStatus get status => _status;

  SaleSnapshot? _snapshot;
  SaleSnapshot? get snapshot => _snapshot;

  String? _error;
  String? get error => _error;

  String? _unknownCode;
  String? get unknownCode => _unknownCode;

  String? _checkoutInvoiceNo;
  String? get checkoutInvoiceNo => _checkoutInvoiceNo;

  /// True once the sale closed (here or on another till) — lets the page show a
  /// terminal state even when this till didn't initiate the checkout.
  bool get isClosed => _snapshot != null && _snapshot!.status != 'OPEN';

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  bool _disposed = false;
  bool _flushing = false;
  int? _saleId;
  int _appliedVersion = -1;

  final List<_QueuedScan> _outbox = [];
  int _opSeq = 0;
  int get pendingCount => _outbox.length;

  String _newOpId() => '${DateTime.now().microsecondsSinceEpoch}-${_opSeq++}';

  /// Apply a snapshot only if it's at least as new as what we've shown — drops
  /// stale out-of-order responses (e.g. an outbox replay).
  void _apply(SaleSnapshot s) {
    if (s.version < _appliedVersion) return;
    _appliedVersion = s.version;
    _snapshot = s;
    notifyListeners();
  }

  Future<void> start() async {
    _disposed = false;
    try {
      final s = await _ds.openSale();
      if (_disposed) return;
      _saleId = s.saleId;
      _apply(s);
      await _connect();
    } catch (e) {
      if (_disposed) return;
      _error = e.toString();
      _setStatus(PosConnStatus.offline);
    }
  }

  Future<void> _connect() async {
    if (_disposed) return;
    try {
      final ticket = await _ds.requestTicket();
      if (_disposed) return;
      final wsBase = AppConfig.apiBaseUrl
          .replaceFirst(RegExp(r'^http'), 'ws')
          .replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$wsBase${ticket.path}?ticket=${ticket.ticket}&role=console');
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready;
      if (_disposed) {
        await channel.sink.close();
        return;
      }
      _setStatus(PosConnStatus.live);
      _sub = channel.stream.listen(_onData, onDone: _onDone, onError: (_) => _onDone());
      // Self-heal on (re)connect: re-fetch the snapshot, then replay queued scans.
      unawaited(_refresh());
      unawaited(_flushOutbox());
    } catch (_) {
      if (_disposed) return;
      _setStatus(PosConnStatus.reconnecting);
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(data as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (msg['saleId'] != _saleId) return; // only our sale
    // All POS events are version nudges (no cart contents) — re-fetch the
    // authoritative snapshot. review M3.
    final type = msg['type'];
    if (type == 'pos.sale' || type == 'pos.checkout' || type == 'pos.void') {
      unawaited(_refresh());
    }
  }

  void _onDone() {
    if (_disposed) return;
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _setStatus(PosConnStatus.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _retry != null) return;
    _retry = Timer(const Duration(milliseconds: 2000), () {
      _retry = null;
      _connect();
    });
  }

  Future<void> _refresh() async {
    if (_saleId == null) return;
    try {
      final s = await _ds.getSale(_saleId!);
      if (_disposed) return;
      _apply(s);
    } catch (_) {}
  }

  // ── Actions (REST; snapshot adopted from the response) ──
  Future<void> scan(String code) async {
    final c = code.trim();
    if (_saleId == null || c.isEmpty) return;
    _error = null;
    final opId = _newOpId();
    try {
      final outcome = await _ds.scan(_saleId!, c, opId: opId);
      if (_disposed) return;
      if (outcome.isUnknown) {
        _unknownCode = outcome.unknownCode;
        notifyListeners();
      } else if (outcome.snapshot != null) {
        _apply(outcome.snapshot!);
      }
    } catch (_) {
      if (_disposed) return;
      _outbox.add(_QueuedScan(opId, c));
      _error = 'Offline — scan queued, will sync on reconnect.';
      notifyListeners();
    }
  }

  Future<void> _flushOutbox() async {
    if (_saleId == null || _flushing) return;
    _flushing = true;
    try {
      while (_outbox.isNotEmpty) {
        final next = _outbox.first;
        try {
          final outcome = await _ds.scan(_saleId!, next.code, opId: next.opId);
          if (_disposed) return;
          if (outcome.snapshot != null) _apply(outcome.snapshot!);
          _outbox.removeAt(0);
        } catch (_) {
          break; // still offline; retry on next reconnect
        }
      }
    } finally {
      _flushing = false;
    }
  }

  void clearUnknown() {
    _unknownCode = null;
    notifyListeners();
  }

  Future<void> quickAdd({
    required String code,
    required String name,
    required double sellingPrice,
    double? taxPercent,
    double? openingStock,
  }) async {
    if (_saleId == null) return;
    _error = null;
    try {
      final s = await _ds.quickAdd(
        _saleId!,
        code: code,
        name: name,
        sellingPrice: sellingPrice,
        taxPercent: taxPercent,
        openingStock: openingStock,
      );
      if (_disposed) return;
      _unknownCode = null;
      _apply(s);
    } catch (e) {
      if (_disposed) return;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> setQty(int productId, double quantity) => _run(() => _ds.setQty(_saleId!, productId, quantity));
  Future<void> removeItem(int productId) => _run(() => _ds.removeItem(_saleId!, productId));

  Future<void> _run(Future<SaleSnapshot> Function() fn) async {
    if (_saleId == null) return;
    _error = null;
    try {
      final s = await fn();
      if (_disposed) return;
      _apply(s);
    } catch (e) {
      if (_disposed) return;
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> checkout(String mode) async {
    if (_saleId == null) return;
    _error = null;
    try {
      final invoiceNo = await _ds.checkout(_saleId!, mode);
      if (_disposed) return;
      _checkoutInvoiceNo = invoiceNo;
      notifyListeners();
    } catch (e) {
      if (_disposed) return;
      _error = e.toString();
      notifyListeners();
    }
  }

  void _setStatus(PosConnStatus s) {
    if (_disposed) return;
    _status = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
