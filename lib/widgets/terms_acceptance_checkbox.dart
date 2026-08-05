import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors;

// ====== نسخة الشروط والأحكام الحالية. أي تعديل جوهري في نص الشروط
// المفروض يترفق بزيادة الرقم ده، عشان لو حبينا مستقبلًا نجبر المستخدمين
// اللي وافقوا على نسخة قديمة يوافقوا تاني على النسخة الجديدة (بمقارنة
// termsVersion المحفوظ في بروفايلهم بالقيمة الحالية هنا) ======
const String kTermsAndConditionsVersion = '1.0';

/// ====== Checkbox الموافقة على الشروط والأحكام - بيتستخدم في شاشة تسجيل
/// الراكب (profile_setup_screen.dart) وشاشة تسجيل الطيار
/// (driver_registration_screen.dart). لما المستخدم يوافق، الشاشة اللي
/// بتستخدمه هي اللي مسؤولة إنها تكتب termsAcceptedAt (serverTimestamp)
/// و termsVersion (kTermsAndConditionsVersion) في وثيقته وقت الحفظ. ======
class TermsAcceptanceCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  // ====== بيتحط true بعد محاولة إرسال فاشلة والـ checkbox لسه مش متعلّم،
  // بنفس فكرة showError في FormTextField ======
  final bool showError;

  const TermsAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.showError = false,
  });

  void _openTermsDialog(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.termsAndConditionsTitle,
          style: TextStyle(color: context.textColor),
        ),
        content: SingleChildScrollView(
          child: Text(
            loc.termsAndConditionsBody,
            style: TextStyle(color: context.textGreyColor, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              loc.closeButton,
              style: const TextStyle(color: TayarColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: showError
                ? Border.all(color: Colors.red, width: 1.5)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: value,
                activeColor: TayarColors.primary,
                onChanged: (v) => onChanged(v ?? false),
              ),
              // ====== النص التاني بس (مش السطر كله) بيفتح الـ checkbox،
              // عشان ميتعارضش مع recognizer الرابط جوه RichText تحت ======
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: context.textColor, fontSize: 13.5),
                    children: [
                      TextSpan(
                        text: loc.termsAgreementPrefix,
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => onChanged(!value),
                      ),
                      TextSpan(
                        text: loc.termsAndConditionsLinkText,
                        style: const TextStyle(
                          color: TayarColors.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => _openTermsDialog(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 2),
            child: Text(
              loc.termsAgreementRequiredError,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
