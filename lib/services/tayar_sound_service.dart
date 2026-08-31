import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ====== سيرفس صوت التنبيهات: بيشغّل صوت "دينج" قصير + اهتزاز خفيف مع
// بعض في نفس اللحظة، لحظة وصول إشعار مهم والتطبيق فاتح (foreground) -
// زي عرض سعر جديد من سائق، أو وصول الطيار. قابل للتفعيل/الإيقاف من
// المستخدم (مفعّل افتراضيًا) عن طريق مفتاح واحد في SharedPreferences ======
class TayarSoundService {
  static const _prefsKey = 'notification_sound_enabled';
  static final AudioPlayer _player = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefsKey) ?? true;
  }

  static Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }

  /// يشغّل صوت التنبيه + اهتزاز خفيف مع بعض، لو المستخدم مفعّل الخاصية.
  /// آمن الاستدعاء حتى لو فشل تشغيل الصوت (مثلًا الجهاز في وضع صامت) -
  /// الاهتزاز بيتنفذ بغض النظر عن نتيجة الصوت.
  static Future<void> playNotificationAlert() async {
    if (!await isEnabled()) return;

    HapticFeedback.mediumImpact();
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/notification_chime.wav'));
    } catch (_) {
      // ====== نتجاهل أي فشل في تشغيل الصوت (جهاز صامت، مشكلة في
      // audio session، إلخ) - الاهتزاز فوق كافي كـ fallback بصري/حسي ======
    }
  }
}
