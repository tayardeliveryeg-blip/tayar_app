import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart' show TayarColors, TayarThemeColors, PassengerHomeScreen;
import 'package:tayay_app/l10n/generated/app_localizations.dart';

/// ====== شاشة تقييم الطيار بعد انتهاء الرحلة ======
/// بتظهر تلقائيًا لما الأوردر يوصل لحالة completed، وبتسمح للراكب
/// يحط عدد نجوم (1-5) وتعليق اختياري، وبتحدث متوسط تقييم الطيار في Firestore.
class RateTripScreen extends StatefulWidget {
  final String orderId;
  final String driverId;
  final String driverName;
  final double fare;

  const RateTripScreen({
    super.key,
    required this.orderId,
    required this.driverId,
    required this.driverName,
    required this.fare,
  });

  @override
  State<RateTripScreen> createState() => _RateTripScreenState();
}

class _RateTripScreenState extends State<RateTripScreen> {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.pleaseSelectStarsFirst),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final comment = _commentController.text.trim();
      final orderRef = firestore.collection('orders').doc(widget.orderId);
      final driverRef = firestore.collection('drivers').doc(widget.driverId);

      // ====== transaction واحدة: نتأكد إن الطلب ده لسه ما اتقيّمش قبل كده
      // قبل ما نزوّد عداد الطيار، عشان لو الشاشة اتفتحت مرتين لأي سبب
      // (bug مستقبلي، ضغط مزدوج نادر، إلخ) منضخّمش متوسط تقييمه غلط ======
      await firestore.runTransaction((tx) async {
        final orderSnap = await tx.get(orderRef);
        final alreadyRated = orderSnap.data()?['rating'] != null;

        tx.update(orderRef, {
          'rating': _stars,
          'ratingComment': comment.isEmpty ? null : comment,
          'ratedAt': FieldValue.serverTimestamp(),
        });

        // ====== تحديث إجمالي تقييمات الطيار (مجموع النجوم + عدد التقييمات) ======
        // متوسط تقييم الطيار في أي وقت = ratingSum / ratingCount
        // منزودش العداد لو الطلب ده اتقيّم قبل كده أصلًا
        if (!alreadyRated && widget.driverId.isNotEmpty) {
          tx.set(driverRef, {
            'ratingSum': FieldValue.increment(_stars),
            'ratingCount': FieldValue.increment(1),
          }, SetOptions(merge: true));
        }
      });

      if (!mounted) return;
      _finish(showThanks: true);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ التقييم: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToSaveRatingError),
        ),
      );
    }
  }

  Future<void> _finish({bool showThanks = false}) async {
    final loc = AppLocalizations.of(context)!;
    if (showThanks) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.thankYouForRatingLabel)));
      await Future.delayed(const Duration(milliseconds: 600));
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PassengerHomeScreen()),
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
                  loc.rateTripArrivedSafelyTitle,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  loc.rateTripSubtitle,
                  style:  TextStyle(
                    color: context.textGreyColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),

                // ====== كارت الطيار ======
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                              widget.driverName,
                              style:  TextStyle(
                                color: context.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              loc.currencyEGP(widget.fare.toStringAsFixed(0)),
                              style:  TextStyle(
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
                  style:  TextStyle(
                    color: context.textGreyColor,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 24),

                // ====== التعليق (اختياري) ======
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  style:  TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    hintText: loc.commentHintOptional,
                    hintStyle:  TextStyle(color: context.textGreyColor),
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
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRating,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TayarColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSubmitting
                        ?  SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: context.onPrimaryColor,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            loc.submitRatingButton,
                            style:  TextStyle(
                              color: context.textColor,
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
                    style:  TextStyle(color: context.textGreyColor),
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