import 'package:flutter/material.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/l10n/generated/app_localizations.dart';

// ====== كارت اقتراح رفع السعر بعد ما البحث ياخد وقت طويل ======
// (كانت private class _RaiseFareCard جوه searching_offers_screen.dart)
class RaiseFareCard extends StatelessWidget {
  final double currentFare;
  final double suggestedFare;
  final VoidCallback onRaiseFare;
  final VoidCallback onDismiss;

  const RaiseFareCard({
    super.key,
    required this.currentFare,
    required this.suggestedFare,
    required this.onRaiseFare,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            // سبيسر فاضي بنفس عرض زرار الإغلاق عشان النص يتزن في النص بالظبط
            const SizedBox(width: 48),
            Expanded(
              child: Text(
                loc.tryRaisingFareTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: context.textGreyColor, size: 20),
              onPressed: onDismiss,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          loc.raiseFareHintBody,
          style: TextStyle(color: context.textGreyColor, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onRaiseFare,
            style: ElevatedButton.styleFrom(
              backgroundColor: TayarColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              loc.searchWithFareLabel(suggestedFare.toStringAsFixed(0)),
              style: TextStyle(
                color: context.onPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ====== زرار +/- لتعديل السعر ======
// (كانت private class _FareStepButton جوه searching_offers_screen.dart)
class FareStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const FareStepButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? context.cardColor
              : context.cardColor.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: TayarColors.primary.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: context.textColor, size: 20),
      ),
    );
  }
}

// ====== كارت عرض الطيار الواحد ======
// (كانت private class _OfferCard جوه searching_offers_screen.dart)
class OfferCard extends StatelessWidget {
  final String driverName;
  final double? rating;
  final double price;
  final bool isProcessing;
  final VoidCallback onAccept;

  const OfferCard({
    super.key,
    required this.driverName,
    required this.rating,
    required this.price,
    required this.isProcessing,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TayarColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: TayarColors.primary,
            child: Icon(Icons.person, color: context.onPrimaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                if (rating != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: TayarColors.primary,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: TextStyle(
                          color: context.textGreyColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    AppLocalizations.of(context)!.newDriverLabel,
                    style: TextStyle(
                      color: context.textGreyColor,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            AppLocalizations.of(context)!.currencyEGP(price.toStringAsFixed(0)),
            style: const TextStyle(
              color: TayarColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: isProcessing ? null : onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: TayarColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.acceptButton,
                style: TextStyle(color: context.onPrimaryColor, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== دائرة بروفايل طيار واحد بتظهر بأنيميشن بسيط (Scale) أول مرة تتبني ======
// (كانت private class _OfferAvatarPop جوه searching_offers_screen.dart)
class OfferAvatarPop extends StatelessWidget {
  final String? photoUrl;
  final double size;

  const OfferAvatarPop({super.key, required this.photoUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.bgColor, width: 2),
        ),
        child: CircleAvatar(
          backgroundColor: TayarColors.primary,
          backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
              ? NetworkImage(photoUrl!)
              : null,
          child: (photoUrl == null || photoUrl!.isEmpty)
              ? Icon(Icons.person, color: context.onPrimaryColor, size: 16)
              : null,
        ),
      ),
    );
  }
}

// ====== إشعار عرض جديد: بيطلع تحت لما طيار يعمل عرض، وفيه قبول أو رفض ======
// (كانت private class _OfferNotificationSheet جوه searching_offers_screen.dart)
class OfferNotificationSheet extends StatelessWidget {
  final String driverName;
  final double? rating;
  final double price;
  final String? photoUrl;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const OfferNotificationSheet({
    super.key,
    required this.driverName,
    required this.rating,
    required this.price,
    required this.photoUrl,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 24),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: TayarColors.primary,
                      backgroundImage:
                          (photoUrl != null && photoUrl!.isNotEmpty)
                          ? NetworkImage(photoUrl!)
                          : null,
                      child: (photoUrl == null || photoUrl!.isEmpty)
                          ? Icon(
                              Icons.person,
                              color: context.onPrimaryColor,
                              size: 26,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.newOfferFromDriverLabel(driverName),
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (rating != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: TayarColors.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating!.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: context.textGreyColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              AppLocalizations.of(context)!.newDriverLabel,
                              style: TextStyle(
                                color: context.textGreyColor,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      loc.currencyEGP(price.toStringAsFixed(0)),
                      style: const TextStyle(
                        color: TayarColors.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: context.textGreyColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            loc.rejectButton,
                            style: TextStyle(color: context.textGreyColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TayarColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            loc.acceptButton,
                            style: TextStyle(
                              color: context.onPrimaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
