import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:tayay_app/theme/theme_extensions.dart';

// ====== ماركر موقع الطيار على الخريطة: دايرة برتقالية بسهم اتجاه بيدور
// حسب الـ heading الحالي (زاوية حركة الطيار). بيتحط جوه Marker widget من
// flutter_map في الشاشة الأب ======
class DriverPositionMarker extends StatelessWidget {
  final double headingDegrees;

  const DriverPositionMarker({super.key, required this.headingDegrees});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: headingDegrees * math.pi / 180,
      child: Container(
        decoration: BoxDecoration(
          color: TayarColors.primary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
          ],
        ),
        child: const Icon(Icons.navigation, color: Colors.white, size: 22),
      ),
    );
  }
}
