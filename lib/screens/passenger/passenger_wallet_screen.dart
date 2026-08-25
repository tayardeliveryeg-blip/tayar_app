import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/services/promo_service.dart';
import 'package:tayay_app/services/referral_service.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/screens/driver/driver_home_screen.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';
import 'package:tayay_app/widgets/empty_state.dart';
import 'package:tayay_app/widgets/tayar_shimmer.dart';

class PassengerWalletScreen extends StatelessWidget {
  const PassengerWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(loc.myWalletLabel, style: textTheme.titleLarge?.copyWith(color: context.textColor)),
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
              builder: (context, userSnapshot) {
                final balance = (userSnapshot.data?.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance.collection('drivers').doc(uid).snapshots(),
                  builder: (context, driverSnapshot) {
                    final isDriver = driverSnapshot.data?.exists ?? false;
                    final driverBalance = (driverSnapshot.data?.data()?['walletBalance'] as num?)?.toDouble() ?? 0;

                    return ListView(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      children: [
                        AppCard(
                          radius: AppRadius.xxl,
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          color: TayarColors.primary.withValues(alpha: 0.12),
                          border: Border.all(color: TayarColors.primary.withValues(alpha: 0.4)),
                          showShadow: false,
                          child: Column(
                            children: [
                              Text(loc.availableBalance, style: textTheme.bodyMedium?.copyWith(color: context.textGreyColor)),
                              const SizedBox(height: AppSpacing.sm),
                              Text(loc.currencyEGP(balance.toStringAsFixed(0)), style: TayarStatTextStyles.statMedium.copyWith(color: TayarColors.primary)),
                            ],
                          ),
                        ),
                        if (isDriver) ...[
                          const SizedBox(height: AppSpacing.md),
                          AppCard(
                            radius: AppRadius.xxl,
                            padding: EdgeInsets.zero,
                            showShadow: false,
                            child: InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverHomeScreen(initialTab: 3))),
                              borderRadius: BorderRadius.circular(AppRadius.xxl),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.lg),
                                child: Row(
                                  children: [
                                    Icon(Icons.delivery_dining, color: driverBalance < 0 ? TayarColors.error : TayarColors.primary),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(child: Text(loc.walletSummaryDriverLabel, style: textTheme.bodyMedium?.copyWith(color: context.textColor))),
                                    Text(loc.currencyEGP(driverBalance.toStringAsFixed(0)), style: textTheme.titleMedium?.copyWith(color: driverBalance < 0 ? TayarColors.error : TayarColors.primary, fontWeight: FontWeight.bold)),
                                    const SizedBox(width: AppSpacing.xs),
                                    Icon(Icons.chevron_right, color: context.textGreyColor, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                        FutureBuilder<String>(
                          future: ensureReferralCode(uid),
                          builder: (context, codeSnapshot) {
                            final code = codeSnapshot.data;
                            return AppCard(
                              radius: AppRadius.xl,
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              showShadow: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(loc.myReferralCodeTitle, style: textTheme.titleSmall?.copyWith(color: context.textColor, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(loc.myReferralCodeSubtitle, style: textTheme.bodySmall?.copyWith(color: context.textGreyColor)),
                                  const SizedBox(height: AppSpacing.md),
                                  if (code == null)
                                    const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: TayarColors.primary)))
                                  else
                                    Row(
                                      children: [
                                        Expanded(child: AppCard(color: TayarColors.primary.withValues(alpha: 0.1), radius: AppRadius.md, padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm), showShadow: false, child: Text(code, style: textTheme.titleSmall?.copyWith(color: TayarColors.primary, fontWeight: FontWeight.bold, letterSpacing: 1)))),
                                        IconButton(icon: Icon(Icons.copy_rounded, color: context.textColor, size: 20), tooltip: loc.copyReferralCodeButton, onPressed: () { Clipboard.setData(ClipboardData(text: code)); TayarToast.show(context, loc.referralCodeCopiedMessage, type: ToastType.success); }),
                                        IconButton(icon: const Icon(Icons.share_outlined, color: TayarColors.primary, size: 20), tooltip: loc.shareReferralCodeButton, onPressed: () { final message = '${loc.referralShareMessageIntro} $code'; launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}'), mode: LaunchMode.externalApplication); }),
                                      ],
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          child: AppPrimaryButton(
                            onPressed: () => _showRedeemCodeSheet(context, uid),
                            variant: AppButtonVariant.outline,
                            size: AppButtonSize.medium,
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.redeem_outlined), const SizedBox(width: AppSpacing.sm), Text(loc.redeemCodeSectionTitle)]),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        Text(loc.walletTransactionsTitle, style: textTheme.titleMedium?.copyWith(color: context.textColor, fontWeight: FontWeight.bold)),
                        const SizedBox(height: AppSpacing.md),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('walletTransactions').orderBy('createdAt', descending: true).limit(50).snapshots(),
                          builder: (context, txnSnapshot) {
                            if (!txnSnapshot.hasData) return Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl), child: TayarShimmer.list(count: 3));
                            final docs = txnSnapshot.data!.docs;
                            if (docs.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl), child: EmptyState(icon: Icons.account_balance_wallet_outlined, title: loc.noWalletTransactionsLabel));
                            return Column(children: docs.map((doc) => PassengerWalletTransactionTile(data: doc.data())).toList());
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

void _showRedeemCodeSheet(BuildContext context, String uid) {
  final loc = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  bool isSubmitting = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.cardColor,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl))),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) {
        Future<void> submit() async {
          final code = controller.text.trim();
          if (code.isEmpty) return;
          setState(() => isSubmitting = true);
          double? amount;
          String? errorMessage;
          try {
            amount = await redeemPromoCode(code: code, userId: uid);
          } on PromoCodeException catch (e) {
            if (e.message.contains('مش موجود')) {
              try {
                amount = await redeemReferralCode(code: code, newUserId: uid);
              } on ReferralException catch (re) { errorMessage = re.message; }
            } else { errorMessage = e.message; }
          }
          if (!sheetContext.mounted) return;
          setState(() => isSubmitting = false);
          if (amount != null) {
            Navigator.pop(sheetContext);
            TayarToast.show(context, loc.codeRedeemedSuccessMessage(amount.toStringAsFixed(0)), type: ToastType.success);
          } else {
            TayarToast.show(sheetContext, errorMessage ?? loc.invalidCodeGenericError, type: ToastType.error);
          }
        }

        final textTheme = Theme.of(sheetContext).textTheme;
        return Padding(
          padding: EdgeInsets.only(left: AppSpacing.xl, right: AppSpacing.xl, top: AppSpacing.xl, bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(loc.redeemCodeSectionTitle, style: textTheme.titleMedium?.copyWith(color: context.textColor, fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                style: textTheme.bodyLarge?.copyWith(color: context.textColor),
                decoration: InputDecoration(hintText: loc.enterCodeHint, hintStyle: textTheme.bodyLarge?.copyWith(color: context.textGreyColor), filled: true, fillColor: context.bgColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.lg), borderSide: BorderSide.none)),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(width: double.infinity, child: AppPrimaryButton(onPressed: isSubmitting ? null : submit, variant: AppButtonVariant.primary, size: AppButtonSize.medium, isLoading: isSubmitting, child: Text(loc.redeemCodeSubmitButton))),
            ],
          ),
        );
      },
    ),
  );
}

class PassengerWalletTransactionTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const PassengerWalletTransactionTile({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final type = data['type'] as String? ?? '';
    final amount = (data['amount'] as num?)?.toDouble() ?? 0;
    final isDeduction = type == 'trip_payment' || amount < 0;
    final String label;
    final IconData icon;
    if (type == 'promo_credit') { label = loc.walletPromoCreditLabel; icon = Icons.local_offer_outlined; }
    else if (type == 'referral_welcome_credit') { label = loc.walletReferralCreditLabel; icon = Icons.group_add_outlined; }
    else if (isDeduction) { label = loc.walletTripPaymentLabel; icon = Icons.two_wheeler; }
    else { label = loc.walletAdminCreditLabel; icon = Icons.card_giftcard_outlined; }
    final color = isDeduction ? TayarColors.error : TayarColors.success;
    final sign = isDeduction ? '-' : '+';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        radius: AppRadius.xl,
        padding: const EdgeInsets.all(AppSpacing.lg),
        showShadow: false,
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(label, style: textTheme.bodyMedium?.copyWith(color: context.textColor))),
            Text('$sign${loc.currencyEGP(amount.abs().toStringAsFixed(0))}', style: textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
