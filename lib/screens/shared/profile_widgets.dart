// ====== ودجتس مشتركة بين شاشة بروفايل الراكب (passenger_profile_screen.dart)
// وشاشة بروفايل الطيار (driver_profile_screen.dart) - كانوا متكررين حرفيًا
// (copy-paste) في الملفين، فاتنقلوا هنا عشان يبقوا مصدر واحد بس ======
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====================================================
// ====== دائرة صورة البروفايل مع أيقونة تعديل فوقها ======
// ====================================================
class ProfilePhotoPicker extends StatelessWidget {
  final String? existingPhotoBase64;
  final Uint8List? newPhotoBytes;
  final bool isChecking;
  final VoidCallback? onTap;

  const ProfilePhotoPicker({
    super.key,
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
class ProfileTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const ProfileTextField({
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
