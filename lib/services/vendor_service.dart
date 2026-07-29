import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';

// ====================================================
// ====== منطق طلبات انضمام "الشركاء التجاريين" (محلات/مطاعم/صيدليات) ======
// أي مستخدم مسجّل دخول يقدر يبعت طلب واحد من فورم "عايز تبقى شريك تجاري
// معانا؟"، وبيتخزن في vendor_applications بحالة 'pending' لحد ما الأدمن
// يراجعه من تاب "Vendor Requests" في لوحة التحكم (تايار-أدمن).
// الحقول والقيم المسموحة هنا لازم تطابق بالظبط isValidVendorApplication
// في firestore.rules، وإلا الكتابة هترفض من السيرفر.
// ====================================================

/// ====== أنواع النشاط التجاري المسموح بيها في الفورم - نفس القيم بالظبط
/// الموجودة في isValidVendorApplication() بملف firestore.rules ======
const List<String> kVendorBusinessTypes = [
  'مطعم',
  'سوبر ماركت',
  'صيدلية',
  'أخرى',
];

/// ====== بترسل طلب انضمام تاجر جديد (vendor_applications) ======
/// - [storeName]: اسم المحل، من 1 لـ 100 حرف.
/// - [businessType]: لازم تكون واحدة من [kVendorBusinessTypes] بالظبط.
/// - [contactPhone]: رقم موبايل/واتساب، من 1 لـ 20 حرف.
/// - [location]: الموقع اللي المستخدم اختاره (من البحث أو من الخريطة عبر
///   pick_on_map_screen.dart).
/// - [note]: ملاحظة اختيارية، لغاية 300 حرف.
///
/// الحالة بتتبعت دايمًا 'pending' - محدش غير الأدمن يقدر يغيرها بعد كده
/// (شوف allow update في vendor_applications بالـ rules).
///
/// مستخدمة من شاشة الفورم نفسها (خطوة 3) بمجرد ما المستخدم يدوس "إرسال".
Future<void> submitVendorApplication({
  required String storeName,
  required String businessType,
  required String contactPhone,
  required LatLng location,
  String? note,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('لازم تسجل دخول الأول عشان تبعت طلب انضمام.');
  }

  final trimmedNote = note?.trim();

  await FirebaseFirestore.instance.collection('vendor_applications').add({
    'submittedByUserId': user.uid,
    'storeName': storeName.trim(),
    'businessType': businessType,
    'contactPhone': contactPhone.trim(),
    'location': {
      'lat': location.latitude,
      'lon': location.longitude,
    },
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
    if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
  });
}
