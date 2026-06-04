import 'package:intl/intl.dart';

/// Single source of truth for money / number presentation. Centralised so
/// the currency symbol and locale live in ONE place rather than being
/// re-declared per mapper (MOD-1) — a future locale/format change is one
/// edit. The app is India-only today (₹, en_IN grouping).
class AppFormat {
  const AppFormat._();

  /// The currency symbol used everywhere. Prefer [rupees]/[inr] over
  /// hand-writing `'₹'` in new code.
  static const String currencySymbol = '₹';

  /// Whole-rupee currency formatter ("₹13,990"). en_IN digit grouping.
  static final NumberFormat inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: currencySymbol,
    decimalDigits: 0,
  );

  /// Format a value as whole rupees.
  static String rupees(num v) => inr.format(v);
}
