import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tayay_app/theme/app_settings.dart';

// ====================================================
// ====== منطق محفظة الطيار: نسبة الشركة بتتخصم تلقائي ======
// من رصيد محفظة الطيار كل ما رحلة تخلص (الطيار بياخد الكاش
// كامل من الراكب مباشرة، فالمحفظة بتتبع اللي هو مديون بيه
// للشركة). الرصيد ممكن يبقى بالسالب لو الطيار متأخر عن الشحن ======
// ====================================================

/// نسبة عمولة الشركة من كل رحلة — القيمة الافتراضية (10%)، بتتغير فعليًا
/// من خلال إعدادات لوحة الأدمن (AppSettings.instance.commissionRate)
const double kDriverCommissionRate = 0.10;

/// ====== إنهاء الرحلة + خصم نسبة الشركة من محفظة الطيار في نفس الوقت ======
/// (transaction واحدة عشان نضمن إن الحالتين بيحصلوا مع بعض أو ولا واحدة).
/// مستخدمة من driver_home_screen.dart و driver_trip_tracking_screen.dart
/// عشان يبقى منطق إنهاء الرحلة وخصم العمولة في مكان واحد بس ======
Future<void> completeTripAndDeductCommission({
  required String orderId,
  required String driverId,
}) async {
  final orderRef = FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId);
  final driverRef = FirebaseFirestore.instance
      .collection('drivers')
      .doc(driverId);

  await FirebaseFirestore.instance.runTransaction((txn) async {
    final orderSnap = await txn.get(orderRef);
    final fare = (orderSnap.data()?['acceptedFare'] as num?)?.toDouble() ?? 0;
    final commission = fare * AppSettings.instance.commissionRate;

    final driverSnap = await txn.get(driverRef);
    final currentBalance =
        (driverSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
    final newBalance = currentBalance - commission;

    txn.update(orderRef, {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });

    txn.set(driverRef, {
      'walletBalance': newBalance,
    }, SetOptions(merge: true));

    final ledgerRef = driverRef.collection('walletTransactions').doc();
    txn.set(ledgerRef, {
      'type': 'commission',
      'status': 'completed',
      'amount': -commission,
      'orderId': orderId,
      'fare': fare,
      'balanceAfter': newBalance,
      'createdAt': FieldValue.serverTimestamp(),
    });
  });
}

/// ====== تسجيل طلب شحن رصيد جديد من الطيار (في انتظار المراجعة اليدوية) ======
/// الطلب بيتحفظ بحالة 'pending' وميأثرش على الرصيد إلا لما يتراجع ويتوافق
/// عليه يدويًا من Firebase Console حاليًا (لحد ما تتعمل شاشة الأدمن) ======
Future<void> submitWalletTopupRequest({
  required String driverId,
  required double amount,
  required String proofBase64,
}) async {
  final driverRef = FirebaseFirestore.instance
      .collection('drivers')
      .doc(driverId);
  await driverRef.collection('walletTransactions').add({
    'type': 'topup_request',
    'status': 'pending',
    'amount': amount,
    'proofBase64': proofBase64,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
