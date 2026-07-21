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
    // Pin the glyph to [resolvedSize] and centre it — exactly what Material's
    // [Icon] does. Without this, a parent that imposes larger *tight*
    // constraints (a fixed-size icon chip/avatar, an IconButton slot, etc.)
    // stretches the icon: Hugeicons renders via an SvgPicture that scales to
    // fill its constraints, unlike a fixed-size Material font glyph. The outer
    // SizedBox takes the slot's size; the Center hands the icon loose
    // constraints so the SVG stays at [resolvedSize].
    return SizedBox.square(
      dimension: resolvedSize,
      child: Center(
        child: glyph == null
            ? const SizedBox.shrink()
            : HugeIcon(
                icon: glyph,
                size: resolvedSize,
                color: color ?? iconTheme.color ?? const Color(0xFF000000),
              ),
      ),
    );
  }
}
