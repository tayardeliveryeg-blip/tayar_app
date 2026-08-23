import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

// ====================================================
// ====== منطق محفظة الطيار: نسبة الشركة بتتخصم تلقائي ======
// من رصيد محفظة الطيار كل ما رحلة تخلص (الطيار بياخد الكاش
// كامل من الراكب مباشرة، فالمحفظة بتتبع اللي هو مديون بيه
// للشركة). الرصيد ممكن يبقى بالسالب لو الطيار متأخر عن الشحن ======
// ====================================================

/// القيمة المخزّنة في حقل paymentMethod بالطلبات لما الراكب يدفع من
/// محفظته الإلكترونية (نص عربي ثابت زي باقي طرق الدفع - راجع
/// paymentMethodDisplay() في passenger_home.dart لعرضها متعدد اللغة) ======
const String kWalletPaymentMethodValue = 'محفظة إلكترونية';

// ====== نفس بيانات Supabase المستخدمة في sos_service.dart - Edge
// Functions بتاعتنا كلها على نفس المشروع ======
const String _kSupabaseUrl = 'https://pctxhemhytzaufdzuhfz.supabase.co';
const String _kSupabaseAnonKey =
    'sb_publishable_ltwC2X3e-F6nkAiPxszdlQ_x7xTNUC3';

/// ====== استثناء عام لأي خطأ من إنهاء الرحلة - رسالة عربية واضحة تتعرض
/// مباشرة للطيار (نفس فكرة WalletTopupException) ======
class CompleteTripException implements Exception {
  final String message;
  CompleteTripException(this.message);
  @override
  String toString() => message;
}

/// ====== إنهاء الرحلة + تسوية محفظة الطيار.
/// - لو الدفع كاش: الطيار قبض الأجرة كاملة من الراكب يدويًا، فبنخصم نسبة
///   الشركة بس من محفظته (زي ما كان دايمًا).
/// - لو الدفع محفظة إلكترونية: الطيار مقبضش أي كاش من الراكب، فبدل خصم
///   عمولة، بنضيفله نصيبه الصافي كامل (الأجرة - العمولة) - خصم رصيد
///   الراكب نفسه بيحصل بعدين من ناحيته في deductWalletForCompletedTrip.
///
/// ====== الحساب بقى بالكامل على السيرفر (Supabase Edge Function:
/// complete-trip) بدل ما يتنفذ من جهاز الطيار نفسه زي الأول. السبب:
/// firestore.rules كانت مضطرة تسيب drivers/{uid}.walletBalance مفتوح
/// قدام الطيار نفسه عشان الجهاز كان بيكتبه مباشرة بعد كل رحلة - وده كان
/// معناه أي طيار بمعرفة تقنية بسيطة يقدر يغيّر رصيد محفظته لأي رقم يحبه
/// من غير ما يمر على أي رحلة أو عمولة أصلًا. الدالة دلوقتي بس بتنادي
/// السيرفر وتسيبه هو يتأكد من كل حاجة (صاحب الرحلة فعلًا، الرحلة شغالة
/// فعلًا، نسبة العمولة الحقيقية من settings/config) - راجع
/// supabase/functions/complete-trip/index.ts للتفاصيل.
///
/// مستخدمة من driver_home_screen.dart و driver_trip_tracking_screen.dart
/// عشان يبقى منطق إنهاء الرحلة وتسوية المحفظة في مكان واحد بس.
///
/// ====== ملحوظة: مفيش داعي نبعت driverId - السيرفر بياخده من التوكن
/// الموثوق نفسه (X-Firebase-Id-Token)، مش من أي قيمة يبعتها الجهاز.
/// حتى لو كان فيه قيمة متبعتة، مكانش المفروض نوثق فيها أصلًا. ======
Future<void> completeTripAndDeductCommission({required String orderId}) async {
  final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (idToken == null) {
    throw CompleteTripException('لازم تكون مسجل دخول عشان تنهي الرحلة');
  }

  late final http.Response res;
  try {
    res = await http
        .post(
          Uri.parse('$_kSupabaseUrl/functions/v1/complete-trip'),
          headers: {
            'apikey': _kSupabaseAnonKey,
            'Authorization': 'Bearer $_kSupabaseAnonKey',
            'X-Firebase-Id-Token': idToken,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'orderId': orderId}),
        )
        .timeout(const Duration(seconds: 20));
  } catch (_) {
    throw CompleteTripException(
      'تعذر الاتصال بالسيرفر - اتأكد من اتصال النت وحاول تاني',
    );
  }

  if (res.statusCode != 200) {
    String message = 'حصل خطأ في إنهاء الرحلة، حاول تاني';
    try {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>?;
      final serverMessage = decoded?['error'] as String?;
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        message = serverMessage;
      }
    } catch (_) {
      // نسيب الرسالة العامة زي ما هي لو الرد مش JSON لأي سبب
    }
    throw CompleteTripException(message);
  }
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

