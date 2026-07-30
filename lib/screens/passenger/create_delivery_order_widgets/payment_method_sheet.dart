import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show paymentMethodDisplay;
import 'package:tayay_app/services/wallet_service.dart';

// ====== شريط اختيار طريقة الدفع (كاش / محفظة إلكترونية / إنستاباي) لشاشة
// إنشاء طلب "وصل طلباتي". بيرجع القيمة المختارة أو null لو المستخدم قفل
// الشريط من غير اختيار. المكالم هو المسؤول عن عمل setState بالقيمة الجديدة ======
Future<String?> showDeliveryPaymentMethodSheet(
  BuildContext context, {
  required String currentMethod,
  required double estimatedFare,
}) async {
  final loc = AppLocalizations.of(context)!;
  final options = <Map<String, dynamic>>[
    {'value': 'كاش', 'icon': Icons.payments_outlined},
    {
      'value': 'محفظة إلكترونية',
      'icon': Icons.account_balance_wallet_outlined,
    },
    {'value': 'إنستاباي', 'icon': Icons.bolt_outlined},
  ];

  // ====== رصيد المحفظة الحالي + مقارنته بالأجرة عشان نعرف نفعّل خيار
  // "محفظة إلكترونية" ولا نسيبه غير قابل للاختيار ======
  final uid = FirebaseAuth.instance.currentUser?.uid;
  double walletBalance = 0;
  if (uid != null) {
    try {
      walletBalance = await getPassengerWalletBalance(uid);
    } catch (_) {}
  }
  final walletCoversFare = walletBalance >= estimatedFare && estimatedFare > 0;

  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.bgColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
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
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  loc.choosePaymentMethodTitle,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...options.map((option) {
              final value = option['value'] as String;
              final label = paymentMethodDisplay(sheetContext, value);
              final isSelected = value == currentMethod;
              final isWalletOption = value == 'محفظة إلكترونية';
              final isDisabled = isWalletOption && !walletCoversFare;
              return ListTile(
                onTap: isDisabled
                    ? null
                    : () => Navigator.pop(sheetContext, value),
                leading: Icon(
                  option['icon'] as IconData,
                  color: isDisabled
                      ? context.textGreyColor.withValues(alpha: 0.4)
                      : isSelected
                      ? TayarColors.primary
                      : context.textGreyColor,
                ),
                title: Text(
                  label,
                  style: TextStyle(
                    color: isDisabled
                        ? context.textGreyColor.withValues(alpha: 0.5)
                        : context.textColor,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: isWalletOption
                    ? Text(
                        isDisabled
                            ? loc.walletInsufficientBalanceLabel
                            : loc.walletAvailableBalanceLabel(
                                walletBalance.toStringAsFixed(0),
                              ),
                        style: TextStyle(
                          color: isDisabled
                              ? Colors.redAccent
                              : context.textGreyColor,
                          fontSize: 12,
                        ),
                      )
                    : null,
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: TayarColors.primary)
                    : null,
              );
            }),
          ],
        ),
      ),
    ),
  );
}
