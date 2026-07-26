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