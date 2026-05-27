import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/network/image_url.dart';
import 'package:shopxy_customer/features/home/data/models/home_feed_models.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Customer-side renderer for a FREEFORM slide. Mirrors the merchant
/// editor's `FreeformCanvas` widget (drag/snap handlers omitted — the
/// customer is read-only). Render parity is by construction: every
/// transform applied on the merchant editor lands the same way here.
///
/// Sized to match the templated cards in the same PageView so the
/// merchant doesn't have to pick a different "freeform-only" layout.
class FreeformSlideCard extends StatelessWidget {
  const FreeformSlideCard({super.key, required this.slide});
  final HeroSlide slide;

  @override
  Widget build(BuildContext context) {
    final transform = slide.imageTransform ?? HeroSlideImageTransform.identity;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      child: SizedBox(
        height: 188,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              children: [
                Positioned.fill(child: Container(color: slide.bgColor)),
                if (slide.imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: _TransformedImage(
                      url: slide.imageUrl,
                      imageFit: slide.imageFit,
                      transform: transform,
                    ),
                  ),
                for (final b in slide.textBlocks)
                  Positioned(
                    left: b.xPct / 100 * w,
                    top: b.yPct / 100 * h,
                    width: b.widthPct / 100 * w,
                    child: _TextBlockView(block: b),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TransformedImage extends StatelessWidget {
  const _TransformedImage({
    required this.url,
    required this.imageFit,
    required this.transform,
  });
  final String url;
  final HeroImageFit imageFit;
  final HeroSlideImageTransform transform;

  @override
  Widget build(BuildContext context) {
    final fit = imageFit.boxFit;
    final alignment = imageFit == HeroImageFit.cover
        ? Alignment(
            (transform.focalXPct / 50) - 1,
            (transform.focalYPct / 50) - 1,
          )
        : Alignment.center;
    final matrix = _composeColorMatrix(
      brightness: transform.brightness,
      contrast: transform.contrast,
      saturation: transform.saturation,
    );
    Widget child = Image.network(
      resolveImageUrl(url),
      fit: fit,
      alignment: alignment,
      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.heroPanel),
    );
    if (matrix != null) {
      child =
          ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: child);
    }
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scaleByDouble(
          (transform.flipH ? -1 : 1) * transform.scale,
          (transform.flipV ? -1 : 1) * transform.scale,
          1,
          1,
        )
        ..rotateZ(transform.rotateDeg * 3.141592653589793 / 180),
      child: child,
    );
  }
}

/// Composes brightness × contrast × saturation into one 4×5 matrix.
/// Returns null when every axis is neutral so the renderer can skip
/// the ColorFiltered wrap (saves an off-screen layer on every frame).
List<double>? _composeColorMatrix({
  required double brightness,
  required double contrast,
  required double saturation,
}) {
  const eps = 0.001;
  if ((brightness - 1).abs() < eps &&
      (contrast - 1).abs() < eps &&
      (saturation - 1).abs() < eps) {
    return null;
  }
  // Rec. 601 luminance coefficients — same as the merchant canvas.
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final s = saturation;
  final c = contrast;
  final b = brightness;
  final cTr = (1 - c) * 128;
  return [
    c * (lr + (1 - lr) * s) * b,
    c * (lg - lg * s) * b,
    c * (lb - lb * s) * b,
    0,
    cTr,
    c * (lr - lr * s) * b,
    c * (lg + (1 - lg) * s) * b,
    c * (lb - lb * s) * b,
    0,
    cTr,
    c * (lr - lr * s) * b,
    c * (lg - lg * s) * b,
    c * (lb + (1 - lb) * s) * b,
    0,
    cTr,
    0, 0, 0, 1, 0,
  ];
}

class _TextBlockView extends StatelessWidget {
  const _TextBlockView({required this.block});
  final HeroSlideTextBlock block;

  TextAlign get _align {
    switch (block.align) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'left':
      default:
        return TextAlign.left;
    }
  }

  Color get _color {
    final raw = block.color.replaceFirst('#', '');
    final normalised = raw.length == 6 ? 'FF$raw' : raw;
    return Color(int.parse(normalised, radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      block.text,
      textAlign: _align,
      style: TextStyle(
        color: _color,
        fontWeight: FontWeight.values.firstWhere(
          (w) => w.value == block.weight,
          orElse: () => FontWeight.w700,
        ),
        fontSize: block.fontSize.toDouble(),
        height: 1.15,
      ),
    );
  }
}
