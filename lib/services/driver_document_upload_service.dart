import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// ====== خدمة موحدة لرفع مستندات الكابتن (فيش وتشبيه، رخصة قيادة،
/// صورة الموتوسيكل، ترخيص الموتوسيكل) فعليًا على Firebase Storage.
/// قبل كده الصور دي كانت بتتاخد من المستخدم وتفضل في الذاكرة بس وبتتضيع
/// من غير ما تتحفظ لأي مكان - وده كان معناه إن مراجعة الأدمن للمستندات
/// كانت شكلية بالكامل. المسار: driver_documents/{driverId}/{fileName} -
/// محمي بقواعد storage.rules (الكابتن نفسه + الأدمن بس يقدروا يشوفوه) ======
class DriverDocumentUploadService {
  DriverDocumentUploadService._();

  /// بيرفع الصورة ويرجع رابط تحميلها. لو الرفع فشل (نت، صلاحيات، إلخ)
  /// بيرمي الاستثناء عشان الشاشة اللي بتستدعيه تقدر تعرض رسالة خطأ
  /// واضحة للمستخدم بدل ما تفتكر إن الحفظ نجح وهو أصلاً فشل.
  static Future<String> uploadDocument({
    required String driverId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final ref = FirebaseStorage.instance.ref(
      'driver_documents/$driverId/$fileName.jpg',
    );
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
