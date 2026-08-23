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

                // ====== محفظة الطيار (drivers/{uid}) منفصلة تمامًا عن
                // رصيد الراكب فوق - بتتعرض هنا بس لو المستخدم مسجل كطيار
                // بالفعل. نفس المنطق اللي كان في _WalletSummaryCard بالشريط
                // الجانبي قبل كده، اتنقل هنا داخل شاشة المحفظة نفسها ======
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('drivers')
                      .doc(uid)
                      .snapshots(),
                  builder: (context, driverSnapshot) {
                    final isDriver = driverSnapshot.data?.exists ?? false;
                    final driverBalance =
                        (driverSnapshot.data?.data()?['walletBalance']
                                as num?)
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

                    // ====== كارت مستحقات الطيار - يظهر بس لو المستخدم
                    // مسجل كطيار، وبيودّي مباشرة لتبويب محفظة الطيار
                    // (DriverHomeScreen initialTab: 3) عند الضغط عليه ======
                    if (isDriver) ...[
                      const SizedBox(height: AppSpacing.md),
                      InkWell(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const DriverHomeScreen(initialTab: 3),
                          ),
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.xxl),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: (driverBalance < 0
                                    ? TayarColors.error
                                    : TayarColors.primary)
                                .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                              AppRadius.xxl,
                            ),
                            border: Border.all(
                              color:
                                  (driverBalance < 0
                                          ? TayarColors.error
                                          : TayarColors.primary)
                                      .withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.delivery_dining,
                                color: driverBalance < 0
                                    ? TayarColors.error
                                    : TayarColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  loc.walletSummaryDriverLabel,
                                  style: TextStyle(
                                    color: context.textColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Text(
                                loc.currencyEGP(
                                  driverBalance.toStringAsFixed(0),
                                ),
                                style: TextStyle(
                                  color: driverBalance < 0
                                      ? TayarColors.error
                                      : TayarColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                color: context.textGreyColor,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xxl),

                    // ====== كود الإحالة الشخصي - بيتحمل مرة واحدة (أو
                    // بيتولّد لو مش موجود قبل كده) ======
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
                              Text(
                                loc.myReferralCodeTitle,
                                style: TextStyle(
                                  color: context.textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loc.myReferralCodeSubtitle,
                                style: TextStyle(
                                  color: context.textGreyColor,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              if (code == null)
                                const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: TayarColors.primary,
                                    ),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppCard(
                                        color: TayarColors.primary
                                            .withValues(alpha: 0.1),
                                        radius: AppRadius.md,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.md,
                                          vertical: AppSpacing.sm,
                                        ),
                                        showShadow: false,
                                        child: Text(
                                          code,
                                          style: const TextStyle(
                                            color: TayarColors.primary,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.copy_rounded,
                                        color: context.textColor,
                                        size: 20,
                                      ),
                                      tooltip: loc.copyReferralCodeButton,
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: code),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              loc.referralCodeCopiedMessage,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.share_outlined,
                                        color: TayarColors.primary,
                                        size: 20,
                                      ),
                                      tooltip: loc.shareReferralCodeButton,
                                      onPressed: () {
                                        final message =
                                            '${loc.referralShareMessageIntro} $code';
                                        launchUrl(
                                          Uri.parse(
                                            'https://wa.me/?text=${Uri.encodeComponent(message)}',
                                          ),
                                          mode: LaunchMode.externalApplication,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ====== استخدام كود خصم أو كود إحالة ======
                    OutlinedButton.icon(
                      onPressed: () => _showRedeemCodeSheet(context, uid),
                      icon: const Icon(
                        Icons.redeem_outlined,
                        color: TayarColors.primary,
                      ),
                      label: Text(loc.redeemCodeSectionTitle),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TayarColors.primary,
                        side: const BorderSide(color: TayarColors.primary),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
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
                );
              },
            ),
    );
  }
}

// ====== بوتوم شيت بسيطة لاستخدام كود خصم أو كود إحالة - بتجرب الكود أول
// حاجة كـ promo code، ولو مش موجود بتجرب تاني كـ referral code، عشان
// المستخدم مش محتاج يعرف نوع الكود بنفسه ======
void _showRedeemCodeSheet(BuildContext context, String uid) {
  final loc = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  bool isSubmitting = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
    ),
    builder: (sheetContext) {
      return StatefulBuilder(
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
              // ====== لو الكود مش موجود كـ promo، نجرب نفس الكود كـ
              // referral code قبل ما نستسلم ونعرض خطأ ======
              if (e.message.contains('مش موجود')) {
                try {
                  amount = await redeemReferralCode(
                    code: code,
                    newUserId: uid,
                  );
                } on ReferralException catch (re) {
                  errorMessage = re.message;
                }
              } else {
                errorMessage = e.message;
              }
            }

            if (!sheetContext.mounted) return;
            setState(() => isSubmitting = false);

            if (amount != null) {
              Navigator.pop(sheetContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    loc.codeRedeemedSuccessMessage(amount.toStringAsFixed(0)),
                  ),
                  backgroundColor: TayarColors.success,
                ),
              );
            } else {
              ScaffoldMessenger.of(sheetContext).showSnackBar(
                SnackBar(
                  content: Text(errorMessage ?? loc.invalidCodeGenericError),
                  backgroundColor: TayarColors.error,
                ),
              );
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              top: AppSpacing.xl,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.redeemCodeSectionTitle,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    hintText: loc.enterCodeHint,
                    hintStyle: TextStyle(color: context.textGreyColor),
                    filled: true,
                    fillColor: context.bgColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    onPressed: isSubmitting ? null : submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TayarColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(loc.redeemCodeSubmitButton),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
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

    final String label;
    final IconData icon;
    if (type == 'promo_credit') {
      label = loc.walletPromoCreditLabel;
    } else if (type == 'referral_welcome_credit') {
      label = loc.walletReferralCreditLabel;
    } else if (isDeduction) {
      label = loc.walletTripPaymentLabel;
    } else {
      label = loc.walletAdminCreditLabel;
    }
    if (type == 'promo_credit') {
      icon = Icons.local_offer_outlined;
    } else if (type == 'referral_welcome_credit') {
      icon = Icons.group_add_outlined;
    } else if (isDeduction) {
      icon = Icons.two_wheeler;
    } else {
      icon = Icons.card_giftcard_outlined;
    }
    final color = isDeduction ? TayarColors.error : TayarColors.success;
    final sign = isDeduction ? '-' : '+';

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
              '$sign${loc.currencyEGP(amount.abs().toStringAsFixed(0))}',
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
