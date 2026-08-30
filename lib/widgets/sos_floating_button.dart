import 'package:flutter/material.dart';

import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/sos_action_sheet.dart';

/// ====== زرار الطوارئ العائم اللي بيظهر أثناء أي رحلة شغالة (راكب أو
/// طيار) - دايمًا أحمر وواضح عشان يتلقط بسرعة وقت الحاجة. بيعمل نبضة
/// هالة خفيفة حواليه باستمرار (نفس روح PulsingDot) عشان يلفت الانتباه
/// إنه موجود من غير ما يبقى مزعج بصريًا - النبضة بطيئة (2.2 ثانية)
/// وخفيفة الشفافية، مش وميض سريع ======
class SosFloatingButton extends StatefulWidget {
  final String userRole; // 'passenger' | 'driver'
  final String orderId;

  const SosFloatingButton({
    super.key,
    required this.userRole,
    required this.orderId,
  });

  @override
  State<SosFloatingButton> createState() => _SosFloatingButtonState();
}

class _SosFloatingButtonState extends State<SosFloatingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showSosActionSheet(
        context,
        userRole: widget.userRole,
        orderId: widget.orderId,
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value; // 0 -> 1 بشكل متكرر
          return SizedBox(
            width: 66,
            height: 66,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ====== الهالة المتوسّعة والمتلاشية حوالين الزرار ======
                Opacity(
                  opacity: (1 - t) * 0.35,
                  child: Container(
                    width: 44 + (22 * t),
                    height: 44 + (22 * t),
                    decoration: BoxDecoration(
                      color: TayarColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                child!,
              ],
            ),
          );
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: TayarColors.error.withValues(alpha: 0.95),
            shape: BoxShape.circle,
            boxShadow: AppShadows.floating(context),
          ),
          child: const Icon(Icons.warning_rounded, color: Colors.white),
        ),
      ),
    );
  }
}
