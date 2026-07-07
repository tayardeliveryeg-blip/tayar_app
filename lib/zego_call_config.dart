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
}