/// ====== تسوية رسوم إلغاء رحلة (بعد ما الراكب يلغي رحلة كان سائق قابلها
/// بالفعل، متأخر عن مهلة الإلغاء المجاني) - بتتنادى فورًا بعد كتابة إلغاء
/// الطلب نفسه (منفصلة، مش جوه نفس الـ transaction - راجع تعليق
/// isValidCancellationFeeDeduction في firestore.rules لسبب الفصل ده، نفس
/// فكرة deductWalletForCompletedTrip بالظبط).
///
/// آمنة تتنادى أكتر من مرة على نفس الطلب (idempotent) - لو مش مدفوعة
/// بالمحفظة، أو الرسوم صفر، أو اتخصمت قبل كده، الدالة مش هتعمل حاجة.
/// بعكس خصم أجرة الرحلة العادية، هنا مسموح الرصيد يفضل بالسالب (زي محفظة
/// السائق) عشان مانمنعش الإلغاء لمجرد إن الرصيد مش كافي وقتها. ======
Future<void> settleCancellationFee({
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

    final isWalletPayment =
        orderData['paymentMethod'] == kWalletPaymentMethodValue;
    final isCancelled = orderData['status'] == 'cancelled';
    final isCustomerCancelled = orderData['cancelledBy'] == 'customer';
    final fee = (orderData['cancellationFee'] as num?)?.toDouble() ?? 0;
    final alreadyDeducted = orderData['cancellationFeeDeducted'] == true;
    if (!isWalletPayment ||
        !isCancelled ||
        !isCustomerCancelled ||
        fee <= 0 ||
        alreadyDeducted) {
      return;
    }

    final userSnap = await txn.get(userRef);
    final currentBalance =
        (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
    final newBalance = currentBalance - fee;

    txn.update(orderRef, {'cancellationFeeDeducted': true});

    txn.set(userRef, {
      'walletBalance': newBalance,
      'walletLastCancellationFeeOrderId': orderId,
    }, SetOptions(merge: true));

    final ledgerRef = userRef.collection('walletTransactions').doc();
    txn.set(ledgerRef, {
      'type': 'cancellation_fee',
      'amount': -fee,
      'orderId': orderId,
      'balanceAfter': newBalance,
      'createdAt': FieldValue.serverTimestamp(),
    });
  });
}

/// ====== بترجع رصيد محفظة الراكب الحالي (users/{uid}.walletBalance) ======
/// مستخدمة في شاشة اختيار طريقة الدفع عشان نعرف نفعّل خيار "محفظة إلكترونية"
/// من عدمه حسب كفاية الرصيد للأجرة الحالية ======
Future<double> getPassengerWalletBalance(String uid) async {
  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  return (snap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
}

/// ====== استثناء مخصص لطلب شحن الرصيد - رسالة عربية واضحة تتعرض
/// مباشرة للمستخدم (نفس فكرة PromoCodeException/ReferralException) ======
class WalletTopupException implements Exception {
  final String message;
  WalletTopupException(this.message);
  @override
  String toString() => message;
}

/// ====== حد أدنى/أقصى لمبلغ طلب الشحن الواحد - مش قيد أمني صارم (الأدمن
/// بيراجع المبلغ والإيصال يدويًا برضو قبل الموافقة)، الهدف بس حماية من
/// أخطاء كتابة زي إضافة صفر بالغلط أو رقم صغير جدًا مش هيغطي حتى مصاريف
/// المراجعة ======
const double kMinWalletTopupAmount = 20;
const double kMaxWalletTopupAmount = 5000;

/// ====== تسجيل طلب شحن رصيد جديد من الطيار (في انتظار المراجعة من لوحة
/// الأدمن - راجع tayar-admin/public/index.html، قسم Driver top-up
/// requests) ======
Future<void> submitWalletTopupRequest({
  required String driverId,
  required double amount,
  required String proofBase64,
}) async {
  if (amount < kMinWalletTopupAmount || amount > kMaxWalletTopupAmount) {
    throw WalletTopupException(
      'المبلغ لازم يكون بين ${kMinWalletTopupAmount.toStringAsFixed(0)} '
      'و ${kMaxWalletTopupAmount.toStringAsFixed(0)} جنيه',
    );
  }

  final driverRef = FirebaseFirestore.instance
      .collection('drivers')
      .doc(driverId);

  // ====== منع أكتر من طلب شحن pending واحد في نفس الوقت - عشان مايتكررش
  // نفس الطلب في قايمة مراجعة الأدمن ولا يحصل لبس مين اتراجع ومين لأ ======
  final existingPending = await driverRef
      .collection('walletTransactions')
      .where('type', isEqualTo: 'topup_request')
      .where('status', isEqualTo: 'pending')
      .limit(1)
      .get();
  if (existingPending.docs.isNotEmpty) {
    throw WalletTopupException(
      'عندك طلب شحن قيد المراجعة بالفعل - استنى نتيجته الأول قبل ما تبعت طلب جديد',
    );
  }

  await driverRef.collection('walletTransactions').add({
    'type': 'topup_request',
    'status': 'pending',
    'amount': amount,
    'proofBase64': proofBase64,
    'createdAt': FieldValue.serverTimestamp(),
  });
}
