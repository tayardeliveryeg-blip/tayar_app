import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors;

// ====== أيقونة موتوسيكل طيار واحد على الخريطة: بتنبض باستمرار عشان تحس إنها
// "شغالة" حتى وهي مش بتتحرك، ولو الطيار عمل عرض سعر على الطلب ده بتظهر
// بابل السعر فوقها مع هالة مضيئة تفرقها عن باقي الطيارين ======
// (كانت private class _DriverMotoMarker جوه searching_offers_screen.dart)
class DriverMotoMarker extends StatelessWidget {
  final Animation<double> pulse;
  final bool hasOffer;
  final double? price;

  const DriverMotoMarker({
    super.key,
    required this.pulse,
    required this.hasOffer,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        // ====== لسه بيدور بس (من غير عرض): نبضة خفيفة جدًا (0.94 - 1.0)
        // عمل عرض سعر: نبضة أوضح شوية (1.0 - 1.12) عشان يلفت النظر ======
        final scale = hasOffer
            ? 1.0 + (pulse.value * 0.12)
            : 0.94 + (pulse.value * 0.06);
        return Transform.scale(scale: scale, child: child);
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (hasOffer)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TayarColors.primary.withValues(alpha: 0.22),
                border: Border.all(color: TayarColors.primary, width: 1.5),
              ),
            ),
          const Text('🏍️', style: TextStyle(fontSize: 26)),
          if (hasOffer && price != null)
            Positioned(
              top: -6,
              child: TweenAnimationBuilder<double>(
                // ====== المفتاح مربوط بالسعر عشان لو الطيار غيّر عرضه، البابل
                // تعمل "bounce" تاني وتلفت النظر إن فيه تحديث ======
                key: ValueKey(price),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, -34 * value),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: TayarColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    price!.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ====== حالة أنيميشن حركة طيار قريب واحد على الخريطة ======
// (كانت private class _NearbyDriverMarker جوه searching_offers_screen.dart)
class NearbyDriverMarker {
  LatLng displayed;
  LatLng prev;
  LatLng target;

  NearbyDriverMarker({
    required this.displayed,
    required this.prev,
    required this.target,
  });
}
