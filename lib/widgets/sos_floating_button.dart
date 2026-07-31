import 'package:flutter/material.dart';

import 'package:tayay_app/widgets/sos_action_sheet.dart';

/// ====== زرار الطوارئ العائم اللي بيظهر أثناء أي رحلة شغالة (راكب أو
/// طيار) - دايمًا أحمر وواضح عشان يتلقط بسرعة وقت الحاجة ======
class SosFloatingButton extends StatelessWidget {
  final String userRole; // 'passenger' | 'driver'
  final String orderId;

  const SosFloatingButton({
    super.key,
    required this.userRole,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showSosActionSheet(
        context,
        userRole: userRole,
        orderId: orderId,
      ),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.95),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Icon(Icons.warning_rounded, color: Colors.white),
      ),
    );
  }
}
