import 'package:intl/intl.dart';

class AppFormat {
  const AppFormat._();

  static const String currencySymbol = '₹';

  static final NumberFormat inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: currencySymbol,
    decimalDigits: 0,
  );

  static final NumberFormat inrPrecise = NumberFormat.currency(
    locale: 'en_IN',
    symbol: currencySymbol,
    decimalDigits: 2,
  );

  static String rupees(num v) => inr.format(v);

  static String rupeesPrecise(num v) => inrPrecise.format(v);

  static String rupeesSmart(num v) =>
      v == v.roundToDouble() ? inr.format(v) : inrPrecise.format(v);
}
