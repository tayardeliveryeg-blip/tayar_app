import 'package:cloud_firestore/cloud_firestore.dart';

// ====================================================
// ====== منطق أكواد الخصم (promo codes): استبدال كود بمنح رصيد محفظة ======
// كل حاجة بتحصل في transaction واحدة، وFirestore Security Rules بتتحقق
// من نفس الشروط دي بالظبط (شوف isValidPromoCredit في firestore.rules)
// فمفيش داعي نتأكد تاني هنا إن الكود صالح - القواعد هترفض أي محاولة
// غلط تلقائيًا. الاستثناءات هنا بترجم رسائل الرفض دي لنص عربي واضح
// للمستخدم بدل رسالة الخطأ التقنية الافتراضية.
// ====================================================

/// ====== استثناءات مخصصة لأسباب رفض استبدال كود الخصم، عشان الواجهة تقدر
/// تعرض رسالة عربية واضحة حسب السبب بدل رسالة خطأ Firestore التقنية ======
class PromoCodeException implements Exception {
  final String message;
  PromoCodeException(this.message);
  @override
  String toString() => message;
}

/// ====== بيستبدل كود خصم بمنح رصيد لمحفظة الراكب - بيتحقق من كل الشروط
/// يدويًا هنا الأول عشان نقدر نرجّع رسالة خطأ عربية واضحة ومحددة بدل ما
/// نسيب Firestore Security Rules ترفض العملية برسالة generic غامضة.
/// القواعد نفسها بتتحقق من نفس الشروط دي تاني كطبقة حماية نهائية.
///
/// بترجع قيمة الخصم (بالجنيه) لو نجحت العملية، عشان الواجهة تقدر تعرض
/// "تم إضافة X جنيه لمحفظتك" ======
Future<double> redeemPromoCode({
  required String code,
  required String userId,
}) async {
  final normalizedCode = code.trim().toUpperCase();
  if (normalizedCode.isEmpty) {
    throw PromoCodeException('من فضلك اكتب كود الخصم');
  }

  final promoRef = FirebaseFirestore.instance
      .collection('promo_codes')
      .doc(normalizedCode);
  final userRef = FirebaseFirestore.instance.collection('users').doc(userId);
  final redeemedRef = userRef
      .collection('redeemedPromoCodes')
      .doc(normalizedCode);

  return FirebaseFirestore.instance.runTransaction((txn) async {
    final promoSnap = await txn.get(promoRef);
    if (!promoSnap.exists) {
      throw PromoCodeException('الكود ده مش موجود، اتأكد منه وحاول تاني');
    }
    final promo = promoSnap.data()!;

    if (promo['active'] != true) {
      throw PromoCodeException('الكود ده مبقاش شغال');
    }

    final maxUses = (promo['maxUses'] as num?)?.toInt() ?? 0;
    final usedCount = (promo['usedCount'] as num?)?.toInt() ?? 0;
    if (usedCount >= maxUses) {
      throw PromoCodeException('الكود ده خلصت أماكنه');
    }

    final expiresAt = promo['expiresAt'] as Timestamp?;
    if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
      throw PromoCodeException('صلاحية الكود ده انتهت');
    }

    final redeemedSnap = await txn.get(redeemedRef);
    if (redeemedSnap.exists) {
      throw PromoCodeException('انت استخدمت الكود ده قبل كده');
    }

    final discountValue = (promo['discountValue'] as num?)?.toDouble() ?? 0;
    if (discountValue <= 0) {
      throw PromoCodeException('في مشكلة في الكود ده، جرب كود تاني');
    }

    final userSnap = await txn.get(userRef);
    final currentBalance =
        (userSnap.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
    final newBalance = currentBalance + discountValue;

    txn.set(userRef, {
      'walletBalance': newBalance,
      'walletLastPromoCode': normalizedCode,
    }, SetOptions(merge: true));

    txn.set(redeemedRef, {
      'discountValue': discountValue,
      'redeemedAt': FieldValue.serverTimestamp(),
    });

    txn.update(promoRef, {'usedCount': usedCount + 1});

    final ledgerRef = userRef.collection('walletTransactions').doc();
    txn.set(ledgerRef, {
      'type': 'promo_credit',
      'amount': discountValue,
      'promoCode': normalizedCode,
      'balanceAfter': newBalance,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return discountValue;
  });
}
