import 'package:cloud_firestore/cloud_firestore.dart';

// ====================================================
// ====== ربط سجل الطيار المُضاف يدويًا من لوحة التحكم ======
// (Firestore doc بـ ID عشوائي عن طريق زرار "+ Add driver") بحساب
// الطيار الحقيقي (drivers/{uid}) بعد أول تسجيل دخول، عن طريق
// مطابقة رقم الموبايل. لو لقينا تطابق، بنرحّل كل بيانات السجل
// القديم (اسم، موتوسيكل، إلخ) للمستند الصحيح ونمسح القديم —
// بدل ما يفضل سجل يتيم متربطش بـ UID حقيقي أبدًا. ======
// ====================================================

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
/// المستخدم فين (شاشة تسجيل السائق / الرئيسية) من غير ما يعمل قراءة تانية.
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

  final firestore = FirebaseFirestore.instance;
  final driversRef = firestore.collection('drivers');

  try {
    final query = await driversRef
        .where('phoneNormalized', isEqualTo: normalized)
        .where('isPreInvited', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return const DriverLinkResult(linked: false);

    final oldDoc = query.docs.first;

    // ====== نادرًا ما يحصل (لو الأدمن كتب نفس الـ UID غلط)، بس لو حصل
    // منضربش batch؛ نظف الفلاج بس ======
    if (oldDoc.id == uid) {
      await oldDoc.reference.update({
        'isPreInvited': false,
        'linkedFromPreInvite': true,
      });
      return DriverLinkResult(linked: true, driverData: oldDoc.data());
    }

    final mergedData = Map<String, dynamic>.from(oldDoc.data());
    mergedData.remove('isPreInvited');
    mergedData['linkedFromPreInvite'] = true;
    mergedData['linkedAt'] = FieldValue.serverTimestamp();

    final batch = firestore.batch();
    batch.set(driversRef.doc(uid), mergedData, SetOptions(merge: true));
    batch.delete(oldDoc.reference);
    await batch.commit();

    return DriverLinkResult(linked: true, driverData: mergedData);
  } catch (e) {
    // ====== لو حصل أي خطأ (مثلاً صلاحيات) منوقفش تسجيل الدخول عشان كده،
    // السائق هيكمل تسجيل عادي وهيتعامل معاه كأنه مستخدم جديد ======
    return const DriverLinkResult(linked: false);
  }
}
