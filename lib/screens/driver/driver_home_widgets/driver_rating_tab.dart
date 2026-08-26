import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== يتأكد إن مستند drivers/{uid} فيه ratingSum/ratingCount جاهزين ======
// لو الطيار قديم من قبل إضافة الكاش ده (أو مفيش كاش لأي سبب)، بيحسبها مرة واحدة
// من كل الطلبات المكتملة القديمة ويخزنها، عشان أي قراءة بعد كده تبقى رخيصة
// (مستند واحد بدل مسح كل الطلبات في كل مرة). لو الكاش موجود بالفعل، منعملش حاجة.
// public (مش private) عشان يتنادى من شاشة الطيار الرئيسية كمان.
Future<void> ensureDriverRatingCacheExists(String driverId) async {
  final driverRef = FirebaseFirestore.instance
      .collection('drivers')
      .doc(driverId);
  try {
    final doc = await driverRef.get();
    if (doc.data()?['ratingCount'] != null) return; // متحسبة بالفعل

    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .get();

    final ratings = <double>[];
    for (final d in snapshot.docs) {
      final r = (d.data()['rating'] as num?)?.toDouble();
      if (r != null) ratings.add(r);
    }
    final sum = ratings.fold<double>(0, (a, b) => a + b);

    await driverRef.set({
      'ratingSum': sum,
      'ratingCount': ratings.length,
    }, SetOptions(merge: true));
  } catch (e) {
    debugPrint('⚠️ تعذر تجهيز كاش تقييم الطيار: $e');
  }
}

// ====== تبويب "تقييمي": متوسط تقييمات الركاب ======
class DriverRatingTab extends StatefulWidget {
  final String driverId;
  const DriverRatingTab({super.key, required this.driverId});

  @override
  State<DriverRatingTab> createState() => DriverRatingTabState();
}

class DriverRatingTabState extends State<DriverRatingTab> {
  @override
  void initState() {
    super.initState();
    ensureDriverRatingCacheExists(widget.driverId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('drivers')
          .doc(widget.driverId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: TayarColors.primary),
          );
        }

        final data = snapshot.data!.data();
        final count = (data?['ratingCount'] as num?)?.toInt() ?? 0;

        if (count <= 0) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.driverNoRatings,
              style: TextStyle(color: context.textGreyColor),
            ),
          );
        }

        final sum = (data?['ratingSum'] as num?)?.toDouble() ?? 0.0;
        final avg = sum / count;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(avg.toStringAsFixed(2), style: TayarStatTextStyles.statHuge),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = i < avg.round();
                  return Icon(
                    filled ? Icons.star : Icons.star_border,
                    color: TayarColors.primary,
                    size: 24,
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                AppLocalizations.of(context)!.ratingCountLabel(count),
                style: TextStyle(color: context.textGreyColor, fontSize: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}

