import 'package:flutter/material.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/admin/data/models/banner.dart';
import 'package:shopxy/features/carousel/data/models/carousel.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Live-rendering canvas for a FREEFORM slide. Doubles as both the
/// merchant's editor (when `editable: true`) and the preview surface
/// — keeping one widget for both means a tweak to the renderer can't
/// drift between edit and preview behaviour.
///
/// Editable mode adds:
///   * Drag handle on every text block (the whole block is the handle).
///     Drags snap to a 12-column / 8-row grid; the active grid line
///     paints under the touch point.
///   * Tap a block → reports the selection via [onSelect]; the editor
///     page shows an inspector below for text / font / color edits.
///   * Tap empty canvas → clears the selection.
///
/// Positioning is percent-of-canvas (xPct/yPct/widthPct) so the layout
/// resolves identically on customer screens of any density.
class FreeformCanvas extends StatelessWidget {
  const FreeformCanvas({
    super.key,
    required this.imageUrl,
    required this.bgColor,
    required this.imageFit,
    required this.transform,
    required this.blocks,
    this.editable = false,
    this.selectedBlockId,
    this.onSelect,
    this.onBlockChanged,
    this.aspect = 16 / 9,
  });

  final String? imageUrl;
  final Color bgColor;
  final BannerImageFit imageFit;
  final CarouselSlideImageTransform transform;
  final List<CarouselSlideTextBlock> blocks;

  final bool editable;
  final String? selectedBlockId;
  /// Fires when the merchant taps a block (id) or the empty canvas (null).
  final ValueChanged<String?>? onSelect;
  /// Fires while a block is being dragged. The block list is treated
  /// as immutable from the caller's side; we only emit the updated
  /// row so the parent can splice it in.
  final ValueChanged<CarouselSlideTextBlock>? onBlockChanged;

  /// Canvas aspect ratio. The customer hero card ships at 16:9-ish;
  /// using the same aspect here means what the merchant sees is what
  /// the customer renders.
  final double aspect;

  /// 12-column / 8-row snap grid in percent (0..100). Exposed so the
  /// drag handler and the painter agree.
  static const int gridCols = 12;
  static const int gridRows = 8;
  static const double _colPct = 100 / gridCols;
  static const double _rowPct = 100 / gridRows;

