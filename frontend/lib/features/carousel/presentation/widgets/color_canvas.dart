import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Inline HSV picker used in the slide editor's Advanced section.
///
/// Layout (top-down):
///   1. Two preview swatches — "BG" and "Accent". Tap to choose which
///      colour the canvas currently writes to. The active swatch is
///      ringed in brand green.
///   2. Saturation/Brightness canvas — drag anywhere to set both
///      channels. The selected point shows as a ringed thumb.
///   3. Hue strip — drag to rotate the canvas through the spectrum.
///   4. Hex readouts under each swatch so power users can still
///      see/copy the value.
///
/// All inputs are continuous (no taps to confirm) and the editor
/// updates the underlying hex TextFields on every change so the live
/// preview reacts instantly.
class ColorCanvas extends StatefulWidget {
  const ColorCanvas({
    super.key,
    required this.bg,
    required this.accent,
    required this.onChanged,
  });

  final Color bg;
  final Color accent;
  /// Fires whenever either channel changes. `target` is `'bg'` or
  /// `'accent'` and `hex` is the canonical `#RRGGBB` string.
  final void Function(String target, String hex) onChanged;

  @override
  State<ColorCanvas> createState() => _ColorCanvasState();
}

class _ColorCanvasState extends State<ColorCanvas> {
  // 'bg' or 'accent' — which preview swatch the canvas writes to. We
  // keep the active target as a string so it round-trips with the
  // editor's existing `_bgColor` / `_accentColor` controllers without
  // introducing a new enum.
  String _target = 'bg';

  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.bg);
  }

  @override
  void didUpdateWidget(covariant ColorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the editor's other side (e.g. a palette preset tap) replaced
    // the colour we're currently editing, sync the canvas thumb to it
    // so the picker and the form stay in lockstep.
    final live = _target == 'bg' ? widget.bg : widget.accent;
    final old = _target == 'bg' ? oldWidget.bg : oldWidget.accent;
    if (live != old && live != _hsv.toColor()) {
      _hsv = HSVColor.fromColor(live);
    }
  }

  String _toHex(Color c) {
    final r = (c.r * 255).round() & 0xff;
    final g = (c.g * 255).round() & 0xff;
    final b = (c.b * 255).round() & 0xff;
    return '#'
        '${r.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${g.toRadixString(16).padLeft(2, '0').toUpperCase()}'
        '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
  }

  void _emit() {
    widget.onChanged(_target, _toHex(_hsv.toColor()));
  }

  void _switchTarget(String t) {
    if (_target == t) return;
    setState(() {
      _target = t;
      _hsv = HSVColor.fromColor(t == 'bg' ? widget.bg : widget.accent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _TargetSwatch(
                label: 'Background',
                color: widget.bg,
                hex: _toHex(widget.bg),
                selected: _target == 'bg',
                onTap: () => _switchTarget('bg'),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: _TargetSwatch(
                label: 'Accent',
                color: widget.accent,
                hex: _toHex(widget.accent),
                selected: _target == 'accent',
                onTap: () => _switchTarget('accent'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        ClipRRect(
          borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
          child: AspectRatio(
            aspectRatio: 2.2,
            child: _SVCanvas(
              hue: _hsv.hue,
              saturation: _hsv.saturation,
              value: _hsv.value,
              onChange: (s, v) {
                setState(() {
                  _hsv = HSVColor.fromAHSV(1, _hsv.hue, s, v);
                });
                _emit();
              },
            ),
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        _HueStrip(
          hue: _hsv.hue,
          onChange: (h) {
            setState(() {
              _hsv = HSVColor.fromAHSV(1, h, _hsv.saturation, _hsv.value);
            });
            _emit();
          },
        ),
      ],
    );
  }
}

class _TargetSwatch extends StatelessWidget {
  const _TargetSwatch({
    required this.label,
    required this.color,
    required this.hex,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final Color color;
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.sm),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: BorderSide(
              color: selected ? AppColors.brand : AppColors.hairline,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: AppSizes.xxxl,
              height: AppSizes.xxxl,
              decoration: BoxDecoration(
                color: color,
                borderRadius: AppShapes.squircleRadius(AppSizes.radiusSm),
                border: Border.all(color: AppColors.hairline),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.black,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    hex,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saturation/Brightness canvas. Saturation runs left→right, brightness
/// top→bottom (top = full brightness, bottom = black). Implemented as
/// two stacked gradients on a Stack so we don't need a CustomPainter.
class _SVCanvas extends StatelessWidget {
  const _SVCanvas({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChange,
  });
  final double hue;
  final double saturation;
  final double value;
  final void Function(double s, double v) onChange;

  void _handle(Offset local, Size size) {
    final s = (local.dx / size.width).clamp(0.0, 1.0);
    final v = 1.0 - (local.dy / size.height).clamp(0.0, 1.0);
    onChange(s, v);
  }

  @override
  Widget build(BuildContext context) {
    final base = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    return LayoutBuilder(
      builder: (_, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handle(d.localPosition, size),
          onPanUpdate: (d) => _handle(d.localPosition, size),
          onTapDown: (d) => _handle(d.localPosition, size),
          child: Stack(
            children: [
              // Saturation: white → fully-saturated hue.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [AppColors.white, base],
                    ),
                  ),
                ),
              ),
              // Brightness: transparent → black.
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black],
                    ),
                  ),
                ),
              ),
              // Thumb. Position is relative to the canvas size — using
              // Align with a -1..1 coordinate space keeps the math
              // independent of physical pixels.
              Align(
                alignment: Alignment(
                  saturation * 2 - 1,
                  (1 - value) * 2 - 1,
                ),
                child: _Thumb(color: HSVColor.fromAHSV(1, hue, saturation, value).toColor()),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Full-spectrum hue slider. The thumb rides along the gradient and
/// reports the new hue (0..360) on tap or drag.
class _HueStrip extends StatelessWidget {
  const _HueStrip({required this.hue, required this.onChange});
  final double hue;
  final ValueChanged<double> onChange;

  static const List<Color> _hueStops = [
    Color(0xFFFF0000),
    Color(0xFFFFFF00),
    Color(0xFF00FF00),
    Color(0xFF00FFFF),
    Color(0xFF0000FF),
    Color(0xFFFF00FF),
    Color(0xFFFF0000),
  ];

  void _handle(Offset local, Size size) {
    final h = (local.dx / size.width).clamp(0.0, 1.0) * 360;
    onChange(h);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final size = Size(c.maxWidth, AppSizes.xxl);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (d) => _handle(d.localPosition, size),
          onPanUpdate: (d) => _handle(d.localPosition, size),
          onTapDown: (d) => _handle(d.localPosition, size),
          child: Stack(
            children: [
              Container(
                height: AppSizes.xxl,
                decoration: BoxDecoration(
                  borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
                  gradient: const LinearGradient(colors: _hueStops),
                ),
              ),
              Align(
                alignment: Alignment(hue / 360 * 2 - 1, 0),
                child: _Thumb(
                  color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                  size: 22,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.color, this.size = 20});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
    );
  }
}
