import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'passenger_home.dart' show TayarColors, paymentMethodDisplay;

// ====== شاشة سجل الطلبات: بتعرض كل طلبات الراكب الحالي (رحلات + توصيل) ======
// بنجيب كل حاجة من collection('orders') فلترة على customerId، وبنرتب
// النتايج محليًا (client-side) حسب createdAt عشان نتجنب الحاجة لعمل
// composite index في Firestore.
class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _ordersRef =>
      FirebaseFirestore.instance.collection('orders');

  // ====== لون وحالة كل طلب ======
  Color _statusColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.greenAccent;
      case 'cancelled':
        return Colors.redAccent;
      case 'in_progress':
      case 'accepted':
        return TayarColors.primary;
      default:
        return TayarColors.textGrey;
    }
  }

  String _statusLabel(String? status, AppLocalizations l10n) {
    switch (status) {
      case 'searching':
        return l10n.orderStatusSearchingLabel;
      case 'accepted':
        return l10n.orderStatusAcceptedLabel;
      case 'in_progress':
        return l10n.orderStatusInProgressLabel;
      case 'completed':
        return l10n.orderStatusCompletedLabel;
      case 'cancelled':
        return l10n.orderStatusCancelledLabel;
      default:
        return status ?? '';
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} - $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: TayarColors.background,
      appBar: AppBar(
        backgroundColor: TayarColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          l10n.orderHistoryLabel,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: uid == null
          ? Center(
              child: Text(
                l10n.noOrdersYetTitle,
                style: const TextStyle(color: TayarColors.textGrey),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _ordersRef
                  .where('customerId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      l10n.searchFailedTryAgainError,
                      style: const TextStyle(color: TayarColors.textGrey),
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

                final docs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aTime = a.data()['createdAt'] as Timestamp?;
                    final bTime = b.data()['createdAt'] as Timestamp?;
                    if (aTime == null || bTime == null) return 0;
                    return bTime.compareTo(aTime); // الأحدث أولًا
                  });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.history,
                          color: TayarColors.textGrey,
                          size: 56,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noOrdersYetTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.noOrdersYetSubtitle,
                          style: const TextStyle(
                            color: TayarColors.textGrey,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final serviceType = data['serviceType'] as String?;
                    final isDelivery = serviceType == 'delivery';
                    final status = data['status'] as String?;
                    final destinationAddress =
                        data['destinationAddress'] as String? ?? '';
                    final fare =
                        (data['acceptedFare'] ?? data['proposedFare']) as num?;
                    final paymentMethod = data['paymentMethod'] as String?;
                    final rating = data['rating'];
                    final createdAt = data['createdAt'] as Timestamp?;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: TayarColors.cardDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: TayarColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isDelivery
                                    ? Icons.inventory_2_outlined
                                    : Icons.two_wheeler,
                                color: TayarColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isDelivery
                                    ? l10n.deliveryOrderTypeLabel
                                    : l10n.rideOrderTypeLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(
                                    status,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _statusLabel(status, l10n),
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.flag,
                                color: TayarColors.textGrey,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  destinationAddress,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                _formatDate(createdAt),
                                style: const TextStyle(
                                  color: TayarColors.textGrey,
                                  fontSize: 11,
                                ),
                              ),
                              const Spacer(),
                              if (fare != null)
                                Text(
                                  l10n.fareAmountEgpLabel(
                                    fare.toStringAsFixed(0),
                                  ),
                                  style: const TextStyle(
                                    color: TayarColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                          if (paymentMethod != null || rating != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (paymentMethod != null)
                                  Text(
                                    paymentMethodDisplay(
                                      context,
                                      paymentMethod,
                                    ),
                                    style: const TextStyle(
                                      color: TayarColors.textGrey,
                                      fontSize: 11,
                                    ),
                                  ),
                                const Spacer(),
                                if (rating != null)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        '$rating',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
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
