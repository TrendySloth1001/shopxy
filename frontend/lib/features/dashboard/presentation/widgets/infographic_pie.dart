import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/constants/app_curves.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

class PieRow {
  const PieRow({required this.label, required this.value});
  final String label;
  final double value;
}

final piePaletteA = <Color>[
  AppColors.brand,
  AppColors.accentIndigo,
  AppColors.accentAmber,
  AppColors.success,
  AppColors.accentTeal,
  AppColors.accentRose,
];
final piePaletteB = <Color>[
  AppColors.accentTeal,
  AppColors.accentRose,
  AppColors.brand,
  AppColors.accentAmber,
  AppColors.accentIndigo,
  AppColors.success,
];
final piePaletteC = <Color>[
  AppColors.accentAmber,
  AppColors.accentRose,
  AppColors.accentIndigo,
  AppColors.brand,
  AppColors.success,
  AppColors.accentTeal,
];

const double _w = 800;
const double _h = 520;
const double _cx = _w / 2;
const double _cy = _h / 2;
const double _hub = 86;
const double _rMin = 184;
const double _rMax = 228;
const double _gapDeg = 3;
const double _stub = 24;
const double _explode = 14;

class _Seg {
  _Seg({
    required this.label,
    required this.value,
    required this.color,
    required this.pct,
    required this.start,
    required this.end,
    required this.mid,
    required this.rOut,
  });
  final String label;
  final double value;
  final Color color;
  final int pct;
  final double start;
  final double end;
  final double mid;
  final double rOut;
}

Offset _polar(double r, double angleDeg) {
  final a = (angleDeg - 90) * math.pi / 180;
  return Offset(_cx + r * math.cos(a), _cy + r * math.sin(a));
}

List<PieRow> _collapse(List<PieRow> rows, int maxSlices, String otherLabel) {
  final sorted = rows.where((r) => r.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (sorted.length <= maxSlices) return sorted;
  final head = sorted.sublist(0, maxSlices - 1);
  final rest = sorted
      .sublist(maxSlices - 1)
      .fold<double>(0, (s, r) => s + r.value);
  return [...head, PieRow(label: otherLabel, value: rest)];
}

String _trim(String s, [int n = 18]) =>
    s.length > n ? '${s.substring(0, n - 1)}…' : s;

class InfographicPie extends StatefulWidget {
  const InfographicPie({
    super.key,
    required this.rows,
    required this.palette,
    required this.formatValue,
    this.subject = 'the total',
    this.itemNoun = 'items',
  });

  final List<PieRow> rows;
  final List<Color> palette;
  final String Function(double) formatValue;
  final String subject;
  final String itemNoun;

  @override
  State<InfographicPie> createState() => _InfographicPieState();
}

class _InfographicPieState extends State<InfographicPie> {
  int? _active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final otherLabel = l10n.dashboardPieOther;
    final slices = _collapse(widget.rows, widget.palette.length, otherLabel);
    final total = slices.fold<double>(0, (s, r) => s + r.value);
    if (total <= 0) {
      return _EmptyPie(message: l10n.dashboardNoDataInPeriod);
    }
    final maxVal = slices.map((s) => s.value).reduce(math.max);
    final single = slices.length == 1;

    final segs = <_Seg>[];
    var acc = 0.0;
    for (var i = 0; i < slices.length; i++) {
      final s = slices[i];
      final sweep = (s.value / total) * 360;
      final start = acc;
      final end = start + sweep;
      acc = end;
      segs.add(
        _Seg(
          label: s.label,
          value: s.value,
          color: widget.palette[i % widget.palette.length],
          pct: ((s.value / total) * 100).round(),
          start: start,
          end: end,
          mid: (start + end) / 2,
          rOut: single ? _rMax : _rMin + (s.value / maxVal) * (_rMax - _rMin),
        ),
      );
    }

    final chart = AspectRatio(
      aspectRatio: _w / _h,
      child: LayoutBuilder(
        builder: (context, c) {
          return GestureDetector(
            onTapUp: (d) =>
                _handleTap(d.localPosition, c.maxWidth, segs, single),
            child: CustomPaint(
              size: Size(c.maxWidth, c.maxWidth * _h / _w),
              painter: _PiePainter(
                segs: segs,
                active: _active,
                single: single,
                formatValue: widget.formatValue,
              ),
            ),
          );
        },
      ),
    );

    final sidebar = _Sidebar(
      segs: segs,
      total: total,
      active: _active,
      formatValue: widget.formatValue,
      subject: widget.subject,
      itemNoun: widget.itemNoun,
      otherLabel: otherLabel,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= 560) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: chart),
                  const SizedBox(width: AppSizes.lg),
                  SizedBox(width: 240, child: sidebar),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                chart,
                const SizedBox(height: AppSizes.lg),
                sidebar,
              ],
            );
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: AppCurves.decelerate,
          child: _active == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSizes.md),
                  child: _DetailStrip(
                    seg: segs[_active!],
                    formatValue: widget.formatValue,
                    subject: widget.subject,
                  ),
                ),
        ),
      ],
    );
  }

  void _handleTap(Offset pos, double boxW, List<_Seg> segs, bool single) {
    final scale = boxW / _w;
    final sx = pos.dx / scale;
    final sy = pos.dy / scale;
    final dx = sx - _cx;
    final dy = sy - _cy;
    final r = math.sqrt(dx * dx + dy * dy);
    var ang = math.atan2(dy, dx) * 180 / math.pi + 90;
    ang %= 360;
    if (ang < 0) ang += 360;

    for (var i = 0; i < segs.length; i++) {
      final s = segs[i];
      final inAngle = single || (ang >= s.start && ang < s.end);
      if (inAngle && r >= _hub && r <= s.rOut + 6) {
        setState(() => _active = _active == i ? null : i);
        return;
      }
    }
    setState(() => _active = null);
  }
}

