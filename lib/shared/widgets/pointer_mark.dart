import 'package:flutter/material.dart';

/// The Tassel mark (logo concept 04), flat and single-colour.
class PointerMark extends StatelessWidget {
  const PointerMark({super.key, required this.color, this.size = 32});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Pointer',
    image: true,
    child: CustomPaint(size: Size.square(size), painter: _MarkPainter(color)),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48);
    final fill = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(24, 9)
        ..lineTo(40, 17)
        ..lineTo(24, 25)
        ..lineTo(8, 17)
        ..close(),
      fill,
    );
    canvas.drawLine(
      const Offset(40, 17),
      const Offset(40, 28),
      Paint()
        ..color = color
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(const Offset(40, 33), 4.4, fill);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}
