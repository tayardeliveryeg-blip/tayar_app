// ====== إرسال دعوة مكالمة صوتية حقيقية (Call Invitation) ======
// بدل ما الطرفين يفتحوا نفس شاشة CallScreen يدويًا في نفس اللحظة (غرفة
// مشتركة من غير أي تنبيه)، الدالة دي بتستخدم ميزة ZegoCloud Call Invitation
// اللي بتبعت "رنين" حقيقي للطرف التاني، ويظهرله واجهة رد/رفض حتى لو
// التطبيق شغال في الخلفية (بعد ضبط الـ Offline Push من كونسول Zego).
//
// لازم ZegoUIKitPrebuiltCallInvitationService().init(...) يكون اتعمله
// استدعاء قبل كده مرة واحدة (بيحصل في lib/call_invitation_setup.dart).
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

Future<void> sendCallInvitation({
  required String calleeId,
  required String calleeName,
}) async {
  if (calleeId.isEmpty) {
    throw Exception(
      'معرف الطرف التاني (calleeId) فاضي - مينفعش نبعت دعوة مكالمة',
    );
  }
  await ZegoUIKitPrebuiltCallInvitationService().send(
    invitees: [ZegoCallUser(calleeId, calleeName)],
    isVideoCall: false,
    // ====== لازم يتطابق بالظبط مع الـ Push Resource ID اللي اتعمل في ======
    // ====== كونسول Zego (Project → Push Notification → Customized     ======
    // ====== push resource) عشان الرنين يشتغل والتطبيق مقفول تمامًا.    ======
    resourceID: 'zegouikit_call',
  );
}
