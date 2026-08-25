import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/driver/registration/registration_shared_widgets.dart';
import 'package:tayay_app/services/driver_document_upload_service.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';
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

  // ====== بتتحط true بعد محاولة "حفظ" فاشلة والحقل المطلوب لسه فاضي،
  // عشان نعرض إطار أحمر حواليه — وبترجع false تلقائيًا أول ما المستخدم
  // يعبّيه ======
  bool _bikePhotoError = false;
  bool _brandError = false;
  bool _plateError = false;

  @override
  void initState() {
    super.initState();
    _brandController.addListener(_clearBrandError);
    _plateController.addListener(_clearPlateError);
  }

  void _clearBrandError() {
    if (_brandError && _brandController.text.trim().isNotEmpty) {
      setState(() => _brandError = false);
    }
  }

  void _clearPlateError() {
    if (_plateError && _plateController.text.trim().isNotEmpty) {
      setState(() => _plateError = false);
    }
  }

  @override
  void dispose() {
    _brandController.removeListener(_clearBrandError);
    _plateController.removeListener(_clearPlateError);
    _brandController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    super.dispose();
  }

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
        _bikePhotoError = false;
      } else {
        _licensePhoto = bytes;
      }
    });
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final bikePhotoMissing = _bikePhoto == null;
    final brandEmpty = _brandController.text.trim().isEmpty;
    final plateEmpty = _plateController.text.trim().isEmpty;
    if (bikePhotoMissing || brandEmpty || plateEmpty) {
      setState(() {
        _bikePhotoError = bikePhotoMissing;
        _brandError = brandEmpty;
        _plateError = plateEmpty;
      });
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.bikeInfoRequiredError,
        type: ToastType.warning,
      );
      return;
    }
    setState(() => _bikePhotoError = false);
    setState(() => _isSaving = true);
    try {
      final bikePhotoUrl = await DriverDocumentUploadService.uploadDocument(
        driverId: uid,
        fileName: 'bike_photo',
        bytes: _bikePhoto!,
      );
      String? licensePhotoUrl;
      if (_licensePhoto != null) {
        licensePhotoUrl = await DriverDocumentUploadService.uploadDocument(
          driverId: uid,
          fileName: 'bike_license_photo',
          bytes: _licensePhoto!,
        );
      }
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'bikeInfo': {
          'brand': _brandController.text.trim(),
          'model': _modelController.text.trim(),
          'color': _colorController.text.trim(),
          'plateNumber': _plateController.text.trim(),
          'year': _yearController.text.trim(),
          'hasBikePhoto': true,
          'bikePhotoUrl': bikePhotoUrl,
          'hasLicensePhoto': _licensePhoto != null,
          'licensePhotoUrl': ?licensePhotoUrl,
          'complete': true,
        },
      }, SetOptions(merge: true));
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ معلومات الموتوسيكل: $e');
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
              showError: _bikePhotoError,
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
          showError: _brandError,
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
          showError: _plateError,
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
