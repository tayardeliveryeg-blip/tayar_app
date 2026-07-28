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

/// القيمة المخزّنة في حقل paymentMethod بالطلبات لما الراكب يدفع من
/// محفظته الإلكترونية (نص عربي ثابت زي باقي طرق الدفع - راجع
/// paymentMethodDisplay() في passenger_home.dart لعرضها متعدد اللغة) ======
const String kWalletPaymentMethodValue = 'محفظة إلكترونية';

/// ====== إنهاء الرحلة + تسوية محفظة الطيار في نفس الوقت (transaction واحدة
/// عشان نضمن إن الحالتين بيحصلوا مع بعض أو ولا واحدة).
/// - لو الدفع كاش: الطيار قبض الأجرة كاملة من الراكب يدويًا، فبنخصم نسبة
///   الشركة بس من محفظته (زي ما كان دايمًا).
/// - لو الدفع محفظة إلكترونية: الطيار مقبضش أي كاش من الراكب، فبدل خصم
///   عمولة، بنضيفله نصيبه الصافي كامل (الأجرة - العمولة) - خصم رصيد
///   الراكب نفسه بيحصل بعدين من ناحيته في deductWalletForCompletedTrip. ======
/// مستخدمة من driver_home_screen.dart و driver_trip_tracking_screen.dart
/// عشان يبقى منطق إنهاء الرحلة وتسوية المحفظة في مكان واحد بس ======
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
    final isWalletPayment =
        orderSnap.data()?['paymentMethod'] == kWalletPaymentMethodValue;

    final driverSnap = await txn.get(driverRef);
    final currentBalance =
        (driverSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;

    final commission = fare * AppSettings.instance.commissionRate;
    final walletDelta = isWalletPayment ? (fare - commission) : -commission;
    final newBalance = currentBalance + walletDelta;

    txn.update(orderRef, {
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });

    txn.set(driverRef, {
      'walletBalance': newBalance,
    }, SetOptions(merge: true));

    final ledgerRef = driverRef.collection('walletTransactions').doc();
    txn.set(ledgerRef, {
      'type': isWalletPayment ? 'trip_earning' : 'commission',
      'status': 'completed',
      'amount': walletDelta,
      'orderId': orderId,
      'fare': fare,
      'balanceAfter': newBalance,
      'createdAt': FieldValue.serverTimestamp(),
    });
  });
}

/// ====== خصم رصيد الراكب لطلب مكتمل مدفوع بمحفظته الإلكترونية + تسجيل
/// الحركة في سجل محفظته - transaction واحدة بتخصم الرصيد وتعلّم الطلب
/// walletDeducted:true مع بعض. Firestore Security Rules بتتحقق من نفس
/// الشروط دي بالظبط (شوف isValidWalletDeduction في firestore.rules) فمفيش
/// داعي نتأكد تاني هنا إن الرصيد كافي - القاعدة هترفض أي محاولة تخلي
/// الرصيد بالسالب.
///
/// آمن تتنادى أكتر من مرة على نفس الطلب (idempotent) - لو مش مدفوعة
/// بالمحفظة، أو لسه مش completed، أو اتخصمت قبل كده، الدالة مش هتعمل حاجة.
///
/// مستخدمة من trip_tracking_screen.dart بمجرد ما حالة الطلب تبقى
/// 'completed'، قبل ما نروح لشاشة تقييم الطيار. ======
Future<void> deductWalletForCompletedTrip({
  required String orderId,
  required String userId,
}) async {
  final orderRef = FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId);
  final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

  await FirebaseFirestore.instance.runTransaction((txn) async {
    final orderSnap = await txn.get(orderRef);
    final orderData = orderSnap.data();
    if (orderData == null) return;

    final isWalletPayment = orderData['paymentMethod'] == kWalletPaymentMethodValue;
    final isCompleted = orderData['status'] == 'completed';
    final alreadyDeducted = orderData['walletDeducted'] == true;
    if (!isWalletPayment || !isCompleted || alreadyDeducted) return;

    final fare = (orderData['acceptedFare'] as num?)?.toDouble() ?? 0;

    final userSnap = await txn.get(userRef);
    final currentBalance =
        (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
    final newBalance = currentBalance - fare;

    txn.update(orderRef, {'walletDeducted': true});

    txn.set(userRef, {
      'walletBalance': newBalance,
      'walletLastDeductionOrderId': orderId,
    }, SetOptions(merge: true));

    final ledgerRef = userRef.collection('walletTransactions').doc();
    txn.set(ledgerRef, {
      'type': 'trip_payment',
      'amount': -fare,
      'orderId': orderId,
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
