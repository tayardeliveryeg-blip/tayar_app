// ====== تفعيل خدمة "دعوة المكالمة" (Call Invitation) مرة واحدة لكل جلسة ======
// من غير الاستدعاء ده، المستخدم مش هيقدر يستقبل أي دعوة مكالمة (رنين) من
// حد تاني - لازم يتنادى مرة واحدة بعد تسجيل الدخول (من initState بتاع
// DriverHomeScreen و PassengerHomeScreen).
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import 'package:tayay_app/services/zego_call_config.dart';

bool _callInvitationInitialized = false;

// ====== بيرجع true لو الخدمة اتهيّأت بنجاح فعلاً (مش بس اتنادت) ======
// مفيدة للتشخيص: لو false بعد استدعاء الدالة، يبقى فيه مشكلة في init نفسه
// (appID/appSign غلط، مفيش نت، إلخ) وده اللي بيخلي زرار المكالمة "ساكت".
bool get isCallInvitationServiceReady => _callInvitationInitialized;

Future<void> setupCallInvitationService({
  required GlobalKey<NavigatorState> navigatorKey,
}) async {
  if (_callInvitationInitialized) return;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint(
      '⚠️ [CallInvitation] المستخدم لسه مش مسجل دخول وقت محاولة التهيئة - '
      'هتتأجل التهيئة، وأي محاولة مكالمة قبل كده هتفشل.',
    );
    return;
  }

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

  try {
    await ZegoUIKitPrebuiltCallInvitationService().init(
      appID: ZegoCallConfig.appId,
      appSign: ZegoCallConfig.appSign,
      userID: user.uid,
      userName: myName,
      plugins: [ZegoUIKitSignalingPlugin()],
      // ====== إعدادات إشعار المكالمة الواردة على أندرويد ======
      // showOnFullScreen: يخلي الإشعار يظهر full-screen (زي مكالمة تليفون
      // حقيقية) حتى لو الموبايل مقفول أو التطبيق في الخلفية تمامًا.
      // showOnLockedScreen: يخلي الإشعار يظهر فوق شاشة القفل.
      notificationConfig: ZegoCallInvitationNotificationConfig(
        androidNotificationConfig: ZegoCallAndroidNotificationConfig(
          showOnFullScreen: true,
          showOnLockedScreen: true,
          // channelID/channelName لازم يتطابقوا مع Push Resource ID المسجّل في
          // كونسول Zego (Project → Push Notification) عشان الرنين يشتغل والتطبيق مقفول.
          callChannel: ZegoCallAndroidNotificationChannelConfig(
            channelID: 'zegouikit_call',
            channelName: 'مكالمات طيار',
          ),
        ),
      ),
      requireConfig: (ZegoCallInvitationData data) {
        return ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall()
          ..avatarBuilder = ZegoCallConfig.avatarBuilder
          ..duration.isVisible = true;
      },
    );

    _callInvitationInitialized = true;
    debugPrint('✅ [CallInvitation] الخدمة اتهيّأت بنجاح للمستخدم ${user.uid}');
  } catch (e, st) {
    // ====== لو init فشل (appID/appSign غلط، مفيش نت وقت الفتح، إلخ) كانت
    // بتفشل بصمت تمامًا وأي محاولة مكالمة بعد كده تبقى "ساكتة" من غير أي
    // رسالة خطأ. دلوقتي بنسجّلها بوضوح في الـ console عشان يبان السبب. ======
    debugPrint('❌ [CallInvitation] فشلت تهيئة خدمة المكالمات: $e');
    debugPrint('$st');
  }
}
