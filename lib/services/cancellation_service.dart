import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tayay_app/services/wallet_service.dart';
import 'package:tayay_app/theme/app_settings.dart';

/// ====== نتيجة حساب رسوم الإلغاء قبل ما نعرض بوتوم شيت الأسباب للمستخدم ======
class CancellationFeeQuote {
  final double amount;
  const CancellationFeeQuote(this.amount);
  bool get hasFee => amount > 0;
}

/// ====== بتحسب هل الإلغاء دلوقتي هيترتب عليه رسوم ولا لأ، حسب مهلة
/// الإلغاء المجاني في إعدادات الأدمن. الرسوم بتتحصل بس لو:
/// - سائق قابل الطلب فعلاً (status == 'accepted' - قبل كده يعني لسه
///   'searching' ومفيش سائق التزم، فالإلغاء فاضل مجاني زي ما كان دايمًا)
/// - وعدى على وقت القبول (acceptedAt) أكتر من freeCancellationWindowMinutes ======
CancellationFeeQuote quoteCancellationFee({
  required String status,
  DateTime? acceptedAt,
}) {
  if (status != 'accepted' || acceptedAt == null) {
    return const CancellationFeeQuote(0);
  }
  final settings = AppSettings.instance;
  final elapsedMinutes = DateTime.now().difference(acceptedAt).inMinutes;
  if (elapsedMinutes < settings.freeCancellationWindowMinutes) {
    return const CancellationFeeQuote(0);
  }
  return CancellationFeeQuote(settings.cancellationFeeAmount);
}

/// ====== بتنفذ إلغاء الراكب لطلبه فعليًا: بتكتب status/cancellationReason/
/// cancelledBy/cancellationFee/cancelledAt على الطلب في خطوة واحدة، وبعدين
/// (لو الرسوم أكبر من صفر ومدفوع بالمحفظة الإلكترونية) بتسوي خصم الرسوم
/// فورًا في خطوة منفصلة (راجع settleCancellationFee في wallet_service.dart
/// لسبب الفصل - firestore.rules محتاجة الطلب يبقى 'cancelled' فعلاً أول
/// قبل ما تسمح بخصم الرسوم من المحفظة). لو الدفع كاش، الرسوم بتتسجل على
/// الطلب بس للمرجعية الإدارية من غير خصم تلقائي (مفيش وسيلة تحصيل آلي). ======
Future<void> cancelOrderAsCustomer({
  required String orderId,
  required String userId,
  required String reasonCode,
  required double feeAmount,
}) async {
  final orderRef = FirebaseFirestore.instance
      .collection('orders')
      .doc(orderId);
  await orderRef.update({
    'status': 'cancelled',
    'cancellationReason': reasonCode,
    'cancelledBy': 'customer',
    'cancellationFee': feeAmount,
    'cancelledAt': FieldValue.serverTimestamp(),
  });
  if (feeAmount > 0) {
    await settleCancellationFee(orderId: orderId, userId: userId);
  }
}
