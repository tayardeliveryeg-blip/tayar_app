import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// ====== خدمة زر الطوارئ (SOS) ======
/// بتسجل تنبيه فوري في مجموعة sos_alerts في Firestore بمجرد ما المستخدم
/// (راكب أو طيار) يدوس على زرار الطوارئ أثناء رحلة شغالة، مع موقعه اللحظي
/// واسمه ورقمه وبيانات الرحلة لو موجودة - عشان لوحة تحكم الأدمن تعرضه فورًا.
/// التسجيل بيحصل بغض النظر عن أي إجراء تاني (اتصال بالشرطة/الدعم/جهة
/// الطوارئ الشخصية) عشان الأدمن يبقى عارف حتى لو المستخدم قفل الشاشة بسرعة.
///
/// بالإضافة لـ Firestore (تخزين دائم + تاب SOS في لوحة الأدمن)، بنكتب
/// كمان نسخة مبسطة في Supabase (جدول sos_alerts هناك). ده مش بديل عن
/// Firestore، ده بس "جرس إنذار" إضافي: Supabase عندها Database Webhook
/// بتشتغل تلقائي عند أي إضافة وبتنادي Edge Function بتبعت Push فوري
/// للأدمن عن طريق OneSignal - بديل لـ Cloud Functions اللي محتاجة خطة
/// Blaze. لو كتابة Supabase فشلت (نت، إلخ) إحنا بنكمل عادي من غير ما
/// نوقف التنبيه الأساسي في Firestore، لأنه هو الأهم والمصدر الرسمي.
class SosService {
  SosService._();

  static final _firestore = FirebaseFirestore.instance;

  static const String _supabaseUrl =
      'https://pctxhemhytzaufdzuhfz.supabase.co';
  static const String _supabaseAnonKey =
      'sb_publishable_ltwC2X3e-F6nkAiPxszdlQ_x7xTNUC3';

  /// بيسجل تنبيه طوارئ جديد ويرجع الـ id بتاعه، أو null لو مفيش يوزر مسجل
  /// دخول. لو تعذر الوصول لموقع الجهاز (مثلاً صلاحية الموقع متبقتش) التنبيه
  /// بيتسجل برضه من غير موقع بدل ما يتضاع بالكامل - وصول التنبيه للأدمن
  /// أهم من دقة الموقع.
  static Future<String?> triggerAlert({
    required String userRole, // 'passenger' | 'driver'
    String? orderId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    GeoPoint? location;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 8));
      location = GeoPoint(position.latitude, position.longitude);
    } catch (_) {
      // نكمل من غير موقع - وصول التنبيه للأدمن أهم من دقة الموقع
    }

    final profile = await _loadUserProfile(user, userRole);

    final doc = await _firestore.collection('sos_alerts').add({
      'userId': user.uid,
      'userName': profile.name,
      'userPhone': profile.phone,
      'userRole': userRole,
      'orderId': orderId,
      'location': location,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // جرس الإنذار الفوري (Supabase -> Push) - غير حرج، فمنستناش نتيجته
    // ولا بنفشل التنبيه الأساسي لو هو اللي فشل
    _notifySupabase(
      firestoreAlertId: doc.id,
      userId: user.uid,
      userName: profile.name,
      userPhone: profile.phone,
      userRole: userRole,
      orderId: orderId,
      location: location,
    );

    return doc.id;
  }

  static Future<void> _notifySupabase({
    required String firestoreAlertId,
    required String userId,
    required String userName,
    required String userPhone,
    required String userRole,
    String? orderId,
    GeoPoint? location,
  }) async {
    try {
      await http
          .post(
            Uri.parse('$_supabaseUrl/rest/v1/sos_alerts'),
            headers: {
              'apikey': _supabaseAnonKey,
              'Authorization': 'Bearer $_supabaseAnonKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'firestore_alert_id': firestoreAlertId,
              'user_id': userId,
              'user_name': userName,
              'user_phone': userPhone,
              'user_role': userRole,
              'order_id': orderId,
              'lat': location?.latitude,
              'lng': location?.longitude,
            }),
          )
          .timeout(const Duration(seconds: 6));
    } catch (_) {
      // مش حرج - Firestore هو المصدر الرسمي، ده بس تنبيه إضافي سريع
    }
  }

  static Future<_ProfileInfo> _loadUserProfile(
    User user,
    String userRole,
  ) async {
    try {
      final collection = userRole == 'driver' ? 'drivers' : 'users';
      final snap = await _firestore.collection(collection).doc(user.uid).get();
      final personalInfo =
          snap.data()?['personalInfo'] as Map<String, dynamic>?;
      final firstName = (personalInfo?['firstName'] as String?) ?? '';
      final lastName = (personalInfo?['lastName'] as String?) ?? '';
      final name = '$firstName $lastName'.trim();
      final phone =
          (personalInfo?['phone'] as String?) ?? user.phoneNumber ?? '';
      return _ProfileInfo(
        name: name.isNotEmpty ? name : (user.displayName ?? ''),
        phone: phone,
      );
    } catch (_) {
      return _ProfileInfo(
        name: user.displayName ?? '',
        phone: user.phoneNumber ?? '',
      );
    }
  }

  /// جهة اتصال الطوارئ المحفوظة للمستخدم الحالي (لو موجودة)
  static Future<String?> getEmergencyContact(String userRole) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final collection = userRole == 'driver' ? 'drivers' : 'users';
    final snap = await _firestore.collection(collection).doc(user.uid).get();
    final phone = snap.data()?['emergencyContactPhone'] as String?;
    return (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null;
  }

  /// حفظ/تعديل جهة اتصال الطوارئ
  static Future<void> setEmergencyContact(
    String userRole,
    String phone,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final collection = userRole == 'driver' ? 'drivers' : 'users';
    await _firestore.collection(collection).doc(user.uid).set(
      {'emergencyContactPhone': phone.trim()},
      SetOptions(merge: true),
    );
  }
}

class _ProfileInfo {
  final String name;
  final String phone;
  const _ProfileInfo({required this.name, required this.phone});
}
