import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ====== زرار أساسي موحّد: نفس شكل ElevatedButton القياسي بتاع الثيم
// (elevatedButtonTheme في theme_extensions.dart) + اهتزاز لمسي خفيف وتأثير
// تصغير بسيط عند الضغط، بدل ما نضيف السلوك ده يدويًا في كل شاشة عندها
// زرار أساسي. الاستخدام: AppPrimaryButton(onPressed: ..., child: ...)
// بدل ElevatedButton العادي — نفس الـ API تقريبًا عشان الاستبدال يبقى سهل.
class AppPrimaryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
  });

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Listener(
        onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onPointerUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onPointerCancel: enabled
            ? (_) => setState(() => _pressed = false)
            : null,
        child: ElevatedButton(
          onPressed: enabled
              ? () {
                  HapticFeedback.mediumImpact();
                  widget.onPressed!();
                }
              : null,
          style: widget.style,
          child: widget.child,
        ),
      ),
    );
  }
}
