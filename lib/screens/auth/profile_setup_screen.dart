import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/services/referral_service.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarThemeColors, PassengerHomeScreen;
import 'package:tayay_app/widgets/terms_acceptance_checkbox.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';
import 'package:tayay_app/utils/tayar_page_route.dart';

// ====================================================
// ====== شاشة استكمال بيانات الراكب بعد أول تسجيل دخول ======
// بتظهر مرة واحدة بس لما يختار "راكب" في شاشة اختيار الدور.
// الطيار مش بيمر من هنا لأن شاشة تسجيل الطيار نفسها بتجمع
// بياناته الشخصية كجزء من إجراءات القبول ======
// ====================================================
class ProfileSetupScreen extends StatefulWidget {
  final String role;

  const ProfileSetupScreen({super.key, required this.role});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _referralController = TextEditingController();
  bool _isSaving = false;
  bool _termsAccepted = false;
  bool _showTermsError = false;

  @override
  void initState() {
    super.initState();
    // ====== لو جوجل رجّع اسم جاهز، بنحطه معمور من الأول ======
    _nameController = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.displayName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;
    // ====== زي التحقق من باقي حقول الفورم، بنمنع الحفظ لحد ما المستخدم
    // يعلّم على موافقته على الشروط والأحكام، ونوريه إطار أحمر حوالين
    // الـ checkbox زي أي حقل فاضي ======
    if (!_termsAccepted) {
      setState(() => _showTermsError = true);
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    final name = _nameController.text.trim();

    try {
      if (FirebaseAuth.instance.currentUser?.displayName != name) {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      }

      final nameParts = name.split(RegExp(r'\s+'));
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'personalInfo': {
          'firstName': nameParts.first,
          'lastName': nameParts.length > 1
              ? nameParts.sublist(1).join(' ')
              : '',
        },
        'role': widget.role,
        'createdAt': FieldValue.serverTimestamp(),
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'termsVersion': kTermsAndConditionsVersion,
      }, SetOptions(merge: true));

      // ====== لو كتب كود دعوة، نحاول نستبدله - لو فشل (كود غلط/مستخدم
      // قبل كده) منعرقلش تسجيله، بس نوريه رسالة بسيطة ونكمّل عادي ======
      final referralCode = _referralController.text.trim();
      if (referralCode.isNotEmpty) {
        try {
          await redeemReferralCode(code: referralCode, newUserId: uid);
        } on ReferralException catch (_) {
          // ====== صامت عمدًا - مش سبب كافي نوقف تسجيل حساب جديد ======
        }
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        TayarPageRoute(builder: (_) => const PassengerHomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      TayarToast.show(context, e.toString(), type: ToastType.error);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 50),
                Text(
                  loc.completeProfileTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: context.textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  loc.completeProfileSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textGreyColor),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    labelText: loc.nameLabel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return loc.requiredFieldError;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _referralController,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: context.textColor),
                  decoration: InputDecoration(
                    labelText: loc.referralOptionalFieldLabel,
                    hintText: loc.referralOptionalFieldHint,
                    hintStyle: TextStyle(color: context.textGreyColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TermsAcceptanceCheckbox(
                  value: _termsAccepted,
                  showError: _showTermsError,
                  onChanged: (v) => setState(() {
                    _termsAccepted = v;
                    if (v) _showTermsError = false;
                  }),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 55,
                  child: AppPrimaryButton(
                    onPressed: _saveAndContinue,
                    variant: AppButtonVariant.primary,
                    isLoading: _isSaving,
                    child: Text(
                      loc.continueButton,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
