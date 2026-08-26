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

  String? _checkoutInvoiceId;
  String? get checkoutInvoiceId => _checkoutInvoiceId;

  double? _onlineAmount;

  double? _onlinePaidAmount;
  double? get onlinePaidAmount => _onlinePaidAmount;

  bool get isClosed =>
      _snapshot != null && (_snapshot!.status == 'CHECKED_OUT' || _snapshot!.status == 'VOIDED');

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  bool _disposed = false;
  bool _flushing = false;
  String? _saleId;
  int _appliedVersion = -1;
  int _seq = 0;

  final Map<String, Completer<Map<String, dynamic>>> _pending = {};
  final Map<String, Timer> _pendingTimers = {};
  final List<_QueuedScan> _outbox = [];
  int get pendingCount => _outbox.length;

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  void _apply(Map<String, dynamic> data) {
    final snap = SaleSnapshot.fromJson(data);
    if (snap.version < _appliedVersion) return;
    _appliedVersion = snap.version;
    _saleId = snap.saleId;
    _snapshot = snap;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _send(String op, [Map<String, dynamic> args = const {}]) {
    final channel = _channel;
    if (channel == null) return Future.value({'ok': false, 'error': 'offline'});
    final reqId = _newId();
    final completer = Completer<Map<String, dynamic>>();
    _pending[reqId] = completer;
    _pendingTimers[reqId] = Timer(const Duration(seconds: 12), () {
      _pendingTimers.remove(reqId);
      if (_pending.remove(reqId) != null && !completer.isCompleted) {
        completer.complete({'ok': false, 'error': 'timeout'});
      }
    });
    channel.sink.add(jsonEncode({'t': 'cmd', 'reqId': reqId, 'op': op, ...args}));
    return completer.future;
  }

  Future<void> start() async {
    _disposed = false;
    await _connect();
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
      final res = _saleId == null ? await _send('open') : await _send('snapshot', {'saleId': _saleId});
      if (res['ok'] == true) _apply(res['data'] as Map<String, dynamic>);
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
    if (msg['t'] == 'res' && msg['reqId'] is String) {
      final reqId = msg['reqId'] as String;
      _pendingTimers.remove(reqId)?.cancel();
      final c = _pending.remove(reqId);
      if (c != null && !c.isCompleted) c.complete(msg);
      return;
    }
    final type = msg['type'];
    if (type == 'pos.checkout' && msg['saleId']?.toString() == _saleId && _onlineAmount != null) {
      _onlinePaidAmount = _onlineAmount;
      _onlineAmount = null;
      notifyListeners();
    }
    if ((type == 'pos.sale' || type == 'pos.checkout' || type == 'pos.void') && msg['saleId']?.toString() == _saleId) {
      unawaited(_refresh());
    }
  }

  void _onDone() {
    if (_disposed) return;
    _sub?.cancel();
    _sub = null;
    _channel = null;
    for (final entry in _pending.entries) {
      _pendingTimers.remove(entry.key)?.cancel();
      if (!entry.value.isCompleted) entry.value.complete({'ok': false, 'error': 'disconnected'});
    }
    _pending.clear();
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
    final res = await _send('snapshot', {'saleId': _saleId});
    if (res['ok'] == true && !_disposed) _apply(res['data'] as Map<String, dynamic>);
  }

  Future<void> holdAndNew() async {
    _appliedVersion = -1;
    final res = await _send('open');
    if (res['ok'] == true && !_disposed) _apply(res['data'] as Map<String, dynamic>);
  }

  Future<void> recall(String saleId) async {
    _appliedVersion = -1;
    final res = await _send('snapshot', {'saleId': saleId});
    if (res['ok'] == true && !_disposed) _apply(res['data'] as Map<String, dynamic>);
  }

  Future<List<Map<String, dynamic>>> searchProducts(String term) async {
    final res = await _send('search', {'term': term});
    if (res['ok'] != true) return const [];
    final data = res['data'];
    return data is List ? data.cast<Map<String, dynamic>>() : const [];
  }

  Future<void> addItem(String productId, {double quantity = 1}) async {
    if (_saleId == null) return;
    _error = null;
    final res = await _send('addItem', {'saleId': _saleId, 'productId': productId, 'quantity': quantity});
    if (_disposed) return;
    if (res['ok'] == true) {
      _apply(res['data'] as Map<String, dynamic>);
    } else {
      _error = _human(res['error']);
      notifyListeners();
    }
  }

  Future<List<Map<String, dynamic>>> listOpen() async {
    final res = await _send('listOpen');
    if (res['ok'] != true) return const [];
    final data = res['data'];
    return data is List ? data.cast<Map<String, dynamic>>() : const [];
  }

  static const _transportErrors = {'offline', 'disconnected', 'timeout'};

  Future<void> scan(String code) async {
    final c = code.trim();
    if (_saleId == null || c.isEmpty) return;
    _error = null;
    final opId = _newId();
    final res = await _send('scan', {'saleId': _saleId, 'code': c, 'opId': opId});
    if (_disposed) return;
    if (res['ok'] == true) {
      final dataMap = res['data'] as Map<String, dynamic>;
      if (dataMap['unknown'] == true) {
        _unknownCode = dataMap['code'] as String?;
        notifyListeners();
      } else {
        _apply(dataMap);
      }
      if (_outbox.isNotEmpty) unawaited(_flushOutbox());
      return;
    }
    if (_transportErrors.contains(res['error'])) {
      _outbox.add(_QueuedScan(opId, c));
      _error = 'Offline — scan queued, will sync on reconnect.';
    } else {
      _error = _human(res['error']);
    }
    notifyListeners();
  }

  Future<void> _flushOutbox() async {
    if (_saleId == null || _flushing) return;
    _flushing = true;
    try {
      while (_outbox.isNotEmpty) {
        final next = _outbox.first;
        final res = await _send('scan', {'saleId': _saleId, 'code': next.code, 'opId': next.opId});
        if (res['ok'] != true) break;
        if (_disposed) return;
        final dataMap = res['data'] as Map<String, dynamic>;
        if (dataMap['unknown'] != true) _apply(dataMap);
        _outbox.removeAt(0);
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _runSnap(String op, Map<String, dynamic> args) async {
    if (_saleId == null) return;
    _error = null;
    final res = await _send(op, {'saleId': _saleId, ...args});
    if (_disposed) return;
    if (res['ok'] == true) {
      _apply(res['data'] as Map<String, dynamic>);
    } else {
      _error = _human(res['error']);
      notifyListeners();
    }
  }

  Future<void> setQty(String productId, double quantity) => _runSnap('setQty', {'productId': productId, 'quantity': quantity});
  Future<void> removeItem(String productId) => _runSnap('removeLine', {'productId': productId});

  Future<void> quickAdd({
    required String code,
    required String name,
    required double sellingPrice,
    double? taxPercent,
    double? openingStock,
  }) async {
    if (_saleId == null) return;
    _error = null;
    final res = await _send('quickAdd', {
      'saleId': _saleId,
      'code': code,
      'name': name,
      'sellingPrice': sellingPrice,
      'taxPercent': ?taxPercent,
      'openingStock': ?openingStock,
    });
    if (_disposed) return;
    if (res['ok'] == true) {
      _unknownCode = null;
      _apply(res['data'] as Map<String, dynamic>);
    } else {
      _error = _human(res['error']);
      notifyListeners();
    }
  }

  Future<void> setLineDiscount(String productId, double discount) =>
      _runSnap('setLineDiscount', {'productId': productId, 'discount': discount});
  Future<void> setHeaderDiscount(double discount) =>
      _runSnap('setHeaderDiscount', {'discount': discount});

  Future<void> checkout(String mode, {String? customerName, String? customerPhone}) async {
    if (_saleId == null) return;
    _error = null;
    final hasCustomer = (customerName != null && customerName.isNotEmpty) || (customerPhone != null && customerPhone.isNotEmpty);
    final res = await _send('checkout', {
      'saleId': _saleId,
      'tender': {'mode': mode},
      if (hasCustomer) 'customer': {'name': ?customerName, 'phone': ?customerPhone},
    });
    if (_disposed) return;
    if (res['ok'] == true) {
      final data = res['data'] as Map<String, dynamic>;
      _checkoutInvoiceNo = data['invoiceNo'] as String? ?? '—';
      _checkoutInvoiceId = data['invoiceId']?.toString();
      notifyListeners();
    } else {
      _error = _human(res['error']);
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> startOnline() async {
    if (_saleId == null) return null;
    _error = null;
    final res = await _send('payOnline', {'saleId': _saleId});
    if (_disposed) return null;
    if (res['ok'] == true) {
      final d = res['data'] as Map<String, dynamic>;
      _onlineAmount = (d['amount'] as num?)?.toDouble();
      unawaited(_refresh());
      return d;
    }
    _error = _human(res['error']);
    notifyListeners();
    return null;
  }

  Future<void> syncOnline() async {
    if (_saleId == null) return;
    final res = await _send('syncOnline', {'saleId': _saleId});
    if (_disposed) return;
    if (res['ok'] == true) _apply(res['data'] as Map<String, dynamic>);
  }

  Future<void> cancelOnline() async {
    if (_saleId == null) return;
    _onlineAmount = null;
    final res = await _send('cancelOnline', {'saleId': _saleId});
    if (_disposed) return;
    if (res['ok'] == true) {
      _apply(res['data'] as Map<String, dynamic>);
    } else {
      unawaited(_refresh());
    }
  }

  void clearUnknown() {
    _unknownCode = null;
    notifyListeners();
  }

  String _human(dynamic error) {
    final e = error?.toString() ?? '';
    if (e == 'offline' || e == 'timeout' || e == 'disconnected') return 'Reconnecting…';
    return e.isEmpty ? 'Something went wrong.' : e;
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
    for (final t in _pendingTimers.values) {
      t.cancel();
    }
    _pendingTimers.clear();
    _pending.clear();
    _sub?.cancel();
    _channel?.sink.close();
    super.dispose();
  }
}
