import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== شاشة "محفظتي" للراكب: الرصيد الحالي + سجل الحركات - نفس فكرة
// DriverWalletTab بالظبط، بس من غير زرار شحن (رصيد الراكب بيتزود من
// الأدمن بس، مفيش شحن ذاتي زي الطيار) ======
class PassengerWalletScreen extends StatelessWidget {
  const PassengerWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(loc.myWalletLabel, style: TextStyle(color: context.textColor)),
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnapshot) {
                final balance =
                    (userSnapshot.data?.data()?['walletBalance'] as num?)
                        ?.toDouble() ??
                    0;

                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  children: [
                    // ====== كارت الرصيد الحالي ======
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      decoration: BoxDecoration(
                        color: TayarColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        border: Border.all(
                          color: TayarColors.primary.withValues(alpha: 0.4),
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
                              color: TayarColors.primary,
                            ),
                          ),
                        ],
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
                          .collection('users')
                          .doc(uid)
                          .collection('walletTransactions')
                          .orderBy('createdAt', descending: true)
                          .limit(50)
                          .snapshots(),
                      builder: (context, txnSnapshot) {
                        if (!txnSnapshot.hasData) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.xl,
                              ),
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
                              .map(
                                (doc) => PassengerWalletTransactionTile(
                                  data: doc.data(),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// ====== سطر واحد في سجل حركات محفظة الراكب (خصم رحلة أو رصيد ممنوح من
// الأدمن) - نفس فكرة WalletTransactionTile بتاعة الطيار ======
class PassengerWalletTransactionTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const PassengerWalletTransactionTile({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final type = data['type'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final isDeduction = type == 'trip_payment' || amount < 0;

    final label = isDeduction
        ? loc.walletTripPaymentLabel
        : loc.walletAdminCreditLabel;
    final icon = isDeduction
        ? Icons.two_wheeler
        : Icons.card_giftcard_outlined;
    final color = isDeduction ? TayarColors.error : TayarColors.success;
    final sign = isDeduction ? '-' : '+';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
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
            '$sign${loc.currencyEGP(amount.abs().toStringAsFixed(0))}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
