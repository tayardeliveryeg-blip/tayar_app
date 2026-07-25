import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Result of validating a profile photo.
class PhotoValidationResult {
  final bool isValid;
  final String? errorMessageAr; // Arabic message to show the user

  const PhotoValidationResult._({required this.isValid, this.errorMessageAr});

  factory PhotoValidationResult.valid() =>
      const PhotoValidationResult._(isValid: true);

  factory PhotoValidationResult.invalid(String ar) =>
      PhotoValidationResult._(isValid: false, errorMessageAr: ar);
}

/// Validates that a picked/captured image is suitable as a security-grade
/// profile picture: exactly one face, close-up (large in frame), centered,
/// facing forward, eyes open — similar to InDrive's driver photo check.
///
/// ⚠️ google_mlkit_face_detection has no web implementation, so on web this
/// always returns valid() without checking — the check only applies on
/// Android/iOS, which is where camera-based verification actually matters.
class ProfilePhotoValidator {
  ProfilePhotoValidator._();

  static FaceDetector? _detector;

  static FaceDetector _getDetector() {
    return _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        performanceMode: FaceDetectorMode.accurate,
        enableClassification: true, // needed for eyesOpen probability
        minFaceSize: 0.15, // ignore tiny/far-away faces early
      ),
    );
  }

  static const double _minFaceWidthRatio = 0.35;
  static const double _maxCenterOffsetRatio = 0.22;
  static const double _maxYawDegrees = 20;
  static const double _maxRollDegrees = 20;

  /// [imagePath] must be a real file-system path (e.g. XFile.path on
  /// mobile) — required by ML Kit. [bytes] is the same image's raw bytes,
  /// used only to read width/height (works on every platform).
  static Future<PhotoValidationResult> validate({
    required String imagePath,
    required Uint8List bytes,
  }) async {
    if (kIsWeb) return PhotoValidationResult.valid();

    final inputImage = InputImage.fromFilePath(imagePath);

    List<Face> faces;
    try {
      faces = await _getDetector().processImage(inputImage);
    } catch (_) {
      return PhotoValidationResult.invalid('تعذر تحليل الصورة، حاول مرة أخرى');
    }

    if (faces.isEmpty) {
      return PhotoValidationResult.invalid(
        'لم يتم العثور على وجه في الصورة. من فضلك التقط صورة لوجهك بوضوح',
      );
    }
    if (faces.length > 1) {
      return PhotoValidationResult.invalid(
        'تم رصد أكثر من وجه في الصورة. تأكد أنك الشخص الوحيد في الصورة',
      );
    }

    final face = faces.first;
    final imageSize = await _decodeImageSize(bytes);
    if (imageSize == null) {
      return PhotoValidationResult.invalid('حدث خطأ أثناء قراءة الصورة');
    }

    final faceWidthRatio = face.boundingBox.width / imageSize.width;
    if (faceWidthRatio < _minFaceWidthRatio) {
      return PhotoValidationResult.invalid(
        'الوجه بعيد جدًا عن الكاميرا. اقترب أكتر والتقط صورة قريبة للوجه',
      );
    }

    final faceCenterX = face.boundingBox.left + face.boundingBox.width / 2;
    final faceCenterY = face.boundingBox.top + face.boundingBox.height / 2;
    final offsetXRatio = (faceCenterX - imageSize.width / 2).abs() / imageSize.width;
    final offsetYRatio = (faceCenterY - imageSize.height / 2).abs() / imageSize.height;
    if (offsetXRatio > _maxCenterOffsetRatio || offsetYRatio > _maxCenterOffsetRatio) {
      return PhotoValidationResult.invalid('من فضلك ضع وجهك في منتصف الصورة');
    }

    final yaw = face.headEulerAngleY ?? 0;
    final roll = face.headEulerAngleZ ?? 0;
    if (yaw.abs() > _maxYawDegrees || roll.abs() > _maxRollDegrees) {
      return PhotoValidationResult.invalid('من فضلك انظر مباشرة إلى الكاميرا');
    }

    final leftEyeOpen = face.leftEyeOpenProbability;
    final rightEyeOpen = face.rightEyeOpenProbability;
    if (leftEyeOpen != null && rightEyeOpen != null) {
      if (leftEyeOpen < 0.4 || rightEyeOpen < 0.4) {
        return PhotoValidationResult.invalid(
          'تأكد أن عينيك مفتوحتين وملامح وجهك واضحة',
        );
      }
    }

    return PhotoValidationResult.valid();
  }

  static Future<_ImgSize?> _decodeImageSize(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = _ImgSize(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      codec.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  /// Call once at app shutdown if you want to free native resources early
  /// (not required — the OS reclaims them anyway).
  static void dispose() {
    _detector?.close();
    _detector = null;
  }
}

class _ImgSize {
  final double width;
  final double height;
  _ImgSize(this.width, this.height);
}