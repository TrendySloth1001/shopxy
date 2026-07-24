import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icons_material.g.dart';
import 'package:shopxy/shared/theme/app_theme_spec.dart';

/// Resolve a glyph to a Material [IconData] for the active icon style, or null
/// to render the Hugeicons default. This is the SINGLE choke point for the
/// icon-style axis: the `material*` styles look the glyph up in the codegen'd
/// [kMaterialIconMap] (keyed on the const [AppIcons] glyphs — const
/// canonicalisation makes identity lookup work); anything unmapped, or the
/// `hugeicons` default, returns null → Hugeicons renders. No call site changes.
IconData? resolveMaterialIcon(AppIconData? glyph, AppIconStyle style) {
  if (glyph == null || style == AppIconStyle.hugeicons) return null;
  final set = kMaterialIconMap[glyph];
  if (set == null) return null;
  return switch (style) {
    AppIconStyle.materialOutlined => set.outlined,
    AppIconStyle.materialRounded => set.rounded,
    AppIconStyle.materialSharp => set.sharp,
    AppIconStyle.hugeicons => null,
  };
}

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
    final resolvedColor = color ?? iconTheme.color ?? const Color(0xFF000000);

    // Icon-style axis: render a Material glyph when the active style is a
    // `material*` one and this glyph is mapped; otherwise fall through to
    // Hugeicons (the default, and the fallback for anything unmapped).
    final material = resolveMaterialIcon(icon, AppThemeSpec.active.iconStyle);
    if (material != null) {
      return SizedBox.square(
        dimension: resolvedSize,
        child: Center(
          child: Icon(material, size: resolvedSize, color: resolvedColor),
        ),
      );
    }
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
