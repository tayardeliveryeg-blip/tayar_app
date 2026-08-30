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

// ====================================================
// ====== دليل الشركاء التجاريين المؤكدين (vendor_partners) - بيظهر في
// خريطة الراكب وفي شاشة "شركاؤنا التجاريين" بعد ما الأدمن يأكد الطلب
// (زرار "Confirm & Publish" في تاب Vendor Requests). كوليكشن منفصل عن
// vendor_applications عشان القراءة هنا مفتوحة لأي مستخدم مسجل دخول ======
// ====================================================

/// ====== شريك تجاري واحد ظاهر في التطبيق (بيانات عامة بس) ======
class VendorPartner {
  final String id;
  final String storeName;
  final String businessType;
  final LatLng location;

  VendorPartner({
    required this.id,
    required this.storeName,
    required this.businessType,
    required this.location,
  });

  factory VendorPartner.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final loc = data['location'] as Map<String, dynamic>? ?? {};
    return VendorPartner(
      id: id,
      storeName: (data['storeName'] as String?) ?? '',
      businessType: (data['businessType'] as String?) ?? '',
      location: LatLng(
        ((loc['lat'] as num?) ?? 0).toDouble(),
        ((loc['lon'] as num?) ?? 0).toDouble(),
      ),
    );
  }
}

/// ====== ستريم لايف بكل الشركاء التجاريين المنشورين - مستخدم في دبوس
/// الخريطة (passenger_home.dart) وشاشة "شركاؤنا التجاريين" ======
Stream<List<VendorPartner>> streamVendorPartners() {
  return FirebaseFirestore.instance
      .collection('vendor_partners')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((doc) => VendorPartner.fromDoc(doc.id, doc.data()))
            .toList(),
      );
}

/// إعادة جلب الشركاء التجاريين من السيرفر مباشرة (pull-to-refresh).
Future<void> refreshVendorPartners() async {
  await FirebaseFirestore.instance
      .collection('vendor_partners')
      .get(const GetOptions(source: Source.server));
}
