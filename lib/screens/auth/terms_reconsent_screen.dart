import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/utils/tayar_page_route.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';
import 'package:tayay_app/widgets/terms_acceptance_checkbox.dart';

// ====================================================
// ====== بند 8 من gap analysis: شاشة إعادة موافقة إجبارية على الشروط
// والأحكام. بتظهر بس لما termsVersion المحفوظة في وثيقة المستخدم
// (users/{uid} للراكب أو drivers/{uid} للطيار) تكون مختلفة عن
// kTermsAndConditionsVersion الحالية - يعني المستخدم وافق على نسخة
// قديمة وقبل ما يكمل لازم يوافق على الجديدة. بتتحط في AuthGate
// (main.dart) بدل شاشة الراكب/الطيار الرئيسية لحد ما يوافق ======
// ====================================================
class TermsReconsentScreen extends StatefulWidget {
  // ====== 'passenger' أو 'driver' - بيحدد نكتب التحديث في users/{uid}
  // ولا drivers/{uid} ======
  final String role;
  // ====== الشاشة اللي هيتحول لها بعد ما يوافق (DriverHomeScreen أو
  // PassengerHomeScreen) - بتتبعت من AuthGate عشان الشاشة دي متعرفش
  // حاجة عن تفاصيل التوجيه ======
  final Widget destination;

  const TermsReconsentScreen({
    super.key,
    required this.role,
    required this.destination,
  });

  @override
  State<TermsReconsentScreen> createState() => _TermsReconsentScreenState();
}

class _TermsReconsentScreenState extends State<TermsReconsentScreen> {
  bool _termsAccepted = false;
  bool _showTermsError = false;
  bool _isSaving = false;

  Future<void> _agreeAndContinue() async {
    if (!_termsAccepted) {
      setState(() => _showTermsError = true);
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    try {
      final collection = widget.role == 'driver' ? 'drivers' : 'users';
      await FirebaseFirestore.instance.collection(collection).doc(uid).set({
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'termsVersion': kTermsAndConditionsVersion,
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        TayarPageRoute(builder: (_) => widget.destination),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.termsReconsentSavingError,
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ====== لو رفض يوافق، بنسجّله خروج بدل ما نسيبه عالق على الشاشة دي
  // للأبد من غير أي مخرج - قرار الموافقة لازم يفضل اختياري فعليًا ======
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TayarColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: TayarColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                loc.termsReconsentTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                loc.termsReconsentBody,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textGreyColor, height: 1.5),
              ),
              const SizedBox(height: 32),
              TermsAcceptanceCheckbox(
                value: _termsAccepted,
                showError: _showTermsError,
                onChanged: (v) => setState(() {
                  _termsAccepted = v;
                  if (v) _showTermsError = false;
                }),
              ),
              const SizedBox(height: 20),
              AppPrimaryButton(
                onPressed: _isSaving ? null : _agreeAndContinue,
                isLoading: _isSaving,
                child: Text(
                  loc.termsReconsentAgreeButton,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.onPrimaryColor,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSaving ? null : _signOut,
                child: Text(
                  loc.termsReconsentSignOutButton,
                  style: TextStyle(color: context.textGreyColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
