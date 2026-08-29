import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
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

/// ====== تحميل ستايل OpenFreeMap "Liberty" مرة واحدة وتخزينه مؤقتًا على
/// مستوى التطبيق كله (بدل ما كل شاشة خريطة - فيه 6 شاشات - تعمل تحميل
/// جديد للستايل من الأول). الستايل أصلًا بيتخزن على القرص جوه المكتبة
/// كمان (stale-while-revalidate)، لكن الكاش ده بيمنع حتى إعادة القراءة
/// من القرص/الشبكة عند كل تنقل بين الشاشات جوه نفس جلسة التطبيق.
///
/// ====== ملحوظة مهمة: بقى فيه ستايل واحد بس (مش فاتح وغامق منفصلين) ======
/// كان فيه قبل كده ستايل "dark" منفصل من OpenFreeMap (نسخة من Dark
/// Matter)، بس اتضح إنه رمادي/أسود مسطح تقريبًا من غير تنويع ألوان
/// حقيقي بين المية/الحدائق/الشوارع (المشروع الأصلي بتاعه متوقف التطوير
/// من فريق OpenMapTiles، بعكس Liberty اللي لسه بيتحدث). فالتنوع اللوني
/// في الوضع الغامق كان أقل بكتير من الفاتح ومحسوس إنه "أسود قاتم".
///
/// الحل: بنستخدم ستايل "Liberty" الغني بالألوان في الوضعين، وفي الوضع
/// الغامق بنلف طبقة الخريطة بفلتر ألوان (invert + hue-rotate 180°) -
/// نفس التقنية المعروفة اللي بتستخدمها كتير مواقع وتطبيقات لعمل نسخة
/// غامقة من خريطة فاتحة. بيقلب السطوع فبيبقى الأبيض أسود، بس بيلف درجة
/// اللون رجوع 180 عشان الألوان تفضل قريبة من الطبيعية (المية تفضل زرقاء
/// غامقة، الحدائق تفضل خضرا غامقة) بدل ما تتحول لألوان معكوسة غريبة.
/// النتيجة: نفس تفاصيل وتنوع ألوان الخريطة الفاتحة بالظبط، بس بشكل غامق
/// مريح للعين، من غير ما نحتاج نصمم/نلاقي ستايل غامق منفصل. ======
class _TayarMapStyles {
  static Future<vt.Style>? _liberty;

  static Future<vt.Style> liberty() {
    return _liberty ??= vt.StyleReader(
      uri: 'https://tiles.openfreemap.org/styles/liberty',
    ).read();
  }
}

/// ====== مصفوفة فلتر الألوان اللي بتحول الستايل الفاتح لغامق (نفس تأثير
/// CSS filter: invert(100%) hue-rotate(180deg) المستخدم كتير لعمل نسخة
/// غامقة من خريطة فاتحة). القيم محسوبة يدويًا (invert ثم دوران درجة اللون
/// 180° بمعادلة W3C القياسية لفلتر hue-rotate) ومدموجة في مصفوفة واحدة
/// 4×5 عشان تتطبق كـ ColorFilter.matrix على عرض طبقة الخريطة بالكامل. ======
const List<double> _darkMapInvertFilterMatrix = [
  0.574, -1.430, -0.144, 0, 255,
  -0.426, -0.430, -0.144, 0, 255,
  -0.426, -1.430, 0.856, 0, 255,
  0, 0, 0, 1, 0,
];

/// ====== طبقة الخريطة الموحّدة لكل شاشات الخريطة في التطبيق ======
/// اتبدّلت من raster tiles (صور جاهزة) لـ vector tiles حقيقية عن طريق
/// OpenFreeMap (18 أغسطس 2026) — مجاني بالكامل، من غير API key أو حساب،
/// وأقرب شكل ممكن لجوجل مابس من غير أي مصاريف. البيانات جايه من OSM في
/// الوضعين، فالتسميات غنية بنفس المستوى في الفاتح والغامق مع بعض.
class TayarTileLayer extends StatefulWidget {
  const TayarTileLayer({super.key});

  @override
  State<TayarTileLayer> createState() => _TayarTileLayerState();
}

class _TayarTileLayerState extends State<TayarTileLayer> {
  Future<vt.Style>? _future;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _future ??= _TayarMapStyles.liberty();

    return FutureBuilder<vt.Style>(
      future: _future,
      builder: (context, snapshot) {
        final style = snapshot.data;
        if (style == null) {
          // ====== خلفية بسيطة لحد ما الستايل يتحمل. بيحصل مرة واحدة بس
          // في حياة التطبيق (الستايل متخزن بعد كده)، فمش هيبان تقريبًا ======
          return Container(
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F0),
          );
        }
        final tileLayer = vt.VectorTileLayer(
          theme: style.theme,
          tileProviders: style.providers,
          rasterSources: style.rasterSources,
          sprites: style.sprites,
        );
        // ====== في الوضع الغامق بس: فلتر invert+hue-rotate بيحوّل نفس
        // ستايل Liberty الملوّن لنسخة غامقة بنفس التنوع اللوني (راجع
        // تعليق _darkMapInvertFilterMatrix فوق) ======
        if (!isDark) {
  return ColorFiltered(
    // فلتر محايد (identity matrix) — نفس الألوان بالظبط، الهدف بس إجبار
    // الـ engine يعمل compositing layer واحدة زي اللي بتحصل في الوضع
    // الغامق، عشان BackdropFilter يقدر يشوف الخريطة صح (تست للتأكد من
    // فرضية إن غياب ColorFiltered هو سبب اختفاء البلور في الوضع الفاتح).
    colorFilter: const ColorFilter.matrix([
      1, 0, 0, 0, 0,
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ]),
    child: tileLayer,
  );
}
        return ColorFiltered(
          colorFilter: const ColorFilter.matrix(_darkMapInvertFilterMatrix),
          child: tileLayer,
        );
      },
    );
  }
}

/// ====== إسناد مصدر بيانات الخريطة (Attribution) — إجباري حسب شروط
/// استخدام OpenStreetMap و OpenFreeMap المجانية. لازم يتضاف كـ آخر child في
/// كل شاشة فيها FlutterMap جنب TayarTileLayer، عشان يفضل ظاهر فوق كل
/// الطبقات التانية (دبابيس/خطوط) من غير ما يحجب أي عنصر تفاعلي مهم.
/// المكان topLeft (مش bottomLeft/bottomRight) مقصود: في 4 من الـ 6
/// شاشات فيه bottom sheet أو زرار ملتصق بأسفل الشاشة بعرضها بالكامل،
/// بينما زاوية أعلى يسار فاضية في الـ 6 شاشات كلها.
/// ====== شكل الأيقونة: أيقونة دائرية صغيرة (i) بدل النص الطويل اللي
/// كان بيتكسر ويتداخل مع عناصر تانية على شاشات الموبايل الصغيرة. النص
/// الكامل (المصدر + رابط الترخيص) بيظهر في BottomSheet لما المستخدم
/// يدوس على الأيقونة، وده كافي قانونيًا لأن شروط OSM/OpenFreeMap بتطلب إسناد
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
    final source = 'OpenStreetMap contributors • OpenFreeMap';

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
