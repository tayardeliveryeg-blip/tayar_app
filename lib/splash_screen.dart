import 'package:flutter/material.dart';
import 'main.dart' show AuthGate;
import 'passenger_home.dart' show TayarColors, TayarThemeColors;

/// ====== شاشة السبلاش المتحركة اللي بتظهر أول ما التطبيق يفتح ======
/// المربع البرتقالي بيظهر فاضي الأول، وبعدين شعار الموتوسيكل بيدخل
/// من برا الشاشة (من الشمال) لجوه المربع بحركة ناعمة فيها ارتداد بسيط
/// في الآخر (overshoot) عشان يبان احترافي بدل ما يقف وقفة فجأة.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // ====== المربع البرتقالي: سكيل + فيد بسيط وقت الظهور ======
  late final Animation<double> _boxScale;
  late final Animation<double> _boxOpacity;

  // ====== شعار الموتوسيكل: قيمة من 1 (برا الشاشة تمامًا شمال) لـ 0 (في نص المربع) ======
  late final Animation<double> _motoProgress;
  late final Animation<double> _motoOpacity;

  // ====== اسم "طيار" بيفضح تحت المربع بعد ما الموتوسيكل يوصل ======
  late final Animation<double> _titleOpacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _boxOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
    );
    _boxScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    // ====== الحركة الأساسية: دخول الموتوسيكل من برا الشاشة مع ارتداد بسيط ======
    _motoProgress = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 0.85, curve: Curves.easeOutBack),
      ),
    );
    _motoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 0.45, curve: Curves.easeIn),
    );

    _titleOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.75, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();
    _goNext();
  }

  Future<void> _goNext() async {
    // ====== وقت كافي عشان الحركة تخلص + وقفة بسيطة قبل الانتقال ======
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const boxSize = 150.0;
    // ====== المسافة اللي الموتوسيكل بيقطعها: من برا حافة الشاشة الشمال لحد نص المربع ======
    final travelDistance = (screenWidth / 2) + boxSize;

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Opacity(
                  opacity: _boxOpacity.value,
                  child: Transform.scale(
                    scale: _boxScale.value,
                    child: Container(
                      width: boxSize,
                      height: boxSize,
                      decoration: BoxDecoration(
                        color: TayarColors.primary,
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [
                          BoxShadow(
                            color: TayarColors.primary.withValues(alpha: 0.35),
                            blurRadius: 36,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(34),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.translate(
                              offset: Offset(
                                -(_motoProgress.value * travelDistance),
                                0,
                              ),
                              child: Opacity(
                                opacity: _motoOpacity.value,
                                child: Image.asset(
                                  'assets/splash/moto_icon.png',
                                  width: 96,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Opacity(
                  opacity: _titleOpacity.value,
                  child: Text(
                    'TAYAR',
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Arial',
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
