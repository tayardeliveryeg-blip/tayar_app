import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart' show TayarColors, TayarThemeColors;
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/services/driver_invite_link_helper.dart';
import 'package:tayay_app/screens/driver/registration/registration_shared_widgets.dart';
import 'package:tayay_app/services/driver_document_upload_service.dart';
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
  // ====== بتتحط true لو نجحنا نعبّي أي حقل من بروفايل الراكب - بنستخدمها
  // بس عشان نعرض تلميح بسيط فوق الفورم، مالهاش أي تأثير على منطق الحفظ ======
  bool _prefilledFromPassenger = false;

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
    _loadPrefillFromPassengerProfile();
  }

  // ====== لو الراكب عنده بروفايل محفوظ بالفعل (دخل التطبيق كراكب الأول
  // وبعدين اختار "وضع الطيار" من القايمة الجانبية)، نعبّي بيانات هذا
  // القسم تلقائيًا من users/{uid} بدل ما يكتبها من الصفر تاني - قابلة
  // للتعديل بالكامل زي أي حقل عادي. لو ده أول قسم بيفتحه من الأساس
  // (مستخدم جديد اختار "طيار" مباشرة من شاشة اختيار الدور، مفيش بروفايل
  // راكب أصلًا) الدالة مبتعملش حاجة بهدوء.
  //
  // لو القسم ده كان already مكتمل (complete:true) من زيارة سابقة لنفس
  // القسم، منعملش تعبئة تلقائية تاني عشان منبوظش أي تعديل يدوي عمله
  // الطيار بنفسه على بياناته كطيار. ======
  Future<void> _loadPrefillFromPassengerProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final driverDoc = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .get();
      final alreadyComplete =
          driverDoc.data()?['personalInfo']?['complete'] == true;
      if (alreadyComplete) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final passengerInfo =
          userDoc.data()?['personalInfo'] as Map<String, dynamic>?;
      if (passengerInfo == null || !mounted) return;

      final firstName = passengerInfo['firstName'] as String?;
      final lastName = passengerInfo['lastName'] as String?;
      final birthDate = passengerInfo['birthDate'] as String?;
      final phone = passengerInfo['phone'] as String?;
      final photoBase64 = passengerInfo['photoBase64'] as String?;
      var didPrefillSomething = false;

      setState(() {
        if (firstName != null && firstName.isNotEmpty) {
          _firstNameController.text = firstName;
          didPrefillSomething = true;
        }
        if (lastName != null && lastName.isNotEmpty) {
          _lastNameController.text = lastName;
          didPrefillSomething = true;
        }
        if (birthDate != null && birthDate.isNotEmpty) {
          _birthDateController.text = birthDate;
          didPrefillSomething = true;
        }
        if (_mobileController.text.isEmpty &&
            phone != null &&
            phone.isNotEmpty) {
          _mobileController.text = phone;
          didPrefillSomething = true;
        }
        if (photoBase64 != null && photoBase64.isNotEmpty) {
          try {
            _photoBytes = base64Decode(photoBase64);
            didPrefillSomething = true;
          } catch (_) {
            // ====== لو الفك فشل لأي سبب، نسيب مربع الصورة فاضي زي ما كان -
            // الطيار يقدر يرفع صورة يدويًا عادي ======
          }
        }
        _prefilledFromPassenger = didPrefillSomething;
      });
    } catch (e) {
      debugPrint('تعذر تحميل بروفايل الراكب للتعبئة التلقائية: $e');
    }
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

    // ====== التحقق بالـ OTP اتشال بالكامل من التطبيق (محتاج خطة Blaze
    // على Firebase مدفوعة). الرقم بيتخزن زي ما اتكتب من غير توثيق،
    // والربط التلقائي بسجل "مُضاف يدويًا" بقى معطّل تلقائيًا (قاعدة
    // isPreInvitedMatch محتاجة request.auth.token.phone_number اللي
    // مبقاش بيتحط أبدًا) — الأدمن بقى محتاج يربط أي سائق مُضاف يدويًا
    // بنفسه من لوحة التحكم بعد أول تسجيل دخول له ======
    await _completeSave(mobile);
  }

  Future<void> _completeSave(String mobile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _isSaving = true);
    try {
      // ====== محاولة ربط تلقائي بسجل "مُضاف يدويًا" من لوحة التحكم —
      // بقت دايمًا no-op عمليًا دلوقتي (بعد ما شلنا التحقق بالـ OTP)
      // لأن قاعدة isPreInvitedMatch في firestore.rules محتاجة
      // request.auth.token.phone_number موثّق، وده مبيتحطش تاني.
      // سايبينها زي ما هي (آمنة، بترجع linked:false بهدوء) بدل ما نمسحها،
      // تحسّبًا لأي حساب قديم لسه معاه phone claim من قبل إلغاء OTP.
      // الربط دلوقتي شغل يدوي من الأدمن ======
      await linkPreInvitedDriverIfNeeded(uid: uid, phoneNumber: mobile);

      String? photoUrl;
      if (_photoBytes != null) {
        photoUrl = await DriverDocumentUploadService.uploadDocument(
          driverId: uid,
          fileName: 'personal_photo',
          bytes: _photoBytes!,
        );
      }

      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'personalInfo': {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'birthDate': _birthDateController.text.trim(),
          'hasPhoto': _photoBytes != null,
          'photoUrl': ?photoUrl,
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
        if (_prefilledFromPassenger)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: TayarColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: TayarColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.prefilledFromPassengerProfileHint,
                      style: TextStyle(
                        color: context.textColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
