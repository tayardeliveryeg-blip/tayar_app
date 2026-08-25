import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/driver/driver_wallet_topup_screen.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/widgets/empty_state.dart';
import 'package:tayay_app/widgets/tayar_shimmer.dart';

class DriverWalletTab extends StatelessWidget {
  final String driverId;
  const DriverWalletTab({super.key, required this.driverId});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('drivers').doc(driverId).snapshots(),
      builder: (context, driverSnapshot) {
        final balance = (driverSnapshot.data?.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
        final isNegative = balance < 0;
        final balanceColor = isNegative ? TayarColors.error : TayarColors.primary;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            AppCard(
              radius: AppRadius.xxl,
              padding: const EdgeInsets.all(AppSpacing.xxl),
              showShadow: false,
              color: balanceColor.withValues(alpha: 0.12),
              border: Border.all(color: balanceColor.withValues(alpha: 0.4)),
              child: Column(
                children: [
                  Text(loc.availableBalance, style: textTheme.bodyMedium?.copyWith(color: context.textGreyColor)),
                  const SizedBox(height: AppSpacing.sm),
                  Text(loc.currencyEGP(balance.toStringAsFixed(0)), style: TayarStatTextStyles.statMedium.copyWith(color: balanceColor)),
                  if (isNegative) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(loc.negativeWalletBalanceNote, textAlign: TextAlign.center, style: textTheme.bodySmall?.copyWith(color: TayarColors.error)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppPrimaryButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverWalletTopupScreen())),
              variant: AppButtonVariant.primary,
              size: AppButtonSize.medium,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_card_outlined, color: context.onPrimaryColor),
                  const SizedBox(width: AppSpacing.sm),
                  Text(loc.topUpWalletButton, style: textTheme.labelLarge?.copyWith(color: context.onPrimaryColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(loc.walletTransactionsTitle, style: textTheme.titleMedium?.copyWith(color: context.textColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.md),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('drivers').doc(driverId).collection('walletTransactions').orderBy('createdAt', descending: true).limit(50).snapshots(),
              builder: (context, txnSnapshot) {
                if (!txnSnapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: TayarShimmer.list(count: 3),
                  );
                }
                final docs = txnSnapshot.data!.docs;
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: EmptyState(
                      icon: Icons.account_balance_wallet_outlined,
                      title: loc.noWalletTransactionsLabel,
                    ),
                  );
                }
                return Column(children: docs.map((doc) => WalletTransactionTile(data: doc.data())).toList());
              },
            ),
          ],
        );
      },
    );
  }
}

class WalletTransactionTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const WalletTransactionTile({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final type = data['type'] as String? ?? '';
    final status = data['status'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final rejectionReason = data['rejectionReason'] as String?;
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
    final displayAmount = type == 'commission' ? amount : amount.abs();
    final sign = displayAmount < 0 || type == 'commission' ? '' : '+';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.lg),
        showShadow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: Text(label, style: textTheme.bodyMedium?.copyWith(color: context.textColor))),
                Text('$sign${loc.currencyEGP(displayAmount.abs().toStringAsFixed(0))}', style: textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            if (status == 'rejected' && rejectionReason != null && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xxl),
                child: Text(rejectionReason, style: textTheme.bodySmall?.copyWith(color: context.textGreyColor)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
