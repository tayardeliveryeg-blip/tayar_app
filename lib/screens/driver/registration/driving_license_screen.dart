import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/driver/registration/registration_shared_widgets.dart';
class DrivingLicenseScreen extends StatefulWidget {
  const DrivingLicenseScreen({super.key});

  @override
  State<DrivingLicenseScreen> createState() => _DrivingLicenseScreenState();
}

class _DrivingLicenseScreenState extends State<DrivingLicenseScreen> {
  final _expiryController = TextEditingController();
  Uint8List? _licensePhoto;
  bool _isSaving = false;

  // ====== بتتحط true بعد محاولة "حفظ" فاشلة والحقل المطلوب لسه فاضي،
  // عشان نعرض إطار أحمر حواليه — وبترجع false تلقائيًا أول ما المستخدم
  // يعبّيه ======
  bool _licensePhotoError = false;
  bool _expiryError = false;

  @override
  void initState() {
    super.initState();
    _expiryController.addListener(_clearExpiryError);
  }

  void _clearExpiryError() {
    if (_expiryError && _expiryController.text.trim().isNotEmpty) {
      setState(() => _expiryError = false);
    }
  }

  @override
  void dispose() {
    _expiryController.removeListener(_clearExpiryError);
    _expiryController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _licensePhoto = bytes;
      _licensePhotoError = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      _expiryController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final licensePhotoMissing = _licensePhoto == null;
    final expiryEmpty = _expiryController.text.trim().isEmpty;
    if (licensePhotoMissing || expiryEmpty) {
      setState(() {
        _licensePhotoError = licensePhotoMissing;
        _expiryError = expiryEmpty;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.licensePhotoUploadRequired,
          ),
        ),
      );
      return;
    }
    setState(() => _licensePhotoError = false);
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
    return SectionScaffold(
      title: AppLocalizations.of(context)!.sectionDrivingLicense,
      isSaving: _isSaving,
      onSave: _save,
      children: [
        Center(
          child: PhotoUploadTile(
            label: AppLocalizations.of(context)!.sectionDrivingLicense,
            imageBytes: _licensePhoto,
            onTap: _pickPhoto,
            showError: _licensePhotoError,
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _pickDate,
          child: AbsorbPointer(
            child: FormTextField(
              controller: _expiryController,
              hint: AppLocalizations.of(context)!.licenseExpiryHint,
              showError: _expiryError,
            ),
          ),
        ),
      ],
    );
  }
}

// ====================================================
// ====== 3) المستندات الشخصية ======
// ====================================================
