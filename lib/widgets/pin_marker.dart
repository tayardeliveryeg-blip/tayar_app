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
/// دائرة زرقاء صغيرة صلبة في النص، وحواليها هالة زرقاء فاتحة شفافة أكبر
/// بتمثّل نطاق الدقة (accuracy radius) — نفس الشكل القياسي المعروف.
class LiveLocationDot extends StatelessWidget {
  /// قطر الهالة الخارجية الشفافة بالكامل
  final double haloSize;
  /// قطر الدائرة الصلبة في النص
  final double dotSize;

  const LiveLocationDot({
    super.key,
    this.haloSize = 56,
    this.dotSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: haloSize,
      height: haloSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ====== الهالة الشفافة: نطاق الدقة حوالين الموقع ======
          Container(
            width: haloSize,
            height: haloSize,
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.18),
              shape: BoxShape.circle,
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