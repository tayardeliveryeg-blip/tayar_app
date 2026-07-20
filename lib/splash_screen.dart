import 'package:flutter/material.dart';
import 'main.dart' show AuthGate;
import 'passenger_home.dart' show TayarColors;

/// ====== شاشة السبلاش ======
/// المربع البرتقالي + شعار الموتوسيكل بقى بيظهر ثابت (من غير حركة) من
/// خلال Native Splash Screen (flutter_native_splash) على مستوى النظام،
/// وبيتحدد لونه تلقائيًا حسب الوضع الفاتح/الغامق للجهاز.
///
/// الشاشة دي بقت مسؤولة بس عن عرض "وصلك في لحظة" (عربي أو إنجليزي حسب
/// لغة التطبيق الحالية) لفترة قصيرة بعد ما الـ Native Splash يختفي،
/// وبعدها بتنتقل لـ AuthGate.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  // ====== مدة ظهور شاشة "وصلك في لحظة" قبل الانتقال ======
  static const _taglineDuration = Duration(milliseconds: 1600);

  @override
  void initState() {
    super.initState();
    _runSequence();
  }

  Future<void> _runSequence() async {
    await Future.delayed(_taglineDuration);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, _, _) => const AuthGate(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ====== شاشة "وصلك في لحظة" الجاهزة، عربي أو إنجليزي ======
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: TayarColors.primary,
      body: SizedBox.expand(
        child: Image.asset(
          isArabic
              ? 'assets/splash/tagline_ar.png'
              : 'assets/splash/tagline_en.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
