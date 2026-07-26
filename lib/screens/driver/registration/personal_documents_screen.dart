import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/driver/registration/registration_shared_widgets.dart';
class PersonalDocumentsScreen extends StatefulWidget {
  const PersonalDocumentsScreen({super.key});

  @override
  State<PersonalDocumentsScreen> createState() =>
      _PersonalDocumentsScreenState();
}

class _PersonalDocumentsScreenState extends State<PersonalDocumentsScreen> {
  final _idNumberController = TextEditingController();
  Uint8List? _criminalRecordFront;
  Uint8List? _criminalRecordBack;
  bool _isSaving = false;

  Future<void> _pickPhoto(bool isFront) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
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
    if (_criminalRecordFront == null ||
        _idNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.criminalRecordUploadRequired,
          ),
        ),
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
    return SectionScaffold(
      title: AppLocalizations.of(context)!.sectionPersonalDocuments,
      isSaving: _isSaving,
      onSave: _save,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            PhotoUploadTile(
              label: AppLocalizations.of(context)!.criminalRecordFrontLabel,
              imageBytes: _criminalRecordFront,
              onTap: () => _pickPhoto(true),
            ),
            PhotoUploadTile(
              label: AppLocalizations.of(context)!.criminalRecordBackLabel,
              imageBytes: _criminalRecordBack,
              optional: true,
              onTap: () => _pickPhoto(false),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FormTextField(
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
