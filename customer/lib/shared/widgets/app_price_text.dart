import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Consistent currency rendering. Two key rules from `DESIGN.md`:
///   * Tabular figures so columns of prices align across rows.
///   * Full currency symbol always — never strip the ₹ to "save space".
///
/// `compact` shows ₹1,299 (no paisa). `precise` shows ₹1,299.00 —
/// use precise on detail pages, totals, line items; compact in cards
/// and chips where pixel real-estate matters.
class AppPriceText extends StatelessWidget {
  const AppPriceText(
    this.amount, {
    super.key,
    this.precise = false,
    this.strikethrough = false,
    this.style,
    this.color,
    this.fontWeight,
  });

  /// Compact constructor — no paisa. Use in cards and lists.
  const AppPriceText.compact(
    this.amount, {
    super.key,
    this.strikethrough = false,
    this.style,
    this.color,
    this.fontWeight,
  }) : precise = false;

  /// Precise constructor — full ₹X,XXX.YY. Use on detail pages and
  /// totals.
  const AppPriceText.precise(
    this.amount, {
    super.key,
    this.strikethrough = false,
    this.style,
    this.color,
    this.fontWeight,
  }) : precise = true;

  final num amount;
  final bool precise;
  final bool strikethrough;
  final TextStyle? style;
  final Color? color;
  final FontWeight? fontWeight;

  static final _compactFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: AppStrings.currencySymbol,
    decimalDigits: 0,
  );

  static final _preciseFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: AppStrings.currencySymbol,
    decimalDigits: 2,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = (precise ? _preciseFmt : _compactFmt).format(amount);
    final base = style ?? theme.textTheme.bodyLarge;
    return Text(
      formatted,
      style: base?.copyWith(
        color: color ?? AppColors.black,
        fontWeight: fontWeight ?? FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
        decoration: strikethrough ? TextDecoration.lineThrough : null,
        decorationColor: AppColors.subtle,
      ),
    );
  }
}
