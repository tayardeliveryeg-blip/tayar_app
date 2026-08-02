import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:tayay_app/theme/theme_extensions.dart';

/// ====== نوع الدبوس: انطلاق أو وجهة ======
enum PinType { pickup, destination }

/// ====== شكل الدبوس الموحّد في كل شاشات الخريطة ======
/// مربع أبيض في الوضع الفاتح / مربع غامق في الوضع الغامق (context.textColor)،
/// وجواه أيقونة برتقالية: علامة تحديد الموقع (location_on) لنقطة الانطلاق،
/// وعلم (flag) لنقطة الوجهة. نفس الشكل بالظبط في كل الشاشات.
class PinMarker extends StatelessWidget {
  final PinType type;
  final double size;

  const PinMarker({super.key, required this.type, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.textColor,
        borderRadius: BorderRadius.circular(size * 0.27),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6),
        ],
      ),
      child: Icon(
        type == PinType.pickup ? Icons.location_on : Icons.flag,
        color: TayarColors.primary,
        size: size * 0.6,
      ),
    );
  }
}

/// ====== نقطة موقعك الحيّة على الخريطة (زي نقطة Google Maps الزرقاء) ======
/// دائرة زرقاء صغيرة صلبة في النص. نطاق الدقة (accuracy halo) بقى بيترسم
/// منفصل كـ CircleLayer جغرافي على الخريطة (مش هنا) عشان يكبر ويصغر مع
/// الزوم زي جوجل مابس بالظبط. لو الاتجاه (heading) متاح من الـ GPS،
/// بيظهر سهم صغير واضح فوق النقطة بيدور لايف مع اتجاه حركة المستخدم.
class LiveLocationDot extends StatelessWidget {
  /// قطر الدائرة الصلبة في النص
  final double dotSize;
  /// اتجاه حركة المستخدم بالدرجات (0 = شمال، بيزيد مع اتجاه عقارب الساعة).
  /// لو null، مش هيتعرض سهم اتجاه خالص (لسه مفيش قراءة اتجاه موثوقة).
  final double? heading;

  const LiveLocationDot({super.key, this.dotSize = 18, this.heading});

  /// ====== مسافة السهم عن مركز النقطة ======
  static const double _arrowOffset = 13;

  /// المساحة الكلية اللي الـ widget بياخدها فعليًا (بعد إضافة السهم).
  /// المفروض تُستخدم كـ width/height لـ Marker بتاع flutter_map عشان
  /// النقطة تفضل متمركزة صح على الإحداثية الحقيقية.
  static double totalSize(double dotSize) => dotSize + _arrowOffset * 2;

  @override
  Widget build(BuildContext context) {
    final boxSize = totalSize(dotSize);

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ====== السهم: بيدور حسب heading حوالين مركز النقطة ======
          if (heading != null)
            Transform.rotate(
              angle: heading! * math.pi / 180,
              child: Align(
                alignment: Alignment.topCenter,
                child: CustomPaint(
                  size: const Size(12, 10),
                  painter: _SmallArrowPainter(),
                ),
              ),
            ),
          // ====== الدائرة الزرقاء الصلبة في النص ======
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ====== رسم سهم صغير واضح بيوضح اتجاه حركة المستخدم فوق النقطة الزرقاء ======
/// مثلث أزرق صغير، طرفه لفوق (اتجاه الشمال = 0 درجة)، بحدود بيضاء رفيعة
/// عشان يبان واضح فوق أي خلفية.
class _SmallArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height * 0.72)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, Paint()..color = Colors.blue);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _SmallArrowPainter oldDelegate) => false;
}

/// ====== دبوس نقطة الانطلاق مع "ساق" (خط + نقطة حمرا صغيرة) بيوصله بالإحداثية
/// الحقيقية بالظبط ======
/// المشكلة اللي بيحلّها: أي Marker في flutter_map بيتمركز افتراضيًا حوالين
/// نقطة الإحداثية (يعني نص الـ widget = مكان الإحداثية فعليًا). فلو حطينا
/// أيقونة PinMarker العادية لوحدها فوق إحداثية نقطة الانطلاق، نص الأيقونة
/// (مش رأسها) هو اللي هيقع بالظبط على الإحداثية — وده بيخلّي أي نقطة تانية
/// (زي النقطة الزرقاء الحيّة لموقع المستخدم) لو قريبة، تتداخل بصريًا مع
/// جسم الأيقونة نفسها بدل ما تبان تحتها بوضوح.
///
/// الحل: بننده الأيقونة + خط واصل + نقطة حمرا صغيرة تحتها (بالظبط زي دبوس
/// السحب في نص الشاشة)، وبنحسب ارتفاع الـ widget الكلي بحيث نص الـ widget
/// (يعني مكان الإحداثية الفعلي) يطابق بالظبط مركز النقطة الحمرا الصغيرة —
/// فتبقى الأيقونة "طالعة فوق" النقطة بدل ما تبقى متداخلة معاها.
class PinMarkerWithStem extends StatelessWidget {
  final PinType type;
  final double iconSize;

  const PinMarkerWithStem({super.key, this.type = PinType.pickup, this.iconSize = 44});

  // ====== لازم القيم دي تتبع نفس أبعاد الـ widget فعليًا (شوف build) عشان
  // حساب totalHeight يبقى مضبوط ======
  static const double _lineHeight = 14;
  static const double _dotSize = 8;

  /// الارتفاع الكلي المطلوب لـ Marker.height عشان الإحداثية الحقيقية تقع
  /// بالظبط عند مركز النقطة الحمرا (مش في نص الأيقونة)
  double get totalHeight {
    final dotCenterFromTop = iconSize + _lineHeight + (_dotSize / 2);
    return dotCenterFromTop * 2;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: iconSize,
      height: totalHeight,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 0,
            child: PinMarker(type: type, size: iconSize),
          ),
          Positioned(
            top: iconSize,
            child: Container(width: 2, height: _lineHeight, color: Colors.white54),
          ),
          Positioned(
            top: iconSize + _lineHeight,
            child: Container(
              width: _dotSize,
              height: _dotSize,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}