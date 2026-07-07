import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'zego_call_config.dart';

/// ====== شاشة مكالمة صوتية داخل التطبيق بين الراكب والطيار ======
/// بتستخدم orderId كـ callID موحّد، فلما الطرفين يفتحوا نفس الشاشة
/// بيدخلوا في نفس المكالمة تلقائيًا. مفيش أرقام تليفون بتتكشف هنا خالص.
class CallScreen extends StatelessWidget {
  final String orderId;
  final String myUserId;
  final String myUserName;

  const CallScreen({
    super.key,
    required this.orderId,
    required this.myUserId,
    required this.myUserName,
  });

  @override
  Widget build(BuildContext context) {
    if (ZegoCallConfig.appId == 0 || ZegoCallConfig.appSign.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A1816),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'لازم الأول تضيف App ID و App Sign بتوع ZegoCloud في ملف\n'
              'lib/zego_call_config.dart عشان المكالمة تشتغل.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      );
    }

    return ZegoUIKitPrebuiltCall(
      appID: ZegoCallConfig.appId,
      appSign: ZegoCallConfig.appSign,
      userID: myUserId,
      userName: myUserName,
      callID: 'trip_$orderId', // نفس الـ ID للطرفين = نفس المكالمة
      config: ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall(),
      events: ZegoUIKitPrebuiltCallEvents(
        onCallEnd: (event, defaultAction) {
          // ====== أي سبب لانتهاء المكالمة (شخص واحد فاضل، أو حد قفل): نرجع للشاشة السابقة ======
          defaultAction.call();
        },
      ),
    );
  }
}
