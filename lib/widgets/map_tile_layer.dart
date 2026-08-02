import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// ====== حد أقصى لمساحة الخريطة القابلة للسحب: نفس حدود العالم اللي
/// التايلز فعليًا موجودة فيها (خط عرض ±85.0511، وهو الحد الأقصى لعرض
/// Web Mercator). بيتحط في MapOptions.cameraConstraint في أي شاشة فيها
/// سحب/زوم عشان المستخدم ميقدرش يسحب الخريطة لحد ما يوصل لفراغ رمادي
/// بره حدود التايلز (فوق أو تحت الخريطة) ======
final tayarMapCameraConstraint = CameraConstraint.contain(
  bounds: LatLngBounds(
    const LatLng(-85.0511, -180),
    const LatLng(85.0511, 180),
  ),
);

/// ====== طبقة الخريطة الموحّدة لكل شاشات الخريطة في التطبيق ======
/// ملحوظة: الوضع الغامق للخريطة (Mapbox Dark) متوقف مؤقتًا لحد ما يتم
/// عمل حساب Mapbox وربط الـ API key بشكل آمن. حاليًا الخريطة بتستخدم
/// OpenStreetMap العادي في كل الأحوال (فاتح وغامق) لحد ما نرجّع التفعيل.
class TayarTileLayer extends StatelessWidget {
  const TayarTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c'],
      userAgentPackageName: 'com.tayar.app',
      // ====== fade-in ناعم لظهور التايلز بدل ما تبان فجأة ======
      tileDisplay: const TileDisplay.fadeIn(
        duration: Duration(milliseconds: 200),
      ),
    );

    // ====== TODO: هنا هيتفعّل اختيار Mapbox Dark لما نضيف الـ API key ======
    // final isDark = Theme.of(context).brightness == Brightness.dark;
    // if (isDark) {
    //   return TileLayer(
    //     urlTemplate:
    //         'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}{r}?access_token=YOUR_TOKEN',
    //     userAgentPackageName: 'com.tayar.app',
    //     retinaMode: RetinaMode.isHighDensity(context),
    //     tileDisplay: const TileDisplay.fadeIn(
    //       duration: Duration(milliseconds: 200),
    //     ),
    //   );
    // }
  }
}