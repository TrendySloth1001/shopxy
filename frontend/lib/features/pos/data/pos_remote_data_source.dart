import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';

/// The POS runs entirely over the WebSocket; the only HTTP call is the ticket
/// mint that bootstraps the socket (Bearer-authed via ApiClient). See
/// PosSaleClient for the command protocol.
class PosRemoteDataSource {
  const PosRemoteDataSource(this._client);
  final ApiClient _client;

  /// Mint a WS ticket from the POS (invoices) area.
  Future<({String ticket, String path})> requestTicket() async {
    final r = await _client.post('/me/pos/ticket');
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Ticket failed (${r.statusCode}): ${r.body}');
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    return (ticket: body['ticket'] as String, path: body['path'] as String);
  }
}
