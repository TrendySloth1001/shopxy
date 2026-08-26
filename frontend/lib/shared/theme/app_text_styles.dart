import 'package:flutter/material.dart';

extension AppTextWeight on TextStyle {
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);

  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);

  TextStyle get extraBold => copyWith(fontWeight: FontWeight.w800);

  TextStyle get black => copyWith(fontWeight: FontWeight.w900);
}

abstract final class AppTextStyles {
  AppTextStyles._();

  static TextStyle caption(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 11);

  static TextStyle micro(BuildContext context) => Theme.of(
    context,
  ).textTheme.labelSmall!.copyWith(fontSize: 10, fontWeight: FontWeight.w600);
}
