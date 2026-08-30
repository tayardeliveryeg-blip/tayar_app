import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== لحظة احتفال بصرية خفيفة للنجاحات المهمة (وصول الرحلة، تأكيد
// الطلب، نجاح الدفع، إلخ) - أيقونة صح بتنط جوه دايرة (bounce) محاطة
// بنقط صغيرة بتتطاير للخارج وتخف تدريجيًا (fade). كله بـ Flutter
// animations الأساسية من غير أي مكتبة خارجية (confetti إلخ) عشان بيئة
// البناء هنا معندهاش وصول لـ pub.dev ======
class SuccessCelebration extends StatefulWidget {
  final String title;
  final String? subtitle;
  final Color accentColor;
  final VoidCallback? onFinished;

  const SuccessCelebration({
    super.key,
    required this.title,
    this.subtitle,
    this.accentColor = TayarColors.success,
    this.onFinished,
  });

  @override
  State<SuccessCelebration> createState() => _SuccessCelebrationState();
}

class _SuccessCelebrationState extends State<SuccessCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  // ====== 10 نقط بزوايا موزّعة حوالين الدايرة، كل واحدة بتتطاير بمسافة
  // ومدة عشوائية بسيطة عشان الحركة متبقاش شكلها آلي/متماثل بالظبط ======
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    final rnd = math.Random();
    _particles = List.generate(10, (i) {
      final angle = (i / 10) * 2 * math.pi + rnd.nextDouble() * 0.3;
      return _Particle(
        angle: angle,
        distance: 46 + rnd.nextDouble() * 22,
        delay: rnd.nextDouble() * 0.15,
      );
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) widget.onFinished?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (final p in _particles) _buildParticle(p, t),
                      _buildCheckCircle(t),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Opacity(
                  opacity: Curves.easeIn.transform(
                    ((t - 0.35) / 0.4).clamp(0.0, 1.0),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          widget.subtitle!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCheckCircle(double t) {
    // ====== منحنى elastic بيدي إحساس "نطة" حقيقية للدايرة والأيقونة
    // بدل ما تظهر بثبات - أول 60% من مدة الأنيميشن بس ======
    final scaleT = (t / 0.6).clamp(0.0, 1.0);
    final scale = Curves.elasticOut.transform(scaleT);
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.accentColor,
          boxShadow: [
            BoxShadow(
              color: widget.accentColor.withValues(alpha: 0.5),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
      ),
    );
  }

  Widget _buildParticle(_Particle p, double t) {
    final localT = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(localT);
    final dx = math.cos(p.angle) * p.distance * eased;
    final dy = math.sin(p.angle) * p.distance * eased;
    final opacity = (1 - localT).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.accentColor,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double delay;
  const _Particle({
    required this.angle,
    required this.distance,
    required this.delay,
  });
}

/// ====== طريقة الاستخدام الموصى بيها: بتفتح المكوّن فوق أي شاشة (overlay
/// شفاف من غير barrier قابل للضغط) وبتقفل نفسها تلقائيًا بعد المدة، وبترجع
/// Future بتخلص لما تقفل - استخدمها بالـ await قبل أي navigation تانية:
///
///   await showSuccessCelebration(context, title: 'وصلت بالسلامة!');
///   Navigator.pushReplacement(...);
Future<void> showSuccessCelebration(
  BuildContext context, {
  required String title,
  String? subtitle,
  Color accentColor = TayarColors.success,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) {
      return SuccessCelebration(
        title: title,
        subtitle: subtitle,
        accentColor: accentColor,
        onFinished: () => Navigator.of(context).maybePop(),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
