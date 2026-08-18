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
/// الوضع الغامق بيستخدم Esri World Dark Gray Canvas — ستايل رمادي غامق
/// أدفى وأقل قتامة من CartoDB Dark Matter. الخريطة دي عند Esri متقسّمة
/// طبقتين لازم يتحطوا فوق بعض:
/// 1) Base: الخلفية الرمادية بس (شوارع/مباني/مسطحات مائية من غير أسماء)
/// 2) Reference: أسماء الشوارع والمناطق والحدود (خلفيتها شفافة عشان
///    تتراكب فوق الـ Base وتبان الأسماء واضحة)
/// الاتنين مجانيين بالكامل من غير أي API key. ملحوظة: ترتيب الإحداثيات
/// عند Esri هو {z}/{y}/{x} مش {z}/{x}/{y} زي OSM/CartoDB.
class TayarTileLayer extends StatelessWidget {
  const TayarTileLayer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDark) {
      return Stack(
        children: [
          TileLayer(
            urlTemplate:
                'https://services.arcgisonline.com/arcgis/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.tayar.app',
            tileDisplay: const TileDisplay.fadeIn(
              duration: Duration(milliseconds: 200),
            ),
          ),
          TileLayer(
            urlTemplate:
                'https://services.arcgisonline.com/arcgis/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
            userAgentPackageName: 'com.tayar.app',
            tileDisplay: const TileDisplay.fadeIn(
              duration: Duration(milliseconds: 200),
            ),
          ),
        ],
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
  const TayarMapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final source = isDark
        ? 'Esri, HERE, Garmin • OpenStreetMap contributors'
        : 'OpenStreetMap contributors';

    return Align(
      alignment: Alignment.topLeft,
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
