import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/services/profile_photo_validator.dart';
import 'package:tayay_app/screens/shared/profile_widgets.dart';
import 'package:tayay_app/screens/shared/profile_photo_edit_screen.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';

// ====================================================
// ====== شاشة بروفايل الراكب: قابلة للتعديل ======
// (الصورة، الاسم، تاريخ الميلاد، الموبايل، العنوان)
// نفس شكل وسلوك شاشة بروفايل الطيار بالظبط، لكن بتحفظ
// بيانات الراكب في collection('users') بدل collection('drivers') ======
// ====================================================
class PassengerProfileScreen extends StatefulWidget {
  const PassengerProfileScreen({super.key});

  @override
  State<PassengerProfileScreen> createState() => _PassengerProfileScreenState();
}

class _PassengerProfileScreenState extends State<PassengerProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // ====== الصورة الحالية المحفوظة كـ Base64 جوه مستند الراكب في Firestore ======
  String? _existingPhotoBase64;
  // ====== الصورة الجديدة اللي المستخدم اختارها في الجلسة الحالية (لسه متحفظتش) ======
  Uint8List? _newPhotoBytes;

  bool _isLoading = true;
  bool _isSaving = false;
  // ====== true أثناء تشغيل فحص الوجه على الصورة المختارة قبل قبولها ======
  bool _isCheckingPhoto = false;

  // ====== بتتحط true بعد محاولة "حفظ" فاشلة والحقل المطلوب لسه فاضي،
  // عشان نعرض إطار أحمر حواليه — وبترجع false تلقائيًا أول ما المستخدم
  // يكتب فيه حاجة ======
  bool _firstNameError = false;
  bool _lastNameError = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _firstNameController.addListener(_clearFirstNameError);
    _lastNameController.addListener(_clearLastNameError);
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

  // ====== تحميل بيانات الراكب الحالية عشان الحقول تظهر معمورة، مش فاضية ======
  Future<void> _loadProfile() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      final data = doc.data();
      final personalInfo = data?['personalInfo'] as Map<String, dynamic>?;
      if (personalInfo != null) {
        _firstNameController.text = personalInfo['firstName'] ?? '';
        _lastNameController.text = personalInfo['lastName'] ?? '';
        _birthDateController.text = personalInfo['birthDate'] ?? '';
        _phoneController.text = personalInfo['phone'] ?? '';
        _addressController.text = personalInfo['address'] ?? '';
        _existingPhotoBase64 = personalInfo['photoBase64'] as String?;
      }
    } catch (e) {
      debugPrint('❌ خطأ في تحميل بيانات البروفايل: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ====== بوتوم شيت بسيط يسيب المستخدم يختار هيجيب الصورة منين:
  // من معرض الصور، أو يفتح الكاميرا مباشرة ويلتقط صورة جديدة ======
  Future<void> _showPhotoSourceSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    l10n.choosePhotoSourceTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: sheetContext.textColor,
                    ),
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.photo_library_outlined,
                  color: TayarColors.primary,
                ),
                title: Text(
                  l10n.chooseFromGalleryLabel,
                  style: TextStyle(color: sheetContext.textColor),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt_outlined,
                  color: TayarColors.primary,
                ),
                title: Text(
                  l10n.takePhotoLabel,
                  style: TextStyle(color: sheetContext.textColor),
                ),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
            ],
          ),
        );
      },
    );
    if (source == null) return;
    await _pickPhoto(source);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: 640,
      maxHeight: 640,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();

    // ====== قبل قبول الصورة، نتأكد إنها صورة وجه قريبة وواضحة زي متطلبات
    // التحقق الأمني (نفس فكرة InDrive)، وده بيشتغل على الموبايل بس ======
    setState(() => _isCheckingPhoto = true);
    final result = await ProfilePhotoValidator.validate(
      imagePath: file.path,
      bytes: bytes,
    );
    if (!mounted) return;
    setState(() => _isCheckingPhoto = false);

    if (!result.isValid) {
      TayarToast.show(context, result.errorMessageAr!, type: ToastType.error);
      return;
    }

    // ====== الصورة عدّت فحص الوجه، دلوقتي نسيب المستخدم يكبّر/يصغّر
    // ويظبط الصورة جوه دائرة القص قبل ما تتحفظ فعليًا ======
    if (!mounted) return;
    final editedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ProfilePhotoEditScreen(imageBytes: bytes),
        fullscreenDialog: true,
      ),
    );
    if (editedBytes == null) return;

    setState(() => _newPhotoBytes = editedBytes);
  }

  Future<void> _pickDate() async {
    // ====== لو المستخدم عنده تاريخ ميلاد محفوظ بالفعل، نفتح الـ picker
    // على نفس التاريخ ده بدل ما يرجع لسنة 2000 ثابتة كل مرة ======
    DateTime initial = DateTime(2000);
    final saved = _birthDateController.text.trim();
    if (saved.isNotEmpty) {
      final parsed = DateTime.tryParse(saved);
      if (parsed != null) initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _birthDateController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  // ====== الحد الأقصى لحجم أي مستند في Firestore حوالي 1 ميجابايت، فبنسيب
  // هامش أمان كويس ونرفض أي صورة الـ base64 بتاعها هيتعدى 700 كيلوبايت
  // (الحجم الأصلي للصورة بيكبر ~33% لما يتحول Base64) ======
  static const int _maxBase64Length = 700 * 1024;

  // ====== لو المستخدم اختار صورة جديدة، نحوّلها Base64 عشان تتحفظ جوه
  // مستند الراكب مباشرة في Firestore (بدون Storage)؛ لو مفيش صورة جديدة
  // نسيب القديمة زي ما هي ======
  String? _encodePhotoIfNeeded() {
    if (_newPhotoBytes == null) return _existingPhotoBase64;
    return base64Encode(_newPhotoBytes!);
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null) return;
    final firstNameEmpty = _firstNameController.text.trim().isEmpty;
    final lastNameEmpty = _lastNameController.text.trim().isEmpty;
    if (firstNameEmpty || lastNameEmpty) {
      setState(() {
        _firstNameError = firstNameEmpty;
        _lastNameError = lastNameEmpty;
      });
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.fullNameRequiredError,
        type: ToastType.warning,
      );
      return;
    }

    // ====== تحقق بسيط من رقم الموبايل المصري: لازم يبدأ بـ 01 ويكون 11 رقم
    // بالظبط (زي 01012345678)، أو يسمح بترك الحقل فاضي لو المستخدم عايز
    // يكمله لاحقًا ======
    final phone = _phoneController.text.trim();
    final egyptianPhoneRegex = RegExp(r'^01[0125][0-9]{8}$');
    if (phone.isNotEmpty && !egyptianPhoneRegex.hasMatch(phone)) {
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.invalidPhoneNumberError,
        type: ToastType.warning,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final photoBase64 = _encodePhotoIfNeeded();

      if (photoBase64 != null && photoBase64.length > _maxBase64Length) {
        if (!mounted) return;
        TayarToast.show(
          context,
          AppLocalizations.of(context)!.photoTooLargeError,
          type: ToastType.error,
        );
        // ====== نشيل الصورة الكبيرة من الذاكرة عشان المستخدم يضطر يختار
        // صورة تانية بدل ما يفضل عالق يدوس Save على نفس الصورة المرفوضة ======
        setState(() {
          _newPhotoBytes = null;
          _isSaving = false;
        });
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'personalInfo': {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'birthDate': _birthDateController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          'photoBase64': ?photoBase64,
          'hasPhoto': photoBase64 != null,
          'complete': true,
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.profileUpdatedSuccess,
        type: ToastType.success,
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ البروفايل: $e');
      if (!mounted) return;
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.saveFailedError,
        type: ToastType.error,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.removeListener(_clearFirstNameError);
    _lastNameController.removeListener(_clearLastNameError);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _birthDateController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(
          AppLocalizations.of(context)!.navProfile,
          style: TextStyle(color: context.textColor),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TayarColors.primary),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ListView(
                      children: [
                        Center(
                          child: ProfilePhotoPicker(
                            existingPhotoBase64: _existingPhotoBase64,
                            newPhotoBytes: _newPhotoBytes,
                            isChecking: _isCheckingPhoto,
                            onTap: _isCheckingPhoto
                                ? null
                                : _showPhotoSourceSheet,
                          ),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              AppLocalizations.of(context)!.changePhotoLabel,
                              style: TextStyle(
                                color: context.textGreyColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ProfileTextField(
                          controller: _firstNameController,
                          hint: AppLocalizations.of(context)!.firstNameHint,
                          showError: _firstNameError,
                        ),
                        ProfileTextField(
                          controller: _lastNameController,
                          hint: AppLocalizations.of(context)!.lastNameHint,
                          showError: _lastNameError,
                        ),
                        GestureDetector(
                          onTap: _pickDate,
                          child: AbsorbPointer(
                            child: ProfileTextField(
                              controller: _birthDateController,
                              hint: AppLocalizations.of(context)!.birthDateHint,
                            ),
                          ),
                        ),
                        ProfileTextField(
                          controller: _phoneController,
                          hint: AppLocalizations.of(context)!.phoneNumberLabel,
                          keyboardType: TextInputType.phone,
                        ),
                        ProfileTextField(
                          controller: _addressController,
                          hint: AppLocalizations.of(context)!.addressLabel,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 54,
                    child: AppPrimaryButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TayarColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: context.onPrimaryColor,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              AppLocalizations.of(context)!.saveButton,
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
