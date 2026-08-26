import 'package:cloud_firestore/cloud_firestore.dart';

// ====================================================
// ====== إعدادات التطبيق القابلة للتحكم من لوحة الأدمن ======
// بتتقرا مرة واحدة من Firestore (settings/config) وقت بدء التطبيق
// وتفضل محفوظة في الذاكرة. لو حصل أي فشل في الاتصال، بترجع
// لنفس القيم الافتراضية اللي كانت متثبتة في الكود قبل كده،
// عشان التطبيق يفضل شغال حتى لو مفيش نت وقت الإقلاع.
// ====================================================
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  double baseFare = 10.0;
  double perKmRate = 5.0;
  double commissionRate = 0.10;
  double serviceRadiusKm =
      15.0; // محفوظة للمستقبل: مفيش فلترة بالمسافة مفعّلة في مطابقة الطيارين لسه
  String supportPhone = '+201064286901';
  double referralWelcomeBonus = 20.0;
  int maxScheduleAdvanceDays = 7;
  // ====== رسوم إلغاء الرحلة (تتحصل بس لو طيار كان قابل الطلب فعلاً، وبعد
  // ما مهلة الإلغاء المجاني تنتهي - راجع cancellation_reason_sheet.dart) ======
  double cancellationFeeAmount = 10.0;
  int freeCancellationWindowMinutes = 3;

  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('config')
          .get();
      final data = doc.data();
      if (data != null) {
        baseFare = (data['deliveryFee'] as num?)?.toDouble() ?? baseFare;
        perKmRate = (data['perKmRate'] as num?)?.toDouble() ?? perKmRate;
        final commissionPercent = (data['commissionPercent'] as num?)
            ?.toDouble();
        if (commissionPercent != null) commissionRate = commissionPercent / 100;
        serviceRadiusKm =
            (data['serviceRadiusKm'] as num?)?.toDouble() ?? serviceRadiusKm;
        supportPhone = (data['supportPhone'] as String?) ?? supportPhone;
        referralWelcomeBonus =
            (data['referralWelcomeBonus'] as num?)?.toDouble() ??
            referralWelcomeBonus;
        maxScheduleAdvanceDays =
            (data['maxScheduleAdvanceDays'] as num?)?.toInt() ??
            maxScheduleAdvanceDays;
        cancellationFeeAmount =
            (data['cancellationFeeAmount'] as num?)?.toDouble() ??
            cancellationFeeAmount;
        freeCancellationWindowMinutes =
            (data['freeCancellationWindowMinutes'] as num?)?.toInt() ??
            freeCancellationWindowMinutes;
      }
    } catch (_) {
      // صامت: هنفضل شغالين بالقيم الافتراضية
    }
    _loaded = true;
  }

  double estimateFare(double distanceKm) => baseFare + (perKmRate * distanceKm);
}
