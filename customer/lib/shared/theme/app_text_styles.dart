import 'package:flutter/material.dart';

/// Typography helpers layered on top of the themed `TextTheme`
/// ([AppTypography]). The base style always stays the token
/// (`theme.textTheme.*`); these only vary the weight, replacing the ~850
/// scattered `.copyWith(fontWeight: FontWeight.wN)` overrides with a named,
/// value-identical accessor.
///
/// ```dart
/// Text('Total', style: theme.textTheme.titleMedium!.extraBold)
/// // was: ...titleMedium!.copyWith(fontWeight: FontWeight.w800)
/// ```
///
/// Add a new *weight* here; add a new *semantic style* to [AppTextStyles].
extension AppTextWeight on TextStyle {
  /// FontWeight.w500
  TextStyle get medium => copyWith(fontWeight: FontWeight.w500);

  /// FontWeight.w600
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);

  /// FontWeight.w700
  TextStyle get bold => copyWith(fontWeight: FontWeight.w700);

  /// FontWeight.w800
  TextStyle get extraBold => copyWith(fontWeight: FontWeight.w800);

  /// FontWeight.w900
  TextStyle get black => copyWith(fontWeight: FontWeight.w900);
}

/// Named semantic text styles for recurring roles that don't map cleanly onto a
/// single Material slot. Resolve against the ambient theme so colour/family
/// stay themed. Prefer these (or `theme.textTheme.* [+ weight]`) over inline
/// `TextStyle(fontSize: …)`.
abstract final class AppTextStyles {
  AppTextStyles._();

  /// Tiny metadata / captions (timestamps, helper text) — 11px.
  static TextStyle caption(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!.copyWith(fontSize: 11);

  /// Micro labels / badge text — 10px, semibold.
  static TextStyle micro(BuildContext context) => Theme.of(
    context,
  ).textTheme.labelSmall!.copyWith(fontSize: 10, fontWeight: FontWeight.w600);
}
