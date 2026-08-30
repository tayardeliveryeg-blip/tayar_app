import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/screens/driver/driver_home_screen.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';
import 'package:tayay_app/utils/tayar_page_route.dart';

/// ====== شاشة تقييم الراكب بعد انتهاء الرحلة (من ناحية الطيار) ======
/// نفس فكرة RateTripScreen بالظبط لكن بالعكس: الطيار هو اللي بيقيّم الراكب.
/// بتظهر فورًا بعد ما الطيار يدوس "إنهاء الرحلة"، وبتحدّث متوسط تقييم
/// الراكب في مستند users/{customerId} بنفس منطق ratingSum/ratingCount
/// المستخدم بالفعل لتقييم الطيارين.
class RateRiderScreen extends StatefulWidget {
  final String orderId;
  final String customerId;
  final String customerName;
  final double fare;

  const RateRiderScreen({
    super.key,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.fare,
  });

  @override
  State<RateRiderScreen> createState() => _RateRiderScreenState();
}

class _RateRiderScreenState extends State<RateRiderScreen> {
  int _stars = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_stars == 0) {
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.pleaseSelectStarsFirst,
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final comment = _commentController.text.trim();
      final orderRef = firestore.collection('orders').doc(widget.orderId);
      // ====== الراكب متخزّن في مجموعة users (مش drivers) ======
      final customerRef = firestore.collection('users').doc(widget.customerId);

      // ====== نفس فكرة transaction تقييم الطيار بالظبط: نتأكد إن الطلب ده
      // لسه ما اتقيّمش من ناحية الطيار قبل ما نزوّد عداد الراكب، عشان لو
      // الشاشة اتفتحت مرتين لأي سبب منضخّمش متوسط تقييمه غلط. بنستخدم
      // اسم حقل مختلف (driverRating) عن حقل تقييم الراكب للطيار (rating)
      // عشان الاتنين يقدروا يتخزنوا على نفس مستند الطلب من غير تعارض ======
      await firestore.runTransaction((tx) async {
        final orderSnap = await tx.get(orderRef);
        final alreadyRated = orderSnap.data()?['driverRating'] != null;

        tx.update(orderRef, {
          'driverRating': _stars,
          'driverRatingComment': comment.isEmpty ? null : comment,
          'driverRatedAt': FieldValue.serverTimestamp(),
        });

        // ====== تحديث إجمالي تقييمات الراكب (مجموع النجوم + عدد التقييمات) ======
        // متوسط تقييم الراكب في أي وقت = ratingSum / ratingCount
        if (!alreadyRated && widget.customerId.isNotEmpty) {
          tx.set(customerRef, {
            'ratingSum': FieldValue.increment(_stars),
            'ratingCount': FieldValue.increment(1),
          }, SetOptions(merge: true));
        }
      });

      if (!mounted) return;
      _finish(showThanks: true);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ تقييم الراكب: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.failedToSaveRatingError,
        type: ToastType.error,
      );
    }
  }

  Future<void> _finish({bool showThanks = false}) async {
    final loc = AppLocalizations.of(context)!;
    if (showThanks) {
      TayarToast.show(
        context,
        loc.thankYouForRatingLabel,
        type: ToastType.success,
      );
      await Future.delayed(const Duration(milliseconds: 600));
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      TayarPageRoute(builder: (_) => const DriverHomeScreen()),
      (route) => false,
    );
  }

  String _starsLabel(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    switch (_stars) {
      case 1:
        return loc.ratingVeryBadLabel;
      case 2:
        return loc.ratingFairLabel;
      case 3:
        return loc.ratingGoodLabel;
      case 4:
        return loc.ratingVeryGoodLabel;
      case 5:
        return loc.ratingExcellentLabel;
      default:
        return loc.chooseYourRatingLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    // ====== منمنعش الرجوع بالزرار الفيزيائي بدون تقييم أو تخطي واضح ======
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Icon(
                  Icons.flag_circle,
                  color: TayarColors.primary,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  loc.rateRiderTripFinishedTitle,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  loc.rateRiderSubtitle,
                  style: TextStyle(color: context.textGreyColor, fontSize: 14),
                ),
                const SizedBox(height: 28),

                // ====== كارت الراكب ======
                SizedBox(
                  width: double.infinity,
                  child: AppCard(
                    padding: const EdgeInsets.all(16),
                    radius: 16,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: TayarColors.primary,
                          child: Icon(
                            Icons.person,
                            color: context.onPrimaryColor,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.customerName,
                                style: TextStyle(
                                  color: context.textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.currencyEGP(widget.fare.toStringAsFixed(0)),
                                style: TextStyle(
                                  color: context.textGreyColor,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ====== النجوم ======
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starIndex = index + 1;
                    return GestureDetector(
                      onTap: () => setState(() => _stars = starIndex),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          starIndex <= _stars ? Icons.star : Icons.star_border,
                          color: TayarColors.primary,
                          size: 44,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  _starsLabel(context),
                  style: TextStyle(color: context.textGreyColor, fontSize: 14),
                ),

                const SizedBox(height: 24),

                // ====== التعليق (اختياري) ======
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  style: TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    hintText: loc.commentHintOptional,
                    hintStyle: TextStyle(color: context.textGreyColor),
                    filled: true,
                    fillColor: context.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const Spacer(),

                // ====== زرار الإرسال ======
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: AppPrimaryButton(
                    onPressed: _submitRating,
                    variant: AppButtonVariant.primary,
                    isLoading: _isSubmitting,
                    child: Text(
                      loc.submitRatingButton,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.onPrimaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // ====== تخطي بدون تقييم ======
                TextButton(
                  onPressed: _isSubmitting ? null : () => _finish(),
                  child: Text(
                    loc.skipButton,
                    style: TextStyle(color: context.textGreyColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
