import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'passenger_home.dart' show TayarColors;

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
        const SnackBar(content: Text('من فضلك اختار عدد النجوم الأول')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final comment = _commentController.text.trim();

      // ====== حفظ التقييم على الرحلة نفسها ======
      await firestore.collection('orders').doc(widget.orderId).update({
        'rating': _stars,
        'ratingComment': comment.isEmpty ? null : comment,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      // ====== تحديث إجمالي تقييمات الطيار (مجموع النجوم + عدد التقييمات) ======
      // متوسط تقييم الطيار في أي وقت = ratingSum / ratingCount
      if (widget.driverId.isNotEmpty) {
        await firestore.collection('drivers').doc(widget.driverId).set({
          'ratingSum': FieldValue.increment(_stars),
          'ratingCount': FieldValue.increment(1),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      _finish(showThanks: true);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ التقييم: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ التقييم، حاول تاني')),
      );
    }
  }

  void _finish({bool showThanks = false}) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (showThanks) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('شكرًا لتقييمك! 🌟')));
    }
  }

  String get _starsLabel {
    switch (_stars) {
      case 1:
        return 'سيء جدًا';
      case 2:
        return 'مقبول';
      case 3:
        return 'كويس';
      case 4:
        return 'جيد جدًا';
      case 5:
        return 'ممتاز';
      default:
        return 'اختار تقييمك';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ====== منمنعش الرجوع بالزرار الفيزيائي بدون تقييم أو تخطي واضح ======
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: TayarColors.background,
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
                const Text(
                  'وصلت لوجهتك بأمان!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'قيّم رحلتك مع الطيار',
                  style: TextStyle(color: TayarColors.textGrey, fontSize: 14),
                ),
                const SizedBox(height: 28),

                // ====== كارت الطيار ======
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TayarColors.cardDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundColor: TayarColors.primary,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.fare.toStringAsFixed(0)} جنيه',
                              style: const TextStyle(
                                color: TayarColors.textGrey,
                                fontSize: 13,
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
                  _starsLabel,
                  style: const TextStyle(
                    color: TayarColors.textGrey,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 24),

                // ====== التعليق (اختياري) ======
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'اكتب تعليقك (اختياري)',
                    hintStyle: const TextStyle(color: TayarColors.textGrey),
                    filled: true,
                    fillColor: TayarColors.cardDark,
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
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'إرسال التقييم',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),

                // ====== تخطي بدون تقييم ======
                TextButton(
                  onPressed: _isSubmitting ? null : () => _finish(),
                  child: const Text(
                    'تخطي',
                    style: TextStyle(color: TayarColors.textGrey),
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
