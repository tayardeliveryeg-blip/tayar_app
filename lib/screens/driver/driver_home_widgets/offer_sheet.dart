import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/services/fare_negotiation_rules.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== شيت تقديم عرض بسعر مخصص من السائق على طلب ======
// (كانت قبل كده private classes جوه driver_home_screen.dart واتقسمت في ملف منفصل)
class OfferSheet extends StatefulWidget {
  final double proposedFare;
  final double initialFare;
  final String pickupAddress;
  final String destinationAddress;
  final double distanceKm;
  final ValueChanged<double> onSubmit;

  const OfferSheet({
    super.key,
    required this.proposedFare,
    required this.initialFare,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.distanceKm,
    required this.onSubmit,
  });

  @override
  State<OfferSheet> createState() => OfferSheetState();
}

class OfferSheetState extends State<OfferSheet> {
  late double _price;
  static const double _step = 5.0;

  // ====== نفس الحدود المطبّقة في شاشة الراكب (searching_offers_screen.dart)،
  // محسوبة على initialFare الثابت مش على أي قيمة متغيّرة ======
  double get _minPrice => FareNegotiationRules.minFareFor(widget.initialFare);
  double get _maxPrice => FareNegotiationRules.maxFareFor(widget.initialFare);

  @override
  void initState() {
    super.initState();
    _price = widget.proposedFare.clamp(_minPrice, _maxPrice).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        top: AppSpacing.xl,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.handleColor,
              borderRadius: BorderRadius.circular(AppRadius.handle),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${widget.pickupAddress} ← ${widget.destinationAddress}',
            style: TextStyle(color: context.textColor, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            AppLocalizations.of(
              context,
            )!.distanceKmLabel(widget.distanceKm.toStringAsFixed(1)),
            style: TextStyle(color: context.textGreyColor, fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            AppLocalizations.of(context)!.setYourPriceLabel,
            style: TextStyle(color: context.textColor, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StepButton(
                icon: Icons.remove,
                onTap: _price <= _minPrice
                    ? null
                    : () => setState(() => _price -= _step),
              ),
              SizedBox(
                width: 130,
                child: Text(
                  AppLocalizations.of(
                    context,
                  )!.currencyEGP(_price.toStringAsFixed(0)),
                  textAlign: TextAlign.center,
                  style: TayarStatTextStyles.statSmall,
                ),
              ),
              StepButton(
                icon: Icons.add,
                onTap: _price >= _maxPrice
                    ? null
                    : () => setState(() => _price += _step),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => widget.onSubmit(_price),
              style: ElevatedButton.styleFrom(
                backgroundColor: TayarColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.submitOfferButton,
                style: TextStyle(
                  color: context.onPrimaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const StepButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled
              ? TayarColors.primary
              : TayarColors.primary.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: context.onPrimaryColor, size: 20),
      ),
    );
  }
}

