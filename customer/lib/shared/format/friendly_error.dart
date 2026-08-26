import 'dart:async';
import 'dart:io';

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
  if (msg.startsWith('ClientException') ||
      msg.contains('XMLHttpRequest') ||
      msg.startsWith('HandshakeException')) {
    return "Can't reach the server. Check your connection and try again.";
  }
  return msg;
}
