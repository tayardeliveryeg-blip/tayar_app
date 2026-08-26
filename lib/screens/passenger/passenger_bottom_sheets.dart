// ====== شرايط الشاشة السفلية الخاصة بشاشة الراكب: كارت البحث/الأماكن
// المحفوظة (الوضع الطبيعي) وكارت ملخص الرحلة (بعد اختيار وجهة). الودجتس
// الفرعية المساعدة (الأماكن المحفوظة، تذكير التقييم، الوجهات الأخيرة،
// البانرات، الخدمات السريعة، كارت ملخص الرحلة) اتفصلت في فولدر
// passenger_home_widgets/ عشان الملف ده كان كبير جدًا (1266 سطر) — نفس
// السلوك بالظبط، بس منظّم في ملفات أصغر لكل ودجت مسؤولية واحدة ======
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/screens/passenger/passenger_home_widgets/saved_places_row.dart';
import 'package:tayay_app/screens/passenger/passenger_home_widgets/rate_last_trip_reminder.dart';
import 'package:tayay_app/screens/passenger/passenger_home_widgets/recent_destinations_section.dart';
import 'package:tayay_app/screens/passenger/passenger_home_widgets/quick_service_button.dart';
import 'package:tayay_app/screens/passenger/passenger_home_widgets/trip_summary_card.dart';

// ====== إعادة تصدير: passenger_home.dart وملفات تانية كانت بتستورد
// NewCustomerPromoBanner وBecomeVendorPromoBanner من الملف ده على طول -
// الـ export ده بيخليهم يفضلوا شغالين من غير ما نغيّر الاستيراد بتاعهم ======
export 'package:tayay_app/screens/passenger/passenger_home_widgets/promo_banners.dart';

// ====================================================
// ====== طبقة "اسحب من أي مكان": بتخلي المستخدم يقدر يسحب الشريط لفوق/
// لتحت بالضغط في أي نقطة جواه (مش بس من المقبض الصغير فوق زي الأول).
// بنستخدم Listener بدل GestureDetector عشان Listener بيسمع لحركة
// الإصبع الخام مباشرة من غير ما يدخل "معركة" الإيماءات (gesture arena) -
// فده بيسيب أي تاب أو سحب تاني جوه الشريط (زرار البحث، سكرول الأماكن
// المحفوظة، البانرات..إلخ) شغال عادي زي ما هو من غير أي تعارض ======
// ====================================================
class _SheetDragArea extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDragStart;
  final void Function(DragUpdateDetails)? onDragUpdate;
  final void Function(DragEndDetails)? onDragEnd;

  const _SheetDragArea({
    required this.child,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  State<_SheetDragArea> createState() => _SheetDragAreaState();
}

class _SheetDragAreaState extends State<_SheetDragArea> {
  VelocityTracker? _velocityTracker;
  Offset? _lastPosition;

  void _handlePointerDown(PointerDownEvent event) {
    _velocityTracker = VelocityTracker.withKind(event.kind);
    _velocityTracker!.addPosition(event.timeStamp, event.position);
    _lastPosition = event.position;
    widget.onDragStart?.call();
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_lastPosition == null) return;
    _velocityTracker?.addPosition(event.timeStamp, event.position);
    final dy = event.position.dy - _lastPosition!.dy;
    _lastPosition = event.position;
    if (dy == 0) return;
    widget.onDragUpdate?.call(
      DragUpdateDetails(
        globalPosition: event.position,
        delta: Offset(0, dy),
        primaryDelta: dy,
      ),
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
    widget.onDragEnd?.call(
      DragEndDetails(
        velocity: velocity,
        primaryVelocity: velocity.pixelsPerSecond.dy,
      ),
    );
    _velocityTracker = null;
    _lastPosition = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _velocityTracker = null;
    _lastPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: widget.onDragUpdate == null ? null : _handlePointerDown,
      onPointerMove: widget.onDragUpdate == null ? null : _handlePointerMove,
      onPointerUp: widget.onDragUpdate == null ? null : _handlePointerUp,
      onPointerCancel: widget.onDragUpdate == null
          ? null
          : _handlePointerCancel,
      child: widget.child,
    );
  }
}

