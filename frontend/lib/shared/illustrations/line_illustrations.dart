import 'package:flutter/material.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

/// Inline-painted line illustrations in the Glassdoor editorial style.
///
/// Each illustration is a `CustomPainter` drawing onto a square canvas.
/// Compose with [LineIllustration] to render at any size — strokes scale
/// automatically. Stick to black line work + at most one brand-green
/// accent so the family stays coherent.
class LineIllustration extends StatelessWidget {
  const LineIllustration({
    super.key,
    required this.kind,
    this.size = 160,
    this.accent = AppColors.brand,
  });

  final LineArt kind;
  final double size;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LinePainter(kind, accent),
      ),
    );
  }
}

enum LineArt {
  boxes,
  invoice,
  handshake,
  ledger,
  customers,
  vendors,
  passkey,
  checkmark,
  emptyClipboard,
  warning,
  chart,
  cable,
  productTag,
  deliveryNote,
  receipt,
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.kind, this.accent);
  final LineArt kind;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // Normalize all artwork to a 100x100 unit cell — easy to read coords.
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    final stroke = Paint()
      ..color = AppColors.black
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = AppColors.black
      ..style = PaintingStyle.fill;
    final accentStroke = Paint()
      ..color = accent
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final accentFill = Paint()..color = accent;

    switch (kind) {
      case LineArt.boxes:
        _drawBoxes(canvas, stroke, accentStroke);
      case LineArt.invoice:
        _drawInvoice(canvas, stroke, accentStroke, accentFill);
      case LineArt.handshake:
        _drawHandshake(canvas, stroke);
      case LineArt.ledger:
        _drawLedger(canvas, stroke, accentStroke);
      case LineArt.customers:
        _drawCustomers(canvas, stroke);
      case LineArt.vendors:
        _drawVendors(canvas, stroke);
      case LineArt.passkey:
        _drawPasskey(canvas, stroke, accentStroke, accentFill);
      case LineArt.checkmark:
        _drawCheckmark(canvas, stroke, accentStroke, accentFill);
      case LineArt.emptyClipboard:
        _drawEmptyClipboard(canvas, stroke);
      case LineArt.warning:
        _drawWarning(canvas, stroke, accentStroke);
      case LineArt.chart:
        _drawChart(canvas, stroke, accentStroke);
      case LineArt.cable:
        _drawCable(canvas, stroke, accentStroke);
      case LineArt.productTag:
        _drawProductTag(canvas, stroke, fill, accentStroke);
      case LineArt.deliveryNote:
        _drawDeliveryNote(canvas, stroke, accentStroke);
      case LineArt.receipt:
        _drawReceipt(canvas, stroke, accentStroke);
    }
    canvas.restore();
  }

  // ── individual scenes ─────────────────────────────────────────────────

  void _drawBoxes(Canvas c, Paint stroke, Paint accent) {
    // Two stacked boxes with a small one on top — classic warehouse vibe.
    final bigBox = Path()
      ..moveTo(20, 60)
      ..lineTo(60, 60)
      ..lineTo(60, 90)
      ..lineTo(20, 90)
      ..close();
    c.drawPath(bigBox, stroke);
    // Tape line
    c.drawLine(const Offset(40, 60), const Offset(40, 90), stroke);
    // Top box
    final topBox = Path()
      ..moveTo(48, 30)
      ..lineTo(82, 30)
      ..lineTo(82, 60)
      ..lineTo(48, 60)
      ..close();
    c.drawPath(topBox, stroke);
    c.drawLine(const Offset(65, 30), const Offset(65, 60), stroke);
    // Green check sticker on big box
    c.drawCircle(const Offset(35, 75), 5.5, accent);
    final check = Path()
      ..moveTo(32, 75)
      ..lineTo(34.5, 77.5)
      ..lineTo(38, 73);
    c.drawPath(check, Paint()
      ..color = AppColors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
  }

  void _drawInvoice(Canvas c, Paint stroke, Paint accent, Paint accentFill) {
    // Paper with torn bottom + a few text lines + a green stamp.
    final paper = Path()
      ..moveTo(22, 18)
      ..lineTo(78, 18)
      ..lineTo(78, 78)
      ..lineTo(72, 84)
      ..lineTo(66, 78)
      ..lineTo(60, 84)
      ..lineTo(54, 78)
      ..lineTo(48, 84)
      ..lineTo(42, 78)
      ..lineTo(36, 84)
      ..lineTo(30, 78)
      ..lineTo(22, 78)
      ..close();
    c.drawPath(paper, stroke);
    // Title bar
    c.drawLine(const Offset(30, 30), const Offset(60, 30), stroke);
    c.drawLine(const Offset(30, 38), const Offset(70, 38), stroke);
    c.drawLine(const Offset(30, 46), const Offset(70, 46), stroke);
    c.drawLine(const Offset(30, 54), const Offset(55, 54), stroke);
    // Green "PAID" stamp circle
    c.drawCircle(const Offset(64, 62), 8, accent);
  }

  void _drawHandshake(Canvas c, Paint stroke) {
    // Two arms meeting in a handshake. Cuffs + hands.
    final leftArm = Path()
      ..moveTo(10, 70)
      ..lineTo(30, 50)
      ..lineTo(45, 55)
      ..lineTo(50, 60);
    c.drawPath(leftArm, stroke);
    final rightArm = Path()
      ..moveTo(90, 70)
      ..lineTo(70, 50)
      ..lineTo(55, 55)
      ..lineTo(50, 60);
    c.drawPath(rightArm, stroke);
    // Cuffs
    c.drawLine(const Offset(15, 65), const Offset(25, 55), stroke);
    c.drawLine(const Offset(85, 65), const Offset(75, 55), stroke);
    // Hands meeting — small loop
    c.drawCircle(const Offset(50, 60), 6, stroke);
  }

  void _drawLedger(Canvas c, Paint stroke, Paint accent) {
    // Open book / ledger with two pages and lines.
    final book = Path()
      ..moveTo(15, 28)
      ..lineTo(50, 24)
      ..lineTo(50, 80)
      ..lineTo(15, 84)
      ..close();
    c.drawPath(book, stroke);
    final book2 = Path()
      ..moveTo(50, 24)
      ..lineTo(85, 28)
      ..lineTo(85, 84)
      ..lineTo(50, 80)
      ..close();
    c.drawPath(book2, stroke);
    // Lines on pages
    for (int i = 0; i < 4; i++) {
      final y = 38 + i * 10.0;
      c.drawLine(Offset(22, y), Offset(45, y - i * 0.4), stroke);
      c.drawLine(Offset(55, y - i * 0.4), Offset(78, y), stroke);
    }
    // Brand-colored ribbon
    c.drawLine(const Offset(50, 24), const Offset(50, 95), accent);
  }

  void _drawCustomers(Canvas c, Paint stroke) {
    // Three head-and-shoulders silhouettes.
    void person(double cx, double cy, double r) {
      c.drawCircle(Offset(cx, cy), r, stroke);
      final shoulders = Path()
        ..moveTo(cx - r * 1.8, cy + r * 3)
        ..quadraticBezierTo(cx, cy + r * 1.4, cx + r * 1.8, cy + r * 3);
      c.drawPath(shoulders, stroke);
    }
    person(28, 42, 8);
    person(50, 38, 9);
    person(72, 42, 8);
  }

  void _drawVendors(Canvas c, Paint stroke) {
    // Storefront with awning.
    final base = Path()
      ..moveTo(18, 80)
      ..lineTo(18, 45)
      ..lineTo(82, 45)
      ..lineTo(82, 80)
      ..close();
    c.drawPath(base, stroke);
    // Awning
    final awning = Path()
      ..moveTo(14, 45)
      ..lineTo(86, 45)
      ..lineTo(82, 35)
      ..lineTo(18, 35)
      ..close();
    c.drawPath(awning, stroke);
    // Awning stripes
    c.drawLine(const Offset(30, 35), const Offset(26, 45), stroke);
    c.drawLine(const Offset(45, 35), const Offset(41, 45), stroke);
    c.drawLine(const Offset(60, 35), const Offset(56, 45), stroke);
    c.drawLine(const Offset(75, 35), const Offset(71, 45), stroke);
    // Door
    final door = Path()
      ..moveTo(42, 80)
      ..lineTo(42, 60)
      ..quadraticBezierTo(50, 55, 58, 60)
      ..lineTo(58, 80);
    c.drawPath(door, stroke);
  }

  void _drawPasskey(Canvas c, Paint stroke, Paint accent, Paint accentFill) {
    // Phone outline + fingerprint hint + small green check chip.
    final phone = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(30, 18, 40, 70),
        const Radius.circular(6),
      ));
    c.drawPath(phone, stroke);
    // Screen
    c.drawRect(const Rect.fromLTWH(35, 24, 30, 55), stroke);
    // Fingerprint loops
    for (int i = 0; i < 3; i++) {
      c.drawArc(
        Rect.fromCircle(center: const Offset(50, 50), radius: 6 + i * 3.0),
        3.4,
        2.4,
        false,
        stroke,
      );
    }
    // Green tick badge
    c.drawCircle(const Offset(70, 30), 7, accentFill);
    final check = Path()
      ..moveTo(67, 30)
      ..lineTo(69.5, 32.5)
      ..lineTo(73, 28);
    c.drawPath(check, Paint()
      ..color = AppColors.white
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
  }

  void _drawCheckmark(Canvas c, Paint stroke, Paint accent, Paint accentFill) {
    // Big green ring with a checkmark.
    c.drawCircle(const Offset(50, 50), 28, accent..strokeWidth = 3);
    final tick = Path()
      ..moveTo(38, 51)
      ..lineTo(46, 60)
      ..lineTo(62, 42);
    final tickPaint = Paint()
      ..color = AppColors.black
      ..strokeWidth = 3.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(tick, tickPaint);
  }

  void _drawEmptyClipboard(Canvas c, Paint stroke) {
    final board = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 22, 44, 60),
        const Radius.circular(4),
      ));
    c.drawPath(board, stroke);
    // Clip top
    c.drawRect(const Rect.fromLTWH(40, 16, 20, 12), stroke);
    // Dotted lines (empty)
    final dashPaint = Paint()
      ..color = AppColors.black
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (int i = 0; i < 4; i++) {
      final y = 40 + i * 10.0;
      for (double x = 34; x < 66; x += 4) {
        c.drawLine(Offset(x, y), Offset(x + 2, y), dashPaint);
      }
    }
  }

  void _drawWarning(Canvas c, Paint stroke, Paint accent) {
    final tri = Path()
      ..moveTo(50, 18)
      ..lineTo(86, 80)
      ..lineTo(14, 80)
      ..close();
    c.drawPath(tri, stroke);
    c.drawLine(const Offset(50, 38), const Offset(50, 60), stroke);
    c.drawCircle(const Offset(50, 70), 1.8, Paint()..color = AppColors.black);
  }

  void _drawChart(Canvas c, Paint stroke, Paint accent) {
    // Axes
    c.drawLine(const Offset(18, 18), const Offset(18, 82), stroke);
    c.drawLine(const Offset(18, 82), const Offset(86, 82), stroke);
    // Bars
    final bar = Paint()
      ..color = AppColors.black
      ..style = PaintingStyle.fill;
    c.drawRect(const Rect.fromLTWH(28, 60, 8, 22), bar);
    c.drawRect(const Rect.fromLTWH(44, 48, 8, 34), bar);
    c.drawRect(const Rect.fromLTWH(60, 36, 8, 46), bar);
    // Trend line green
    final line = Path()
      ..moveTo(32, 58)
      ..lineTo(48, 46)
      ..lineTo(64, 34)
      ..lineTo(80, 26);
    c.drawPath(line, accent);
    c.drawCircle(const Offset(80, 26), 3, Paint()..color = accent.color);
  }

  void _drawCable(Canvas c, Paint stroke, Paint accent) {
    // USB-C connector + coiled cable + small green spark.
    final connector = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 40, 22, 14),
        const Radius.circular(3),
      ));
    c.drawPath(connector, stroke);
    c.drawLine(const Offset(20, 47), const Offset(14, 47), stroke);
    // Coil
    final coil = Path()..moveTo(42, 47);
    for (int i = 0; i < 4; i++) {
      coil.relativeQuadraticBezierTo(6, -8, 12, 0);
      coil.relativeQuadraticBezierTo(6, 8, 12, 0);
    }
    c.drawPath(coil, stroke);
    // Accent spark
    c.drawLine(const Offset(80, 30), const Offset(86, 24), accent);
    c.drawLine(const Offset(84, 32), const Offset(90, 32), accent);
  }

  void _drawProductTag(Canvas c, Paint stroke, Paint fill, Paint accent) {
    // Price tag.
    final tag = Path()
      ..moveTo(22, 32)
      ..lineTo(58, 32)
      ..lineTo(82, 56)
      ..lineTo(58, 80)
      ..lineTo(22, 80)
      ..close();
    c.drawPath(tag, stroke);
    c.drawCircle(const Offset(34, 50), 4, stroke);
    c.drawCircle(const Offset(34, 50), 1.5, fill);
    // Lines for product info
    c.drawLine(const Offset(46, 50), const Offset(70, 50), stroke);
    c.drawLine(const Offset(46, 58), const Offset(64, 58), stroke);
    // Brand-green dot accent
    c.drawCircle(const Offset(78, 70), 3, accent);
  }

  void _drawDeliveryNote(Canvas c, Paint stroke, Paint accent) {
    // Truck-ish hand off — clipboard + small truck silhouette.
    final pad = Path()
      ..addRRect(RRect.fromRectAndRadius(
        const Rect.fromLTWH(20, 22, 38, 50),
        const Radius.circular(3),
      ));
    c.drawPath(pad, stroke);
    // Truck body
    c.drawRect(const Rect.fromLTWH(62, 50, 22, 18), stroke);
    final cab = Path()
      ..moveTo(84, 50)
      ..lineTo(92, 56)
      ..lineTo(92, 68)
      ..lineTo(84, 68);
    c.drawPath(cab, stroke);
    // Wheels
    c.drawCircle(const Offset(68, 70), 3, stroke);
    c.drawCircle(const Offset(86, 70), 3, stroke);
    // Pad lines
    c.drawLine(const Offset(26, 36), const Offset(50, 36), stroke);
    c.drawLine(const Offset(26, 44), const Offset(50, 44), stroke);
    c.drawLine(const Offset(26, 52), const Offset(46, 52), stroke);
    // Green check on the clipboard
    final check = Path()
      ..moveTo(28, 62)
      ..lineTo(32, 66)
      ..lineTo(40, 56);
    c.drawPath(check, accent);
  }

  void _drawReceipt(Canvas c, Paint stroke, Paint accent) {
    // Long receipt curling at bottom.
    final receipt = Path()
      ..moveTo(36, 16)
      ..lineTo(64, 16)
      ..lineTo(64, 78)
      ..quadraticBezierTo(60, 86, 56, 78)
      ..quadraticBezierTo(52, 70, 48, 78)
      ..quadraticBezierTo(44, 86, 40, 78)
      ..quadraticBezierTo(36, 70, 36, 78)
      ..close();
    c.drawPath(receipt, stroke);
    // Lines
    for (int i = 0; i < 5; i++) {
      final y = 26 + i * 8.0;
      c.drawLine(Offset(42, y), Offset(58, y), stroke);
    }
    // Accent stripe at top (header band)
    c.drawLine(const Offset(36, 22), const Offset(64, 22), accent);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.accent != accent;
}
