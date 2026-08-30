import 'package:flutter/material.dart';

// ====== عداد رقمي متحرك (count-up) - لما القيمة تتغير، الرقم "بيعد"
// بصريًا من القيمة القديمة للجديدة بدل ما يقفز فجأة. مستخدم في أرصدة
// المحفظة وملخصات الأرباح. TweenAnimationBuilder بيتعامل تلقائيًا مع
// تغيّر القيمة أثناء الحركة (لو رصيد جديد وصل قبل ما الأنيميشن القديمة
// تخلص، بيكمل بسلاسة من مكانه الحالي للقيمة الجديدة، مش بيرجع للصفر) ======
class TayarAnimatedCounter extends StatelessWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;

  const TayarAnimatedCounter({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return Text(formatter(animatedValue), style: style);
      },
    );
  }
}
