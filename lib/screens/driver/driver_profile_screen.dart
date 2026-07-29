import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart' show TayarColors, TayarThemeColors;
import 'package:tayay_app/services/profile_photo_validator.dart';

// ====================================================
// ====== شاشة بروفايل الطيار: قابلة للتعديل ======
// (الصورة، الاسم، تاريخ الميلاد، الموبايل، العنوان)
// بيانات الموتوسيكل والمستندات مش موجودة هنا، بتتعدّل من
// مكانها في تسجيل الطيار مش من هنا ======
// ====================================================
class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // ====== الصورة الحالية المحفوظة كـ Base64 جوه مستند الطيار في Firestore ======
  String? _existingPhotoBase64;
  // ====== الصورة الجديدة اللي المستخدم اختارها في الجلسة الحالية (لسه متحفظتش) ======
  Uint8List? _newPhotoBytes;

  bool _isLoading = true;
  bool _isSaving = false;
  // ====== true أثناء تشغيل فحص الوجه على الصورة المختارة قبل قبولها ======
  bool _isCheckingPhoto = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ====== تحميل بيانات الطيار الحالية عشان الحقول تظهر معمورة، مش فاضية ======
  Future<void> _loadProfile() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('drivers')
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
                leading: Icon(Icons.photo_library_outlined,
                    color: TayarColors.primary),
                title: Text(l10n.chooseFromGalleryLabel,
                    style: TextStyle(color: sheetContext.textColor)),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              ListTile(
                leading:
                    Icon(Icons.camera_alt_outlined, color: TayarColors.primary),
                title: Text(l10n.takePhotoLabel,
                    style: TextStyle(color: sheetContext.textColor)),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessageAr!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _newPhotoBytes = bytes);
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

  // ====== الحد الأقصى لحجم أي مستند في Firestore حوالي 1 ميجابايت، فبنسيب
  // هامش أمان كويس ونرفض أي صورة الـ base64 بتاعها هيتعدى 700 كيلوبايت
  // (الحجم الأصلي للصورة بيكبر ~33% لما يتحول Base64) ======
  static const int _maxBase64Length = 700 * 1024;

  // ====== لو المستخدم اختار صورة جديدة، نحوّلها Base64 عشان تتحفظ جوه
  // مستند الطيار مباشرة في Firestore (بدون Storage)؛ لو مفيش صورة جديدة
  // نسيب القديمة زي ما هي ======
  String? _encodePhotoIfNeeded() {
    if (_newPhotoBytes == null) return _existingPhotoBase64;
    return base64Encode(_newPhotoBytes!);
  }

  Future<void> _save() async {
    final uid = _uid;
    if (uid == null) return;
    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.fullNameRequiredError),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final photoBase64 = _encodePhotoIfNeeded();

      if (photoBase64 != null && photoBase64.length > _maxBase64Length) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.photoTooLargeError),
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.profileUpdatedSuccess),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ البروفايل: $e');
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
                          child: _ProfilePhotoPicker(
                            existingPhotoBase64: _existingPhotoBase64,
                            newPhotoBytes: _newPhotoBytes,
                            isChecking: _isCheckingPhoto,
                            onTap:
                                _isCheckingPhoto ? null : _showPhotoSourceSheet,
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
                        _ProfileTextField(
                          controller: _firstNameController,
                          hint: AppLocalizations.of(context)!.firstNameHint,
                        ),
                        _ProfileTextField(
                          controller: _lastNameController,
                          hint: AppLocalizations.of(context)!.lastNameHint,
                        ),
                        GestureDetector(
                          onTap: _pickDate,
                          child: AbsorbPointer(
                            child: _ProfileTextField(
                              controller: _birthDateController,
                              hint: AppLocalizations.of(context)!.birthDateHint,
                            ),
                          ),
                        ),
                        _ProfileTextField(
                          controller: _phoneController,
                          hint: AppLocalizations.of(context)!.phoneNumberLabel,
                          keyboardType: TextInputType.phone,
                        ),
                        _ProfileTextField(
                          controller: _addressController,
                          hint: AppLocalizations.of(context)!.addressLabel,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
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

// ====================================================
// ====== دائرة صورة البروفايل مع أيقونة تعديل فوقها ======
// ====================================================
class _ProfilePhotoPicker extends StatelessWidget {
  final String? existingPhotoBase64;
  final Uint8List? newPhotoBytes;
  final bool isChecking;
  final VoidCallback? onTap;

  const _ProfilePhotoPicker({
    required this.existingPhotoBase64,
    required this.newPhotoBytes,
    required this.onTap,
    this.isChecking = false,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (newPhotoBytes != null) {
      imageProvider = MemoryImage(newPhotoBytes!);
    } else if (existingPhotoBase64 != null && existingPhotoBase64!.isNotEmpty) {
      try {
        imageProvider = MemoryImage(base64Decode(existingPhotoBase64!));
      } catch (_) {
        imageProvider = null;
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: context.cardColor,
            backgroundImage: imageProvider,
            child: imageProvider == null
                ? Icon(Icons.person, color: context.textGreyColor, size: 48)
                : null,
          ),
          if (isChecking)
            Positioned.fill(
              child: CircleAvatar(
                radius: 56,
                backgroundColor: Colors.black45,
                child: const CircularProgressIndicator(color: Colors.white),
              ),
            ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: TayarColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.camera_alt,
                color: context.onPrimaryColor,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================
// ====== حقل نص موحّد لشاشة البروفايل ======
// ====================================================
class _ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const _ProfileTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: context.textColor),
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.textGreyColor),
          filled: true,
          fillColor: context.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
