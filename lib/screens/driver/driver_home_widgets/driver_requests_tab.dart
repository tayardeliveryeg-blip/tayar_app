import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/screens/driver/driver_trip_tracking_screen.dart';
import 'package:tayay_app/screens/driver/driver_home_widgets/order_request_card.dart';
import 'package:tayay_app/screens/driver/driver_home_widgets/offer_sheet.dart';
import 'package:tayay_app/screens/driver/driver_home_widgets/active_trip_card.dart';
import 'package:tayay_app/screens/driver/driver_home_widgets/trip_request_detail_screen.dart';

// ====== دالة مساعدة موحّدة لاستخراج GeoPoint من حقول الموقع ======
// (نسخة مستقلة بتخدم التبويب ده بس، النسخة الأصلية لسه موجودة في
// driver_home_screen.dart لاستخدامها في منطق تتبع الموقع)
GeoPoint? extractGeoPointForRequestsTab(dynamic raw) {
  if (raw is Map<String, dynamic>) {
    return raw['geopoint'] as GeoPoint?;
  } else if (raw is GeoPoint) {
    return raw;
  }
  return null;
}

// ====== دالة مساعدة لتحويل حقل scheduledFor (Firestore Timestamp) لـ
// DateTime - null يعني رحلة فورية زي ما كان دايمًا ======
DateTime? extractScheduledForRequestsTab(dynamic raw) {
  if (raw is Timestamp) return raw.toDate();
  return null;
}

// ====== محتوى تبويب "طلباتي" (الرحلة النشطة + الطلبات المتاحة) ======
// (كان جوه driver_home_screen.dart كـ _buildRequestsTab واتقسم في ملف منفصل)
class DriverRequestsTab extends StatelessWidget {
  final User user;
  final CollectionReference<Map<String, dynamic>> ordersRef;
  final bool isOnline;
  final Set<String> offeredOrderIds;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> Function(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orders,
  )
  filterOrdersWithinServiceRadius;
  final Future<void> Function(String orderId, double price) onSubmitOffer;
  final Future<void> Function(String orderId) onStartTrip;
  final Future<void> Function(String orderId) onCompleteTrip;

  const DriverRequestsTab({
    super.key,
    required this.user,
    required this.ordersRef,
    required this.isOnline,
    required this.offeredOrderIds,
    required this.filterOrdersWithinServiceRadius,
    required this.onSubmitOffer,
    required this.onStartTrip,
    required this.onCompleteTrip,
  });

