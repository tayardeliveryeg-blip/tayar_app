import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

/// ====== مين اللي بيلغي: بيحدد قايمة الأسباب المعروضة (الراكب والسائق
/// عندهم أسباب مختلفة) ======
enum CancellationActor { customer, driver }

class _CancellationReasonOption {
  final String code;
  final String label;
  const _CancellationReasonOption(this.code, this.label);
}

/// ====== بوتوم شيت اختيار سبب الإلغاء - مشترك بين شاشات الراكب (تتبع
/// الرحلة، الرحلات المجدولة) وأي فيتشر إلغاء مستقبلي من ناحية السائق.
/// بترجع كود السبب المختار (String، من قايمة ثابتة مطابقة لـ
/// firestore.rules) أو null لو المستخدم قفل الشيت من غير ما يختار.
///
/// [feeAmount]: لو أكبر من صفر، بيظهر تحذير واضح بمبلغ رسوم الإلغاء فوق
/// قايمة الأسباب قبل ما المستخدم يكمل - الحساب الفعلي (هل الرسوم مستحقة
/// أصلاً حسب مهلة الإلغاء المجاني) بيتم في الشاشة المستدعية قبل النداء
/// على الدالة دي. ======
Future<String?> showCancellationReasonSheet(
  BuildContext context, {
  required CancellationActor actor,
  double feeAmount = 0,
}) {
  final loc = AppLocalizations.of(context)!;
  final options = actor == CancellationActor.customer
      ? [
          _CancellationReasonOption(
            'changed_mind',
            loc.cancelReasonChangedMind,
          ),
          _CancellationReasonOption(
            'driver_too_slow',
            loc.cancelReasonDriverTooSlow,
          ),
          _CancellationReasonOption(
            'wrong_address',
            loc.cancelReasonWrongAddress,
          ),
          _CancellationReasonOption(
            'found_other_way',
            loc.cancelReasonFoundOtherWay,
          ),
          _CancellationReasonOption('other', loc.cancelReasonOther),
        ]
      : [
          _CancellationReasonOption(
            'passenger_no_response',
            loc.cancelReasonPassengerNoResponse,
          ),
          _CancellationReasonOption(
            'passenger_not_at_location',
            loc.cancelReasonPassengerNotAtLocation,
          ),
          _CancellationReasonOption(
            'vehicle_issue',
            loc.cancelReasonVehicleIssue,
          ),
          _CancellationReasonOption('other', loc.cancelReasonOther),
        ];

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: context.cardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: sheetContext.textGreyColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                loc.cancelReasonSheetTitle,
                style: TextStyle(
                  color: sheetContext.textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (feeAmount > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.cancellationFeeWarning(
                            feeAmount.toStringAsFixed(0),
                          ),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ...options.map(
                (opt) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      color: sheetContext.textColor,
                      fontSize: 14,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_left,
                    color: TayarColors.primary,
                  ),
                  onTap: () => Navigator.pop(sheetContext, opt.code),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
