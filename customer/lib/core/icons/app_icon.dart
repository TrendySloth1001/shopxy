import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';

/// Drop-in replacement for Flutter's [Icon] that renders a Hugeicons glyph.
///
/// It mirrors [Icon]'s API — a positional icon plus optional [size]/[color] —
/// and, like [Icon], falls back to the ambient [IconTheme] for size and colour
/// when they aren't given. That lets `AppIcon(AppIcons.foo)` sit anywhere an
/// `Icon(...)` used to and keep the same theming.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size, this.color});

  /// The Hugeicons glyph payload (see [AppIcons]). Nullable to mirror [Icon];
  /// a null icon renders a blank box of the resolved size.
  final AppIconData? icon;

  /// Icon size in logical pixels; defaults to the ambient [IconTheme] size.
  final double? size;

  /// Icon colour; defaults to the ambient [IconTheme] colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24.0;
    final glyph = icon;
    if (glyph == null) return SizedBox.square(dimension: resolvedSize);
    return HugeIcon(
      icon: glyph,
      size: resolvedSize,
      color: color ?? iconTheme.color ?? const Color(0xFF000000),
    );
  }
}
