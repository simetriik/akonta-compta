import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Symbole Akonta (tête d'éléphant : oreille, tête, trompe) dessiné en vectoriel, d'après le kit logo.
class AkontaLogo extends StatelessWidget {
  const AkontaLogo({super.key, this.height = 40, this.color = AkColors.ink, this.withWordmark = true});

  final double height;
  final Color color;
  final bool withWordmark;

  @override
  Widget build(BuildContext context) {
    final symbol = SizedBox(height: height, width: height, child: CustomPaint(painter: _ElephantPainter(color)));
    if (!withWordmark) return symbol;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        symbol,
        SizedBox(width: height * 0.25),
        Text('akonta', style: TextStyle(fontSize: height * 0.55, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.5)),
      ],
    );
  }
}

class _ElephantPainter extends CustomPainter {
  _ElephantPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 256;
    final paint = Paint()..color = color;
    // Trompe (version petite taille du kit : sans œil, trompe épaissie)
    final trunk = Path()
      ..moveTo(120 * s, 140 * s)
      ..cubicTo(100 * s, 164 * s, 90 * s, 186 * s, 100 * s, 204 * s)
      ..arcToPoint(Offset(132 * s, 208 * s), radius: Radius.circular(16 * s), clockwise: false)
      ..cubicTo(124 * s, 190 * s, 128 * s, 168 * s, 160 * s, 140 * s)
      ..close();
    // Oreille
    final ear = Path()
      ..moveTo(122 * s, 61 * s)
      ..cubicTo(70 * s, 43 * s, 34 * s, 68 * s, 38 * s, 103 * s)
      ..cubicTo(40 * s, 131 * s, 72 * s, 153 * s, 118 * s, 149 * s)
      ..cubicTo(110 * s, 123 * s, 108 * s, 88 * s, 122 * s, 61 * s)
      ..close();
    canvas.drawPath(trunk, paint);
    canvas.drawPath(ear, paint);
    // Tête
    canvas.drawOval(Rect.fromCenter(center: Offset(160 * s, 101 * s), width: 108 * s, height: 116 * s), paint);
    if (size.width >= 48) {
      canvas.drawCircle(Offset(148 * s, 88 * s), 5 * s, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _ElephantPainter old) => old.color != color;
}
