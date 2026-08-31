import 'package:flutter/material.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== أيقونة كاستوم لزرار "ملائمة المسار مع الشاشة" (route fit-to-bounds):
// 4 زوايا (زي أيقونة focus/crop) وجواها خط منحني بسيط بينه نقطتين، يرمز
// للمسار بين نقطة البداية والنهاية. اتعملت CustomPaint لأن مفيش أيقونة
// جاهزة في Material Icons بتجمع المعنيين (مسار + ملائمة حدود) مع بعض ======
class RouteFitIcon extends StatelessWidget {
  final double size;
  final Color? color;

  const RouteFitIcon({super.key, this.size = 22, this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _RouteFitPainter(color: color ?? context.textColor),
    );
  }
}

class _RouteFitPainter extends CustomPainter {
  final Color color;

  const _RouteFitPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cornerLen = w * 0.3;
    const inset = 1.2;

    final cornerPaint = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    void bracket(Offset corner, Offset armX, Offset armY) {
      canvas.drawLine(corner, corner + armX, cornerPaint);
      canvas.drawLine(corner, corner + armY, cornerPaint);
    }

    // الزوايا الأربعة (فوق شمال، فوق يمين، تحت شمال، تحت يمين)
    bracket(
      const Offset(inset, inset),
      Offset(cornerLen, 0),
      Offset(0, cornerLen),
    );
    bracket(
      Offset(w - inset, inset),
      Offset(-cornerLen, 0),
      Offset(0, cornerLen),
    );
    bracket(
      Offset(inset, h - inset),
      Offset(cornerLen, 0),
      Offset(0, -cornerLen),
    );
    bracket(
      Offset(w - inset, h - inset),
      Offset(-cornerLen, 0),
      Offset(0, -cornerLen),
    );

    // خط المسار المنحني جوه الزوايا
    final routePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final start = Offset(w * 0.33, h * 0.7);
    final end = Offset(w * 0.7, h * 0.33);
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(w * 0.5, h * 0.3, end.dx, end.dy);
    canvas.drawPath(path, routePaint);

    final dotPaint = Paint()..color = color;
    canvas.drawCircle(start, 1.8, dotPaint);
    canvas.drawCircle(end, 1.8, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _RouteFitPainter oldDelegate) =>
      oldDelegate.color != color;
}
