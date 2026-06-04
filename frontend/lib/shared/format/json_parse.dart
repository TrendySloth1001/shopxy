// Resilient JSON date parsing for list endpoints (MOD-3). A single
// malformed/missing date would otherwise fail the entire row/list parse
// via `DateTime.parse`. These fall back instead of throwing.

/// Parse a required ISO date, falling back to [fallback] (or the epoch)
/// when the value is missing or unparseable — so one bad row can't sink
/// a whole list.
DateTime parseDate(Object? v, {DateTime? fallback}) {
  if (v is String) {
    final d = DateTime.tryParse(v);
    if (d != null) return d;
  }
  return fallback ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// Parse an optional ISO date — null when absent or unparseable.
DateTime? parseDateOrNull(Object? v) =>
    v is String ? DateTime.tryParse(v) : null;
