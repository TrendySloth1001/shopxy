import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Squircle thumbnail used everywhere a product needs an avatar — list
/// rows, detail-page hero, edit-page preview. Falls back to a
/// hash-tinted monogram when there's no image (or the image fails to
/// load), so a product without a photo still reads as recognisable.
///
/// Provide [size] for the side of the square. Border radius scales
/// gently with size — small thumbs use [AppSizes.radiusMd], large
/// thumbs use [AppSizes.radiusLg] so they don't look like blown-up
/// versions of the small chip.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({
    super.key,
    required this.product,
    this.size = AppSizes.productThumbSize,
  });

  final Product product;
  final double size;

  /// Stable per-product hash → one of six brand-friendly accents. Same
  /// product always picks the same colour so the row reads as a deck
  /// of recognisable cards rather than identical placeholders.
  // Getter, not `static final`: AppColors.* are theme-aware getters, so a
  // cached list would freeze the light-mode tints and not flip in dark.
  static List<(Color bg, Color fg)> get _accents => [
        (AppColors.brandSoft, AppColors.brandStrong),
        (AppColors.accentTealSoft, AppColors.accentTeal),
        (AppColors.accentIndigoSoft, AppColors.accentIndigo),
        (AppColors.accentAmberSoft, AppColors.accentAmber),
        (AppColors.accentRoseSoft, AppColors.accentRose),
        (AppColors.successSoft, AppColors.success),
      ];

  String get _initial {
    final name = product.name.trim();
    if (name.isEmpty) return '?';
    return name[0].toUpperCase();
  }

  (Color, Color) get _palette =>
      _accents[product.id.hashCode.abs() % _accents.length];

  @override
  Widget build(BuildContext context) {
    final raw = product.primaryImageUrl ?? '';
    final hasImage = raw.isNotEmpty;
    final resolved = hasImage ? resolveImageUrl(raw) : '';
    final radius = size <= 64 ? AppSizes.radiusMd : AppSizes.radiusLg;
    final shape = AppShapes.squircle(
      radius,
      side: BorderSide(color: AppColors.hairline, width: 1),
    );
    final (bg, fg) = _palette;

    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: hasImage ? AppColors.surface : AppColors.tileBg(bg),
        shape: shape,
      ),
      child: hasImage
          ? ClipPath(
              clipper: ShapeBorderClipper(shape: shape),
              child: CachedNetworkImage(
                imageUrl: resolved,
                fit: BoxFit.cover,
                // Decode to the physical pixel size of this thumb, not the
                // source resolution — a 1500² product photo otherwise decodes
                // to ~9 MB in RAM for a ≤64px slot. Rounds up a touch so a
                // hero-sized thumb still stays crisp.
                memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                placeholder: (_, _) => Container(
                  color: AppColors.heroPanel,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (_, _, _) =>
                    _MonogramFallback(initial: _initial, bg: bg, fg: fg, size: size),
              ),
            )
          : _MonogramFallback(initial: _initial, bg: bg, fg: fg, size: size),
    );
  }
}

class _MonogramFallback extends StatelessWidget {
  const _MonogramFallback({
    required this.initial,
    required this.bg,
    required this.fg,
    required this.size,
  });
  final String initial;
  final Color bg;
  final Color fg;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Letter scales with the container so it always reads the same
    // visual weight whether this is a 36px thumb or a 160px hero.
    final fontSize = (size * 0.42).clamp(14.0, 64.0);
    return Container(
      color: AppColors.tileBg(bg),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: fontSize,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
