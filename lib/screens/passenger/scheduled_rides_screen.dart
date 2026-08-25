import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/screens/driver/driver_home_widgets/order_request_card.dart'
    show formatScheduledForDisplay;
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/cancellation_reason_sheet.dart';
import 'package:tayay_app/services/cancellation_service.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';

// ====================================================
// ====== شاشة "الرحلات المجدولة": بتعرض بس رحلات الراكب المحجوزة
// مقدمًا (orderType == 'scheduled') واللي لسه مستنية (searching) أو
// اتقبلت من سائق (accepted) بس لسه ما بدأتش فعليًا. بتديله خيار
// إلغاء أي رحلة منهم قبل ميعادها. الرحلات المكتملة/الملغاة أصلاً
// موجودة في سجل الطلبات العادي (order_history_screen.dart) —
// الشاشة دي مخصصة بس للـ "جاية قدام" ======
// ====================================================
class ScheduledRidesScreen extends StatelessWidget {
  const ScheduledRidesScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      FirebaseFirestore.instance.collection('orders');

  String _statusLabel(String? status, AppLocalizations l10n) {
    switch (status) {
      case 'searching':
        return l10n.orderStatusSearchingLabel;
      case 'accepted':
        return l10n.orderStatusAcceptedLabel;
      default:
        return status ?? '';
    }
  }

  Future<void> _cancelRide(
    BuildContext context,
    String orderId, {
    required String status,
    DateTime? acceptedAt,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final quote = quoteCancellationFee(status: status, acceptedAt: acceptedAt);
    final reasonCode = await showCancellationReasonSheet(
      context,
      actor: CancellationActor.customer,
      feeAmount: quote.amount,
    );
    if (reasonCode == null || !context.mounted) return;

    final loc = AppLocalizations.of(context)!;
    try {
      await cancelOrderAsCustomer(
        orderId: orderId,
        userId: uid,
        reasonCode: reasonCode,
        feeAmount: quote.amount,
      );
      if (!context.mounted) return;
      TayarToast.show(
        context,
        quote.hasFee
            ? loc.cancellationFeeChargedSnackbar(quote.amount.toStringAsFixed(0))
            : loc.scheduledRideCancelledSuccess,
        type: quote.hasFee ? ToastType.warning : ToastType.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      TayarToast.show(context, loc.genericErrorTryAgain, type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(
          l10n.myScheduledRidesLabel,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: uid == null
          ? Center(
              child: Text(
                l10n.noScheduledRidesTitle,
                style: TextStyle(color: context.textGreyColor),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // ====== فلترة على customerId بس من السيرفر (زي
              // order_history_screen.dart بالظبط) عشان نتجنب الحاجة
              // لـ composite index؛ فلترة orderType/status وترتيب
              // scheduledFor بتتم محليًا بعد الجلب ======
              stream: _ordersRef
                  .where('customerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      l10n.searchFailedTryAgainError,
                      style: TextStyle(color: context.textGreyColor),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: TayarColors.primary,
                    ),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data();
                  final orderType = data['orderType'] as String?;
                  final status = data['status'] as String?;
                  return orderType == 'scheduled' &&
                      (status == 'searching' || status == 'accepted');
                }).toList()
                  ..sort((a, b) {
                    final aTime = a.data()['scheduledFor'] as Timestamp?;
                    final bTime = b.data()['scheduledFor'] as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return aTime.compareTo(bTime); // الأقرب ميعاد أولًا
                  });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          color: context.textGreyColor,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noScheduledRidesTitle,
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.noScheduledRidesSubtitle,
                          style: TextStyle(
                            color: context.textGreyColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final status = data['status'] as String?;
                    final pickupAddress =
                        data['pickupAddress'] as String? ?? '';
                    final destinationAddress =
                        data['destinationAddress'] as String? ?? '';
                    final scheduledFor =
                        data['scheduledFor'] as Timestamp?;
                    final acceptedAt = data['acceptedAt'] as Timestamp?;
                    final fare =
                        (data['acceptedFare'] ?? data['proposedFare']) as num?;
                    final driverName = data['driverName'] as String?;

                    return AppCard(
                      padding: const EdgeInsets.all(16),
                      radius: 16,
                      border: Border.all(
                        color: TayarColors.primary.withValues(alpha: 0.15),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: TayarColors.primary.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.schedule,
                                      color: TayarColors.primary,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      scheduledFor != null
                                          ? formatScheduledForDisplay(
                                              scheduledFor.toDate(),
                                            )
                                          : '',
                                      style: const TextStyle(
                                        color: TayarColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _statusLabel(status, l10n),
                                style: TextStyle(
                                  color: context.textGreyColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.trip_origin,
                                color: Colors.green,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  pickupAddress,
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.flag,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  destinationAddress,
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (driverName != null)
                                Expanded(
                                  child: Text(
                                    driverName,
                                    style: TextStyle(
                                      color: context.textGreyColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              if (fare != null) ...[
                                const Spacer(),
                                Text(
                                  l10n.fareAmountEgpLabel(
                                    fare.toStringAsFixed(0),
                                  ),
                                  style: const TextStyle(
                                    color: TayarColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => _cancelRide(
                                context,
                                doc.id,
                                status: status ?? '',
                                acceptedAt: acceptedAt?.toDate(),
                              ),
                              icon: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                              label: Text(
                                l10n.cancelOrderButton,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Colors.redAccent,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