class _EmptyPie extends StatelessWidget {
  const _EmptyPie({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSizes.xl),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: AppIcon(
                AppIcons.barChartOutlined,
                size: 24,
                color: AppColors.subtle,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: DashText.bodySm.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.segs,
    required this.active,
    required this.single,
    required this.formatValue,
  });

  final List<_Seg> segs;
  final int? active;
  final bool single;
  final String Function(double) formatValue;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _w;
    canvas.save();
    canvas.scale(scale, scale);

    for (var i = 0; i < segs.length; i++) {
      final s = segs[i];
      final sel = active == i;
      final dimmed = active != null && !sel;
      final opacity = dimmed ? 0.4 : 1.0;
      final color = s.color.withValues(alpha: opacity);

      canvas.save();
      if (sel && !single) {
        final a = (s.mid - 90) * math.pi / 180;
        canvas.translate(math.cos(a) * _explode, math.sin(a) * _explode);
      }

      if (single) {
        final mid = (_hub + s.rOut) / 2;
        canvas.drawCircle(
          const Offset(_cx, _cy),
          mid,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.rOut - _hub,
        );
      } else {
        final a0 = s.start + _gapDeg / 2;
        final a1 = s.end - _gapDeg / 2;
        canvas.drawPath(
          _sectorPath(_hub, s.rOut, a0, a1),
          Paint()..color = color,
        );
        if (sel) {
          canvas.drawPath(
            _sectorPath(_hub, s.rOut, a0, a1),
            Paint()
              ..color = s.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4,
          );
        }
      }

      final lp = _polar((_hub + s.rOut) / 2, single ? 0 : s.mid);
      _text(
        canvas,
        '${s.pct}%',
        lp,
        TextStyle(
          color: AppColors.white.withValues(alpha: opacity),
          fontSize: s.pct >= 8 ? 22 : 14,
          fontWeight: FontWeight.w700,
        ),
        align: TextAlign.center,
        anchor: _Anchor.center,
      );

      final tip = _polar(s.rOut + 4, s.mid);
      final knee = _polar(s.rOut + 18, s.mid);
      final right = knee.dx >= _cx;
      final endX = right ? knee.dx + _stub : knee.dx - _stub;
      final textX = right ? endX + 6 : endX - 6;
      final linePaint = Paint()
        ..color = AppColors.subtle.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final lpath = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(knee.dx, knee.dy)
        ..lineTo(endX, knee.dy);
      canvas.drawPath(lpath, linePaint);

      _text(
        canvas,
        _trim(s.label),
        Offset(textX, knee.dy - 4),
        TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700),
        anchor: right ? _Anchor.bottomLeft : _Anchor.bottomRight,
      );
      _text(
        canvas,
        formatValue(s.value),
        Offset(textX, knee.dy + 2),
        TextStyle(
          color: AppColors.muted.withValues(alpha: opacity),
          fontSize: 13,
        ),
        anchor: right ? _Anchor.topLeft : _Anchor.topRight,
      );

