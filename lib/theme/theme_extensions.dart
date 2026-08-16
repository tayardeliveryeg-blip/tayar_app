import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ====== ألوان البراند ======
// ملاحظة: القيم التالية (background, cardDark, textGrey) بتفضل بقيمها
// الغامقة القديمة عشان الشاشات اللي لسه ما اتحولتش لنظام الوضع الفاتح/الغامق
// (Theme الجديد) تفضل شغالة زي ما هي بالظبط من غير أي كسر. أي شاشة جديدة أو
// متحولة المفروض تستخدم context.bgColor / context.cardColor / context.textGreyColor
// اللي بتتغيّر تلقائيًا حسب الوضع الحالي (شوف TayarThemeColors تحت).
class TayarColors {
  static const Color primary = Color(0xFFFF6B00); // الأورانج الأساسي - ثابت في الوضعين
  static const Color primaryDark = Color(0xFFE85F00); // درجة أغمق شوية للأورانج (hover/pressed states)
  static const Color background = Color(0xFF1A1816); // (قديم) الخلفية الداكنة
  static const Color cardDark = Color(0xFF2A2826); // (قديم)
  static const Color textWhite = Colors.white; // (قديم)
  static const Color textGrey = Color(0xFFB0B0B0); // (قديم)

  // ====== القيم الفعلية للوضعين، تُستخدم من خلال TayarThemeColors ======
  static const Color backgroundDark = Color(0xFF1A1816);
  static const Color backgroundLight = Color(0xFFF7F5F3);
  static const Color cardDarkMode = Color(0xFF2A2826);
  static const Color cardLightMode = Colors.white;
  static const Color textWhiteDark = Colors.white;
  static const Color textWhiteLight = Colors.black;
  static const Color textGreyDark = Color(0xFFB0B0B0);
  static const Color textGreyLight = Color(0xFF6E6660);
  static const Color dividerDark = Colors.white12;
  static const Color dividerLight = Color(0x14000000); // black بنسبة شفافية قليلة

  // ====== ألوان مساعدة موحّدة (تحل محل الألوان اللي كانت بتتكتب يدويًا
  // في الشاشات المختلفة زي أخضر النجاح أو أحمر الخطأ) ======
  static const Color success = Color(0xFF2E9E5B);
  static const Color error = Color(0xFFE5484D);
  static const Color warning = Color(0xFFF5A623);
}

// ====== Extension بيدّي أي شاشة وصول سهل وسريع للألوان الصح حسب الوضع
// الحالي (فاتح/غامق) بدل ما تكتب اللون يدويًا. الاستخدام:
//   context.bgColor       -> لون الخلفية
//   context.cardColor     -> لون الكروت
//   context.textColor     -> لون النص الأساسي (أبيض في الغامق / غامق في الفاتح)
//   context.textGreyColor -> لون النص الثانوي
//   context.dividerColor2 -> لون الفواصل
//   context.isDarkMode    -> true لو الوضع الحالي غامق
//
// ====== ملاحظة مهمة: ده المكان الوحيد اللي المفروض يتعرف فيه extension على
// BuildContext بالأسماء دي. لازم ميتكررش تعريف تاني بنفس الأسماء (زي
// bgColor/cardColor/textColor/textGreyColor) في أي ملف تاني، لأن أي شاشة
// بتستورد ملفين فيهم extension بنفس الأسماء هيحصلها compile error
// "ambiguous extension" لأن Dart مش هيعرف يفضّل أنهي extension يستخدم ======
extension TayarThemeColors on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  Color get bgColor =>
      isDarkMode ? TayarColors.backgroundDark : TayarColors.backgroundLight;
  Color get cardColor =>
      isDarkMode ? TayarColors.cardDarkMode : TayarColors.cardLightMode;
  Color get textColor =>
      isDarkMode ? TayarColors.textWhiteDark : TayarColors.textWhiteLight;
  Color get textGreyColor =>
      isDarkMode ? TayarColors.textGreyDark : TayarColors.textGreyLight;
  Color get dividerColor2 =>
      isDarkMode ? TayarColors.dividerDark : TayarColors.dividerLight;

  // ====== لون أي نص/أيقونة فوق خلفية برتقالية كاملة (زرار، أفاتار، شارة...):
  // أبيض ثابت في الوضعين الغامق والفاتح (زي بنرات الشاشة الرئيسية). لا يُستخدم
  // فوق التدرّجات البرتقالية الشفافة (withValues alpha) لأن المحتوى هناك بيفضل
  // برتقالي ======
  Color get onPrimaryColor => Colors.white;

  // ====== لون خط السحب (Drag Handle) فوق الـ Bottom Sheets. كان مكتوب
  // Colors.grey.shade700 يدويًا في أكتر من شاشة، وده كان بيبان غريب في
  // الوضع الفاتح لأنه لون غامق ثابت. دلوقتي بيتغيّر حسب الوضع الحالي ======
  Color get handleColor =>
      isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400;
}

