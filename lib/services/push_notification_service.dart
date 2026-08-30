// ====== خدمة إشعارات الدفع (Push Notifications) عن طريق Firebase Cloud
// Messaging ======
// المسؤوليات:
// 1) تسجيل الـ FCM Token بتاع الجهاز في مستند المستخدم في Firestore
//    (drivers/{uid} أو users/{uid} حسب نوع الحساب) عشان Supabase Edge
//    Functions (chat-notify/general-notify في supabase/functions/) تعرف
//    تبعتله إشعار.
// 2) عرض إشعار محلي (system notification) لما رسالة توصل والتطبيق فاتح
//    في الـ foreground (FCM لوحدها ما بتعرضش إشعار في الـ foreground).
// 3) التعامل مع الضغط على الإشعار وفتح المحادثة المناسبة.
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tayay_app/main.dart' show navigatorKey;
import 'package:tayay_app/screens/passenger/trip_chat_screen.dart';
import 'package:tayay_app/utils/tayar_page_route.dart';

/// ====== لازم تكون top-level function (أو static) عشان FCM يقدر يستدعيها
/// وقت وصول إشعار والتطبيق مقفول/في الخلفية تمامًا ======
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ====== مفيش حاجة إضافية مطلوبة هنا فعليًا: النظام بيعرض الإشعار من
  // تلقاء نفسه من الـ "notification" payload لما يجيله وهو مقفول، بس
  // سيبنا الدالة موجودة عشان الـ FCM registration نفسه يشتغل صح ======
}

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'tayar_chat_channel',
    'رسائل الرحلة',
    description: 'إشعارات رسائل الشات بين الراكب والطيار',
    importance: Importance.high,
  );

  bool _initialized = false;

  Future<void> init({required bool isDriver}) async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // ====== طلب إذن الإشعارات (لازم على iOS، ومستحسن على أندرويد 13+) ======
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // ====== إعداد الإشعار المحلي (لعرضه لما التطبيق يكون فاتح) ======
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // ====== حفظ التوكن الحالي + الاستماع لأي تحديث ليه لاحقًا ======
    final token = await messaging.getToken();
    if (token != null) await _saveToken(token, isDriver: isDriver);
    messaging.onTokenRefresh.listen((t) => _saveToken(t, isDriver: isDriver));

    // ====== التطبيق فاتح (foreground): نعرض إشعار محلي بأنفسنا ======
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // ====== المستخدم ضغط على الإشعار والتطبيق كان في الخلفية ======
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // ====== التطبيق كان مقفول تمامًا وانفتح بالضغط على إشعار ======
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);
  }

  Future<void> _saveToken(String token, {required bool isDriver}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final collection = isDriver ? 'drivers' : 'users';
    await FirebaseFirestore.instance.collection(collection).doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload == null) return;
    final data = jsonDecode(response.payload!) as Map<String, dynamic>;
    _openChatFromData(data);
  }

  void _handleNotificationTap(RemoteMessage message) {
    _openChatFromData(message.data);
  }

  void _openChatFromData(Map<String, dynamic> data) {
    if (data['type'] != 'chat') return;
    final orderId = data['orderId'] as String?;
    final otherPartyName = data['senderName'] as String? ?? '';
    if (orderId == null) return;
    navigatorKey.currentState?.push(
      TayarPageRoute(
        builder: (_) =>
            TripChatScreen(orderId: orderId, otherPartyName: otherPartyName),
      ),
    );
  }
}

/// ====== ستريم بسيط بيرجع true لو عند المستخدم الحالي أي إشعار لسه مش
/// مقروء - مستخدم لعرض شارة (badge) صغيرة فوق أيقونة الإشعارات في الشاشة
/// الرئيسية والقايمة الجانبية، من غير ما نحتاج نجيب كل الإشعارات هناك.
/// بيرجع false على طول لو مفيش مستخدم مسجّل دخول ======
Stream<bool> hasUnreadNotificationsStream() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(false);
  return FirebaseFirestore.instance
      .collection('notifications')
      .where('userId', isEqualTo: uid)
      .where('isRead', isEqualTo: false)
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isNotEmpty);
}
