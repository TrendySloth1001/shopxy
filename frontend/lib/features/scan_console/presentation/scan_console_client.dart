import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shopxy/core/config/app_config.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/scan_console/data/scan_console_remote_data_source.dart';

enum ScanConnStatus { connecting, connected, reconnecting, error }

/// One row of scanner-side feedback, driven by the server's ack so it reflects
/// what actually reached the backend (not just what the camera saw).
class ScanFeedback {
  ScanFeedback({
    required this.title,
    required this.subtitle,
    required this.ok,
    required this.at,
  });
  final String title;
  final String subtitle;
  final bool ok;
  final DateTime at;
}

/// Holds the scanner's live WebSocket to the shop room: mints a ticket, opens
/// the socket (role=scanner), pushes scans, and surfaces connection + presence
/// state so the phone can show "connection established · N watching". Reconnects
/// with a fresh ticket on drop.
class ScanConsoleClient extends ChangeNotifier {
  ScanConsoleClient(ApiClient client) : _ds = ScanConsoleRemoteDataSource(client);
  final ScanConsoleRemoteDataSource _ds;

  ScanConnStatus _status = ScanConnStatus.connecting;
  ScanConnStatus get status => _status;

  String? _error;
  String? get error => _error;

  int _consoles = 0;
  int get consoles => _consoles;
  int _scanners = 0;
  int get scanners => _scanners;

  int _sentCount = 0;
  int get sentCount => _sentCount;

  final List<ScanFeedback> _recent = [];
  List<ScanFeedback> get recent => List.unmodifiable(_recent);

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  int _attempt = 0;
  bool _disposed = false;

  Future<void> start() async {
    _disposed = false;
    await _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    _setStatus(_attempt == 0 ? ScanConnStatus.connecting : ScanConnStatus.reconnecting);
    try {
      final ticket = await _ds.requestTicket();
      if (_disposed) return;

      // Same host as the REST base, ws(s) scheme. The phone's apiBaseUrl and the
      // WebSocket therefore share one origin (the dev tunnel) — "same url".
      final wsBase = AppConfig.apiBaseUrl
          .replaceFirst(RegExp(r'^http'), 'ws')
          .replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse('$wsBase${ticket.path}?ticket=${ticket.ticket}&role=scanner');

      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      await channel.ready; // throws on a failed handshake (e.g. 401)
      if (_disposed) {
        await channel.sink.close();
        return;
      }
      _error = null;
      _sub = channel.stream.listen(_onData, onDone: _onDone, onError: (_) => _onDone());
    } catch (e) {
      if (_disposed) return;
      _error = _humanError(e);
      _setStatus(ScanConnStatus.error);
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
    switch (msg['type']) {
      case 'connected':
        _attempt = 0;
        _applyPresence(msg['presence'] as Map<String, dynamic>?);
        _setStatus(ScanConnStatus.connected);
      case 'presence':
        _applyPresence(msg['presence'] as Map<String, dynamic>?);
        notifyListeners();
      case 'ack':
        final matched = msg['matched'] == true;
        final code = (msg['code'] as String?) ?? '';
        _recent.insert(
          0,
          ScanFeedback(
            title: matched ? ((msg['name'] as String?) ?? code) : code,
            subtitle: matched ? ((msg['sku'] as String?) ?? '') : 'No match in this shop',
            ok: matched,
            at: DateTime.now(),
          ),
        );
        if (matched) _sentCount++;
        if (_recent.length > 30) _recent.removeLast();
        notifyListeners();
    }
  }

  void _applyPresence(Map<String, dynamic>? p) {
    _consoles = (p?['consoles'] as int?) ?? 0;
    _scanners = (p?['scanners'] as int?) ?? 0;
  }

  void _onDone() {
    if (_disposed) return;
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _consoles = 0;
    _scanners = 0;
    _setStatus(ScanConnStatus.reconnecting);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _retry != null) return;
    final exp = _attempt > 4 ? 4 : _attempt;
    final delayMs = (1000 * (1 << exp)).clamp(1000, 8000);
    _attempt++;
    _retry = Timer(Duration(milliseconds: delayMs), () {
      _retry = null;
      _connect();
    });
  }

  /// Push a scanned code over the socket. Dropped silently if not connected —
  /// the UI shows the connection state so the user knows scans aren't flowing.
  void sendScan(String code) {
    if (_status != ScanConnStatus.connected || _channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'scan', 'code': code}));
  }

  Future<void> clearConsole() async {
    await _ds.clearConsole();
    _recent.clear();
    _sentCount = 0;
    notifyListeners();
  }

  void _setStatus(ScanConnStatus s) {
    _status = s;
    notifyListeners();
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('401') || s.contains('403')) {
      return 'Not authorised — sign in again.';
    }
    return 'Cannot reach the server. Check your connection.';
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
