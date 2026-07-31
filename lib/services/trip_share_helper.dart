import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// ====== مساعد "مشاركة الرحلة": بيبني رسالة نصية فيها تفاصيل الرحلة +
/// رابط جوجل مابس لموقع الطرف التاني وقت الإرسال، وبيفتح واتساب عشان
/// المستخدم يختار يبعتها لمين (أهل/صحاب) - رابط عام wa.me من غير رقم
/// محدد، فبيفتح شاشة اختيار جهة اتصال جوه واتساب نفسه ======

String buildTripShareMessage({
  required String intro,
  required String otherPartyLabel,
  required String otherPartyName,
  required String fromLabel,
  required String pickupAddress,
  required String toLabel,
  required String destinationAddress,
  String? locationLabel,
  LatLng? currentLocation,
}) {
  final buffer = StringBuffer()
    ..writeln(intro)
    ..writeln('$otherPartyLabel: $otherPartyName')
    ..writeln('$fromLabel: $pickupAddress')
    ..writeln('$toLabel: $destinationAddress');
  if (currentLocation != null && locationLabel != null) {
    buffer.write(
      '$locationLabel: https://www.google.com/maps?q='
      '${currentLocation.latitude},${currentLocation.longitude}',
    );
  }
  return buffer.toString();
}

/// بيفتح واتساب لمشاركة نص الرحلة، بيرجع true لو نجح فتح التطبيق
Future<bool> shareTripViaWhatsapp(String message) {
  final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
