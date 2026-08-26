import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/format/app_format.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

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

  const AppPriceText.compact(
    this.amount, {
    super.key,
    this.strikethrough = false,
    this.style,
    this.color,
    this.fontWeight,
  }) : precise = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = (precise ? AppFormat.inrPrecise : AppFormat.inr).format(amount);
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
