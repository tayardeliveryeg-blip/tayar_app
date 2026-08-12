import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/driver/driver_wallet_topup_screen.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';

// ====== تبويب "محفظتي": الرصيد الصافي بعد عمولة الشركة + سجل الحركات ======
// (كانت قبل كده private classes جوه driver_home_screen.dart واتقسمت في ملف منفصل)
class DriverWalletTab extends StatelessWidget {
  final String driverId;
  const DriverWalletTab({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('drivers')
          .doc(driverId)
          .snapshots(),
      builder: (context, driverSnapshot) {
        final balance =
            (driverSnapshot.data?.data()?['walletBalance'] as num?)
                ?.toDouble() ??
            0;
        final isNegative = balance < 0;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // ====== كارت الرصيد الحالي ======
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: (isNegative ? TayarColors.error : TayarColors.primary)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                border: Border.all(
                  color: (isNegative ? TayarColors.error : TayarColors.primary)
                      .withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    loc.availableBalance,
                    style: TextStyle(
                      color: context.textGreyColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    loc.currencyEGP(balance.toStringAsFixed(0)),
                    style: TayarStatTextStyles.statMedium.copyWith(
                      color: isNegative
                          ? TayarColors.error
                          : TayarColors.primary,
                    ),
                  ),
                  if (isNegative) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      loc.negativeWalletBalanceNote,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TayarColors.error, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ====== زرار شحن المحفظة ======
            SizedBox(
              height: 50,
              child: AppPrimaryButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: TayarColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DriverWalletTopupScreen(),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_card_outlined,
                      color: context.onPrimaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loc.topUpWalletButton,
                      style: TextStyle(
                        color: context.onPrimaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            // ====== سجل المعاملات ======
            Text(
              loc.walletTransactionsTitle,
              style: TextStyle(
                color: context.textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('drivers')
                  .doc(driverId)
                  .collection('walletTransactions')
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, txnSnapshot) {
                if (!txnSnapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                      child: CircularProgressIndicator(
                        color: TayarColors.primary,
                      ),
                    ),
                  );
                }
                final docs = txnSnapshot.data!.docs;
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Center(
                      child: Text(
                        loc.noWalletTransactionsLabel,
                        style: TextStyle(color: context.textGreyColor),
                      ),
                    ),
                  );
                }
                return Column(
                  children: docs
                      .map((doc) => WalletTransactionTile(data: doc.data()))
                      .toList(),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ====== سطر واحد في سجل معاملات المحفظة (عمولة رحلة أو طلب شحن) ======
class WalletTransactionTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const WalletTransactionTile({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final type = data['type'] as String? ?? '';
    final status = data['status'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;

    late final String label;
    late final IconData icon;
    late final Color color;

    if (type == 'commission') {
      label = loc.walletCommissionTransactionLabel;
      icon = Icons.percent;
      color = TayarColors.error;
    } else if (status == 'approved') {
      label = loc.walletTopupApprovedLabel;
      icon = Icons.check_circle_outline;
      color = TayarColors.success;
    } else if (status == 'rejected') {
      label = loc.walletTopupRejectedLabel;
      icon = Icons.cancel_outlined;
      color = TayarColors.error;
    } else {
      label = loc.walletTopupPendingLabel;
      icon = Icons.hourglass_top_outlined;
      color = TayarColors.warning;
    }

    final displayAmount = type == 'commission'
        ? amount // من الأساس بالسالب في الداتا
        : amount.abs();
    final sign = displayAmount < 0 || type == 'commission' ? '' : '+';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.lg),
        showShadow: false,
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: context.textColor, fontSize: 14),
              ),
            ),
            Text(
              '$sign${loc.currencyEGP(displayAmount.abs().toStringAsFixed(0))}',
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