      canvas.restore();
    }

    canvas.drawCircle(
      const Offset(_cx, _cy),
      _hub + 1,
      Paint()..color = AppColors.black,
    );
    canvas.drawCircle(
      const Offset(_cx, _cy),
      _hub - 28,
      Paint()..color = AppColors.canvas,
    );

    canvas.restore();
  }

  Path _sectorPath(double rInner, double rOuter, double start, double end) {
    final p1 = _polar(rOuter, start);
    final p2 = _polar(rOuter, end);
    final p3 = _polar(rInner, end);
    final p4 = _polar(rInner, start);
    final large = (end - start) > 180;
    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..arcToPoint(
        p2,
        radius: Radius.circular(rOuter),
        largeArc: large,
        clockwise: true,
      )
      ..lineTo(p3.dx, p3.dy)
      ..arcToPoint(
        p4,
        radius: Radius.circular(rInner),
        largeArc: large,
        clockwise: false,
      )
      ..close();
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    TextAlign align = TextAlign.left,
    required _Anchor anchor,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = at.dx;
    var dy = at.dy;
    switch (anchor) {
      case _Anchor.center:
        dx -= tp.width / 2;
        dy -= tp.height / 2;
      case _Anchor.bottomLeft:
        dy -= tp.height;
      case _Anchor.bottomRight:
        dx -= tp.width;
        dy -= tp.height;
      case _Anchor.topLeft:
        break;
      case _Anchor.topRight:
        dx -= tp.width;
    }
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.active != active || old.segs != segs;
}

enum _Anchor { center, topLeft, topRight, bottomLeft, bottomRight }

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.segs,
    required this.total,
    required this.active,
    required this.formatValue,
    required this.subject,
    required this.itemNoun,
    required this.otherLabel,
  });

  final List<_Seg> segs;
  final double total;
  final int? active;
  final String Function(double) formatValue;
  final String subject;
  final String itemNoun;
  final String otherLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final top = segs.first;
    final second = segs.length > 1 && segs[1].label != otherLabel
        ? segs[1]
        : null;
    final smallest = segs.length > 2 ? segs.last : null;
    final topK = math.min(2, segs.length);
    final topKpct = segs.take(topK).fold<int>(0, (a, s) => a + s.pct);
    final avg = total / segs.length;

    final summary = StringBuffer()
      ..write(
        l10n.dashboardPieSummaryBase(
          formatValue(total),
          '${segs.length}',
          itemNoun,
          formatValue(avg.round().toDouble()),
        ),
      )
      ..write(' ')
      ..write(
        l10n.dashboardPieSummaryLead(
          top.label,
          '${top.pct}',
          formatValue(top.value),
        ),
      );
    if (second != null) {
      summary.write(
        l10n.dashboardPieSummaryAheadOf(second.label, '${second.pct}'),
      );
    }
    summary.write('.');
    if (segs.length > 2) {
      summary.write(' ');
      summary.write(l10n.dashboardPieSummaryTopK('$topK', '$topKpct', subject));
      if (smallest != null) {
        summary.write(
          l10n.dashboardPieSummaryTrails(smallest.label, '${smallest.pct}'),
        );
      }
      summary.write('.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(l10n.dashboardAboutThisChart),
        const SizedBox(height: AppSizes.sm),
        Text(summary.toString(), style: DashText.bodyMd.copyWith(height: 1.5)),
        const SizedBox(height: AppSizes.md),
        Divider(height: 1, thickness: 1, color: AppColors.hairline),
        for (var i = 0; i < segs.length; i++)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: active != null && active != i ? 0.5 : 1,
            child: Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.hairline)),
              ),
              padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: segs[i].color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Text(
                      segs[i].label,
                      style: DashText.bodySm.copyWith(color: AppColors.black),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Text(
                    '${formatValue(segs[i].value)} · ${segs[i].pct}%',
                    style: DashText.bodySm.copyWith(
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSizes.sm),
        Text(
          l10n.dashboardTapSliceHint,
          style: DashText.bodySm.copyWith(
            color: AppColors.subtle,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _DetailStrip extends StatelessWidget {
  const _DetailStrip({
    required this.seg,
    required this.formatValue,
    required this.subject,
  });
  final _Seg seg;
  final String Function(double) formatValue;
  final String subject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(AppSizes.radiusLg),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: seg.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: DashText.bodySm.copyWith(color: AppColors.black),
                children: [
                  TextSpan(
                    text: seg.label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' — '),
                  TextSpan(
                    text: formatValue(seg.value),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: l10n.dashboardPieDetailTail('${seg.pct}', subject),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
