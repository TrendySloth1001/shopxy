import 'package:flutter/material.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

/// One plotted line.
class TrendSeriesData {
  const TrendSeriesData({
    required this.key,
    required this.label,
    required this.color,
    required this.values,
  });
  final String key;
  final String label;
  final Color color;
  final List<double> values;
}

/// Rich multi-series trend chart: smooth Catmull-Rom curves, gridlines, axis
/// labels, a toggleable legend and a drag-to-inspect crosshair + tooltip.
/// Mirrors `components/trend-chart.tsx` (hover → touch-drag on mobile).
class TrendChart extends StatefulWidget {
  const TrendChart({
    super.key,
    required this.series,
    required this.xLabels,
    required this.formatValue,
    required this.formatTick,
    this.initialHidden = const [],
  });

  final List<TrendSeriesData> series;
  final List<String> xLabels;
  final String Function(double) formatValue;
  final String Function(double) formatTick;
  final List<String> initialHidden;

  @override
  State<TrendChart> createState() => _TrendChartState();
}

class _TrendChartState extends State<TrendChart> {
  late final Set<String> _hidden = {...widget.initialHidden};
  int? _hover;

  static const double _plotHeight = 240;
  static const double _yAxisWidth = 46;

  void _toggle(String key) {
    setState(() {
      if (_hidden.contains(key)) {
        _hidden.remove(key);
      } else if (widget.series.length - _hidden.length > 1) {
        _hidden.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        widget.series.where((s) => !_hidden.contains(s.key)).toList();
    final n = widget.xLabels.length;
    var max = 1.0;
    for (final s in visible) {
      for (final v in s.values) {
        if (v > max) max = v;
      }
    }
    final ticks = [max, max * .75, max * .5, max * .25, 0.0];
    final xStep = (n / 7).ceil().clamp(1, n == 0 ? 1 : n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle legend.
        Wrap(
          spacing: AppSizes.sm,
          runSpacing: AppSizes.sm,
          children: [
            for (final s in widget.series)
              _LegendChip(
                label: s.label,
                color: s.color,
                on: !_hidden.contains(s.key),
                onTap: () => _toggle(s.key),
              ),
          ],
        ),
        const SizedBox(height: AppSizes.md),
        // Plot row: y-axis + chart.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _yAxisWidth,
              height: _plotHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final t in ticks)
                    Text(
                      widget.formatTick(t),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.subtle,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  void setHoverFromX(double dx) {
                    if (w == 0 || n <= 1) return;
                    final frac = (dx / w).clamp(0.0, 1.0);
                    setState(() => _hover = (frac * (n - 1)).round());
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onHorizontalDragStart: (d) =>
                            setHoverFromX(d.localPosition.dx),
                        onHorizontalDragUpdate: (d) =>
                            setHoverFromX(d.localPosition.dx),
                        onHorizontalDragEnd: (_) =>
                            setState(() => _hover = null),
                        onHorizontalDragCancel: () =>
                            setState(() => _hover = null),
                        child: SizedBox(
                          height: _plotHeight,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _TrendPainter(
                                    series: visible,
                                    max: max,
                                    n: n,
                                    hover: _hover,
                                  ),
                                ),
                              ),
                              if (_hover != null)
                                _Tooltip(
                                  hover: _hover!,
                                  n: n,
                                  width: w,
                                  visible: visible,
                                  label: widget.xLabels[_hover!],
                                  formatValue: widget.formatValue,
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      // X-axis labels.
                      SizedBox(
                        height: 16,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            for (var i = 0; i < n; i++)
                              if (i % xStep == 0 || i == n - 1)
                                Positioned(
                                  left: (n <= 1
                                          ? 0
                                          : (i / (n - 1)) * w)
                                      .clamp(0.0, w) -
                                      18,
                                  child: SizedBox(
                                    width: 36,
                                    child: Text(
                                      widget.xLabels[i],
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                      overflow: TextOverflow.visible,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.subtle),
                                    ),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.color,
    required this.on,
    required this.onTap,
  });
  final String label;
  final Color color;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: on ? color : color.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSizes.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: on ? AppColors.black : AppColors.subtle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({
    required this.hover,
    required this.n,
    required this.width,
    required this.visible,
    required this.label,
    required this.formatValue,
  });
  final int hover;
  final int n;
  final double width;
  final List<TrendSeriesData> visible;
  final String label;
  final String Function(double) formatValue;

  @override
  Widget build(BuildContext context) {
    final xFrac = n <= 1 ? 0.0 : hover / (n - 1);
    final card = Container(
      constraints: BoxConstraints(maxWidth: width * 0.55),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DashText.labelMd),
          const SizedBox(height: AppSizes.xs),
          for (final s in visible)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: s.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    formatValue(s.values.length > hover ? s.values[hover] : 0),
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.black,
                        fontFeatures: tabularFigures),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Flexible(
                    child: Text(
                      s.label,
                      style: DashText.bodySm,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return Positioned(
      top: 4,
      left: xFrac < 0.5 ? (xFrac * width + 12) : null,
      right: xFrac < 0.5 ? null : ((1 - xFrac) * width + 12),
      child: card,
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.series,
    required this.max,
    required this.n,
    required this.hover,
  });

  final List<TrendSeriesData> series;
  final double max;
  final int n;
  final int? hover;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Gridlines (5).
    final grid = Paint()
      ..color = AppColors.hairline
      ..strokeWidth = 1;
    for (var i = 0; i < 5; i++) {
      final y = (i / 4) * h;
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    double xOf(int i) => n <= 1 ? 0 : (i / (n - 1)) * w;
    double yOf(double v) => h - (v / max) * h;

    // Lines (smooth Catmull-Rom → cubic bezier).
    for (final s in series) {
      final pts = [
        for (var i = 0; i < s.values.length; i++)
          Offset(xOf(i), yOf(s.values[i])),
      ];
      if (pts.isEmpty) continue;
      final path = Path();
      if (pts.length == 1) {
        path.moveTo(0, pts[0].dy);
        path.lineTo(w, pts[0].dy);
      } else {
        path.moveTo(pts[0].dx, pts[0].dy);
        for (var i = 0; i < pts.length - 1; i++) {
          final p0 = i > 0 ? pts[i - 1] : pts[i];
          final p1 = pts[i];
          final p2 = pts[i + 1];
          final p3 = i + 2 < pts.length ? pts[i + 2] : p2;
          final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6,
              p1.dy + (p2.dy - p0.dy) / 6);
          final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6,
              p2.dy - (p3.dy - p1.dy) / 6);
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Crosshair + markers.
    if (hover != null && n > 1) {
      final hx = xOf(hover!);
      // Dashed vertical line.
      final dash = Paint()
        ..color = AppColors.subtle
        ..strokeWidth = 1;
      const dashH = 5.0, gapH = 4.0;
      var y = 0.0;
      while (y < h) {
        canvas.drawLine(Offset(hx, y), Offset(hx, (y + dashH).clamp(0, h)), dash);
        y += dashH + gapH;
      }
      for (final s in series) {
        if (s.values.length <= hover!) continue;
        final c = Offset(hx, yOf(s.values[hover!]));
        canvas.drawCircle(c, 5, Paint()..color = AppColors.canvas);
        canvas.drawCircle(c, 4, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.hover != hover || old.max != max || old.series != series;
}
