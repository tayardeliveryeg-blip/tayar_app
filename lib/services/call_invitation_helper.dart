// ====== إرسال دعوة مكالمة صوتية حقيقية (Call Invitation) ======
// بدل ما الطرفين يفتحوا نفس شاشة CallScreen يدويًا في نفس اللحظة (غرفة
// مشتركة من غير أي تنبيه)، الدالة دي بتستخدم ميزة ZegoCloud Call Invitation
// اللي بتبعت "رنين" حقيقي للطرف التاني، ويظهرله واجهة رد/رفض حتى لو
// التطبيق شغال في الخلفية (بعد ضبط الـ Offline Push من كونسول Zego).
//
// لازم ZegoUIKitPrebuiltCallInvitationService().init(...) يكون اتعمله
// استدعاء قبل كده مرة واحدة (بيحصل في lib/call_invitation_setup.dart).
import 'package:flutter/foundation.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:tayay_app/services/call_invitation_setup.dart' show isCallInvitationServiceReady;

Future<void> sendCallInvitation({
  required String calleeId,
  required String calleeName,
}) async {
  if (calleeId.isEmpty) {
    throw Exception(
      'معرف الطرف التاني (calleeId) فاضي - مينفعش نبعت دعوة مكالمة',
    );
  }

  // ====== لو خدمة دعوة المكالمات لسه معملهاش init بنجاح (مثلاً فشل صامت
  // في التهيئة قبل كده)، بلاش نسيب send() تعلّق من غير أي رسالة - نرمي
  // error واضح فورًا بدل ما الزرار يبقى "ساكت" ======
  if (!isCallInvitationServiceReady) {
    debugPrint(
      '❌ [CallInvitation] محاولة إرسال دعوة مكالمة وخدمة الـ init لسه '
      'مش جاهزة - راجع لوج التهيئة اللي فوق (فشلت ليه).',
    );
    throw Exception(
      'خدمة المكالمات لسه مش جاهزة - جرّب تقفل التطبيق وتفتحه تاني',
    );
  }

  try {
    await ZegoUIKitPrebuiltCallInvitationService()
        .send(
          invitees: [ZegoCallUser(calleeId, calleeName)],
          isVideoCall: false,
          // ====== لازم يتطابق بالظبط مع الـ Push Resource ID اللي اتعمل في ======
          // ====== كونسول Zego (Project → Push Notification → Customized     ======
          // ====== push resource) عشان الرنين يشتغل والتطبيق مقفول تمامًا.    ======
          resourceID: 'zegouikit_call',
        )
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            debugPrint(
              '❌ [CallInvitation] send() علّق أكتر من 15 ثانية من غير رد - '
              'على الأغلب مشكلة شبكة أو إعداد في Zego Console.',
            );
            throw Exception('تعذر إرسال دعوة المكالمة - تأكد من اتصال الإنترنت وحاول تاني');
          },
        );
    debugPrint('✅ [CallInvitation] اتبعتت دعوة مكالمة لـ $calleeId بنجاح');
  } catch (e) {
    debugPrint('❌ [CallInvitation] فشل إرسال دعوة المكالمة لـ $calleeId: $e');
    rethrow;
  }
}
