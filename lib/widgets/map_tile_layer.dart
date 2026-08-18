import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/theme_extensions.dart';

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
/// الوضع الغامق بيستخدم CartoDB Dark Matter tiles (مبنية على بيانات
/// OpenStreetMap) بدل Mapbox — ستايل مظلم جاهز ومجاني بالكامل من غير
/// أي API key أو تسجيل أو وسيلة دفع.
class TayarTileLayer extends StatelessWidget {
  const TayarTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return TileLayer(
        urlTemplate:
            'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
        subdomains: const ['a', 'b', 'c', 'd'],
        userAgentPackageName: 'com.tayar.app',
        retinaMode: RetinaMode.isHighDensity(context),
        tileDisplay: const TileDisplay.fadeIn(
          duration: Duration(milliseconds: 200),
        ),
      );
    }

    return TileLayer(
      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c'],
      userAgentPackageName: 'com.tayar.app',
      // ====== fade-in ناعم لظهور التايلز بدل ما تبان فجأة ======
      tileDisplay: const TileDisplay.fadeIn(
        duration: Duration(milliseconds: 200),
      ),
    );
  }
}

/// ====== إسناد مصدر بيانات الخريطة (Attribution) — إجباري حسب شروط
/// استخدام OpenStreetMap و CARTO المجانية. لازم يتضاف كـ آخر child في
/// كل شاشة فيها FlutterMap جنب TayarTileLayer، عشان يفضل ظاهر فوق كل
/// الطبقات التانية (دبابيس/خطوط) من غير ما يحجب أي عنصر تفاعلي مهم.
/// المكان topLeft (مش bottomLeft/bottomRight) مقصود: في 4 من الـ 6
/// شاشات فيه bottom sheet أو زرار ملتصق بأسفل الشاشة بعرضها بالكامل،
/// بينما زاوية أعلى يسار فاضية في الـ 6 شاشات كلها.
/// ملحوظة: استخدمنا SimpleAttributionWidget مش RichAttributionWidget
/// لأن RichAttributionWidget بيقبل بس AttributionAlignment.bottomLeft/
/// bottomRight (مفيش قيمة top خالص)، بينما SimpleAttributionWidget
/// بياخد Alignment العادي اللي بيدعم topLeft. ======
class TayarMapAttribution extends StatelessWidget {
  const TayarMapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SimpleAttributionWidget(
      alignment: Alignment.topLeft,
      backgroundColor: context.bgColor.withValues(alpha: 0.7),
      source: Text(
        isDark
            ? 'OpenStreetMap contributors • CARTO'
            : 'OpenStreetMap contributors',
      ),
      onTap: () =>
          launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
    );
  }
}
