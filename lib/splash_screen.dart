import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'main.dart' show AuthGate;
import 'passenger_home.dart' show TayarColors;

/// ====== شاشة السبلاش: مرحلتين ======
/// المرحلة 1: خلفية برتقالية كاملة الشاشة + نص "وصلك في لحظة" بالأبيض،
/// بيتحدد تلقائيًا عربي أو إنجليزي حسب لغة التطبيق الحالية.
/// المرحلة 2: نفس هوية اللوجو (خلفية برتقالية + شعار موتوسيكل أبيض)
/// بيدخل من برا الشاشة بحركة فيها ارتداد بسيط (overshoot) مع صوت
/// "زن" قصير مصاحب للحركة عشان يدي إحساس احترافي، وبعدين اسم TAYAR
/// بيفضح تحته.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ====== المرحلة 1: شاشة التاجلاين البرتقالية ======
  late final AnimationController _taglineController;
  late final Animation<double> _taglineOpacity;

  // ====== المرحلة 2: أنيميشن دخول الشعار ======
  late final AnimationController _logoController;
  late final Animation<double> _motoProgress;
  late final Animation<double> _motoOpacity;
  late final Animation<double> _titleOpacity;

  final AudioPlayer _sfxPlayer = AudioPlayer();
  bool _showLogoStage = false;

  @override
  void initState() {
    super.initState();

    // ---- المرحلة 1: التاجلاين (فيد إن -> ثبات -> فيد آوت) ----
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _taglineOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_taglineController);

    // ---- المرحلة 2: دخول شعار الموتوسيكل ----
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _motoProgress = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _motoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
    );
    _titleOpacity = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.65, 1.0, curve: Curves.easeIn),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // ====== المرحلة 1: التاجلاين البرتقالي ======
    await _taglineController.forward();
    if (!mounted) return;

    setState(() => _showLogoStage = true);

    // ====== المرحلة 2: دخول الشعار + الصوت المصاحب ======
    _sfxPlayer.play(AssetSource('sounds/splash_moto.wav'), volume: 0.6);
    await _logoController.forward();
    if (!mounted) return;

    await Future.delayed(const Duration(milliseconds: 400));
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
    _taglineController.dispose();
    _logoController.dispose();
    _sfxPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    const motoWidth = 150.0;
    final travelDistance = (screenWidth / 2) + motoWidth;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // ====== الخلفية برتقالي طول الوقت، من أول لحظة فتح للسبلاش ======
      backgroundColor: TayarColors.primary,
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // ====== المرحلة 1: نص "وصلك في لحظة" ======
            AnimatedBuilder(
              animation: _taglineController,
              builder: (context, child) {
                if (_taglineOpacity.value <= 0) return const SizedBox.shrink();
                return Opacity(
                  opacity: _taglineOpacity.value,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Text(
                      l10n.splashTagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Arial',
                      ),
                    ),
                  ),
                );
              },
            ),

            // ====== المرحلة 2: شعار الموتوسيكل + اسم TAYAR ======
            if (_showLogoStage)
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRect(
                        child: Transform.translate(
                          offset: Offset(
                            -(_motoProgress.value * travelDistance),
                            0,
                          ),
                          child: Opacity(
                            opacity: _motoOpacity.value,
                            child: Image.asset(
                              'assets/splash/moto_icon.png',
                              width: motoWidth,
                              fit: BoxFit.contain,
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
          ],
        ),
      ),
    );
  }
}
