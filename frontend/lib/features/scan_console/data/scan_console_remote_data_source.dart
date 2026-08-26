import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';

class ScanTicket {
  const ScanTicket({required this.ticket, required this.path});
  final String ticket;
  final String path;
}

class ScanConsoleRemoteDataSource {
  const ScanConsoleRemoteDataSource(this._client);
  final ApiClient _client;

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

  Future<void> clearConsole() async {
    final response = await _client.post('/me/scan-console/clear');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Clear failed (${response.statusCode}): ${response.body}');
    }
  }
}