// ====== ملحوظة تسمية: الكلاس ده كان اسمه TayarBottomSheet قبل كده، لكن
// اتغيّر لـ TripConfirmationSheet عشان كان بيتعارض بالاسم مع مكوّن
// TayarBottomSheet العام الجديد في widgets/tayar_bottom_sheet.dart (UI kit).
// الكلاس ده تحديدًا خاص بكارت ملخص الرحلة (وجهة/مسافة/سعر/تأكيد) في شاشة
// الراكب الرئيسية بس، مش bottom sheet عام ======
class TripConfirmationSheet extends StatelessWidget {
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

  const TripConfirmationSheet({
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
      // ====== heightFactor: 1 مهم جدًا هنا: من غيره الـ Align بياخد كل
      // الارتفاع المسموح بيه من ConstrainedBox اللي فوقه (maxHeight) حتى
      // لو المحتوى الحقيقي أصغر بكتير، وده بيسبب مساحة فاضية غير مرئية
      // فوق الكارت بتأثر على أي حاجة بتقيس ارتفاع الشريط فعليًا (زي زرار
      // تحديد الموقع) ======
      heightFactor: 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: _SheetDragArea(
          onDragStart: onDragStart,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ====== المقبض العلوي: مجرد مؤشر بصري دلوقتي - السحب بقى شغال
              // من أي مكان في الشريط (شوف _SheetDragArea فوق) ======
              Padding(
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
                      TripSummaryCard(
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
  // ====== عدد الطيارين المتاحين حاليًا في نطاق قريب من موقع الراكب.
  // null يعني لسه مفيش موقع لحظي كافي نحسب بيه، و0 يعني مفيش سواقين
  // قريبين — في الحالتين دول العنصر بيختفي (شوف build) ======
  final int? nearbyDriversCount;
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
    this.nearbyDriversCount,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.bottomCenter,
      // ====== نفس ملحوظة heightFactor في TayarBottomSheet فوق: من غيرها
      // كان فيه فراغ غير مرئي بين الزرار العائم فوق (تحديد الموقع) وبين
      // حافة الكارت الحقيقية، لأن الـ Align كان بياخد نص الشاشة كارتفاع
      // (collapsedHeight) حتى لو المحتوى الفعلي أصغر بكتير من كده ======
      heightFactor: 1,
      child: Container(
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: AppShadows.elevated(context),
        ),
        child: _SheetDragArea(
          onDragStart: onDragStart,
          onDragUpdate: onDragUpdate,
          onDragEnd: onDragEnd,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ====== المقبض العلوي: مجرد مؤشر بصري دلوقتي - السحب بقى شغال
              // من أي مكان في الشريط (شوف _SheetDragArea فوق) ======
              Padding(
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
                      // ====== مؤشر السواقين القريبين: بيظهر بس لو عندنا موقع
                      // لحظي للراكب وفيه سواق واحد على الأقل في النطاق ======
                      if (nearbyDriversCount != null && nearbyDriversCount! > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.two_wheeler,
                                color: TayarColors.primary,
                                size: 15,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                loc.nearbyDriversCountLabel(
                                  nearbyDriversCount!,
                                ),
                                style: const TextStyle(
                                  color: TayarColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

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

                      // ====== تذكير تقييم آخر رحلة: بيظهر بس لو آخر رحلة
                      // مكتملة لسه ما اتقيّمتش (مثلاً الراكب قفل التطبيق قبل
                      // ما شاشة التقييم التلقائية تظهر) ======
                      const RateLastTripReminder(),

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
                      SavedPlacesRow(
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
                            child: QuickServiceButton(
                              icon: Icons.two_wheeler,
                              label: loc.serviceRideMe,
                              onTap: onTapRideService,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: QuickServiceButton(
                              icon: Icons.delivery_dining,
                              label: loc.serviceDeliverOrders,
                              onTap: onTapDeliveryService,
                            ),
                          ),
                        ],
                      ),

                      // ====== وجهات أخيرة: بتظهر بس لو فيه رحلات سابقة فعلًا في Firestore ======
                      RecentDestinationsSection(onReorderTrip: onReorderTrip),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
