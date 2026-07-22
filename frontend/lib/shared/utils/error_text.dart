import 'dart:async';

import 'package:shopxy/core/network/offline/offline_errors.dart';

/// Turns any thrown error into a short, user-presentable message.
///
/// The data sources already unwrap API error bodies and rethrow them as
/// `Exception(serverMessage)` — so for those the server's own message is
/// what we want, minus the noisy `Exception: ` prefix that `toString()`
/// adds. Transport-level failures (no network, DNS, TLS, timeout) never
/// carry a useful message, so they're mapped to plain language instead
/// of leaking `SocketException: Failed host lookup: ...` into SnackBars.
String friendlyError(Object e) {
  // Offline write outcomes — a queued update is a *success* ("we've got it,
  // it'll sync"); a blocked one needs the user back online.
  if (e is OfflineWriteQueuedException) {
    return 'Saved offline — this will sync when you\'re back online.';
  }
  if (e is OfflineWriteBlockedException) {
    return 'You\'re offline. Reconnect to complete this.';
  }
  // Transport-level failures — the raw text is useless to a shopkeeper.
  if (e is TimeoutException) {
    return 'The server is taking too long to respond. Please try again.';
  }
  // Any other transport error (socket / TLS / client) — Timeout is handled
  // above, so this covers the rest via the shared classifier.
  if (isTransportError(e)) {
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
