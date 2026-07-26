import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:tayay_app/services/photo_check_thresholds.dart';
import 'package:tayay_app/services/photo_validation_result.dart';

// ====== ربط JS interop مع الدالة العامة اللي بيعرّفها web/face_photo_check.js
// (window.tayarValidateFacePhoto). بترجع Promise<String> فيه JSON.stringify
// لنتيجة تحليل face-api.js على الصورة ======
@JS('tayarValidateFacePhoto')
external JSPromise<JSString> _tayarValidateFacePhoto(JSString base64Image);

/// نسخة الويب من فحص صورة البروفايل: بتستخدم face-api.js (شغال جوه المتصفح
/// عن طريق JS interop، شوف web/face_photo_check.js) بدل ML Kit اللي
/// معندهاش تنفيذ للويب أصلاً.
Future<PhotoValidationResult> validateImpl({
  required String imagePath,
  required Uint8List bytes,
}) async {
  final base64Image = base64Encode(bytes);

  String jsonStr;
  try {
    final resultJs = await _tayarValidateFacePhoto(base64Image.toJS).toDart;
    jsonStr = resultJs.toDart;
  } catch (_) {
    return PhotoValidationResult.invalid('تعذر تحليل الصورة، حاول مرة أخرى');
  }

  Map<String, dynamic> data;
  try {
    data = jsonDecode(jsonStr) as Map<String, dynamic>;
  } catch (_) {
    return PhotoValidationResult.invalid('تعذر تحليل الصورة، حاول مرة أخرى');
  }

  if (data['ok'] != true) {
    switch (data['reason']) {
      case 'no_face':
        return PhotoValidationResult.invalid(
          'لم يتم العثور على وجه في الصورة. من فضلك التقط صورة لوجهك بوضوح',
        );
      case 'multiple_faces':
        return PhotoValidationResult.invalid(
          'تم رصد أكثر من وجه في الصورة. تأكد أنك الشخص الوحيد في الصورة',
        );
      default:
        // models_error / decode_error / أي سبب تاني غير متوقع
        return PhotoValidationResult.invalid(
          'تعذر تحليل الصورة، حاول مرة أخرى',
        );
    }
  }

  final faceWidthRatio = (data['faceWidthRatio'] as num).toDouble();
  if (faceWidthRatio < PhotoCheckThresholds.minFaceWidthRatio) {
    return PhotoValidationResult.invalid(
      'الوجه بعيد جدًا عن الكاميرا. اقترب أكتر والتقط صورة قريبة للوجه',
    );
  }

  final offsetXRatio = (data['offsetXRatio'] as num).toDouble();
  final offsetYRatio = (data['offsetYRatio'] as num).toDouble();
  if (offsetXRatio > PhotoCheckThresholds.maxCenterOffsetRatio ||
      offsetYRatio > PhotoCheckThresholds.maxCenterOffsetRatio) {
    return PhotoValidationResult.invalid('من فضلك ضع وجهك في منتصف الصورة');
  }

  // yaw على الويب مقاس بنسبة عدم تماثل (مش زاوية حقيقية زي ML Kit)، وroll
  // زاوية حقيقية من خط العينين — شوف photo_check_thresholds.dart للتفاصيل
  final yawAsymmetryRatio = (data['yawAsymmetryRatio'] as num)
      .toDouble()
      .abs();
  final rollDegrees = (data['rollDegrees'] as num).toDouble().abs();
  if (yawAsymmetryRatio > PhotoCheckThresholds.maxYawAsymmetryRatio ||
      rollDegrees > PhotoCheckThresholds.maxRollDegrees) {
    return PhotoValidationResult.invalid('من فضلك انظر مباشرة إلى الكاميرا');
  }

  final leftEar = (data['leftEar'] as num).toDouble();
  final rightEar = (data['rightEar'] as num).toDouble();
  if (leftEar < PhotoCheckThresholds.minEyeAspectRatio ||
      rightEar < PhotoCheckThresholds.minEyeAspectRatio) {
    return PhotoValidationResult.invalid(
      'تأكد أن عينيك مفتوحتين وملامح وجهك واضحة',
    );
  }

  return PhotoValidationResult.valid();
}

void disposeImpl() {}
