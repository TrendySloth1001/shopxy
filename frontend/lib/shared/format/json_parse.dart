DateTime parseDate(Object? v, {DateTime? fallback}) {
  if (v is String) {
    final d = DateTime.tryParse(v);
    if (d != null) return d;
  }
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

DateTime? parseDateOrNull(Object? v) =>
    v is String ? DateTime.tryParse(v) : null;
