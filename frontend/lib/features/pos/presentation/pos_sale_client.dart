import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shopxy/core/config/app_config.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/pos/data/pos_models.dart';
import 'package:shopxy/features/pos/data/pos_remote_data_source.dart';
import 'package:shopxy/features/scan_console/data/scan_console_remote_data_source.dart';

enum PosConnStatus { connecting, live, reconnecting, offline }

/// Drives one POS sale on the phone: opens a sale, mirrors the
/// server-authoritative cart, and stays live across devices over the
/// scan-console WebSocket (role=console). Scans/edits go over REST (which adds
/// to the shared cart); the socket delivers the other till's changes.
class PosSaleClient extends ChangeNotifier {
  PosSaleClient(ApiClient client)
      : _ds = PosRemoteDataSource(client),
        _scanDs = ScanConsoleRemoteDataSource(client);

  final PosRemoteDataSource _ds;
  final ScanConsoleRemoteDataSource _scanDs;

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

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  bool _disposed = false;
  int? _saleId;

  Future<void> start() async {
    _disposed = false;
    try {
      final s = await _ds.openSale();
      if (_disposed) return;
      _saleId = s.saleId;
      _snapshot = s;
      notifyListeners();
      await _connect();
    } catch (e) {
      _error = e.toString();
      _setStatus(PosConnStatus.offline);
    }
  }

  Future<void> _connect() async {
    if (_disposed) return;
    try {
      final ticket = await _scanDs.requestTicket();
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
    switch (msg['type']) {
      case 'pos.sale':
        final snap = msg['snapshot'];
        if (snap is Map<String, dynamic>) {
          _snapshot = SaleSnapshot.fromJson(snap);
          notifyListeners();
        }
      case 'pos.checkout':
        _checkoutInvoiceNo ??= '✓';
        notifyListeners();
      case 'pos.void':
        _refresh();
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
      _snapshot = await _ds.getSale(_saleId!);
      notifyListeners();
    } catch (_) {}
  }

  // ── Actions (REST; snapshot adopted from the response) ──
  Future<void> scan(String code) async {
    if (_saleId == null || code.trim().isEmpty) return;
    _error = null;
    try {
      final outcome = await _ds.scan(_saleId!, code.trim());
      if (outcome.isUnknown) {
        _unknownCode = outcome.unknownCode;
      } else if (outcome.snapshot != null) {
        _snapshot = outcome.snapshot;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void clearUnknown() {
    _unknownCode = null;
    notifyListeners();
  }

  Future<void> setQty(int productId, double quantity) => _run(() => _ds.setQty(_saleId!, productId, quantity));
  Future<void> removeItem(int productId) => _run(() => _ds.removeItem(_saleId!, productId));

  Future<void> _run(Future<SaleSnapshot> Function() fn) async {
    if (_saleId == null) return;
    _error = null;
    try {
      _snapshot = await fn();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> checkout(String mode) async {
    if (_saleId == null) return;
    _error = null;
    try {
      _checkoutInvoiceNo = await _ds.checkout(_saleId!, mode);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void _setStatus(PosConnStatus s) {
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
