import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// ====================================================
// ====== ربط سجل الطيار المُضاف يدويًا من لوحة التحكم ======
// (Firestore doc بـ ID عشوائي عن طريق زرار "+ Add driver") بحساب
// الطيار الحقيقي (drivers/{uid}) بعد أول تسجيل دخول، عن طريق
// مطابقة رقم الموبايل. لو لقينا تطابق، بنرحّل كل بيانات السجل
// القديم (اسم، موتوسيكل، إلخ) للمستند الصحيح ونمسح القديم —
// بدل ما يفضل سجل يتيم متربطش بـ UID حقيقي أبدًا.
//
// (2026-08-20) العملية دي بقت بتتم على السيرفر (Supabase Edge Function
// اسمها link-driver) بدل batch مباشر من الموبايل، لأن firestore.rules
// بترفض جزء الـ delete من العملية القديمة (isPreInvitedMatch محتاجة
// phone_number claim مش موجود تاني بعد إلغاء الـ OTP) - شوف
// supabase/functions/link-driver/index.ts للتفاصيل الكاملة. ======
// ====================================================

const String _supabaseUrl = 'https://pctxhemhytzaufdzuhfz.supabase.co';
// ====== نفس مفتاح anon العام المستخدم في sos_service.dart و
// order_confirmation_screen.dart - آمن يتضاف في كود العميل ======
const String _supabaseAnonKey = 'sb_publishable_ltwC2X3e-F6nkAiPxszdlQ_x7xTNUC3';

/// يحوّل أي شكل لرقم موبايل مصري (01xxxxxxxxx / +201xxxxxxxxx / 201xxxxxxxxx)
/// لصيغة موحّدة (آخر 10 أرقام) عشان تتقارن صح مهما اختلفت صيغة الإدخال
/// بين لوحة التحكم (نص حر) و Firebase Auth (صيغة +20 دولية).
String? normalizeEgyptPhone(String? raw) {
  if (raw == null) return null;
  final digitsOnly = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.isEmpty) return null;
  return digitsOnly.length > 10
      ? digitsOnly.substring(digitsOnly.length - 10)
      : digitsOnly;
}

/// نتيجة عملية الربط، عشان اللي بيستدعي الدالة يقدر يقرر يوجّه
/// المستخدم فين (شاشة تسجيل الطيار / الرئيسية) من غير ما يعمل قراءة تانية.
class DriverLinkResult {
  final bool linked;
  final Map<String, dynamic>? driverData;
  const DriverLinkResult({required this.linked, this.driverData});
}

/// يدور على سجل طيار مُضاف يدويًا (isPreInvited == true) بنفس رقم
/// الموبايل بتاع اليوزر الحالي، ولو لقاه: يرحّل بياناته لمستند
/// drivers/{uid} الحقيقي (merge) ويمسح السجل القديم.
/// آمنة تُستدعى في كل مرة (لو مفيش تطابق أو المستخدم راكب عادي، مبتعملش حاجة).
Future<DriverLinkResult> linkPreInvitedDriverIfNeeded({
  required String uid,
  required String? phoneNumber,
}) async {
  final normalized = normalizeEgyptPhone(phoneNumber);
  if (normalized == null || normalized.length < 9) {
    return const DriverLinkResult(linked: false);
  }

  try {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) return const DriverLinkResult(linked: false);

    final response = await http
        .post(
          Uri.parse('$_supabaseUrl/functions/v1/link-driver'),
          headers: {
            'apikey': _supabaseAnonKey,
            'Authorization': 'Bearer $_supabaseAnonKey',
            'X-Firebase-Id-Token': idToken,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'phoneNumber': phoneNumber}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) return const DriverLinkResult(linked: false);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final linked = data['linked'] == true;
    final driverData = data['driverData'] as Map<String, dynamic>?;
    return DriverLinkResult(linked: linked, driverData: driverData);
  } catch (e) {
    // ====== لو حصل أي خطأ (شبكة، تايم أوت، إلخ) منوقفش تسجيل الدخول
    // عشان كده، الطيار هيكمل تسجيل عادي وهيتعامل معاه كأنه مستخدم جديد ======
    return const DriverLinkResult(linked: false);
  }
}
