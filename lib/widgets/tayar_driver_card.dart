import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';

// ====== Driver Offer Card — كارت عرض طيار بأسلوب inDrive، كل المعلومات ظاهرة ======
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
//    لحرف اسم الطيار زي ما بيحصل أصلًا لو مفيش صورة خالص.
// 3. الكارت الخارجي والزرارين بقوا AppCard/AppPrimaryButton الموحدين بدل
//    Container/ElevatedButton منفصلين، عشان ياخدوا نفس الظل والـ press
//    animation المتسقين في التطبيق كله. ======

class TayarDriverCard extends StatelessWidget {
  final String driverName;
  // ====== [تحديث] rating/trips/distance/time/vehicleType بقوا اختياريين.
  // مش كل شاشة في المشروع عندها كل البيانات دي متاحة فعليًا (مثلًا شاشة
  // searching_offers_screen.dart بيوصلها driverName/rating/price/photoUrl
  // بس من الـ offer doc، من غير مسافة أو وقت وصول أو نوع مركبة لكل عرض).
  // بدل ما نضطر نخترع قيم وهمية عشان الكارت "يبان كامل"، أي حقل مش
  // متمرر بيختفي من الواجهة تلقائيًا بدل ما يظهر فاضي أو بأرقام مغلوطة ======
  final double? rating;
  final int? trips;
  final double price;
  final String? distance;
  final String? time;
  final String? vehicleType;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final String? driverImage;

  const TayarDriverCard({
    super.key,
    required this.driverName,
    required this.price,
    required this.onAccept,
    required this.onReject,
    this.rating,
    this.trips,
    this.distance,
    this.time,
    this.vehicleType,
    this.driverImage,
  });

  bool get _hasInfoChips => distance != null || time != null || vehicleType != null;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      padding: EdgeInsets.zero,
      glass: true,
      shadowStyle: AppCardShadow.elevated,
      radius: AppRadius.xxl,
      child: Column(
        children: [
          // صف معلومات الطيار
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
                            frameBuilder:
                                (context, child, frame, wasSynchronouslyLoaded) {
                                  if (wasSynchronouslyLoaded) return child;
                                  return AnimatedOpacity(
                                    opacity: frame == null ? 0 : 1,
                                    duration: const Duration(
                                      milliseconds: 350,
                                    ),
                                    curve: Curves.easeOut,
                                    child: child,
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
                      // لو مفيش rating ولا trips خالص (زي طيار جديد لسه ماعملش
                      // رحلات)، الصف ده مبيتعرضش أصلًا بدل ما يبان فاضي.
                      if (rating != null || trips != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (rating != null)
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
                                      rating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: TayarColors.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Text(
                                loc.newDriverLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: context.textGreyColor,
                                ),
                              ),
                            if (trips != null) ...[
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
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // السعر — كبير وبولد (أسلوب inDrive). سطر واحد مترجم بالكامل
                // عبر currencyEGP بدل تقسيم الرقم والعملة يدويًا، لأن ترتيبهم
                // بيختلف بين العربي ("25 جنيه") والإنجليزي ("EGP 25").
                Text(
                  loc.currencyEGP(price.toStringAsFixed(0)),
                  style: TayarStatTextStyles.statSmall,
                ),
              ],
            ),
          ),

          // صف المسافة والوقت ونوع المركبة — بيظهر بس لو فيه بيانات فعلية
          // متمررة (شاشات زي البحث عن عروض حاليًا معهاش مسافة/وقت لكل عرض).
          if (_hasInfoChips) ...[
            Divider(color: context.dividerColor2, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  if (distance != null)
                    _InfoChip(icon: Icons.location_on_outlined, label: distance!),
                  if (distance != null && (time != null || vehicleType != null))
                    const SizedBox(width: AppSpacing.md),
                  if (time != null) _InfoChip(icon: Icons.access_time_rounded, label: time!),
                  if (time != null && vehicleType != null) const SizedBox(width: AppSpacing.md),
                  if (vehicleType != null)
                    _InfoChip(icon: Icons.two_wheeler, label: vehicleType!),
                ],
              ),
            ),
          ] else
            const SizedBox(height: AppSpacing.sm),

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
                    child: Text(loc.rejectButton),
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
                    child: Text(loc.acceptButton),
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