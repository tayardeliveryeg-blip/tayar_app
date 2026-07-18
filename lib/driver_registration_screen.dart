import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'passenger_home.dart' show TayarColors, TayarThemeColors;
import 'driver_home_screen.dart';
import 'l10n/generated/app_localizations.dart';

// ====================================================
// ====== الشاشة الرئيسية: قائمة أقسام تسجيل الطيار ======
// ====================================================
class DriverRegistrationScreen extends StatefulWidget {
  const DriverRegistrationScreen({super.key});

  @override
  State<DriverRegistrationScreen> createState() => _Dr9yMnTm4NSzvG9rrwjM2ec8xZgh1cafXH8();
}

class _Dr9yMnTm4NSzvG9rrwjM2ec8xZgh1cafXH8 extends State<DriverRegistrationScreen> {
  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  bool _isSubmitting = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadDriverData();
  }

  Future<void> _loadDriverData() async {
    if (_uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('drivers').doc(_uid).get();
      setState(() {
        _driverData = doc.data();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ خطأ في تحميل بيانات الطيار: $e');
      setState(() => _isLoading = false);
    }
  }

  bool _isSectionComplete(String key) {
    return _driverData?[key]?['complete'] == true;
  }

  Future<void> _openSection(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    _loadDriverData(); // نحدث حالة الأقسام بعد الرجوع
  }

  bool get _allSectionsComplete =>
      _isSectionComplete('personalInfo') &&
      _isSectionComplete('drivingLicense') &&
      _isSectionComplete('personalDocuments') &&
      _isSectionComplete('bikeInfo');

  Future<void> _submitRegistration() async {
    if (_uid == null || !_allSectionsComplete) return;
    setState(() => _isSubmitting = true);
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(_uid).set({
        'status': 'pending_review', // pending_review → approved → rejected
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: context.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            children: [
              const Icon(Icons.hourglass_top, color: TayarColors.primary, size: 56),
              const SizedBox(height: 12),
              Text(loc.submitApplicationSuccessTitle, style: TextStyle(color: context.textColor)),
            ],
          ),
          content: Text(
            loc.submitApplicationSuccessBody,
            textAlign: TextAlign.center,
            style:  TextStyle(color: context.textGreyColor),
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // يقفل الـ dialog
                  Navigator.of(context).pop(); // يرجع لشاشة الراكب
                },
                child: Text(loc.ok, style: const TextStyle(color: TayarColors.primary)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ خطأ في إرسال طلب التسجيل: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.submitFailedError)),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // لو الطيار مسجل بالفعل ومقبول، نوديه على طول لشاشة الطلبات
    final status = _driverData?['status'];
    if (!_isLoading && status == 'approved') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
        );
      });
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        title: Text(AppLocalizations.of(context)!.driverRegistrationTitle, style:  TextStyle(color: context.textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.closeButton, style:  TextStyle(color: context.textGreyColor)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: TayarColors.primary))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (status == 'pending_review')
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: TayarColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: TayarColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.applicationUnderReviewBanner,
                        style: TextStyle(color: context.textColor),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Text(
                      AppLocalizations.of(context)!.registrationIntroText,
                      style:  TextStyle(color: context.textGreyColor, fontSize: 14),
                    ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView(
                      children: [
                        _SectionTile(
                          title: AppLocalizations.of(context)!.sectionPersonalInfo,
                          isComplete: _isSectionComplete('personalInfo'),
                          onTap: () => _openSection(const PersonalInfoScreen()),
                        ),
                        _SectionTile(
                          title: AppLocalizations.of(context)!.sectionDrivingLicense,
                          isComplete: _isSectionComplete('drivingLicense'),
                          onTap: () => _openSection(const DrivingLicenseScreen()),
                        ),
                        _SectionTile(
                          title: AppLocalizations.of(context)!.sectionPersonalDocuments,
                          isComplete: _isSectionComplete('personalDocuments'),
                          onTap: () => _openSection(const PersonalDocumentsScreen()),
                        ),
                        _SectionTile(
                          title: AppLocalizations.of(context)!.sectionBikeInfo,
                          isComplete: _isSectionComplete('bikeInfo'),
                          onTap: () => _openSection(const BikeInfoScreen()),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: (_allSectionsComplete && !_isSubmitting && status != 'pending_review')
                          ? _submitRegistration
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TayarColors.primary,
                        disabledBackgroundColor: context.cardColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ?  SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: context.textColor, strokeWidth: 2),
                            )
                          : Text(
                              status == 'pending_review'
                                  ? AppLocalizations.of(context)!.applicationUnderReviewButton
                                  : AppLocalizations.of(context)!.continueButton,
                              style:  TextStyle(
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

class _SectionTile extends StatelessWidget {
  final String title;
  final bool isComplete;
  final VoidCallback onTap;

  const _SectionTile({required this.title, required this.isComplete, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      title: Text(title, style:  TextStyle(color: context.textColor, fontSize: 16)),
      subtitle: Text(
        isComplete
            ? AppLocalizations.of(context)!.sectionCompleteLabel
            : AppLocalizations.of(context)!.sectionIncompleteLabel,
        style: TextStyle(
          color: isComplete ? TayarColors.primary : context.textGreyColor,
          fontSize: 14,
        ),
      ),
      leading: CircleAvatar(
        backgroundColor: isComplete ? TayarColors.primary.withValues(alpha: 0.15) : context.cardColor,
        child: Icon(
          isComplete ? Icons.check : Icons.description_outlined,
          color: isComplete ? TayarColors.primary : context.textGreyColor,
        ),
      ),
      trailing:  Icon(Icons.chevron_left, color: context.textGreyColor),
    );
  }
}

// ====================================================
// ====== أدوات مشتركة: حقل نص + مربع رفع صورة ======
// ====================================================
class _FormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const _FormTextField({required this.controller, required this.hint, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style:  TextStyle(color: context.textColor),
        textAlign: TextAlign.right,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:  TextStyle(color: context.textGreyColor),
          filled: true,
          fillColor: context.cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}

class _PhotoUploadTile extends StatelessWidget {
  final String label;
  final Uint8List? imageBytes;
  final VoidCallback onTap;
  final bool optional;

  const _PhotoUploadTile({
    required this.label,
    required this.imageBytes,
    required this.onTap,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  image: imageBytes != null
                      ? DecorationImage(image: MemoryImage(imageBytes!), fit: BoxFit.cover)
                      : null,
                ),
                child: imageBytes == null
                    ?  Icon(Icons.add, color: context.textGreyColor, size: 30)
                    : null,
              ),
              if (optional)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(AppLocalizations.of(context)!.optionalLabel, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style:  TextStyle(color: context.textColor, fontSize: 12), textAlign: TextAlign.center),
      ],
    );
  }
}

// ====================================================
// ====== 1) المعلومات الشخصية ======
// ====================================================
class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  Uint8List? _photoBytes;
  bool _isSaving = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
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
      _birthDateController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.fullNameRequiredError)),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'personalInfo': {
          'firstName': _firstNameController.text.trim(),
          'lastName': _lastNameController.text.trim(),
          'birthDate': _birthDateController.text.trim(),
          'hasPhoto': _photoBytes != null,
          'complete': true,
        },
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
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: AppLocalizations.of(context)!.sectionPersonalInfo,
      isSaving: _isSaving,
      onSave: _save,
      children: [
        Center(
          child: _PhotoUploadTile(label: AppLocalizations.of(context)!.personalPhotoLabel, imageBytes: _photoBytes, onTap: _pickPhoto),
        ),
        const SizedBox(height: 24),
        _FormTextField(controller: _firstNameController, hint: AppLocalizations.of(context)!.firstNameHint),
        _FormTextField(controller: _lastNameController, hint: AppLocalizations.of(context)!.lastNameHint),
        GestureDetector(
          onTap: _pickDate,
          child: AbsorbPointer(
            child: _FormTextField(controller: _birthDateController, hint: AppLocalizations.of(context)!.birthDateHint),
          ),
        ),
      ],
    );
  }
}

