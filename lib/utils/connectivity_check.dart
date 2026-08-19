import 'package:connectivity_plus/connectivity_plus.dart';

// ====================================================
// ====== فحص سريع لحالة الاتصال قبل أي عملية محتاجة إنترنت ======
// (تنقل لشاشة تانية، طلب بيانات، إلخ). بيتفرق عن NoInternetBanner اللي
// بيراقب الاتصال لايف بشكل مستمر - ده فحص لحظي بيتنده قبل أي زرار
// حساس، عشان نمنع فتح شاشة هتفشل في التحميل من الأساس. لو الفحص نفسه
// فشل (استثناء غير متوقع)، بيرجع true عشان منمنعش المستخدم من حاجة
// بسبب خطأ في الفحص نفسه مش قطع اتصال فعلي ======
// ====================================================
Future<bool> hasInternetConnection() async {
  try {
    final results = await Connectivity().checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  } catch (_) {
    return true;
  }
}
