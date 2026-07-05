import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_screen.dart';
import 'passenger_home.dart';

// ====== شاشة الأمان: قفل التطبيق برقم سري + عرض وسيلة تسجيل الدخول + حذف الحساب ======
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _appLockEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAppLockSetting();
  }

  Future<void> _loadAppLockSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appLockEnabled = prefs.getBool('appLockEnabled') ?? false;
      _loading = false;
    });
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      final pin = await _promptSetPin();
      if (pin == null || pin.length != 4) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('appLockPin', pin);
      await prefs.setBool('appLockEnabled', true);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('appLockEnabled', false);
      await prefs.remove('appLockPin');
    }
    if (!mounted) return;
    setState(() => _appLockEnabled = value);
  }

  Future<String?> _promptSetPin() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TayarColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'حدد رقم سري من 4 أرقام',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          style: const TextStyle(color: Colors.white, letterSpacing: 8),
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: TayarColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text(
              'حفظ',
              style: TextStyle(color: TayarColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _providerLabel() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'غير معروف';
    final providers = user.providerData.map((p) => p.providerId).toList();
    if (providers.contains('google.com')) return 'حساب Google';
    if (providers.contains('phone')) return 'رقم الهاتف (${user.phoneNumber ?? ''})';
    if (providers.contains('password')) return 'البريد الإلكتروني وكلمة المرور';
    return 'غير معروف';
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TayarColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'حذف الحساب نهائيًا',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'هيتم حذف حسابك وكل بياناتك نهائيًا ومش هتقدر ترجعها تاني. متأكد؟',
          style: TextStyle(color: TayarColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: TayarColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'حذف نهائي',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // ====== نمسح مستند المستخدم من Firestore الأول (لو موجود) ======
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete()
          .catchError((_) {});

      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }

      // ====== حذف حساب الأوث نفسه ======
      await user.delete();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'requires-recent-login') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'لازم تسجل الخروج والدخول تاني قبل ما تقدر تحذف حسابك',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حصل خطأ: ${e.message}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TayarColors.background,
      appBar: AppBar(
        backgroundColor: TayarColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('الأمان', style: TextStyle(color: Colors.white)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: TayarColors.primary),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.verified_user_outlined,
                        color: TayarColors.primary,
                      ),
                      title: const Text(
                        'وسيلة تسجيل الدخول',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        _providerLabel(),
                        style: const TextStyle(color: TayarColors.textGrey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  children: [
                    SwitchListTile(
                      value: _appLockEnabled,
                      onChanged: _toggleAppLock,
                      activeColor: TayarColors.primary,
                      secondary: const Icon(
                        Icons.lock_outline,
                        color: TayarColors.primary,
                      ),
                      title: const Text(
                        'قفل التطبيق برقم سري',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: const Text(
                        'هتحتاج تدخل الرقم السري كل ما تفتح التطبيق',
                        style: TextStyle(color: TayarColors.textGrey),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      title: const Text(
                        'حذف الحساب نهائيًا',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                      onTap: _confirmDeleteAccount,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: TayarColors.cardDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}
