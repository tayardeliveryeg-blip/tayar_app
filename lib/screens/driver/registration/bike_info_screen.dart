import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/driver/registration/registration_shared_widgets.dart';
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
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
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
    if (_bikePhoto == null ||
        _brandController.text.trim().isEmpty ||
        _plateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.bikeInfoRequiredError),
        ),
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
    return SectionScaffold(
      title: AppLocalizations.of(context)!.sectionBikeInfo,
      isSaving: _isSaving,
      onSave: _save,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            PhotoUploadTile(
              label: AppLocalizations.of(context)!.bikePhotoLabel,
              imageBytes: _bikePhoto,
              onTap: () => _pickPhoto(true),
            ),
            PhotoUploadTile(
              label: AppLocalizations.of(context)!.bikeLicensePhotoLabel,
              imageBytes: _licensePhoto,
              onTap: () => _pickPhoto(false),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FormTextField(
          controller: _brandController,
          hint: AppLocalizations.of(context)!.bikeBrandHint,
        ),
        FormTextField(
          controller: _modelController,
          hint: AppLocalizations.of(context)!.bikeModelHint,
        ),
        FormTextField(
          controller: _colorController,
          hint: AppLocalizations.of(context)!.bikeColorHint,
        ),
        FormTextField(
          controller: _plateController,
          hint: AppLocalizations.of(context)!.bikePlateLabel,
        ),
        FormTextField(
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
