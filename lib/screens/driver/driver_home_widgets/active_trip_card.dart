import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show paymentMethodDisplay;
import 'package:tayay_app/screens/passenger/trip_chat_screen.dart';
import 'package:tayay_app/services/call_invitation_helper.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== كارت الرحلة النشطة فوق قائمة الطلبات + زرار التواصل (شات/مكالمة) ======
// (كانت قبل كده private classes جوه driver_home_screen.dart واتقسمت في ملف منفصل)
class ActiveTripCard extends StatelessWidget {
  final String orderId;
  final String customerId;
  final String customerName;
  final String pickupAddress;
  final String destinationAddress;
  final double fare;
  final String paymentMethod;
  final bool inProgress;
  final VoidCallback onStart;
  final VoidCallback onComplete;
  final VoidCallback onOpenTracking;

  const ActiveTripCard({
    super.key,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.fare,
    required this.paymentMethod,
    required this.inProgress,
    required this.onStart,
    required this.onComplete,
    required this.onOpenTracking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        0,
      ),
      decoration: BoxDecoration(
        color: TayarColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: TayarColors.primary.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ====== منطقة قابلة للضغط: بتفتح شاشة الخريطة والتتبع اللحظي ======
          InkWell(
            onTap: onOpenTracking,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          inProgress
                              ? AppLocalizations.of(
                                  context,
                                )!.tripInProgressLabel
                              : AppLocalizations.of(
                                  context,
                                )!.tripAcceptedWaitingLabel,
                          style: const TextStyle(
                            color: TayarColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.map_outlined,
                        color: TayarColors.primary.withValues(alpha: 0.8),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '$pickupAddress ← $destinationAddress',
                    style: TextStyle(color: context.textColor, fontSize: 14),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.currencyEGP(fare.toStringAsFixed(0)),
                        style: TextStyle(
                          color: context.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Icon(
                        Icons.payments_outlined,
                        color: context.textColor.withValues(alpha: 0.7),
                        size: 14,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        paymentMethodDisplay(context, paymentMethod),
                        style: TextStyle(
                          color: context.textColor.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ====== زرارين التواصل مع الراكب: شات ومكالمة صوتية ======
                Row(
                  children: [
                    Expanded(
                      child: DriverContactButton(
                        icon: Icons.chat_bubble_outline,
                        label: AppLocalizations.of(
                          context,
                        )!.chatWithPassengerLabel,
                        onTap: () {
                          Navigator.push(
                            context,
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
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: DriverContactButton(
                        icon: Icons.call_outlined,
                        label: AppLocalizations.of(context)!.callPassengerLabel,
                        onTap: () async {
                          try {
                            await sendCallInvitation(
                              calleeId: customerId,
                              calleeName: customerName,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تعذر بدء المكالمة: $e'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: inProgress ? onComplete : onStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TayarColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                    ),
                    child: Text(
                      inProgress
                          ? AppLocalizations.of(context)!.endTrip
                          : AppLocalizations.of(context)!.startTrip,
                      style: TextStyle(
                        color: context.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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

// ====== زرار موحّد لأزرار "شات" و"مكالمة" في كارت الرحلة النشطة للطيار ======
class DriverContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const DriverContactButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: TayarColors.primary.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: TayarColors.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: TayarColors.primary, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Text(
              label,
              style: const TextStyle(
                color: TayarColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

