import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/screens/passenger/become_vendor_screen.dart';

// ====== بانر "احصل على أول توصيل مجانًا": بيتشيك على Firestore هل الراكب
// عنده أي رحلة مكتملة قبل كده ولا لأ. لو عنده رحلة مكتملة واحدة على الأقل
// (يعني مش عميل جديد) بيختفي البانر نهائيًا من غير ما يحتاج زرار إغلاق ======
class NewCustomerPromoBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const NewCustomerPromoBanner({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: uid)
          .where('serviceType', isEqualTo: 'passenger')
          .where('status', isEqualTo: 'completed')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        // لسه البيانات بتتحمل أو مفيش يوزر: مانوريش حاجة لحد ما نتأكد
        if (!snapshot.hasData) return const SizedBox.shrink();
        // عنده رحلة مكتملة واحدة على الأقل: مش عميل جديد، مايظهرش البانر
        if (snapshot.data!.docs.isNotEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: TayarColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.soft(context),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_offer_outlined,
                color: Colors.white,
                size: 15,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.homePromoBannerText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close, color: Colors.white70, size: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ====== بانر "لو عايز تبقى شريك تجاري معانا؟": نفس الشكل البصري بالظبط
// بتاع NewCustomerPromoBanner فوق، بس بمنطق مختلف تمامًا - مش شرط إنه
// عميل جديد، وبيختفي بس لو المستخدم بعت طلب انضمام قبل كده (أي حالة، عشان
// مايتكررش الطلب) أو لو دوس زرار الإغلاق. الدوس على البانر نفسه (مش بس
// الأيقونة) بيوديه مباشرة لشاشة الفورم ======
class BecomeVendorPromoBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const BecomeVendorPromoBanner({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('vendor_applications')
          .where('submittedByUserId', isEqualTo: uid)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        // لسه البيانات بتتحمل: مانوريش حاجة لحد ما نتأكد
        if (!snapshot.hasData) return const SizedBox.shrink();
        // بعت طلب انضمام قبل كده (أي حالة): مانوريش البانر تاني
        if (snapshot.data!.docs.isNotEmpty) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BecomeVendorScreen()),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: TayarColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.soft(context),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.storefront_outlined,
                  color: Colors.white,
                  size: 15,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.registerStoreDrawerLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: onDismiss,
                  child: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
