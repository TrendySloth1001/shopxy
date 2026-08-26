library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

bool isTransportError(Object e) =>
    e is SocketException ||
    e is TimeoutException ||
    e is http.ClientException ||
    e is HandshakeException;

class OfflineNoDataException implements Exception {
  const OfflineNoDataException(this.path);

  final String path;

  @override
  String toString() => 'OfflineNoDataException($path)';
}

class OfflineWriteBlockedException implements Exception {
  const OfflineWriteBlockedException(this.method, this.path);

  final String method;
  final String path;

  @override
  String toString() => 'OfflineWriteBlockedException($method $path)';
}

class OfflineWriteQueuedException implements Exception {
  const OfflineWriteQueuedException(this.method, this.path);

  final String method;
  final String path;

  @override
  String toString() => 'OfflineWriteQueuedException($method $path)';
}
