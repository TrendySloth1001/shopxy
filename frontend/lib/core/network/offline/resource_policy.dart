library;

class ResourcePolicy {
  const ResourcePolicy._();

  static const Set<String> _readDenylist = {
    'auth/sessions',
    'auth/refresh',
    'orders/pending-count',
    'products/lookup',
  };

  static final RegExp _idUpdate = RegExp(r'^(parties|vendors|products)/\d+$');
  static final RegExp _notifRead = RegExp(r'^notifications/\d+/read$');

  static String _normalize(String path) {
    var p = path.startsWith('/') ? path.substring(1) : path;
    final q = p.indexOf('?');
    return q >= 0 ? p.substring(0, q) : p;
  }

  static String tagFor(String path) {
    final p = _normalize(path);
    final slash = p.indexOf('/');
    return slash >= 0 ? p.substring(0, slash) : p;
  }

  static bool isCacheableRead(String path) {
    final p = _normalize(path);
    for (final deny in _readDenylist) {
      if (p == deny || p.startsWith('$deny/')) return false;
    }
    return true;
  }

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
