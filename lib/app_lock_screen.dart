import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'passenger_home.dart' show TayarColors, TayarThemeColors;

// ====== شاشة قفل التطبيق: بتظهر فوق كل حاجة لو القفل مفعّل، وبتفضل
// ظاهرة لحد ما المستخدم يدخل الرقم السري الصح ======
class AppLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const AppLockScreen({super.key, required this.onUnlocked});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _controller = TextEditingController();
  String? _error;

  Future<void> _checkPin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('appLockPin');
    if (_controller.text == savedPin) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'الرقم السري غير صحيح');
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.bgColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, color: TayarColors.primary, size: 56),
                const SizedBox(height: 16),
                Text(
                  'أدخل الرقم السري',
                  style: TextStyle(color: context.textColor, fontSize: 18),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  obscureText: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textColor, fontSize: 22, letterSpacing: 12),
                  decoration: const InputDecoration(counterText: ''),
                  onChanged: (v) {
                    if (v.length == 4) _checkPin();
                  },
                  onSubmitted: (_) => _checkPin(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _checkPin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TayarColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: Text('دخول', style: TextStyle(color: context.onPrimaryColor)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}