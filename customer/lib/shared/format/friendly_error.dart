import 'dart:async';
import 'dart:io';

/// Turns a caught error into copy that's safe to show in a SnackBar.
///
/// Data sources throw `Exception('<server message>')` with messages that
/// are already user-appropriate — those pass through (minus the
/// "Exception: " prefix). Transport-level failures (timeouts, dead
/// connections, malformed payloads) would otherwise leak raw
/// `SocketException: …` text at the user, so they map to short, calm
/// fallbacks instead.
String friendlyError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is TimeoutException) {
    return 'The server is taking too long to respond. Please try again.';
  }
  if (error is SocketException) {
    return "Can't reach the server. Check your connection and try again.";
  }
  if (error is HttpException || error is FormatException) return fallback;

  final msg = error.toString().replaceFirst('Exception: ', '').trim();
  if (msg.isEmpty || msg == 'null') return fallback;
  // Raw exception types that still leak through toString().
  if (msg.startsWith('ClientException') ||
      msg.contains('XMLHttpRequest') ||
      msg.startsWith('HandshakeException')) {
    return "Can't reach the server. Check your connection and try again.";
  }
  return msg;
}
