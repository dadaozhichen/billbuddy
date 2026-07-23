import 'package:flutter/material.dart';

/// Renders the BillBuddy app icon as a [Widget] at any size.
///
/// Design: a green rounded square with a white receipt card
/// and a golden coin bearing the ¥ symbol — purely vector.
class BillBuddyIcon extends StatelessWidget {
  const BillBuddyIcon({super.key, this.size = 128});

  /// Preferred icon dimension (both width and height).
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CustomPaint(
          painter: _BillBuddyIconPainter(),
          size: Size.square(size),
        ),
      ),
    );
  }
}

class _BillBuddyIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width; // assume square

    // ── Background gradient ─────────────────────────────────
    final bgRect = Rect.fromLTWH(0, 0, s, s);
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
      ).createShader(bgRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, Radius.circular(s * 0.22)),
      bgPaint,
    );

    // ── Inner shadow ────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(s * 0.08, s * 0.10, s * 0.84, s * 0.84),
        Radius.circular(s * 0.18),
      ),
      shadowPaint,
    );

    // ── White receipt card ──────────────────────────────────
    final cardRect = Rect.fromLTWH(s * 0.20, s * 0.28, s * 0.60, s * 0.50);
    final cardRRect =
        RRect.fromRectAndRadius(cardRect, Radius.circular(s * 0.06));
    canvas.drawRRect(cardRRect, Paint()..color = Colors.white);

    // ── Receipt fold (top-right corner) ─────────────────────
    final foldPath = Path()
      ..moveTo(s * 0.70, s * 0.28)
      ..lineTo(s * 0.70, s * 0.42)
      ..lineTo(s * 0.80, s * 0.42)
      ..close();
    canvas.drawPath(foldPath, Paint()..color = const Color(0xFFE8F5E9));

    // ── Receipt lines (mocked text) ─────────────────────────
    final linePaint = Paint()
      ..color = const Color(0xFFC8E6C9)
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 4; i++) {
      final y = s * 0.38 + i * s * 0.07;
      canvas.drawLine(Offset(s * 0.30, y), Offset(s * 0.60, y), linePaint);
    }

    // ── Golden coin ─────────────────────────────────────────
    final coinCenter = Offset(s * 0.50, s * 0.52);
    final coinRadius = s * 0.16;

    final coinPaint = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0xFFFFD54F), Color(0xFFFF8F00)],
      ).createShader(
          Rect.fromCircle(center: coinCenter, radius: coinRadius));
    canvas.drawCircle(coinCenter, coinRadius, coinPaint);

    // Inner circle highlight
    canvas.drawCircle(
      coinCenter,
      coinRadius * 0.70,
      Paint()..color = const Color(0xFFFFF9C4).withValues(alpha: 0.4),
    );

    // ── ¥ text on coin using TextPainter ────────────────────
    final tp = TextPainter(
      text: TextSpan(
        text: '¥',
        style: TextStyle(
          color: const Color(0xFFE65100),
          fontSize: s * 0.18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(coinCenter.dx - tp.width / 2, coinCenter.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
