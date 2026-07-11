import 'package:flutter/material.dart';

// ====== ألوان البراند ======
// ملاحظة: القيم التالية (background, cardDark, textGrey) بتفضل بقيمها
// الغامقة القديمة عشان الشاشات اللي لسه ما اتحولتش لنظام الوضع الفاتح/الغامق
// (Theme الجديد) تفضل شغالة زي ما هي بالظبط من غير أي كسر. أي شاشة جديدة أو
// متحولة المفروض تستخدم context.bgColor / context.cardColor / context.textGreyColor
// اللي بتتغيّر تلقائيًا حسب الوضع الحالي (شوف TayarThemeColors تحت).
class TayarColors {
  static const Color primary = Color(0xFFFF6B00); // الأورانج الأساسي - ثابت في الوضعين
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
  static const Color textWhiteLight = Color(0xFF201D1A);
  static const Color textGreyDark = Color(0xFFB0B0B0);
  static const Color textGreyLight = Color(0xFF6E6660);
  static const Color dividerDark = Colors.white12;
  static const Color dividerLight = Color(0x14000000); // black بنسبة شفافية قليلة
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
}

// ====== تعريفات الثيم الكامل (فاتح وغامق) اللي بيستخدمها MaterialApp ======
class TayarTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: TayarColors.backgroundDark,
    primaryColor: TayarColors.primary,
    fontFamily: 'Arial',
    colorScheme: const ColorScheme.dark(
      primary: TayarColors.primary,
      surface: TayarColors.cardDarkMode,
    ),
    cardColor: TayarColors.cardDarkMode,
    dividerColor: TayarColors.dividerDark,
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
    fontFamily: 'Arial',
    colorScheme: const ColorScheme.light(
      primary: TayarColors.primary,
      surface: TayarColors.cardLightMode,
    ),
    cardColor: TayarColors.cardLightMode,
    dividerColor: TayarColors.dividerLight,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? TayarColors.primary
            : null,
      ),
    ),
  );
}
