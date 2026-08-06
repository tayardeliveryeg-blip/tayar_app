import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// ====== خدمة موحدة لرفع مستندات الكابتن (فيش وتشبيه، رخصة قيادة،
/// صورة الموتوسيكل، ترخيص الموتوسيكل) فعليًا على Cloudinary.
/// قبل كده الصور دي كانت بتتاخد من المستخدم وتفضل في الذاكرة بس وبتتضيع
/// من غير ما تتحفظ لأي مكان - وده كان معناه إن مراجعة الأدمن للمستندات
/// كانت شكلية بالكامل.
///
/// بدأنا أول مرة بـ Firebase Storage، لكن Storage بيتطلب خطة Blaze حتى
/// للاستخدام المجاني، فاستبدلناها بـ Cloudinary (خطة مجانية 25GB شهريًا)
/// عن طريق "unsigned upload preset" - يعني رفع مباشر من التطبيق من غير
/// ما نحتاج أي مفتاح سري جوه الكود أو سيرفر وسيط.
///
/// المسار: driver_documents/{driverId}/{fileName} (بيتحدد كـ public_id
/// عن طريق الـ folder + context اللي بنبعتهم مع الطلب). ======
class DriverDocumentUploadService {
  DriverDocumentUploadService._();

  static const String _cloudName = 'x7ghgz6x';
  static const String _uploadPreset = 'tayar_driver_docs';
  static final Uri _uploadUrl = Uri.parse(
    'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
  );

  /// بيرفع الصورة على Cloudinary ويرجع رابط تحميلها (secure_url).
  /// لو الرفع فشل (نت، إعدادات الـ preset، إلخ) بيرمي الاستثناء عشان
  /// الشاشة اللي بتستدعيه تقدر تعرض رسالة خطأ واضحة للمستخدم بدل ما
  /// تفتكر إن الحفظ نجح وهو أصلاً فشل.
  static Future<String> uploadDocument({
    required String driverId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final request = http.MultipartRequest('POST', _uploadUrl)
      ..fields['upload_preset'] = _uploadPreset
      ..fields['public_id'] = '$driverId/$fileName'
      ..fields['folder'] = 'driver_documents'
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: '$fileName.jpg',
        ),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        'فشل رفع المستند على Cloudinary (${response.statusCode}): '
        '${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = data['secure_url'] as String?;
    if (secureUrl == null || secureUrl.isEmpty) {
      throw Exception('رد Cloudinary غير متوقع: مفيش secure_url في الرد.');
    }
    return secureUrl;
  }
}
