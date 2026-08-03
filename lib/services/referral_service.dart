import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tayay_app/theme/app_settings.dart';

// ====================================================
// ====== منطق نظام الإحالة (Referral): كل مستخدم عنده كود إحالة شخصي، ======
// ولما مستخدم جديد يدخل كود صحيح وقت التسجيل بياخد هدية ترحيب فورية في
// محفظته، ومكافأة صاحب الكود (المُحيل) بتتسجل في طابور مراجعة وبتتمنح
// يدويًا من الأدمن من تاب المحفظة الموجود بالفعل في لوحة التحكم - نفس
// فلسفة "كل الإدارة من لوحة الأدمن" المتّبعة في باقي التطبيق.
// ====================================================

class ReferralException implements Exception {
  final String message;
  ReferralException(this.message);
  @override
  String toString() => message;
}

const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

String _randomCode() {
  final rand = Random();
  final suffix = List.generate(
    5,
    (_) => _codeChars[rand.nextInt(_codeChars.length)],
  ).join();
  return 'TAYAR$suffix';
}

/// ====== بيرجّع كود الإحالة الشخصي بتاع المستخدم لو موجود قبل كده، أو
/// بيولّد واحد جديد ويسجّله. آمن يتنادى أكتر من مرة (idempotent) - أول
/// حاجة بيعملها إنه يقرا users/{uid}.referralCode، لو موجود بيرجّعه على
/// طول من غير أي كتابة جديدة.
///
/// توليد الكود بيحصل بمحاولات متكررة (حد أقصى 5) لحد ما نلاقي كود لسه
/// مش مستخدم - احتمال التصادم ضئيل جدًا (33^5 احتمال) فمش متوقع نحتاج
/// أكتر من محاولة واحدة عمليًا ======
Future<String> ensureReferralCode(String userId) async {
  final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
  final userSnap = await userRef.get();
  final existing = userSnap.data()?['referralCode'] as String?;
  if (existing != null && existing.isNotEmpty) return existing;

  for (var attempt = 0; attempt < 5; attempt++) {
    final code = _randomCode();
    final codeRef = FirebaseFirestore.instance
        .collection('referralCodes')
        .doc(code);
    final codeSnap = await codeRef.get();
    if (codeSnap.exists) continue;

    final batch = FirebaseFirestore.instance.batch();
    batch.set(codeRef, {
      'referrerId': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(userRef, {'referralCode': code}, SetOptions(merge: true));
    await batch.commit();
    return code;
  }
  throw ReferralException('حصلت مشكلة في توليد كود الإحالة، حاول تاني');
}

/// ====== بيستبدل كود إحالة أدخله مستخدم جديد: بيتحقق إن الكود موجود ومش
/// كود المستخدم نفسه ولسه ما استخدمش كود إحالة قبل كده، وبعدين (1) بيمنح
/// المستخدم الجديد هدية ترحيب فورية في محفظته، (2) بيسجّل طلب مكافأة
/// لصاحب الكود في طابور المراجعة عشان الأدمن يمنحها يدويًا بعدين.
///
/// المفروض تتنادى مرة واحدة بس، غالبًا وقت استكمال بيانات الراكب الجديد
/// (profile_setup_screen.dart) ======
Future<double> redeemReferralCode({
  required String code,
  required String newUserId,
}) async {
  final normalizedCode = code.trim().toUpperCase();
  if (normalizedCode.isEmpty) {
    throw ReferralException('من فضلك اكتب كود الإحالة');
  }

  final codeRef = FirebaseFirestore.instance
      .collection('referralCodes')
      .doc(normalizedCode);
  final userRef = FirebaseFirestore.instance
      .collection('users')
      .doc(newUserId);

  final bonus = AppSettings.instance.referralWelcomeBonus;

  await FirebaseFirestore.instance.runTransaction((txn) async {
    final codeSnap = await txn.get(codeRef);
    if (!codeSnap.exists) {
      throw ReferralException('كود الإحالة ده مش موجود، اتأكد منه وحاول تاني');
    }
    final referrerId = codeSnap.data()!['referrerId'] as String;
    if (referrerId == newUserId) {
      throw ReferralException('مينفعش تستخدم كود الإحالة بتاعك انت');
    }

    final userSnap = await txn.get(userRef);
    final userData = userSnap.data();
    if (userData?['referredByCode'] != null) {
      throw ReferralException('انت استخدمت كود إحالة قبل كده');
    }

    final currentBalance = (userData?['walletBalance'] as num?)?.toDouble() ?? 0;
    final newBalance = currentBalance + bonus;

    txn.set(userRef, {
      'walletBalance': newBalance,
      'referredByCode': normalizedCode,
    }, SetOptions(merge: true));

    final ledgerRef = userRef.collection('walletTransactions').doc();
    txn.set(ledgerRef, {
      'type': 'referral_welcome_credit',
      'amount': bonus,
      'referralCode': normalizedCode,
      'balanceAfter': newBalance,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final rewardRef = FirebaseFirestore.instance
        .collection('pendingReferralRewards')
        .doc();
    txn.set(rewardRef, {
      'referrerId': referrerId,
      'refereeId': newUserId,
      'referralCode': normalizedCode,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  });

  return bonus;
}
