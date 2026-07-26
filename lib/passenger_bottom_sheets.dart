// ====== شرايط الشاشة السفلية الخاصة بشاشة الراكب: كارت البحث/الأماكن
// المحفوظة (الوضع الطبيعي) وكارت ملخص الرحلة (بعد اختيار وجهة)، مع كل
// الودجتس الفرعية المساعدة ليهم. اتفصلت من passenger_home.dart عشان
// الملف الأصلي كان كبير جدًا (2600+ سطر) — نفس السلوك بالظبط ======
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'theme_extensions.dart';
import 'passenger_home.dart' show paymentMethodDisplay;

class TayarBottomSheet extends StatelessWidget {
  final String? destinationAddress;
  final double? distanceKm;
  final int? durationMin;
  final double fare;
  final String paymentMethod;
  final VoidCallback onTapPaymentMethod;
  final VoidCallback onCancelDestination;
  final VoidCallback onConfirmOrder;
  // ====== callbacks السحب: بتخلي المقبض العلوي يقدر يوسّع الشريط لملء
  // الشاشة أو يرجعه للوضع الطبيعي (شوف _onSheetDrag* في الشاشة الأب) ======
  final void Function()? onDragStart;
  final void Function(DragUpdateDetails)? onDragUpdate;
  final void Function(DragEndDetails)? onDragEnd;

