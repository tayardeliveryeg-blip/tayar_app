import 'package:flutter/material.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart' show TayarColors;

/// ====== إعدادات ZegoCloud لخدمة المكالمات الصوتية داخل التطبيق ======
/// لازم تستبدل القيمتين دول ببيانات مشروعك من ZegoCloud Admin Console:
/// https://console.zegocloud.com  →  Projects  →  (اختار مشروعك) → App ID / App Sign
///
/// ملاحظة: القيم دي حساسة زي أي مفتاح API، فيفضل مع الوقت نقلها لمتغيرات
/// بيئة (environment variables) بدل ما تفضل ثابتة جوه الكود لو التطبيق
/// هيتفتح كـ open source في أي وقت.
class ZegoCallConfig {
  static const int appId = 1751431110;
  static const String appSign =
      'c432ac2d11a1fa4443b26c984a5de2c85ece3d034281186cdee0f835974667aa';

  /// ====== أفاتار موحّد بهوية طيار (دايرة برتقالية + أول حرف من الاسم) ======
  /// مستخدم في شاشة المكالمة المباشرة (call_screen.dart) وفي إعداد دعوة
  /// المكالمة (call_invitation_setup.dart) عشان الشكل يكون متطابق في الحالتين.
  static Widget avatarBuilder(
    BuildContext context,
    Size size,
    ZegoUIKitUser? user,
    Map extraInfo,
  ) {
    final name = user?.name.trim() ?? '';
    final initial = name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'T';
    final avatarSize = size.width < size.height ? size.width : size.height;

    return Center(
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [TayarColors.primary, Color(0xFFCC5500)],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: avatarSize / 2.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
