import 'package:flutter/material.dart';

// ====== نقطة نابضة (Pulsing Dot) موحّدة لأي حالة "شغال دلوقتي / live"
// في التطبيق (زي حالة الطيار "متاح"، أو أي مؤشر اتصال مباشر مستقبلي).
// بدل ما كل شاشة ترسم دائرة ثابتة، الـ widget ده بيدّي إحساس إن الحالة
// نشطة فعليًا. أي تعديل مستقبلي على شكل النبضة (سرعتها، حجمها) بيحصل هنا
// بس وينعكس على كل الأماكن اللي بتستخدمه.
// الاستخدام: PulsingDot(color: TayarColors.primary)
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({super.key, required this.color, this.size = 10});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final double t = _controller.value; // 0 -> 1 -> 0
        return SizedBox(
          width: widget.size * 2.6,
          height: widget.size * 2.6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ====== الهالة المتوسّعة والمتلاشية حوالين النقطة الثابتة ======
              Opacity(
                opacity: (1 - t) * 0.45,
                child: Container(
                  width: widget.size + (widget.size * 1.6 * t),
                  height: widget.size + (widget.size * 1.6 * t),
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // ====== النقطة الثابتة في النص ======
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