// ====== قيم الاستدارة الموحّدة (Border Radius Scale) ======
// القيم دي مستخرجة من أكتر قيم كانت متكررة يدويًا في شاشات المشروع (10, 12,
// 14, 16, 30)، عشان أي شاشة جديدة أو بتتحول تستخدم AppRadius.xxx بدل ما
// تكتب رقم يدوي عشوائي، وعشان أي تعديل مستقبلي على شكل الاستدارة يحصل من
// مكان واحد بس. الاستخدام: BorderRadius.circular(AppRadius.lg)
class AppRadius {
  static const double sm = 10; // كروت صغيرة / صور مصغّرة
  static const double md = 12; // حقول الإدخال (متطابقة مع inputDecorationTheme)
  static const double lg = 14; // الأزرار (متطابقة مع elevatedButtonTheme)
  static const double xl = 16; // الكروت الرئيسية (متطابقة مع cardTheme)
  static const double xxl = 20; // كروت/حاويات بارزة (زي كارت طلب جديد)
  static const double pill = 30; // شارات/أزرار بيضاوية الشكل بالكامل

  // القيمة دي مش جزء من الـ scale العام، هي نص ارتفاع خط السحب (Drag Handle)
  // اللي حجمه 40×4 فوق الـ Bottom Sheets، عشان شكله يبقى pill كامل من طرفيه.
  // موجودة هنا بس للتوثيق ومنع تكرار الرقم 2 يدويًا في كل شاشة.
  static const double handle = 2;
}

// ====== ظلال موحّدة (Shadow Presets) ======
// بدل ما كل شاشة تكتب BoxShadow يدويًا بقيم عشوائية (أو من غير ظل خالص
// زي ما كان حادث قبل كده)، أي كارت أو عنصر محتاج عمق بصري ياخد الظل بتاعه
// من هنا. أي تعديل مستقبلي على شكل الظل (قوته، اتجاهه) بيحصل في مكان واحد
// وينعكس على كل التطبيق. الاستخدام: boxShadow: AppShadows.soft(context)
class AppShadows {
  // ظل ناعم عام لأي كارت (البطاقات، الكروت، الحاويات)
  static List<BoxShadow> soft(BuildContext context) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: context.isDarkMode ? 0.35 : 0.08),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // توهّج برتقالي خفيف تحت الأزرار/العناصر الأساسية بلون البراند
  static const List<BoxShadow> primaryGlow = [
    BoxShadow(
      color: Color(0x59FF6B00), // TayarColors.primary بشفافية ~35%
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  // ظل أقوى للعناصر الطافية فوق كل حاجة (Bottom Sheets، الكارت العائم على الخريطة)
  static List<BoxShadow> elevated(BuildContext context) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: context.isDarkMode ? 0.5 : 0.15),
      blurRadius: 24,
      offset: const Offset(0, -4),
    ),
  ];

  // ظل الأزرار الدائرية العائمة فوق الخريطة (الجرس، القايمة الجانبية، موقعي،
  // الرجوع، المشاركة، الطوارئ...). كانت كل شاشة بتكتب قيم مختلفة شوية (blur 8 أو 10،
  // alpha 0.25 أو 0.3) لنفس فكرة الزرار، فاتوحدت هنا في قيمة واحدة متسقة.
  static List<BoxShadow> floating(BuildContext context) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: context.isDarkMode ? 0.4 : 0.25),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  // ظل ماركرز/دبابيس الخريطة (دبوس الانطلاق/الوجهة، نقطة موقع الطيار، دبوس
  // التاجر، فقاعة السعر...). كانت القيم متفرقة بين الملفات (blur 3 لحد 8،
  // alpha من 0.25 لحد 0.35) على نفس فكرة "أيقونة صغيرة طافية فوق الخريطة"،
  // فاتوحدت في ظل واحد أخف من ظل الأزرار (markers أصغر من الأزرار العائمة).
  static const List<BoxShadow> marker = [
    BoxShadow(color: Colors.black38, blurRadius: 6),
  ];
}

// ====== قيم المسافات الموحّدة (Spacing Scale) ======
// نفس فكرة AppRadius بس للـ padding/margin/SizedBox، مبنية على أكتر قيم
// كانت متكررة فعليًا (4, 8, 12, 16, 20, 24). الاستخدام:
//   padding: const EdgeInsets.all(AppSpacing.lg)
//   const SizedBox(height: AppSpacing.md)
class AppSpacing {
  static const double xxs = 2; // مسافات ضيقة جدًا (badges/chips صغيرة)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16; // القيمة الأكتر استخدامًا في المشروع كله
  static const double xl = 20;
  static const double xxl = 24;
}

