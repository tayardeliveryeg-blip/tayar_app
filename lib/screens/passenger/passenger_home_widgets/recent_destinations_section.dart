import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/screens/passenger/passenger_home_widgets/saved_places_row.dart'
    show SavedPlaceChip;

// ====== قسم "وجهات أخيرة": بيجيب آخر 30 طلب رحلة للراكب الحالي من
// collection('orders')، بيفلتر الرحلات المكتملة بس، وبيستخرج منهم أحدث 5
// وجهات مختلفة (deduplicated بالعنوان، الأحدث بياخد الأولوية) ويعرضهم في
// صف قابل للتمرير أفقيًا بنفس ستايل SavedPlacesRow. بيختفي تمامًا لو
// مفيش رحلات سابقة ======
class RecentDestinationsSection extends StatelessWidget {
  final void Function(LatLng location, String address) onReorderTrip;

  const RecentDestinationsSection({super.key, required this.onReorderTrip});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // بنجيب كل رحلات الراكب المكتملة ونرتبها ونفلترها محليًا، عشان نتجنب
      // الحاجة لعمل composite index في Firestore (نفس أسلوب order_history_screen).
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

        // ====== استخراج أحدث 5 وجهات مختلفة: بنمشي على الرحلات من الأحدث
        // للأقدم، ولو العنوان اتكرر (نفس الوجهة راح لها قبل كده) بنتجاهله
        // عشان الصف مايتلخبطش بتكرار نفس المكان أكتر من مرة ======
        final seenAddresses = <String>{};
        final recent = <_RecentDestination>[];
        for (final doc in docs) {
          if (recent.length >= 5) break;
          final data = doc.data();
          final destinationAddress = data['destinationAddress'] as String?;
          final destinationGeoPoint = data['destinationLocation'] as GeoPoint?;
          if (destinationAddress == null || destinationGeoPoint == null) {
            continue;
          }
          if (!seenAddresses.add(destinationAddress)) continue;
          recent.add(
            _RecentDestination(
              address: destinationAddress,
              location: LatLng(
                destinationGeoPoint.latitude,
                destinationGeoPoint.longitude,
              ),
            ),
          );
        }

        if (recent.isEmpty) return const SizedBox.shrink();

        final loc = AppLocalizations.of(context)!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(
              loc.recentDestinationsLabel,
              style: TextStyle(
                color: context.textGreyColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final dest in recent) ...[
                    SizedBox(
                      width: 120,
                      child: SavedPlaceChip(
                        icon: Icons.history,
                        label: dest.address,
                        onTap: () => onReorderTrip(dest.location, dest.address),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ====== موديل بسيط لوجهة أخيرة (عنوان + إحداثيات) بيتستخدم جوه
// RecentDestinationsSection بس ======
class _RecentDestination {
  final String address;
  final LatLng location;

  const _RecentDestination({required this.address, required this.location});
}
