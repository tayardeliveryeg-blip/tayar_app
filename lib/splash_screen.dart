import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'main.dart' show AuthGate;
import 'passenger_home.dart' show TayarColors;

/// ====== شاشة السبلاش ======
/// خلفية برتقالية كاملة الشاشة طول الوقت، وعليها نص "وصلك في لحظة"
/// بالأبيض بيتحدد تلقائيًا عربي أو إنجليزي حسب لغة التطبيق الحالية.
/// النص بيدخل بحركة فيد + سكيل بسيطة مصحوبة بصوت قصير، يفضل ظاهر
/// لحظة، وبعدين بيروح على شاشة تسجيل الدخول / الهوم.
/// ملحوظة: مفيش شعار موتوسيكل ولا اسم TAYAR في الشاشة دي عمدًا.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  final AudioPlayer _sfxPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    );

    // ====== فيد إن سريع -> ثبات -> فيد آوت خفيف قبل الانتقال ======
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 20,
      ),
    ]).animate(_controller);

    _scale = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOutBack),
      ),
    );

    _runSequence();
  }

  Future<void> _runSequence() async {
    // ====== صوت قصير مصاحب للحظة ظهور النص ======
    _sfxPlayer.play(AssetSource('sounds/splash_moto.wav'), volume: 0.6);

    await _controller.forward();
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
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // ====== الخلفية برتقالي طول الوقت ======
      backgroundColor: TayarColors.primary,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Text(
                    l10n.splashTagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Arial',
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
