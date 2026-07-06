import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_screen.dart';
import 'passenger_home.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

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
    final loc = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TayarColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.setPinTitle,
          style: const TextStyle(color: Colors.white),
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
            child: Text(
              loc.cancel,
              style: const TextStyle(color: TayarColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(
              loc.saveButton,
              style: const TextStyle(color: TayarColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  String _providerLabel() {
    final loc = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return loc.unknownProviderLabel;
    final providers = user.providerData.map((p) => p.providerId).toList();
    if (providers.contains('google.com')) return loc.googleAccountLabel;
    if (providers.contains('phone')) {
      return loc.phoneNumberProviderLabel(user.phoneNumber ?? '');
    }
    if (providers.contains('password')) return loc.emailPasswordProviderLabel;
    return loc.unknownProviderLabel;
  }

  Future<void> _confirmDeleteAccount() async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TayarColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.deleteAccountPermanentlyTitle,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          loc.deleteAccountConfirmBody,
          style: const TextStyle(color: TayarColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              loc.cancel,
              style: const TextStyle(color: TayarColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              loc.deletePermanentlyButton,
              style: const TextStyle(color: Colors.redAccent),
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
          SnackBar(content: Text(loc.reauthRequiredForDeleteError)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorOccurredWithMessage(e.message ?? '')),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: TayarColors.background,
      appBar: AppBar(
        backgroundColor: TayarColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          loc.navSecurity,
          style: const TextStyle(color: Colors.white),
        ),
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
                      title: Text(
                        loc.signInMethodLabel,
                        style: const TextStyle(color: Colors.white),
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
                      title: Text(
                        loc.appLockTitle,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        loc.appLockSubtitle,
                        style: const TextStyle(color: TayarColors.textGrey),
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
                      title: Text(
                        loc.deleteAccountPermanentlyTitle,
                        style: const TextStyle(color: Colors.redAccent),
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
