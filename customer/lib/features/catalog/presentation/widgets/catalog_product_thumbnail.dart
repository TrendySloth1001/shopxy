import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/shared/domain/entities/catalog_product.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Image-or-monogram thumbnail for products on the customer side.
/// Mirrors the merchant app's `ProductThumbnail`: real photo when
/// available, hash-tinted monogram fallback when not (or when the
/// network image fails). Used in the grid card, cart row, and detail
/// hero so a product reads the same wherever it appears.
class CatalogProductThumbnail extends StatelessWidget {
  const CatalogProductThumbnail({
    super.key,
    required this.product,
    this.size = 56,
    this.cornerRadius,
  });

  final CatalogProduct product;
  final double size;
  final double? cornerRadius;

  /// Stable per-product hash → one of six brand-friendly accents.
  static const _accents = <(Color bg, Color fg)>[
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

  (Color, Color) get _palette => _accents[product.id % _accents.length];

  @override
  Widget build(BuildContext context) {
    final raw = product.imageUrl ?? '';
    final hasImage = raw.isNotEmpty;
    final resolved = hasImage ? resolveImageUrl(raw) : '';
    final radius = cornerRadius ??
        (size <= AppSizes.massive ? AppSizes.radiusMd : AppSizes.radiusLg);
    final shape = AppShapes.squircle(radius);
    final (bg, fg) = _palette;

    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: hasImage ? AppColors.white : bg,
        shape: shape,
      ),
      child: hasImage
          ? ClipPath(
              clipper: ShapeBorderClipper(shape: shape),
              child: Image.network(
                resolved,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _Monogram(
                  initial: _initial,
                  bg: bg,
                  fg: fg,
                  size: size,
                ),
              ),
            )
          : _Monogram(initial: _initial, bg: bg, fg: fg, size: size),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({
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
    final fontSize = (size * 0.42).clamp(14.0, 64.0);
    return Container(
      color: bg,
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
