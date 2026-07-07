/// ====== إعدادات ZegoCloud لخدمة المكالمات الصوتية داخل التطبيق ======
/// لازم تستبدل القيمتين دول ببيانات مشروعك من ZegoCloud Admin Console:
/// https://console.zegocloud.com  →  Projects  →  (اختار مشروعك) → App ID / App Sign
///
/// ملاحظة: القيم دي حساسة زي أي مفتاح API، فيفضل مع الوقت نقلها لمتغيرات
/// بيئة (environment variables) بدل ما تفضل ثابتة جوه الكود لو التطبيق
/// هيتفتح كـ open source في أي وقت.
class ZegoCallConfig {
  static const int appId = 0; // ضيف الـ App ID بتاعك هنا (رقم)
  static const String appSign = ''; // ضيف الـ App Sign بتاعك هنا (نص)
}
