import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';

/// A one-time ticket for opening the scan-console WebSocket.
class ScanTicket {
  const ScanTicket({required this.ticket, required this.path});
  final String ticket;
  final String path;
}

/// HTTP side of the scan console: mint a WebSocket ticket and clear the feed.
/// Scans themselves travel over the WebSocket (see ScanConsoleClient), so a
/// "connection established" state is real and every scan is acked.
class ScanConsoleRemoteDataSource {
  const ScanConsoleRemoteDataSource(this._client);
  final ApiClient _client;

  /// Mint a single-use ticket (Bearer-authed via ApiClient, with refresh).
  Future<ScanTicket> requestTicket() async {
    final response = await _client.post('/me/scan-console/ticket');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Ticket failed (${response.statusCode}): ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ScanTicket(
      ticket: body['ticket'] as String,
      path: body['path'] as String,
    );
  }

  /// Reset every live console for this shop.
  Future<void> clearConsole() async {
    final response = await _client.post('/me/scan-console/clear');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Clear failed (${response.statusCode}): ${response.body}');
    }
  }
}