// ====================================================
// ====== 2) رخصة القيادة ======
// ====================================================
class DrivingLicenseScreen extends StatefulWidget {
  const DrivingLicenseScreen({super.key});

  @override
  State<DrivingLicenseScreen> createState() => _DrivingLicenseScreenState();
}

class _DrivingLicenseScreenState extends State<DrivingLicenseScreen> {
  final _expiryController = TextEditingController();
  Uint8List? _licensePhoto;
  bool _isSaving = false;

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _licensePhoto = bytes);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      _expiryController.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_licensePhoto == null || _expiryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.licensePhotoUploadRequired)),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'drivingLicense': {
          'expiryDate': _expiryController.text.trim(),
          'hasPhoto': true,
          'complete': true,
        },
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ رخصة القيادة: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.saveFailedError)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: AppLocalizations.of(context)!.sectionDrivingLicense,
      isSaving: _isSaving,
      onSave: _save,
      children: [
        Center(
          child: _PhotoUploadTile(label: AppLocalizations.of(context)!.sectionDrivingLicense, imageBytes: _licensePhoto, onTap: _pickPhoto),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _pickDate,
          child: AbsorbPointer(
            child: _FormTextField(controller: _expiryController, hint: AppLocalizations.of(context)!.licenseExpiryHint),
          ),
        ),
      ],
    );
  }
}

