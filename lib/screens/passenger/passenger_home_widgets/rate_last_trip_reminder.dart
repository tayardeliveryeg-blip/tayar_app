import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/screens/passenger/rate_trip_screen.dart';

// ====== تذكير تقييم آخر رحلة: بيجيب آخر رحلة مكتملة للراكب، ولو مفيش
// حقل 'rating' عليها (يعني اتخطّت التقييم التلقائي على trip_tracking_screen،
// غالبًا لأن الراكب قفل التطبيق قبل ما الشاشة تظهر) بيعرض بانر صغير بيوديه
// لشاشة RateTripScreen مباشرة. بيختفي تمامًا لو مفيش رحلة سابقة أو لو
// اتقيّمت بالفعل ======
class RateLastTripReminder extends StatelessWidget {
  const RateLastTripReminder({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // نفس أسلوب الاستعلام المحلي (بدون composite index) المستخدم في
      // بقية أقسام الشريط ده.
      future: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: uid)
          .limit(30)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs =
            snapshot.data!.docs.where((doc) {
              final data = doc.data();
              return data['serviceType'] == 'passenger' &&
                  data['status'] == 'completed';
            }).toList()..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

        if (docs.isEmpty) return const SizedBox.shrink();

        final lastTripDoc = docs.first;
        final data = lastTripDoc.data();

        // ====== لو آخر رحلة اتقيّمت بالفعل، مفيش داعي للتذكير ======
        if (data['rating'] != null) return const SizedBox.shrink();

        final driverId = data['driverId'] as String? ?? '';
        final driverName = data['driverName'] as String? ?? '';
        final fare = (data['acceptedFare'] as num?)?.toDouble() ?? 0;
        final loc = AppLocalizations.of(context)!;

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RateTripScreen(
                  orderId: lastTripDoc.id,
                  driverId: driverId,
                  driverName: driverName,
                  fare: fare,
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: TayarColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.star_outline,
                    color: TayarColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      loc.rateLastTripReminderText,
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_left,
                    color: context.textGreyColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
