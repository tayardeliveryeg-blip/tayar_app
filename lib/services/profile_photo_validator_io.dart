import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import 'package:tayay_app/services/photo_check_thresholds.dart';
import 'package:tayay_app/services/photo_validation_result.dart';

FaceDetector? _detector;

FaceDetector _getDetector() {
  return _detector ??= FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableClassification: true, // needed for eyesOpen probability
      minFaceSize: 0.15, // ignore tiny/far-away faces early
    ),
  );
}

Future<PhotoValidationResult> validateImpl({
  required String imagePath,
  required Uint8List bytes,
}) async {
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
  if (faceWidthRatio < PhotoCheckThresholds.minFaceWidthRatio) {
    return PhotoValidationResult.invalid(
      'الوجه بعيد جدًا عن الكاميرا. اقترب أكتر والتقط صورة قريبة للوجه',
    );
  }

  final faceCenterX = face.boundingBox.left + face.boundingBox.width / 2;
  final faceCenterY = face.boundingBox.top + face.boundingBox.height / 2;
  final offsetXRatio =
      (faceCenterX - imageSize.width / 2).abs() / imageSize.width;
  final offsetYRatio =
      (faceCenterY - imageSize.height / 2).abs() / imageSize.height;
  if (offsetXRatio > PhotoCheckThresholds.maxCenterOffsetRatio ||
      offsetYRatio > PhotoCheckThresholds.maxCenterOffsetRatio) {
    return PhotoValidationResult.invalid('من فضلك ضع وجهك في منتصف الصورة');
  }

  final yaw = face.headEulerAngleY ?? 0;
  final roll = face.headEulerAngleZ ?? 0;
  if (yaw.abs() > PhotoCheckThresholds.maxYawDegrees ||
      roll.abs() > PhotoCheckThresholds.maxRollDegrees) {
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

void disposeImpl() {
  _detector?.close();
  _detector = null;
}

Future<_ImgSize?> _decodeImageSize(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final size = _ImgSize(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    codec.dispose();
    return size;
  } catch (_) {
    return null;
  }
}

class _ImgSize {
  final double width;
  final double height;
  _ImgSize(this.width, this.height);
}
