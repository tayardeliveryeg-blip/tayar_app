import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart' show paymentMethodDisplay;
import 'package:tayay_app/screens/passenger/trip_chat_screen.dart';
import 'package:tayay_app/services/call_invitation_helper.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/widgets/contact_action_button.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';

class TripDetailsCard extends StatelessWidget {
  final bool inProgress;
  final String orderId;
  final String customerId;
  final String customerName;
  final double distanceKm;
  final int durationMin;
  final double acceptedFare;
  final double proposedFare;
  final String pickupAddress;
  final String destinationAddress;
  final String paymentMethod;
  final VoidCallback onStartTrip;
  final VoidCallback onCompleteTrip;

  const TripDetailsCard({
    super.key,
    required this.inProgress,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.distanceKm,
    required this.durationMin,
    required this.acceptedFare,
    required this.proposedFare,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.paymentMethod,
    required this.onStartTrip,
    required this.onCompleteTrip,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.xl),
            topRight: Radius.circular(AppRadius.xl),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.textGreyColor,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                inProgress ? loc.tripInProgressLabel : loc.tripAcceptedWaitingLabel,
                style: textTheme.labelLarge?.copyWith(color: TayarColors.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: TayarColors.primary,
                    child: Icon(Icons.person, color: context.onPrimaryColor),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(customerName, style: textTheme.titleSmall?.copyWith(color: context.textColor, fontWeight: FontWeight.bold)),
                        Text(loc.distanceDurationLabel(distanceKm.toStringAsFixed(1), durationMin), style: textTheme.bodySmall?.copyWith(color: context.textGreyColor)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(loc.currencyEGP(acceptedFare.toStringAsFixed(0)), style: textTheme.titleMedium?.copyWith(color: TayarColors.primary, fontWeight: FontWeight.bold)),
                      if (proposedFare > 0 && proposedFare != acceptedFare)
                        Text(loc.originalProposedFareLabel(proposedFare.toStringAsFixed(0)), style: textTheme.bodySmall?.copyWith(color: context.textGreyColor)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                radius: AppRadius.md,
                showShadow: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.location_on, color: TayarColors.primary, size: 14),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(pickupAddress, style: textTheme.bodyMedium?.copyWith(color: context.textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                      child: SizedBox(height: 12, child: VerticalDivider(color: context.dividerColor2, thickness: 2)),
                    ),
                    Row(children: [
                      const Icon(Icons.flag, color: TayarColors.primary, size: 14),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(destinationAddress, style: textTheme.bodyMedium?.copyWith(color: context.textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: AppSpacing.sm),
                    Row(children: [
                      Icon(Icons.payments_outlined, color: context.textGreyColor, size: 14),
                      const SizedBox(width: AppSpacing.xs),
                      Text(paymentMethodDisplay(context, paymentMethod), style: textTheme.bodySmall?.copyWith(color: context.textGreyColor)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: ContactActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: loc.chatWithPassengerLabel,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TripChatScreen(orderId: orderId, otherPartyName: customerName))),
                  )),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: ContactActionButton(
                    icon: Icons.call_outlined,
                    label: loc.callPassengerLabel,
                    onTap: () async {
                      try {
                        await sendCallInvitation(calleeId: customerId, calleeName: customerName);
                      } catch (e) {
                        if (context.mounted) TayarToast.show(context, 'تعذر بدء المكالمة: $e', type: ToastType.error);
                      }
                    },
                  )),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  onPressed: inProgress ? onCompleteTrip : onStartTrip,
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.medium,
                  child: Text(
                    inProgress ? loc.endTrip : loc.startTrip,
                    style: textTheme.labelLarge?.copyWith(color: context.onPrimaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
