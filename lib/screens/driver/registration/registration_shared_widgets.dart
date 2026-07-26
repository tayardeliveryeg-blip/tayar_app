import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart' show TayarColors, TayarThemeColors;

class FormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const FormTextField({
    super.key,
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


class PhotoUploadTile extends StatelessWidget {
  final String label;
  final Uint8List? imageBytes;
  final VoidCallback onTap;
  final bool optional;

  const PhotoUploadTile({
    super.key,
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
                      ? DecorationImage(
                          image: MemoryImage(imageBytes!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: imageBytes == null
                    ? Icon(Icons.add, color: context.textGreyColor, size: 30)
                    : null,
              ),
              if (optional)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.optionalLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: context.textColor, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ====================================================
// ====== Scaffold مشترك لكل شاشات الأقسام ======
// ====================================================

class SectionScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isSaving;
  final VoidCallback onSave;

  const SectionScaffold({
    super.key,
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
          icon: Icon(Icons.arrow_forward, color: context.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: TextStyle(color: context.textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)!.closeButton,
              style: TextStyle(color: context.textGreyColor),
            ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isSaving
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
