import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/services/profile_photo_validator.dart';
import 'package:tayay_app/screens/shared/profile_widgets.dart';
import 'package:tayay_app/screens/shared/profile_photo_edit_screen.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
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

  String? _existingPhotoBase64;
  Uint8List? _newPhotoBytes;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isCheckingPhoto = false;

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

  // Specialized sheet: اختيار مصدر الصورة له سلوك خاص، لذلك لا نُجبره على
  // Generic BottomSheet component.
  Future<void> _showPhotoSourceSheet() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: Text(
                    l10n.choosePhotoSourceTitle,
                    style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
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
                  style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                        color: sheetContext.textColor,
                      ),
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
                  style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                        color: sheetContext.textColor,
                      ),
                ),
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

  static const int _maxBase64Length = 700 * 1024;

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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(
          AppLocalizations.of(context)!.navProfile,
          style: textTheme.titleLarge?.copyWith(color: context.textColor),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: TayarColors.primary),
            )
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                            padding: const EdgeInsets.only(top: AppSpacing.sm),
                            child: Text(
                              AppLocalizations.of(context)!.changePhotoLabel,
                              style: textTheme.bodySmall?.copyWith(
                                color: context.textGreyColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
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
                  AppPrimaryButton(
                    onPressed: _isSaving ? null : _save,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.medium,
                    isLoading: _isSaving,
                    child: Text(
                      AppLocalizations.of(context)!.saveButton,
                      style: textTheme.labelLarge?.copyWith(
                        color: context.onPrimaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
