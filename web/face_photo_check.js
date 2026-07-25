// ====================================================
// فحص صورة البروفايل على الويب باستخدام face-api.js
// (لازم يتحمّل بعد سكريبت face-api.min.js في index.html)
// ====================================================

let _modelsLoadPromise = null;

function _loadFaceApiModels() {
  if (_modelsLoadPromise) return _modelsLoadPromise;

  // موديلات محلية جوه web/models/ (بدل الاعتماد على CDN خارجي) — بكده
  // مفيش تأخير أو اعتمادية على جهة تالتة وقت الاستخدام
  const MODEL_URL = "models";

  _modelsLoadPromise = Promise.all([
    faceapi.nets.tinyFaceDetector.loadFromUri(MODEL_URL + "/tiny_face_detector"),
    faceapi.nets.faceLandmark68Net.loadFromUri(MODEL_URL + "/face_landmark_68"),
  ]);

  return _modelsLoadPromise;
}

// ====== حساب Eye Aspect Ratio (EAR) من نقاط العين الـ 6 (موديل 68 نقطة) ======
// EAR واطي = العين مقفولة. المرجع: Soukupová & Čech 2016 (نفس الطريقة
// المستخدمة في أغلب أدوات كشف الرمش بالمتصفح).
function _eyeAspectRatio(eyePoints) {
  const dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  const vertical1 = dist(eyePoints[1], eyePoints[5]);
  const vertical2 = dist(eyePoints[2], eyePoints[4]);
  const horizontal = dist(eyePoints[0], eyePoints[3]);
  if (horizontal === 0) return 0;
  return (vertical1 + vertical2) / (2.0 * horizontal);
}

// ====== الدالة الرئيسية اللي بتتنادى من Dart عبر js_interop ======
// بتاخد صورة Base64 (JPEG/PNG) وبترجع JSON string فيه نتيجة التحليل.
window.tayarValidateFacePhoto = async function (base64Image) {
  try {
    await _loadFaceApiModels();
  } catch (e) {
    return JSON.stringify({ ok: false, reason: "models_error" });
  }

  let img;
  try {
    img = await faceapi.fetchImage("data:image/jpeg;base64," + base64Image);
  } catch (e) {
    return JSON.stringify({ ok: false, reason: "decode_error" });
  }

  const detections = await faceapi
    .detectAllFaces(img, new faceapi.TinyFaceDetectorOptions())
    .withFaceLandmarks();

  if (detections.length === 0) {
    return JSON.stringify({ ok: false, reason: "no_face" });
  }
  if (detections.length > 1) {
    return JSON.stringify({ ok: false, reason: "multiple_faces" });
  }

  const det = detections[0];
  const box = det.detection.box;
  const imgWidth = img.width;
  const imgHeight = img.height;

  const faceWidthRatio = box.width / imgWidth;
  const centerX = box.x + box.width / 2;
  const centerY = box.y + box.height / 2;
  const offsetXRatio = Math.abs(centerX - imgWidth / 2) / imgWidth;
  const offsetYRatio = Math.abs(centerY - imgHeight / 2) / imgHeight;

  const landmarks = det.landmarks;
  const leftEyePts = landmarks.getLeftEye();
  const rightEyePts = landmarks.getRightEye();
  const nosePts = landmarks.getNose();

  const leftEar = _eyeAspectRatio(leftEyePts);
  const rightEar = _eyeAspectRatio(rightEyePts);

  // ====== تقدير الميل (roll) من زاوية الخط الواصل بين مركزي العينين ======
  const leftEyeCenter = {
    x: leftEyePts.reduce((s, p) => s + p.x, 0) / leftEyePts.length,
    y: leftEyePts.reduce((s, p) => s + p.y, 0) / leftEyePts.length,
  };
  const rightEyeCenter = {
    x: rightEyePts.reduce((s, p) => s + p.x, 0) / rightEyePts.length,
    y: rightEyePts.reduce((s, p) => s + p.y, 0) / rightEyePts.length,
  };
  const rollDegrees =
    (Math.atan2(
      rightEyeCenter.y - leftEyeCenter.y,
      rightEyeCenter.x - leftEyeCenter.x
    ) *
      180) /
    Math.PI;

  // ====== تقدير الالتفاف يمين/شمال (yaw) بمقارنة بعد طرف الأنف عن كل عين ======
  // (تقريب هندسي بسيط، مش زاوية 3D حقيقية زي ML Kit، لكنه كافي لرفض صور
  // البروفايل الجانبية بشكل واضح)
  const noseTip = nosePts[Math.floor(nosePts.length / 2)];
  const distToLeft = Math.hypot(noseTip.x - leftEyeCenter.x, noseTip.y - leftEyeCenter.y);
  const distToRight = Math.hypot(noseTip.x - rightEyeCenter.x, noseTip.y - rightEyeCenter.y);
  const avgDist = (distToLeft + distToRight) / 2;
  const yawAsymmetryRatio = avgDist === 0 ? 0 : (distToRight - distToLeft) / avgDist;

  return JSON.stringify({
    ok: true,
    faceWidthRatio,
    offsetXRatio,
    offsetYRatio,
    yawAsymmetryRatio,
    rollDegrees,
    leftEar,
    rightEar,
  });
};