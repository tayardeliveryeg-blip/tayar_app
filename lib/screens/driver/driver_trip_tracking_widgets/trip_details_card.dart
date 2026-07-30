import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show paymentMethodDisplay;
import 'package:tayay_app/screens/passenger/trip_chat_screen.dart';
import 'package:tayay_app/services/call_invitation_helper.dart';
import 'package:tayay_app/widgets/contact_action_button.dart';

// ====== كارت تفاصيل الرحلة أسفل شاشة تتبع الطيار: بيانات الراكب، العنوانين،
// طريقة الدفع، زرارين التواصل (شات/مكالمة)، وزرار بدء/إنهاء الرحلة ======
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

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
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
                  color: Colors.grey.shade700,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                inProgress
                    ? loc.tripInProgressLabel
                    : loc.tripAcceptedWaitingLabel,
                style: const TextStyle(
                  color: TayarColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: TayarColors.primary,
                    child: Icon(Icons.person, color: context.onPrimaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customerName,
                          style: TextStyle(
                            color: context.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          loc.distanceDurationLabel(
                            distanceKm.toStringAsFixed(1),
                            durationMin,
                          ),
                          style: TextStyle(
                            color: context.textGreyColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        loc.currencyEGP(acceptedFare.toStringAsFixed(0)),
                        style: const TextStyle(
                          color: TayarColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      if (proposedFare > 0 && proposedFare != acceptedFare)
                        Text(
                          loc.originalProposedFareLabel(
                            proposedFare.toStringAsFixed(0),
                          ),
                          style: TextStyle(
                            color: context.textGreyColor,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ====== العنوانين ======
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: TayarColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pickupAddress,
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        height: 12,
                        child: VerticalDivider(
                          color: context.dividerColor2,
                          thickness: 2,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.flag,
                          color: TayarColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            destinationAddress,
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          color: context.textColor.withValues(alpha: 0.7),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          paymentMethodDisplay(context, paymentMethod),
                          style: TextStyle(
                            color: context.textColor.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ====== زرارين التواصل مع الراكب ======
              Row(
                children: [
                  Expanded(
                    child: ContactActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: loc.chatWithPassengerLabel,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TripChatScreen(
                              orderId: orderId,
                              otherPartyName: customerName,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ContactActionButton(
                      icon: Icons.call_outlined,
                      label: loc.callPassengerLabel,
                      onTap: () async {
                        try {
                          await sendCallInvitation(
                            calleeId: customerId,
                            calleeName: customerName,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('تعذر بدء المكالمة: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: inProgress ? onCompleteTrip : onStartTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TayarColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    inProgress ? loc.endTrip : loc.startTrip,
                    style: TextStyle(
                      color: context.onPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
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
