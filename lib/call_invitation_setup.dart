// ====== تفعيل خدمة "دعوة المكالمة" (Call Invitation) مرة واحدة لكل جلسة ======
// من غير الاستدعاء ده، المستخدم مش هيقدر يستقبل أي دعوة مكالمة (رنين) من
// حد تاني - لازم يتنادى مرة واحدة بعد تسجيل الدخول (من initState بتاع
// DriverHomeScreen و PassengerHomeScreen).
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'zego_call_config.dart';

bool _callInvitationInitialized = false;

Future<void> setupCallInvitationService({
  required GlobalKey<NavigatorState> navigatorKey,
}) async {
  if (_callInvitationInitialized) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final myName = (user.displayName?.trim().isNotEmpty ?? false)
      ? user.displayName!.trim()
      : (user.phoneNumber ?? 'Tayar User');

  // ====== لازم يكون موجود عشان الـ SDK يعرف يعرض واجهة "مكالمة واردة"
  // (شاشة رد/رفض) فوق أي شاشة في التطبيق. من غيره، الـ SDK بيستقبل
  // الدعوة ويشغّل الرنين بس (لأنه جزء من الإشعار نفسه)، لكن معندوش
  // BuildContext يعرض بيه واجهة القبول/الرفض ======
  // (contextQuery اتشالت في نسخ zego_uikit_prebuilt_call الحديثة،
  // بقى بديلها إنك تسجل الـ navigatorKey قبل الـ init مباشرة)
  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

  await ZegoUIKitPrebuiltCallInvitationService().init(
    appID: ZegoCallConfig.appId,
    appSign: ZegoCallConfig.appSign,
    userID: user.uid,
    userName: myName,
    plugins: [ZegoUIKitSignalingPlugin()],
    // ====== إعدادات إشعار المكالمة الواردة على أندرويد (اسم القناة) ======
    // القيم دي لازم تتأكد إنها متطابقة مع أي إعداد Offline Push في كونسول
    // Zego (Project → Push Notification) عشان الرنين يشتغل حتى لو التطبيق
    // مقفول تمامًا. من غير ده، الرنين هيشتغل بس والتطبيق شغال (foreground
    // أو background لكن العملية لسه شغالة).
    requireConfig: (ZegoCallInvitationData data) {
      return ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();
    },
  );

  _callInvitationInitialized = true;
}