  static double _snap(double pct, double step) =>
      ((pct / step).round() * step).clamp(0.0, 100.0);

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspect,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusLg),
            child: GestureDetector(
              onTapDown: editable
                  ? (_) => onSelect?.call(null) // tap canvas clears selection
                  : null,
              behavior: HitTestBehavior.opaque,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Container(color: bgColor),
                  ),
                  if (imageUrl != null)
                    Positioned.fill(
                      child: _TransformedImage(
                        url: imageUrl!,
                        imageFit: imageFit,
                        transform: transform,
                      ),
                    ),
                  if (editable) Positioned.fill(child: _GridOverlay()),
                  for (final b in blocks)
                    Positioned(
                      left: b.xPct / 100 * w,
                      top: b.yPct / 100 * h,
                      width: b.widthPct / 100 * w,
                      child: _TextBlockView(
                        block: b,
                        editable: editable,
                        selected: editable && b.id == selectedBlockId,
                        canvasWidth: w,
                        canvasHeight: h,
                        onTap: () => onSelect?.call(b.id),
                        onDrag: (dxPct, dyPct) {
                          if (onBlockChanged == null) return;
                          final nextX = _snap(b.xPct + dxPct, _colPct);
                          final nextY = _snap(b.yPct + dyPct, _rowPct);
                          // Keep the block at least partially on canvas so
                          // a drag-off doesn't strand it visually.
                          final clampedX = nextX.clamp(0.0, 100.0 - b.widthPct);
                          final clampedY = nextY.clamp(0.0, 95.0);
                          if (clampedX == b.xPct && clampedY == b.yPct) return;
                          onBlockChanged!(
                            CarouselSlideTextBlock(
                              id: b.id,
                              text: b.text,
                              xPct: clampedX,
                              yPct: clampedY,
                              widthPct: b.widthPct,
                              fontSize: b.fontSize,
                              color: b.color,
                              weight: b.weight,
                              align: b.align,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Applies imageTransform (focal point, scale, rotate, flip, filters)
/// on top of the merchant's BoxFit choice. The focal point shifts the
/// crop window for COVER; CONTAIN ignores it (the whole image fits, so
/// "which part survives" is moot).
class _TransformedImage extends StatelessWidget {
  const _TransformedImage({
    required this.url,
    required this.imageFit,
    required this.transform,
  });
  final String url;
  final BannerImageFit imageFit;
  final CarouselSlideImageTransform transform;

  @override
  Widget build(BuildContext context) {
    final fit = imageFit == BannerImageFit.contain ? BoxFit.contain : BoxFit.cover;

    // Focal alignment: 0..100 → -1..+1 on each axis. Only meaningful
    // for COVER; for CONTAIN we centre.
    final alignment = imageFit == BannerImageFit.cover
        ? Alignment(
            (transform.focalXPct / 50) - 1,
            (transform.focalYPct / 50) - 1,
          )
        : Alignment.center;

    // ColorFilter mimics CSS-style brightness/contrast/saturation. All
    // three axes are bounded server-side at [0.5, 1.5], so the
    // composed matrix stays within visually reasonable territory.
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
      child = ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: child);
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

/// Composes brightness × contrast × saturation into a single 4×5
/// ColorFilter matrix. Returns null when every axis is neutral so the
/// renderer can skip the ColorFiltered wrap entirely.
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
  // Per-channel saturation weights (Rec. 601 luminance coefficients).
  const lr = 0.2126;
  const lg = 0.7152;
  const lb = 0.0722;
  final s = saturation;
  final c = contrast;
  final b = brightness;
  // contrast around 0.5 grey → translation = (1 - c) * 128 normalised
  // to 0..1 (matrix multiplied by 255 by Flutter when applied to bytes).
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

class _GridOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _GridPainter()),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1;
    for (var i = 1; i < FreeformCanvas.gridCols; i++) {
      final x = size.width * i / FreeformCanvas.gridCols;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var j = 1; j < FreeformCanvas.gridRows; j++) {
      final y = size.height * j / FreeformCanvas.gridRows;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}

class _TextBlockView extends StatelessWidget {
  const _TextBlockView({
    required this.block,
    required this.editable,
    required this.selected,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.onTap,
    required this.onDrag,
  });

  final CarouselSlideTextBlock block;
  final bool editable;
  final bool selected;
  final double canvasWidth;
  final double canvasHeight;
  final VoidCallback onTap;
  /// Drag delta as percent of canvas (Δx %, Δy %). Caller snaps + clamps.
  final void Function(double dxPct, double dyPct) onDrag;

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
    // The hex inspector field accepts free-form input; mid-edit values
    // ('#FFF', '#zz0000') reach us before the merchant finishes typing.
    // Fall back to white so the preview never throws while typing.
    final raw = block.color.replaceFirst('#', '');
    if (raw.length != 6 && raw.length != 8) return Colors.white;
    final normalised = raw.length == 6 ? 'FF$raw' : raw;
    final parsed = int.tryParse(normalised, radix: 16);
    return parsed == null ? Colors.white : Color(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final text = Text(
      block.text,
      textAlign: _align,
      style: TextStyle(
        color: _color,
        fontWeight: FontWeight.values
            .firstWhere((w) => w.value == block.weight, orElse: () => FontWeight.w700),
        fontSize: block.fontSize.toDouble(),
        height: 1.15,
      ),
    );

    if (!editable) {
      return text;
    }

    final border = ShapeDecoration(
      shape: AppShapes.squircle(
        AppSizes.radiusSm,
        side: BorderSide(
          color: selected
              ? AppColors.brand
              : Colors.white.withValues(alpha: 0.6),
          width: selected ? 2 : 1,
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onPanUpdate: (d) {
        if (canvasWidth == 0 || canvasHeight == 0) return;
        onDrag(d.delta.dx / canvasWidth * 100, d.delta.dy / canvasHeight * 100);
      },
      child: Container(
        decoration: border,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: text,
      ),
    );
  }
}
