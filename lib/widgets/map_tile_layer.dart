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
/// الوضع الغامق كان بيستخدم Esri World Dark Gray Canvas (ستايل minimal
/// بتصميمه، بيانات HERE/Garmin ضعيفة في الشوارع الفرعية بمصر). اتبدّل
/// لـ CartoDB Dark Matter (18 أغسطس 2026) كحل مؤقت: بيستخدم بيانات OSM
/// نفسها المستخدمة في الوضع الفاتح، فالتسميات بقت غنية بنفس مستوى
/// الفاتح تقريبًا. الحل ده مؤقت لحد ما مفتاح Mapbox يتفعّل، وقتها
/// هيتبدّل الوضعين (فاتح وغامق) لـ Mapbox مع بعض عشان تناسق كامل.
/// مجاني بالكامل من غير أي API key، ومحتاج إسناد "© OpenStreetMap
/// contributors © CARTO" (اتضاف في TayarMapAttribution).
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
/// استخدام OpenStreetMap و Esri المجانية. لازم يتضاف كـ آخر child في
/// كل شاشة فيها FlutterMap جنب TayarTileLayer، عشان يفضل ظاهر فوق كل
/// الطبقات التانية (دبابيس/خطوط) من غير ما يحجب أي عنصر تفاعلي مهم.
/// المكان topLeft (مش bottomLeft/bottomRight) مقصود: في 4 من الـ 6
/// شاشات فيه bottom sheet أو زرار ملتصق بأسفل الشاشة بعرضها بالكامل،
/// بينما زاوية أعلى يسار فاضية في الـ 6 شاشات كلها.
/// ====== شكل الأيقونة: أيقونة دائرية صغيرة (i) بدل النص الطويل اللي
/// كان بيتكسر ويتداخل مع عناصر تانية على شاشات الموبايل الصغيرة. النص
/// الكامل (المصدر + رابط الترخيص) بيظهر في BottomSheet لما المستخدم
/// يدوس على الأيقونة، وده كافي قانونيًا لأن شروط OSM/Esri بتطلب إسناد
/// "متاح ومرئي للمستخدم"، مش إنه يفضل مكتوب بالكامل طول الوقت. ======
class TayarMapAttribution extends StatelessWidget {
  /// [alignment] بيتحكم في مكان الأيقونة لما الويدجت مستخدم كـ child مباشر
  /// جوه FlutterMap (بيملى مساحة الخريطة بالكامل، فالـ Align هو اللي بيحدد
  /// مكانها). لو الويدجت اتحط برا FlutterMap جوه Positioned (زي شاشة
  /// passenger_home اللي بتحاذيها مع زرار تحديد الموقع)، الـ alignment
  /// بيتسابله القيمة الافتراضية (centerRight/centerLeft) عادي من غير تأثير
  /// عملي لأن الـ Positioned هو اللي بيحدد المكان الفعلي.
  ///
  /// [hidden] بيستخدم نفس منطق الإخفاء بتاع زرار تحديد الموقع (بيتلغي وقت
  /// سحب الخريطة) - AnimatedOpacity + IgnorePointer.
  const TayarMapAttribution({
    super.key,
    this.alignment = Alignment.topLeft,
    this.hidden = false,
  });

  final Alignment alignment;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = isDark
        ? 'OpenStreetMap contributors • CARTO'
        : 'OpenStreetMap contributors';

    return Align(
      alignment: alignment,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: hidden ? 0 : 1,
        child: IgnorePointer(
          ignoring: hidden,
          child: GestureDetector(
            onTap: () => _showAttributionSheet(context, source),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: context.bgColor.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: context.textGreyColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAttributionSheet(BuildContext context, String source) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: AppRadius.handle,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: sheetContext.handleColor,
                  borderRadius: BorderRadius.circular(AppRadius.handle),
                ),
                alignment: Alignment.center,
              ),
              Text(
                'مصدر بيانات الخريطة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: sheetContext.textColor,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                source,
                style: TextStyle(
                  fontSize: 14,
                  color: sheetContext.textGreyColor,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
                child: const Text(
                  'تفاصيل الترخيص',
                  style: TextStyle(
                    fontSize: 14,
                    color: TayarColors.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
