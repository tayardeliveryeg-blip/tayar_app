import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart' show TayarThemeColors;
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/services/driver_invite_link_helper.dart';
import 'package:tayay_app/screens/auth/mobile_link_otp_screen.dart';
import 'package:tayay_app/screens/driver/registration/registration_shared_widgets.dart';
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _mobileController = TextEditingController();
  Uint8List? _photoBytes;
  bool _isSaving = false;

  // ====== بتتحط true بعد محاولة "حفظ" فاشلة والحقل المطلوب لسه فاضي/غلط،
  // عشان نعرض إطار أحمر حواليه — وبترجع false تلقائيًا أول ما المستخدم
  // يكتب فيه حاجة ======
  bool _firstNameError = false;
  bool _lastNameError = false;
  bool _mobileError = false;

  @override
  void initState() {
    super.initState();
    // ====== لو دخل بالموبايل أصلاً، منعبيش الحقل تلقائيًا عشان نضمن
    // إنه يراجع الرقم بنفسه (مهم خصوصًا لمستخدمي جوجل اللي معندهمش
    // رقم موبايل مسجل في الـ Auth) ======
    final authPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
    if (authPhone != null && authPhone.isNotEmpty) {
      _mobileController.text = authPhone;
    }
    _firstNameController.addListener(_clearFirstNameError);
    _lastNameController.addListener(_clearLastNameError);
    _mobileController.addListener(_clearMobileError);
  }

  void _clearFirstNameError() {
    if (_firstNameError && _firstNameController.text.trim().isNotEmpty) {
      setState(() => _firstNameError = false);
    }
  }

  void _clearLastNameError() {
    if (_lastNameError && _lastNameController.text.trim().isNotEmpty) {
      setState(() => _lastNameError = false);
    }
  }

  void _clearMobileError() {
    if (_mobileError && _mobileController.text.trim().isNotEmpty) {
      setState(() => _mobileError = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _photoBytes = bytes);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _birthDateController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final firstNameEmpty = _firstNameController.text.trim().isEmpty;
    final lastNameEmpty = _lastNameController.text.trim().isEmpty;
    if (firstNameEmpty || lastNameEmpty) {
      setState(() {
        _firstNameError = firstNameEmpty;
        _lastNameError = lastNameEmpty;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.fullNameRequiredError),
        ),
      );
      return;
    }
    final mobile = _mobileController.text.trim();
    final normalizedMobile = normalizeEgyptPhone(mobile);
    if (normalizedMobile == null || normalizedMobile.length < 9) {
      setState(() => _mobileError = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.phoneNumberFormatError),
        ),
      );
      return;
    }
    setState(() => _mobileError = false);

    // ====== لو الرقم اللي كتبه هنا نفس رقم الـ Auth المُوثّق بالفعل
    // (يعني دخل بالموبايل أصلاً، أو سبق وربط نفس الرقم)، معندناش داعي
    // نطلب منه OTP تاني. غير كده (تسجيل دخول بجوجل مثلًا، أو غيّر الرقم)
    // لازم يوثّق الرقم الجديد أولًا عشان الـ Auth token يبقى فيه
    // phone_number claim حقيقي — ده اللي قاعدة isPreInvitedMatch محتاجاه ======
    final authNormalized = normalizeEgyptPhone(
      FirebaseAuth.instance.currentUser?.phoneNumber,
    );
    if (authNormalized != normalizedMobile) {
      await _verifyAndLinkMobile(mobile);
      return;
    }

    await _completeSave(mobile);
  }

  Future<void> _verifyAndLinkMobile(String mobile) async {
    setState(() => _isSaving = true);
    final l10n = AppLocalizations.of(context)!;

    String formattedPhone = mobile;
    if (formattedPhone.startsWith('0')) {
      formattedPhone = formattedPhone.substring(1);
    }
    formattedPhone = '+20$formattedPhone';

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await FirebaseAuth.instance.currentUser!.linkWithCredential(
            credential,
          );
          await FirebaseAuth.instance.currentUser?.getIdToken(true);
          if (!mounted) return;
          await _completeSave(mobile);
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                e.code == 'credential-already-in-use'
                    ? l10n.credentialAlreadyInUseError
                    : l10n.errorOccurredWithMessage(
                        e.message ?? l10n.tryAgainLabel,
                      ),
              ),
            ),
          );
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        // ====== لما Firebase يرجّع خطأ من غير رسالة واضحة (زي حالة
        // reCAPTCHA/billing مش مظبوطة على مشروع لسه Spark)، بنعرض رسالة
        // مفهومة للمستخدم بدل "Error" الفاضية دي ======
        final hasUsableMessage =
            e.message != null && e.message!.trim().isNotEmpty;
        final displayMessage = hasUsableMessage
            ? e.message!
            : l10n.otpSendFailedGenericError;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurredWithMessage(displayMessage)),
          ),
        );
      },
      codeSent: (String verificationId, int? resendToken) async {
        if (!mounted) return;
        setState(() => _isSaving = false);
        final linked = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => MobileLinkOtpScreen(
              verificationId: verificationId,
              phoneNumber: formattedPhone,
              resendToken: resendToken,
            ),
          ),
        );
        if (linked == true && mounted) {
          await _completeSave(mobile);
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<void> _completeSave(String mobile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      // ====== خطوة احتياطية: نحاول نربط بسجل "مُضاف يدويًا" من لوحة
      // التحكم بالرقم اللي دخله السائق ووثّقه هنا، تغطية للحالة اللي
      // فيها Firebase Auth مش راجع رقم موبايل وقت اللوجين (تسجيل دخول
      // بجوجل مثلًا) فمحاولة الربط وقت navigateAfterAuth بتكون فشلت.
      // آمنة تتنادى حتى لو الربط حصل قبل كده ======
      await linkPreInvitedDriverIfNeeded(uid: uid, phoneNumber: mobile);

      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'personalInfo': {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'birthDate': _birthDateController.text.trim(),
          'hasPhoto': _photoBytes != null,
          'phone': mobile,
          'complete': true,
        },
        // ====== بنخزنه هنا كمان (مش بس جوه personalInfo) عشان يطابق
        // نفس الحقل اللي بيدور عليه linkPreInvitedDriverIfNeeded وبيكتبه
        // الأدمن وقت إضافة سائق يدويًا، فالربط شغال في الاتجاهين ======
        'phoneNormalized': normalizeEgyptPhone(mobile),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ المعلومات الشخصية: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.saveFailedError)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_clearFirstNameError);
    _lastNameController.removeListener(_clearLastNameError);
    _mobileController.removeListener(_clearMobileError);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionScaffold(
      title: AppLocalizations.of(context)!.sectionPersonalInfo,
      isSaving: _isSaving,
      onSave: _save,
      children: [
        Center(
          child: PhotoUploadTile(
            label: AppLocalizations.of(context)!.personalPhotoLabel,
            imageBytes: _photoBytes,
            onTap: _pickPhoto,
          ),
        ),
        const SizedBox(height: 24),
        FormTextField(
          controller: _firstNameController,
          hint: AppLocalizations.of(context)!.firstNameHint,
          showError: _firstNameError,
        ),
        FormTextField(
          controller: _lastNameController,
          hint: AppLocalizations.of(context)!.lastNameHint,
          showError: _lastNameError,
        ),
        GestureDetector(
          onTap: _pickDate,
          child: AbsorbPointer(
            child: FormTextField(
              controller: _birthDateController,
              hint: AppLocalizations.of(context)!.birthDateHint,
            ),
          ),
        ),
        FormTextField(
          controller: _mobileController,
          hint: AppLocalizations.of(context)!.phoneNumberLabel,
          keyboardType: TextInputType.phone,
          showError: _mobileError,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Text(
            AppLocalizations.of(context)!.mobileNumberMatchHint,
            style: TextStyle(color: context.textGreyColor, fontSize: 12),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ====================================================
// ====== 2) رخصة القيادة ======
// ====================================================
