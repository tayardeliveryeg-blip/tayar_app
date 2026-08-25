import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart' show paymentMethodDisplay;
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';

class OrderRequestCard extends StatelessWidget {
  final String pickupAddress;
  final String destinationAddress;
  final double distanceKm;
  final int durationMin;
  final double proposedFare;
  final String paymentMethod;
  final bool alreadyOffered;
  final DateTime? scheduledFor;
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
    this.scheduledFor,
    required this.onQuickAccept,
    required this.onCustomOffer,
    this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return AppCard(
      radius: AppRadius.xl,
      padding: EdgeInsets.zero,
      showShadow: false,
      border: Border.all(color: TayarColors.primary.withValues(alpha: 0.25)),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onOpenDetails,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (scheduledFor != null) ...[
                AppCard(
                  color: TayarColors.primary.withValues(alpha: 0.15),
                  radius: AppRadius.sm,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                  showShadow: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, color: TayarColors.primary, size: 13),
                      const SizedBox(width: AppSpacing.xs),
                      Text(loc.scheduledForLabel(formatScheduledForDisplay(scheduledFor!)), style: textTheme.labelSmall?.copyWith(color: TayarColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              Row(
                children: [
                  const Icon(Icons.location_on, color: TayarColors.primary, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(pickupAddress, style: textTheme.bodyMedium?.copyWith(color: context.textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(children: [const SizedBox(width: AppSpacing.sm), SizedBox(height: 14, child: VerticalDivider(color: TayarColors.divider, thickness: 2))]),
              ),
              Row(
                children: [
                  const Icon(Icons.flag, color: TayarColors.primary, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text(destinationAddress, style: textTheme.bodyMedium?.copyWith(color: context.textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(loc.distanceDurationLabel(distanceKm.toStringAsFixed(1), durationMin), style: textTheme.bodySmall?.copyWith(color: context.textGreyColor)),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(loc.currencyEGP(proposedFare.toStringAsFixed(0)), style: textTheme.titleMedium?.copyWith(color: TayarColors.primary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppSpacing.xxs),
                      AppCard(
                        color: context.textColor.withValues(alpha: 0.08),
                        radius: AppRadius.xxl,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                        showShadow: false,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.payments_outlined, color: context.textGreyColor, size: 12),
                            const SizedBox(width: AppSpacing.xs),
                            Text(paymentMethodDisplay(context, paymentMethod), style: textTheme.labelSmall?.copyWith(color: context.textGreyColor)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (alreadyOffered)
                Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm), child: Text(loc.offerSentAlreadyLabel, style: textTheme.bodyMedium?.copyWith(color: context.textGreyColor))))
              else
                Row(
                  children: [
                    Expanded(
                      child: AppPrimaryButton(
                        onPressed: onCustomOffer,
                        variant: AppButtonVariant.outline,
                        size: AppButtonSize.medium,
                        child: Text(loc.offerCustomButton, style: textTheme.labelLarge?.copyWith(color: TayarColors.primary)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppPrimaryButton(
                        onPressed: onQuickAccept,
                        variant: AppButtonVariant.primary,
                        size: AppButtonSize.medium,
                        child: Text(loc.acceptProposedPrice, style: textTheme.labelLarge?.copyWith(color: context.onPrimaryColor)),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String formatScheduledForDisplay(DateTime dt) {
  return '${_twoDigits(dt.day)}/${_twoDigits(dt.month)} - ${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');
