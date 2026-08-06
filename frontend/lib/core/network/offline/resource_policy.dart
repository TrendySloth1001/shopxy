/// Single source of truth for how each backend resource behaves offline.
///
/// Before this existed, the same knowledge was smeared across four places
/// (a cache denylist, a tag deriver, queueable regexes, and a provider-reload
/// switch) that had to be hand-kept in sync. Everything now derives from the
/// rules here: cacheability, the cache/event tag, queueability, and which tags
/// a provider reloads on.
///
/// A "tag" is a resource group — the first path segment (`/invoices/9/status`
/// → `invoices`). It's the unit of cache grouping, cache invalidation, and
/// revalidation events.
library;

class ResourcePolicy {
  const ResourcePolicy._();

  /// Reads that must always hit the network and are never cached / offline-
  /// served: the live device-session list, token refresh, live counts, and the
  /// barcode lookup (which must reflect current stock). Binary/PDF downloads
  /// go through `ApiClient` like any other GET, but `ApiClient` itself
  /// refuses to cache a non-JSON response body (see `_isJsonResponse` there),
  /// so they never reach the cache regardless of what's listed here.
  ///
  /// NOTE: `/auth/me` is deliberately NOT here — it's cached so the app can
  /// cold-boot into the shell offline (restoring the last-known profile). A
  /// stale/dead session self-corrects on the next online request (the live
  /// revalidation 401s → refresh fails → logout), and cache is wiped on logout.
  static const Set<String> _readDenylist = {
    'auth/sessions',
    'auth/refresh',
    'orders/pending-count',
    'products/lookup',
  };

  /// Naturally-idempotent updates that are safe to queue offline and replay
  /// (replaying the same PATCH/PUT twice → same end state). Deliberately narrow:
  /// only updates to an existing resource. POST *creates* and money/stock
  /// endpoints are excluded — they'd duplicate on replay or need live state.
  static final RegExp _idUpdate = RegExp(r'^(parties|vendors|products)/\d+$');
  static final RegExp _notifRead = RegExp(r'^notifications/\d+/read$');

  /// Strip a leading slash and any query string → the normalized path.
  static String _normalize(String path) {
    var p = path.startsWith('/') ? path.substring(1) : path;
    final q = p.indexOf('?');
    return q >= 0 ? p.substring(0, q) : p;
  }

  /// Resource group of a path (its first segment). Used for cache keys,
  /// invalidation, and revalidation events.
  static String tagFor(String path) {
    final p = _normalize(path);
    final slash = p.indexOf('/');
    return slash >= 0 ? p.substring(0, slash) : p;
  }

  /// Whether a GET may be cached / served from cache offline.
  static bool isCacheableRead(String path) {
    final p = _normalize(path);
    for (final deny in _readDenylist) {
      if (p == deny || p.startsWith('$deny/')) return false;
    }
    return true;
  }

  /// Whether an offline write may be queued and replayed on reconnect.
  static bool isQueueableWrite(String method, String path) {
    final p = _normalize(path);
    switch (method) {
      case 'PATCH':
        return _idUpdate.hasMatch(p) || p == 'auth/me';
      case 'PUT':
        return p == 'me/shop';
      case 'POST':
        return _notifRead.hasMatch(p) || p == 'notifications/read-all';
      default:
        return false;
    }
  }
}