// ====================================================
// ====== 3) المستندات الشخصية ======
// ====================================================
class PersonalDocumentsScreen extends StatefulWidget {
  const PersonalDocumentsScreen({super.key});

  @override
  State<PersonalDocumentsScreen> createState() => _PersonalDocumentsScreenState();
}

class _PersonalDocumentsScreenState extends State<PersonalDocumentsScreen> {
  final _idNumberController = TextEditingController();
  Uint8List? _criminalRecordFront;
  Uint8List? _criminalRecordBack;
  bool _isSaving = false;

  Future<void> _pickPhoto(bool isFront) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      if (isFront) {
        _criminalRecordFront = bytes;
      } else {
        _criminalRecordBack = bytes;
      }
    });
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_criminalRecordFront == null || _idNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.criminalRecordUploadRequired)),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'personalDocuments': {
          'idNumber': _idNumberController.text.trim(),
          'hasCriminalRecordFront': true,
          'hasCriminalRecordBack': _criminalRecordBack != null,
          'complete': true,
        },
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ المستندات الشخصية: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.saveFailedError)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: AppLocalizations.of(context)!.sectionPersonalDocuments,
      isSaving: _isSaving,
      onSave: _save,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PhotoUploadTile(
              label: AppLocalizations.of(context)!.criminalRecordFrontLabel,
              imageBytes: _criminalRecordFront,
              onTap: () => _pickPhoto(true),
            ),
            _PhotoUploadTile(
              label: AppLocalizations.of(context)!.criminalRecordBackLabel,
              imageBytes: _criminalRecordBack,
              optional: true,
              onTap: () => _pickPhoto(false),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _FormTextField(
          controller: _idNumberController,
          hint: AppLocalizations.of(context)!.idNumberHint,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}

// ====================================================
// ====== 4) معلومات الموتوسيكل ======
// ====================================================
class BikeInfoScreen extends StatefulWidget {
  const BikeInfoScreen({super.key});

  @override
  State<BikeInfoScreen> createState() => _BikeInfoScreenState();
}

class _BikeInfoScreenState extends State<BikeInfoScreen> {
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _yearController = TextEditingController();
  Uint8List? _bikePhoto;
  Uint8List? _licensePhoto;
  bool _isSaving = false;

  Future<void> _pickPhoto(bool isBikePhoto) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      if (isBikePhoto) {
        _bikePhoto = bytes;
      } else {
        _licensePhoto = bytes;
      }
    });
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_bikePhoto == null || _brandController.text.trim().isEmpty || _plateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.bikeInfoRequiredError)),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'bikeInfo': {
          'brand': _brandController.text.trim(),
          'model': _modelController.text.trim(),
          'color': _colorController.text.trim(),
          'plateNumber': _plateController.text.trim(),
          'year': _yearController.text.trim(),
          'hasBikePhoto': true,
          'hasLicensePhoto': _licensePhoto != null,
          'complete': true,
        },
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ معلومات الموتوسيكل: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.saveFailedError)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionScaffold(
      title: AppLocalizations.of(context)!.sectionBikeInfo,
      isSaving: _isSaving,
      onSave: _save,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PhotoUploadTile(label: AppLocalizations.of(context)!.bikePhotoLabel, imageBytes: _bikePhoto, onTap: () => _pickPhoto(true)),
            _PhotoUploadTile(label: AppLocalizations.of(context)!.bikeLicensePhotoLabel, imageBytes: _licensePhoto, onTap: () => _pickPhoto(false)),
          ],
        ),
        const SizedBox(height: 24),
        _FormTextField(controller: _brandController, hint: AppLocalizations.of(context)!.bikeBrandHint),
        _FormTextField(controller: _modelController, hint: AppLocalizations.of(context)!.bikeModelHint),
        _FormTextField(controller: _colorController, hint: AppLocalizations.of(context)!.bikeColorHint),
        _FormTextField(controller: _plateController, hint: AppLocalizations.of(context)!.bikePlateLabel),
        _FormTextField(
          controller: _yearController,
          hint: AppLocalizations.of(context)!.bikeYearHint,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
}

// ====================================================
// ====== Scaffold مشترك لكل شاشات الأقسام ======
// ====================================================
class _SectionScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isSaving;
  final VoidCallback onSave;

  const _SectionScaffold({
    required this.title,
    required this.children,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        leading: IconButton(
          icon:  Icon(Icons.arrow_forward, color: context.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style:  TextStyle(color: context.textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.closeButton, style:  TextStyle(color: context.textGreyColor)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: ListView(children: children)),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: isSaving ? null : onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: TayarColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: isSaving
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: context.onPrimaryColor, strokeWidth: 2),
                      )
                    : Text(
                        AppLocalizations.of(context)!.saveButton,
                        style:  TextStyle(color: context.textColor, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}