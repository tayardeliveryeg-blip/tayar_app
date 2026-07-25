import 'dart:typed_data';

import 'photo_validation_result.dart';
export 'photo_validation_result.dart';

import 'profile_photo_validator_stub.dart'
    if (dart.library.io) 'profile_photo_validator_io.dart'
    if (dart.library.html) 'profile_photo_validator_web.dart'
    as impl;

/// Validates that a picked/captured image is suitable as a security-grade
/// profile picture: exactly one face, close-up, centered, forward-facing,
/// eyes open — similar to InDrive's driver photo check.
///
/// Works on every platform:
/// - Android/iOS: uses google_mlkit_face_detection (on-device, accurate).
/// - Web: uses face-api.js running in the browser via JS interop
///   (see web/face_photo_check.js).
///
/// [imagePath] is only used on mobile (must be a real file-system path,
/// e.g. XFile.path). [bytes] is the same image's raw bytes and is used on
/// every platform.
class ProfilePhotoValidator {
  ProfilePhotoValidator._();

  static Future<PhotoValidationResult> validate({
    required String imagePath,
    required Uint8List bytes,
  }) {
    return impl.validateImpl(imagePath: imagePath, bytes: bytes);
  }

  /// Call once at app shutdown if you want to free native resources early
  /// (not required — the OS/browser reclaims them anyway).
  static void dispose() => impl.disposeImpl();
}
