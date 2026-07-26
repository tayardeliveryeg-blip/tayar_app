import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show paymentMethodDisplay;
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== كارت طلب واحد في تبويب "الطلبات" الخاص بالسائق ======
// (كان قبل كده private class جوه driver_home_screen.dart واتقسم في ملف منفصل)
class OrderRequestCard extends StatelessWidget {
  final String pickupAddress;
  final String destinationAddress;
  final double distanceKm;
  final int durationMin;
  final double proposedFare;
  final String paymentMethod;
  final bool alreadyOffered;
  final VoidCallback? onQuickAccept;
  final VoidCallback? onCustomOffer;
  final VoidCallback? onOpenDetails;

  const OrderRequestCard({
    super.key,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.distanceKm,
    required this.durationMin,
    required this.proposedFare,
    required this.paymentMethod,
    required this.alreadyOffered,
    required this.onQuickAccept,
    required this.onCustomOffer,
    this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.xl),
      onTap: onOpenDetails,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: TayarColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on,
                  color: TayarColors.primary,
                  size: 16,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    pickupAddress,
                    style: TextStyle(color: context.textColor, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                children: [
                  SizedBox(width: AppSpacing.sm),
                  SizedBox(
                    height: 14,
                    child: VerticalDivider(
                      color: context.dividerColor2,
                      thickness: 2,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                const Icon(Icons.flag, color: TayarColors.primary, size: 16),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    destinationAddress,
                    style: TextStyle(color: context.textColor, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.distanceDurationLabel(
                    distanceKm.toStringAsFixed(1),
                    durationMin,
                  ),
                  style: TextStyle(color: context.textGreyColor, fontSize: 12),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppLocalizations.of(
                        context,
                      )!.currencyEGP(proposedFare.toStringAsFixed(0)),
                      style: const TextStyle(
                        color: TayarColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: context.textColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            color: context.textGreyColor,
                            size: 12,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            paymentMethodDisplay(context, paymentMethod),
                            style: TextStyle(
                              color: context.textGreyColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (alreadyOffered)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Text(
                    AppLocalizations.of(context)!.offerSentAlreadyLabel,
                    style: TextStyle(
                      color: context.textGreyColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCustomOffer,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        side: const BorderSide(color: TayarColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.offerCustomButton,
                        style: TextStyle(color: TayarColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onQuickAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TayarColors.primary,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.md,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.acceptProposedPrice,
                        style: TextStyle(color: context.textColor),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
