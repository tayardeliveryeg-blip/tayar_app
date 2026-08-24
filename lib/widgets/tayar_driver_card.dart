import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';

// ====== Driver Offer Card — كارت عرض سائق بأسلوب inDrive، كل المعلومات ظاهرة ======
// Usage: TayarDriverCard(
//   driverName: 'أحمد محمد',
//   rating: 4.8,
//   trips: 342,
//   price: 25,
//   distance: '2.5 كم',
//   time: '5 دقائق',
//   vehicleType: 'دراجة',
//   onAccept: () {},
//   onReject: () {},
// )
//
// ====== [ملاحظة دمج] ملف جديد بالكامل، مفيش مقابل قديم ليه. التصحيحات
// اللي اتعملت هنا مقارنة بالنسخة الأصلية:
// 1. Colors.white50 (مش موجودة في Flutter SDK أصلًا، كانت هتوقف الـ build)
//    اتبدلت بـ context.textGreyColor من الثيم الموحّد.
// 2. Image.network كان من غير errorBuilder — لو رابط الصورة فشل (شائع مع
//    انقطاع النت) كان هيظهر أيقونة broken-image قبيحة. دلوقتي فيه fallback
//    لحرف اسم السائق زي ما بيحصل أصلًا لو مفيش صورة خالص.
// 3. الكارت الخارجي والزرارين بقوا AppCard/AppPrimaryButton الموحدين بدل
//    Container/ElevatedButton منفصلين، عشان ياخدوا نفس الظل والـ press
//    animation المتسقين في التطبيق كله. ======

class TayarDriverCard extends StatelessWidget {
  final String driverName;
  final double rating;
  final int trips;
  final double price;
  final String distance;
  final String time;
  final String vehicleType;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final String? driverImage;

  const TayarDriverCard({
    super.key,
    required this.driverName,
    required this.rating,
    required this.trips,
    required this.price,
    required this.distance,
    required this.time,
    required this.vehicleType,
    required this.onAccept,
    required this.onReject,
    this.driverImage,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      padding: EdgeInsets.zero,
      glass: true,
      shadowStyle: AppCardShadow.elevated,
      radius: AppRadius.xxl,
      child: Column(
        children: [
          // صف معلومات السائق
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                // الأفاتار
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [TayarColors.primary, TayarColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: driverImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Image.network(
                            driverImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _AvatarFallback(driverName: driverName),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                      : _AvatarFallback(driverName: driverName),
                ),
                const SizedBox(width: AppSpacing.md),

                // الاسم والتقييم
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: TayarColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: TayarColors.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  rating.toString(),
                                  style: const TextStyle(
                                    color: TayarColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              '$trips رحلة',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: context.textGreyColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // السعر — كبير وبولد (أسلوب inDrive)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(price.toStringAsFixed(0), style: TayarStatTextStyles.statSmall),
                    Text(
                      'ج.م',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textGreyColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(color: context.dividerColor2, height: 1),

          // صف المسافة والوقت ونوع المركبة
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                _InfoChip(icon: Icons.location_on_outlined, label: distance),
                const SizedBox(width: AppSpacing.md),
                _InfoChip(icon: Icons.access_time_rounded, label: time),
                const SizedBox(width: AppSpacing.md),
                _InfoChip(icon: Icons.two_wheeler, label: vehicleType),
              ],
            ),
          ),

          // زرارين الإجراء
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppPrimaryButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      onReject();
                    },
                    variant: AppButtonVariant.secondary,
                    child: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: AppPrimaryButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onAccept();
                    },
                    variant: AppButtonVariant.primary,
                    child: const Text('قبول العرض'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String driverName;
  const _AvatarFallback({required this.driverName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        driverName.isNotEmpty ? driverName[0] : '؟',
        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: context.dividerColor2,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.textGreyColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.textGreyColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