  const TayarBottomSheet({
    super.key,
    required this.destinationAddress,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.paymentMethod,
    required this.onTapPaymentMethod,
    required this.onCancelDestination,
    required this.onConfirmOrder,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    // ====== لو لسه مفيش وجهة متحددة، مفيش حاجة نعرضها تحت ======
    // (البحث بقى فوق جنب زرار القايمة، وخدمات "وصلني/وصل طلباتي" بقت في القايمة الجانبية بس)
    if (destinationAddress == null || distanceKm == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ====== المقبض العلوي: منطقة السحب اللي بتوسّع/تصغّر الشريط ======
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: onDragStart == null
                  ? null
                  : (_) => onDragStart!(),
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragEnd: onDragEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.handleColor,
                      borderRadius: BorderRadius.circular(AppRadius.handle),
                    ),
                  ),
                ),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ====== الوجهة المختارة: أول مكان بيتعرض فيه العنوان
                    // دلوقتي بعد ما شريط البحث العلوي اتشال ======
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: TayarColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              destinationAddress!,
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ملخص الرحلة + زرار الطلب
                    _TripSummaryCard(
                      distanceKm: distanceKm!,
                      durationMin: durationMin ?? 0,
                      fare: fare,
                      paymentMethod: paymentMethod,
                      onTapPaymentMethod: onTapPaymentMethod,
                      onCancel: onCancelDestination,
                      onConfirm: onConfirmOrder,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================
// ====== كارت الشاشة الرئيسية الافتراضي (قبل اختيار وجهة): بحث +
// أماكن محفوظة + آخر رحلة ======
// ====================================================
class TayarIdleBottomSheet extends StatelessWidget {
  final VoidCallback onTapSearch;
  final VoidCallback onTapSavedPlace;
  final void Function(String key, String screenTitle) onSaveAddress;
  final void Function(LatLng location, String address) onReorderTrip;
  final VoidCallback onTapRideService;
  final VoidCallback onTapDeliveryService;
  // ====== callbacks السحب: بتخلي المقبض العلوي يقدر يوسّع الشريط لملء
  // الشاشة أو يرجعه للوضع الطبيعي (شوف _onSheetDrag* في الشاشة الأب) ======
  final void Function()? onDragStart;
  final void Function(DragUpdateDetails)? onDragUpdate;
  final void Function(DragEndDetails)? onDragEnd;

  const TayarIdleBottomSheet({
    super.key,
    required this.onTapSearch,
    required this.onTapSavedPlace,
    required this.onSaveAddress,
    required this.onReorderTrip,
    required this.onTapRideService,
    required this.onTapDeliveryService,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ====== المقبض العلوي: منطقة السحب اللي بتوسّع/تصغّر الشريط ======
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: onDragStart == null
                  ? null
                  : (_) => onDragStart!(),
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragEnd: onDragEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.handleColor,
                      borderRadius: BorderRadius.circular(AppRadius.handle),
                    ),
                  ),
                ),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ====== شريط البحث: بيفتح شاشة اختيار الوجهة الموجودة أصلاً ======
                    GestureDetector(
                      onTap: onTapSearch,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: context.textGreyColor,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              loc.homeSearchHint,
                              style: TextStyle(
                                color: context.textGreyColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ====== أماكن محفوظة: البيت / الشغل / إضافة، بنفس
                    // المقاس بالظبط (كل واحدة Expanded) ======
                    Text(
                      loc.savedPlacesLabel,
                      style: TextStyle(
                        color: context.textGreyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SavedPlacesRow(
                      onUseAddress: onReorderTrip,
                      onSaveAddress: onSaveAddress,
                      onAddTap: onTapSavedPlace,
                      addLabel: loc.savedPlaceAdd,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ====== الخدمات السريعة: تحت الأماكن المحفوظة مباشرة ======
                    Row(
                      children: [
                        Expanded(
                          child: _QuickServiceButton(
                            icon: Icons.two_wheeler,
                            label: loc.serviceRideMe,
                            onTap: onTapRideService,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _QuickServiceButton(
                            icon: Icons.delivery_dining,
                            label: loc.serviceDeliverOrders,
                            onTap: onTapDeliveryService,
                          ),
                        ),
                      ],
                    ),

                    // ====== آخر رحلة: بتظهر بس لو فيه رحلة سابقة فعلًا في Firestore ======
                    _LastTripSection(onReorderTrip: onReorderTrip),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== صف "البيت" و"الشغل": بيسمعوا على users/{uid}.savedAddresses على
// فيرستور لايف. لو المكان لسه مش محفوظ، دوسة عليه بتفتح شاشة اختيار
// العنوان وتحفظه. لو محفوظ فعلًا، دوسة عادية بتستخدمه كوجهة على طول،
// وضغطة مطوّلة (long press) بتفتح شاشة الاختيار تاني عشان يتغيّر ======
class _SavedPlacesRow extends StatelessWidget {
  final void Function(LatLng location, String address) onUseAddress;
  final void Function(String key, String screenTitle) onSaveAddress;
  final VoidCallback onAddTap;
  final String addLabel;

  const _SavedPlacesRow({
    required this.onUseAddress,
    required this.onSaveAddress,
    required this.onAddTap,
    required this.addLabel,
  });

  void _handleTap(
    String key,
    Map<String, dynamic>? savedData,
    String screenTitle,
  ) {
    final lat = (savedData?['lat'] as num?)?.toDouble();
    final lng = (savedData?['lng'] as num?)?.toDouble();
    final address = savedData?['address'] as String?;

    if (lat == null || lng == null || address == null) {
      // مفيش عنوان محفوظ لسه: افتح شاشة الاختيار واحفظه
      onSaveAddress(key, screenTitle);
    } else {
      // العنوان محفوظ: استخدمه كوجهة على طول
      onUseAddress(LatLng(lat, lng), address);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Row(
        children: [
          Expanded(
            child: _SavedPlaceChip(
              icon: Icons.home_outlined,
              label: loc.savedPlaceHome,
              onTap: () => onSaveAddress('home', loc.selectHomeAddressTitle),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SavedPlaceChip(
              icon: Icons.work_outline,
              label: loc.savedPlaceWork,
              onTap: () => onSaveAddress('work', loc.selectWorkAddressTitle),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SavedPlaceChip(
              icon: Icons.add,
              label: addLabel,
              onTap: onAddTap,
            ),
          ),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final savedAddresses =
            snapshot.data?.data()?['savedAddresses'] as Map<String, dynamic>?;
        final home = savedAddresses?['home'] as Map<String, dynamic>?;
        final work = savedAddresses?['work'] as Map<String, dynamic>?;

        return Row(
          children: [
            Expanded(
              child: _SavedPlaceChip(
                icon: Icons.home_outlined,
                label: loc.savedPlaceHome,
                onTap: () => _handleTap('home', home, loc.savedPlaceHome),
                onLongPress: () =>
                    onSaveAddress('home', loc.selectHomeAddressTitle),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SavedPlaceChip(
                icon: Icons.work_outline,
                label: loc.savedPlaceWork,
                onTap: () => _handleTap('work', work, loc.savedPlaceWork),
                onLongPress: () =>
                    onSaveAddress('work', loc.selectWorkAddressTitle),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SavedPlaceChip(
                icon: Icons.add,
                label: addLabel,
                onTap: onAddTap,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ====== شريحة مكان محفوظ (البيت / الشغل / إضافة) ======
class _SavedPlaceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SavedPlaceChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TayarColors.primary, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== قسم "آخر رحلة": بيجيب آخر طلب رحلة مكتمل للراكب الحالي من
// collection('orders') على فيرستور، وبيخفي نفسه تمامًا لو مفيش رحلات سابقة ======
class _LastTripSection extends StatelessWidget {
  final void Function(LatLng location, String address) onReorderTrip;

  const _LastTripSection({required this.onReorderTrip});

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

        if (docs.isEmpty) return const SizedBox.shrink();

        final lastTrip = docs.first.data();
        final destinationAddress = lastTrip['destinationAddress'] as String?;
        final destinationGeoPoint =
            lastTrip['destinationLocation'] as GeoPoint?;
        final pickupAddress = lastTrip['pickupAddress'] as String?;
        if (destinationAddress == null || destinationGeoPoint == null) {
          return const SizedBox.shrink();
        }

        final loc = AppLocalizations.of(context)!;
        final routeLabel = pickupAddress != null
            ? '$pickupAddress ← $destinationAddress'
            : destinationAddress;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.lastTripLabel,
                  style: TextStyle(
                    color: context.textGreyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () => onReorderTrip(
                    LatLng(
                      destinationGeoPoint.latitude,
                      destinationGeoPoint.longitude,
                    ),
                    destinationAddress,
                  ),
                  child: Text(
                    loc.reorderTripLabel,
                    style: const TextStyle(
                      color: TayarColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => onReorderTrip(
                LatLng(
                  destinationGeoPoint.latitude,
                  destinationGeoPoint.longitude,
                ),
                destinationAddress,
              ),
              child: Row(
                children: [
                  Icon(Icons.history, color: context.textGreyColor, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      routeLabel,
                      style: TextStyle(color: context.textColor, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ====== بانر "احصل على أول توصيل مجانًا": بيتشيك على Firestore هل الراكب
// عنده أي رحلة مكتملة قبل كده ولا لأ. لو عنده رحلة مكتملة واحدة على الأقل
// (يعني مش عميل جديد) بيختفي البانر نهائيًا من غير ما يحتاج زرار إغلاق ======
class _NewCustomerPromoBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const _NewCustomerPromoBanner({required this.onDismiss});

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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
              ),
            ],
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
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ====== زرار خدمة سريعة (وصلني / وصل طلباتي) — أيقونة ونص بس، جوه
// الشريط السفلي تحت الأماكن المحفوظة ======
class _QuickServiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickServiceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.dividerColor2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TayarColors.primary, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: context.textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ====== كارت ملخص الرحلة (المسافة + الوقت + السعر + زرار الطلب) ======
class _TripSummaryCard extends StatelessWidget {
  final double distanceKm;
  final int durationMin;
  final double fare;
  final String paymentMethod;
  final VoidCallback onTapPaymentMethod;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _TripSummaryCard({
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.paymentMethod,
    required this.onTapPaymentMethod,
    required this.onCancel,
    required this.onConfirm,
  });

  // ====== أيقونة طريقة الدفع الحالية (بتقارن على القيمة الداخلية الثابتة، مش النص المترجم) ======
  IconData get _paymentIcon {
    switch (paymentMethod) {
      case 'محفظة إلكترونية':
        return Icons.account_balance_wallet_outlined;
      case 'إنستاباي':
        return Icons.bolt_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: TayarColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TripStat(
                icon: Icons.route,
                label: AppLocalizations.of(
                  context,
                )!.distanceKmLabel(distanceKm.toStringAsFixed(1)),
              ),
              _TripStat(
                icon: Icons.access_time,
                label: AppLocalizations.of(
                  context,
                )!.durationMinLabel(durationMin),
              ),
              _TripStat(
                icon: Icons.payments_outlined,
                label: AppLocalizations.of(
                  context,
                )!.currencyEGP(fare.toStringAsFixed(0)),
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // ====== طريقة الدفع: بتفتح شاشة اختيار لما تتدوس ======
          GestureDetector(
            onTap: onTapPaymentMethod,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(_paymentIcon, color: TayarColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    AppLocalizations.of(context)!.paymentMethodLabel,
                    style: TextStyle(
                      color: context.textGreyColor,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    paymentMethodDisplay(context, paymentMethod),
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.keyboard_arrow_left,
                    color: context.textGreyColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    side: BorderSide(color: context.textGreyColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: TextStyle(color: context.textGreyColor),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TayarColors.primary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.confirmButton,
                    style: TextStyle(
                      color: context.onPrimaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _TripStat({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: highlight ? TayarColors.primary : context.textGreyColor,
          size: 22,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(
            color: highlight ? TayarColors.primary : context.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