// ====== ستايلات الأرقام الكبيرة (زي الرصيد، متوسط التقييم، الأرباح) ======
// كانت بتتكرر بنفس الشكل بالظبط (نفس اللون والوزن) في أكتر من مكان في شاشة
// السائق بس بفونت سايز مختلف حسب الأهمية. بدل تكرار TextStyle كامل في كل
// مرة، الاستخدام بقى: style: TayarStatTextStyles.statMedium
class TayarStatTextStyles {
  static const TextStyle statSmall = TextStyle(
    color: TayarColors.primary,
    fontSize: 26,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle statMedium = TextStyle(
    color: TayarColors.primary,
    fontSize: 36,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle statHuge = TextStyle(
    color: TayarColors.primary,
    fontSize: 48,
    fontWeight: FontWeight.bold,
  );
}

// ====== تدرّج الخطوط الموحّد (Typography Scale) ======
// بيحل مشكلة إن كل شاشة كانت بتحدد fontSize بشكل عشوائي (12, 13, 14, 17, 18, 26...).
// بدل كده، أي نص جديد المفروض ياخد الستايل بتاعه من هنا عن طريق:
//   Theme.of(context).textTheme.headlineSmall
//   Theme.of(context).textTheme.bodyMedium
//   ... إلخ
// ده بيضمن إن كل العناوين في التطبيق كله بنفس الحجم والوزن، وكل النصوص العادية
// كمان متسقة، من غير ما تحتاج تكتب fontSize يدويًا في كل مكان.
TextTheme _buildTextTheme(Color baseColor) {
  final base = GoogleFonts.cairoTextTheme();
  return base.copyWith(
    // عناوين كبيرة (شاشات splash / عناوين رئيسية)
    displayLarge: base.displayLarge?.copyWith(
      fontSize: 30,
      fontWeight: FontWeight.w700,
      color: baseColor,
      height: 1.3,
    ),
    // عنوان الشاشة (زي "تسجيل الدخول"، "الملف الشخصي")
    headlineSmall: base.headlineSmall?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: baseColor,
      height: 1.3,
    ),
    // عناوين فرعية جوه الشاشة (زي عنوان كارت أو قسم)
    titleLarge: base.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: baseColor,
      height: 1.3,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: baseColor,
      height: 1.3,
    ),
    // النص الأساسي في التطبيق (فقرات، تفاصيل)
    bodyLarge: base.bodyLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: baseColor,
      height: 1.5,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: baseColor,
      height: 1.5,
    ),
    // نص ثانوي/مساعد (زي تواريخ، ملاحظات صغيرة)
    bodySmall: base.bodySmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: baseColor,
      height: 1.4,
    ),
    // نص الأزرار
    labelLarge: base.labelLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.2,
    ),
  );
}

// ====== تعريفات الثيم الكامل (فاتح وغامق) اللي بيستخدمها MaterialApp ======
class TayarTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: TayarColors.backgroundDark,
    primaryColor: TayarColors.primary,
    textTheme: _buildTextTheme(TayarColors.textWhiteDark),
    colorScheme: const ColorScheme.dark(
      primary: TayarColors.primary,
      secondary: TayarColors.primary,
      onPrimary: Colors.white,
      surface: TayarColors.cardDarkMode,
      error: TayarColors.error,
    ),
    cardColor: TayarColors.cardDarkMode,
    dividerColor: TayarColors.dividerDark,
    // ====== AppBar موحّد لكل الشاشات ======
    appBarTheme: AppBarTheme(
      backgroundColor: TayarColors.backgroundDark,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: TayarColors.textWhiteDark),
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: TayarColors.textWhiteDark,
      ),
    ),
    // ====== شكل موحّد لكل الأزرار الأساسية في التطبيق ======
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TayarColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    // ====== شكل موحّد لحقول الإدخال (بدل ما كل شاشة تظبطه لوحدها) ======
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TayarColors.cardDarkMode,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TayarColors.primary, width: 1.5),
      ),
      hintStyle: GoogleFonts.cairo(color: TayarColors.textGreyDark, fontSize: 14),
    ),
    // ====== شكل موحّد للكروت (بظل ناعم ثابت بدل ما كانت مسطحة تمامًا) ======
    cardTheme: CardThemeData(
      color: TayarColors.cardDarkMode,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.4),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? TayarColors.primary
            : null,
      ),
    ),
  );

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: TayarColors.backgroundLight,
    primaryColor: TayarColors.primary,
    textTheme: _buildTextTheme(TayarColors.textWhiteLight),
    colorScheme: const ColorScheme.light(
      primary: TayarColors.primary,
      secondary: TayarColors.primary,
      onPrimary: Colors.white,
      surface: TayarColors.cardLightMode,
      error: TayarColors.error,
    ),
    cardColor: TayarColors.cardLightMode,
    dividerColor: TayarColors.dividerLight,
    appBarTheme: AppBarTheme(
      backgroundColor: TayarColors.backgroundLight,
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: TayarColors.textWhiteLight),
      titleTextStyle: GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: TayarColors.textWhiteLight,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TayarColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: TayarColors.dividerLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TayarColors.primary, width: 1.5),
      ),
      hintStyle: GoogleFonts.cairo(color: TayarColors.textGreyLight, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      color: TayarColors.cardLightMode,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? TayarColors.primary
            : null,
      ),
    ),
  );
}