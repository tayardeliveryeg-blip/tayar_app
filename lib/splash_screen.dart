import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'main.dart' show AuthGate;
import 'passenger_home.dart' show TayarColors;

/// ====== شاشة السبلاش: مرحلتين ======
/// المرحلة 1: نفس تصميم "وصلك في لحظة" (صورة جاهزة بالكامل) - بتتحدد
/// تلقائيًا عربي أو إنجليزي حسب لغة التطبيق الحالية.
/// المرحلة 2: نفس أنيميشن المربع البرتقالي الأصلي - شعار الموتوسيكل
/// بيدخل من برا الشاشة (الشمال) لجوه المربع بحركة فيها ارتداد بسيط،
/// مصحوبة بصوت محرك موتوسيكل، وبعدين اسم TAYAR بيفضح تحت المربع.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ====== مدة ظهور شاشة "وصلك في لحظة" قبل ما تنتقل للأنيميشن ======
  static const _taglineDuration = Duration(milliseconds: 1600);

  // ====== المرحلة 2: نفس أنيميشن المربع البرتقالي الأصلي بالظبط ======
  late final AnimationController _controller;
  late final Animation<double> _boxScale;
  late final Animation<double> _boxOpacity;
  late final Animation<double> _motoProgress;
  late final Animation<double> _motoOpacity;
  late final Animation<double> _titleOpacity;

  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _showLogoStage = false;

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

    // ====== دخول الموتوسيكل من برا الشاشة مع ارتداد بسيط ======
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

    _runSequence();
  }

  Future<void> _runSequence() async {
    // ====== المرحلة 1: شاشة "وصلك في لحظة" ======
    await Future.delayed(_taglineDuration);
    if (!mounted) return;
    setState(() => _showLogoStage = true);

    // ====== المرحلة 2: صوت محرك الموتوسيكل بالتزامن مع دخوله للمربع ======
    _sfxPlayer.play(AssetSource('sounds/splash_moto.wav'), volume: 0.7);
    _controller.forward();

    await Future.delayed(const Duration(milliseconds: 2400));
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
  void dispose() {
    _controller.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ====== المرحلة 1: صورة "وصلك في لحظة" الجاهزة، عربي أو إنجليزي ======
    if (!_showLogoStage) {
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

    // ====== المرحلة 2: المربع البرتقالي الأصلي + دخول الموتوسيكل ======
    final screenWidth = MediaQuery.of(context).size.width;
    const boxSize = 150.0;
    final travelDistance = (screenWidth / 2) + boxSize;

    return Scaffold(
      backgroundColor: TayarColors.background,
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
                        // قيمة خاصة بصندوق اللوجو في splash فقط، مش من AppRadius scale العام
                        borderRadius: BorderRadius.circular(34),
                        boxShadow: [
                          BoxShadow(
                            color: TayarColors.primary.withValues(
                              alpha: 0.35,
                            ),
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
                  child: const Text(
                    'TAYAR',
                    style: TextStyle(
                      color: Colors.white,
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
