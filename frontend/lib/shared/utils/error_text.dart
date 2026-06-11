import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Turns any thrown error into a short, user-presentable message.
///
/// The data sources already unwrap API error bodies and rethrow them as
/// `Exception(serverMessage)` — so for those the server's own message is
/// what we want, minus the noisy `Exception: ` prefix that `toString()`
/// adds. Transport-level failures (no network, DNS, TLS, timeout) never
/// carry a useful message, so they're mapped to plain language instead
/// of leaking `SocketException: Failed host lookup: ...` into SnackBars.
String friendlyError(Object e) {
  // Transport-level failures — the raw text is useless to a shopkeeper.
  if (e is TimeoutException) {
    return 'The server is taking too long to respond. Please try again.';
  }
  if (e is SocketException ||
      e is HandshakeException ||
      e is http.ClientException) {
    return 'Couldn\'t reach the server. Check your connection.';
  }
  // A response that wasn't the JSON we expected.
  if (e is FormatException) {
    return 'Something went wrong. Please try again.';
  }

  var message = e.toString().trim();
  // Strip the standard `Exception: ` / `Bad state: ` prefixes (repeat to
  // handle nested `Exception: Exception: ...` wrapping).
  while (true) {
    final stripped = message
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^Bad state:\s*'), '');
    if (stripped == message) break;
    message = stripped.trim();
  }
  // Nothing human-readable left (empty, or a bare status code / class
  // name like "Instance of 'XYZ'") → generic fallback.
  if (message.isEmpty ||
      message.startsWith("Instance of '") ||
      RegExp(r'^\d{3}$').hasMatch(message)) {
    return 'Something went wrong. Please try again.';
  }
  return message;
}
