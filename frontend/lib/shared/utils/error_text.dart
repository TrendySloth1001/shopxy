import 'dart:async';

import 'package:shopxy/core/network/offline/offline_errors.dart';

String friendlyError(Object e) {
  if (e is OfflineWriteQueuedException) {
    return 'Saved offline — this will sync when you\'re back online.';
  }
  if (e is OfflineWriteBlockedException) {
    return 'You\'re offline. Reconnect to complete this.';
  }
  if (e is TimeoutException) {
    return 'The server is taking too long to respond. Please try again.';
  }
  if (isTransportError(e)) {
    return 'Couldn\'t reach the server. Check your connection.';
  }
  if (e is FormatException) {
    return 'Something went wrong. Please try again.';
  }

  var message = e.toString().trim();
  while (true) {
    final stripped = message
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^Bad state:\s*'), '');
    if (stripped == message) break;
    message = stripped.trim();
  }
  if (message.isEmpty ||
      message.startsWith("Instance of '") ||
      RegExp(r'^\d{3}$').hasMatch(message)) {
    return 'Something went wrong. Please try again.';
  }
  return message;
}