  void _openOfferSheet(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> orderDoc,
  ) {
    final data = orderDoc.data();
    final double proposedFare = (data['proposedFare'] as num?)?.toDouble() ?? 0;
    // ====== initialFare مش موجودة في الطلبات القديمة قبل إضافة الحقل ده،
    // فبنرجع لـ proposedFare كـ fallback بدل ما نكسر الشاشة ======
    final double initialFare =
        (data['initialFare'] as num?)?.toDouble() ?? proposedFare;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => OfferSheet(
        proposedFare: proposedFare,
        initialFare: initialFare,
        pickupAddress: (data['pickupAddress'] as String?) ?? '',
        destinationAddress: (data['destinationAddress'] as String?) ?? '',
        distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
        onSubmit: (price) {
          Navigator.pop(context);
          onSubmitOffer(orderDoc.id, price);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ====== الرحلة النشطة (لو موجودة) ======
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ordersRef
              .where('driverId', isEqualTo: user.uid)
              .where('status', whereIn: ['accepted', 'in_progress'])
              .limit(1)
              .snapshots(),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const SizedBox.shrink();

            final trip = docs.first;
            final data = trip.data();
            final bool inProgress = data['status'] == 'in_progress';

            return ActiveTripCard(
              orderId: trip.id,
              customerId: (data['customerId'] as String?) ?? '',
              customerName:
                  (data['customerName'] as String?) ??
                  AppLocalizations.of(context)!.defaultCustomerName,
              pickupAddress: (data['pickupAddress'] as String?) ?? '',
              destinationAddress: (data['destinationAddress'] as String?) ?? '',
              fare: (data['acceptedFare'] as num?)?.toDouble() ?? 0,
              paymentMethod:
                  (data['paymentMethod'] as String?) ??
                  AppLocalizations.of(context)!.paymentMethodCash,
              inProgress: inProgress,
              scheduledFor: extractScheduledForRequestsTab(
                data['scheduledFor'],
              ),
              onStart: () => onStartTrip(trip.id),
              onComplete: () => onCompleteTrip(trip.id),
              onOpenTracking: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverTripTrackingScreen(orderId: trip.id),
                ),
              ),
            );
          },
        ),

        // ====== الطلبات المتاحة اللي بتدور على عروض (تظهر بس لو الطيار أونلاين) ======
        Expanded(
          child: !isOnline
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.power_settings_new,
                          color: context.textGreyColor,
                          size: 40,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          AppLocalizations.of(context)!.driverOfflineHint,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.textGreyColor),
                        ),
                      ],
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ordersRef
                      .where('status', isEqualTo: 'searching')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context)!.errorLoadingOrders,
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

                    final orders = filterOrdersWithinServiceRadius(
                      snapshot.data!.docs,
                    );
                    if (orders.isEmpty) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context)!.driverNoOrders,
                          style: TextStyle(color: context.textGreyColor),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final order = orders[index];
                        final data = order.data();
                        final bool alreadyOffered = offeredOrderIds.contains(
                          order.id,
                        );

                        return OrderRequestCard(
                          pickupAddress:
                              (data['pickupAddress'] as String?) ?? '',
                          destinationAddress:
                              (data['destinationAddress'] as String?) ?? '',
                          distanceKm:
                              (data['distanceKm'] as num?)?.toDouble() ?? 0,
                          durationMin:
                              (data['durationMin'] as num?)?.toInt() ?? 0,
                          proposedFare:
                              (data['proposedFare'] as num?)?.toDouble() ?? 0,
                          paymentMethod:
                              (data['paymentMethod'] as String?) ??
                              AppLocalizations.of(context)!.paymentMethodCash,
                          alreadyOffered: alreadyOffered,
                          scheduledFor: extractScheduledForRequestsTab(
                            data['scheduledFor'],
                          ),
                          onQuickAccept: alreadyOffered
                              ? null
                              : () => onSubmitOffer(
                                  order.id,
                                  (data['proposedFare'] as num?)?.toDouble() ??
                                      0,
                                ),
                          onCustomOffer: alreadyOffered
                              ? null
                              : () => _openOfferSheet(context, order),
                          onOpenDetails: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TripRequestDetailScreen(
                                orderId: order.id,
                                pickupAddress:
                                    (data['pickupAddress'] as String?) ?? '',
                                destinationAddress:
                                    (data['destinationAddress'] as String?) ??
                                    '',
                                pickupLocation: extractGeoPointForRequestsTab(
                                  data['pickupLocation'],
                                ),
                                destinationLocation:
                                    extractGeoPointForRequestsTab(
                                      data['destinationLocation'],
                                    ),
                                distanceKm:
                                    (data['distanceKm'] as num?)?.toDouble() ??
                                    0,
                                durationMin:
                                    (data['durationMin'] as num?)?.toInt() ?? 0,
                                proposedFare:
                                    (data['proposedFare'] as num?)
                                        ?.toDouble() ??
                                    0,
                                paymentMethod:
                                    (data['paymentMethod'] as String?) ??
                                    AppLocalizations.of(
                                      context,
                                    )!.paymentMethodCash,
                                alreadyOffered: alreadyOffered,
                                scheduledFor: extractScheduledForRequestsTab(
                                  data['scheduledFor'],
                                ),
                                onQuickAccept: alreadyOffered
                                    ? null
                                    : () => onSubmitOffer(
                                        order.id,
                                        (data['proposedFare'] as num?)
                                                ?.toDouble() ??
                                            0,
                                      ),
                                onCustomOffer: alreadyOffered
                                    ? null
                                    : (price) => onSubmitOffer(order.id, price),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
