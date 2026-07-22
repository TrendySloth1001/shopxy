/// Typed errors for the offline layer.
///
/// The app has no shared `ApiException` — data sources throw plain
/// `Exception(message)` and `friendlyError()` (lib/shared/utils/error_text.dart)
/// maps them to copy. These two are the only *typed* exceptions the offline
/// layer needs so callers (and `friendlyError`) can special-case them.
library;

import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Whether [e] is a transport-level failure — the request never reached the
/// server (socket drop, DNS, TLS, timeout) — as opposed to an HTTP error
/// status, which means the server *did* answer. Single source of truth for
/// "this means offline", shared by `ApiClient` (cache fallback) and
/// `friendlyError` (user copy) so the two can't drift.
bool isTransportError(Object e) =>
    e is SocketException ||
    e is TimeoutException ||
    e is http.ClientException ||
    e is HandshakeException;

/// Thrown by `ApiClient.get` when the network is unreachable AND there is no
/// cached copy to fall back to (e.g. a screen opened for the first time while
/// offline). The UI should show a "you're offline" empty state, not a generic
/// error.
class OfflineNoDataException implements Exception {
  const OfflineNoDataException(this.path);

  /// The request path that had no cache, for logging/diagnostics.
  final String path;

  @override
  String toString() => 'OfflineNoDataException($path)';
}

/// Thrown by `ApiClient.post/patch/put/delete` when the network is unreachable
/// and the endpoint is NOT safe to queue offline (a POST create that would
/// duplicate on replay, or a money/stock-critical mutation that needs live
/// server state). The UI should tell the user to reconnect.
class OfflineWriteBlockedException implements Exception {
  const OfflineWriteBlockedException(this.method, this.path);

  final String method;
  final String path;

  @override
  String toString() => 'OfflineWriteBlockedException($method $path)';
}

/// Signals that an offline write was safely queued (a naturally-idempotent
/// update) and will replay on reconnect.
///
/// **Why an exception for a non-error outcome?** The data layer is uniformly
/// throw-based — every data source turns a non-2xx into `throw Exception(...)`
/// and pages already wrap writes in `try/catch` + `friendlyError`. Signalling
/// "queued" as a typed throwable rides that existing path, so `friendlyError`
/// renders "Saved offline — will sync" with zero per-page changes. Introducing
/// a Result type instead would mean touching all ~90 write call sites, so this
/// stays consistent with the codebase's convention rather than fighting it.
///
/// **Consistency model:** eventual, not optimistic. The edited entity keeps its
/// old value locally until the outbox replays on reconnect (which then
/// invalidates the cache and reloads the list). The user is told clearly that
/// it's saved-and-pending; true optimistic local updates would require
/// per-provider work and are intentionally out of scope.
class OfflineWriteQueuedException implements Exception {
  const OfflineWriteQueuedException(this.method, this.path);

  final String method;
  final String path;

  @override
  String toString() => 'OfflineWriteQueuedException($method $path)';
}
