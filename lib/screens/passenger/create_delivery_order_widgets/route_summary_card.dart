import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/theme/theme_extensions.dart';

// ====== كارت المسافة/الوقت/السعر (بيظهر بعد ما نحدد الموقعين) - أو مؤشر
// تحميل لو المسار لسه بيتحسب ======
class RouteSummaryCard extends StatelessWidget {
  final bool isCalculating;
  final double? distanceKm;
  final double estimatedFare;

  const RouteSummaryCard({
    super.key,
    required this.isCalculating,
    required this.distanceKm,
    required this.estimatedFare,
  });

  @override
  Widget build(BuildContext context) {
    if (isCalculating) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: CircularProgressIndicator(color: TayarColors.primary),
        ),
      );
    }

    if (distanceKm == null) return const SizedBox.shrink();

    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TayarColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TayarColors.primary.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.distanceLabel,
                style: TextStyle(color: context.textGreyColor, fontSize: 14),
              ),
              Text(
                loc.distanceKmLabel(distanceKm!.toStringAsFixed(1)),
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Divider(color: context.dividerColor2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loc.estimatedFareLabel,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                loc.currencyEGP(estimatedFare.toStringAsFixed(0)),
                style: const TextStyle(
                  color: TayarColors.primary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
