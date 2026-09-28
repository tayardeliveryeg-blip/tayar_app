import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';

// ====================================================
// ====== غلاف بسيط حوالين Firebase Analytics: كل استدعاء fire-and-forget
// ومحاط بـ try/catch عشان أي فشل في التتبع (مفيش نت، Analytics مش
// متهيّأ...) مايكسرش أي شاشة أو عملية أساسية أبدًا. بنسجّل بس أحداث الـ
// funnel الأساسية اللي مفيش طريقة تانية نعرفها منها (التقارير الحالية
// في لوحة الأدمن بتغطي البيانات المخزنة في Firestore، مش الرحلة الكاملة
// من التسجيل للطلب للإتمام). مفيش أي بيانات شخصية (اسم/رقم/عنوان) بتتبعت -
// بس معرّفات وقيم تصنيفية ======
// ====================================================
class AnalyticsService {
  AnalyticsService._();

  static void _log(String name, [Map<String, Object>? parameters]) {
    try {
      unawaited(
        FirebaseAnalytics.instance
            .logEvent(name: name, parameters: parameters)
            .catchError((_) {}),
      );
    } catch (_) {
      // صامت عن قصد
    }
  }

  static void setUser(String? uid) {
    try {
      unawaited(
        FirebaseAnalytics.instance.setUserId(id: uid).catchError((_) {}),
      );
    } catch (_) {}
  }

  /// بعد نجاح تسجيل الدخول (جوجل/أبل): مستخدم جديد → sign_up، قديم → login
  static void authSuccess({required bool isNewUser}) =>
      _log(isNewUser ? 'sign_up' : 'login');

  /// بعد ما السيرفر يقبل إنشاء الطلب (create-order) - أول خطوة في الـ funnel
  static void orderCreated({
    required String paymentMethod,
    required bool scheduled,
    required bool autoAccept,
  }) => _log('order_created', {
    'payment_method': paymentMethod,
    'scheduled': scheduled ? 1 : 0,
    'auto_accept': autoAccept ? 1 : 0,
  });

  /// بعد إلغاء الراكب للطلب - reason هو كود السبب (مش نص حر)
  static void orderCancelled({
    required String reason,
    required bool feeCharged,
  }) => _log('order_cancelled', {
    'reason': reason,
    'fee_charged': feeCharged ? 1 : 0,
  });

  /// بعد ما complete-trip يرد 200 - آخر خطوة في الـ funnel
  static void tripCompleted() => _log('trip_completed');
}
