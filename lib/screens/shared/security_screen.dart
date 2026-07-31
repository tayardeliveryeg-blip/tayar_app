import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tayay_app/screens/auth/login_screen.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/services/sos_service.dart';

// ====== شاشة الأمان: قفل التطبيق برقم سري + عرض وسيلة تسجيل الدخول + حذف
// الحساب + جهة اتصال الطوارئ. شاشة مشتركة بين الراكب والطيار - isDriver
// بتحدد نكتب جهة اتصال الطوارئ في users/{uid} ولا drivers/{uid} ======
class SecurityScreen extends StatefulWidget {
  final bool isDriver;

  const SecurityScreen({super.key, this.isDriver = false});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  bool _appLockEnabled = false;
  bool _loading = true;

  String get _userRole => widget.isDriver ? 'driver' : 'passenger';
  final _emergencyContactController = TextEditingController();
  bool _savingEmergencyContact = false;

  @override
  void initState() {
    super.initState();
    _loadAppLockSetting();
    _loadEmergencyContact();
  }

  @override
  void dispose() {
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _loadEmergencyContact() async {
    final phone = await SosService.getEmergencyContact(_userRole);
    if (!mounted) return;
    if (phone != null) {
      setState(() => _emergencyContactController.text = phone);
    }
  }

  Future<void> _saveEmergencyContact() async {
    final phone = _emergencyContactController.text.trim();
    if (phone.isEmpty) return;
    setState(() => _savingEmergencyContact = true);
    try {
      await SosService.setEmergencyContact(_userRole, phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.savedSuccessfully)),
      );
    } finally {
      if (mounted) setState(() => _savingEmergencyContact = false);
    }
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
      // ====== قبل إلغاء القفل، لازم نتأكد من الرقم السري الحالي أولًا ======
      final verified = await _promptVerifyPin();
      if (verified != true) return;
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
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.setPinTitle,
          style: TextStyle(color: context.textColor),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          style: TextStyle(color: context.textColor, letterSpacing: 8),
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              loc.cancel,
              style: TextStyle(color: context.textGreyColor),
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

  // ====== بتطلب من المستخدم يدخل الرقم السري الحالي ويتحقق منه، مستخدمة
  // قبل إلغاء تفعيل القفل عشان محدش غير صاحب التطبيق يقدر يلغيه ======
  Future<bool?> _promptVerifyPin() async {
    final controller = TextEditingController();
    final loc = AppLocalizations.of(context)!;
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString('appLockPin');
    if (!mounted) return null;

    String? errorText;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: context.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            loc.setPinTitle,
            style: TextStyle(color: context.textColor),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                autofocus: true,
                style: TextStyle(color: context.textColor, letterSpacing: 8),
                decoration: InputDecoration(
                  counterText: '',
                  errorText: errorText,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                loc.cancel,
                style: TextStyle(color: context.textGreyColor),
              ),
            ),
            TextButton(
              onPressed: () {
                if (controller.text == savedPin) {
                  Navigator.pop(dialogContext, true);
                } else {
                  setDialogState(() => errorText = 'الرقم السري غير صحيح');
                  controller.clear();
                }
              },
              child: Text(
                loc.saveButton,
                style: const TextStyle(color: TayarColors.primary),
              ),
            ),
          ],
        ),
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
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.deleteAccountPermanentlyTitle,
          style: TextStyle(color: context.textColor),
        ),
        content: Text(
          loc.deleteAccountConfirmBody,
          style: TextStyle(color: context.textGreyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              loc.cancel,
              style: TextStyle(color: context.textGreyColor),
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

      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}

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
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: context.textColor),
        title: Text(
          loc.navSecurity,
          style: TextStyle(color: context.textColor),
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
                        style: TextStyle(color: context.textColor),
                      ),
                      subtitle: Text(
                        _providerLabel(),
                        style: TextStyle(color: context.textGreyColor),
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
                      activeThumbColor: TayarColors.primary,
                      secondary: const Icon(
                        Icons.lock_outline,
                        color: TayarColors.primary,
                      ),
                      title: Text(
                        loc.appLockTitle,
                        style: TextStyle(color: context.textColor),
                      ),
                      subtitle: Text(
                        loc.appLockSubtitle,
                        style: TextStyle(color: context.textGreyColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SectionCard(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.contact_phone_outlined,
                                color: TayarColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                loc.emergencyContactTitle,
                                style: TextStyle(
                                  color: context.textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            loc.emergencyContactSubtitle,
                            style: TextStyle(
                              color: context.textGreyColor,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _emergencyContactController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(color: context.textColor),
                            decoration: InputDecoration(
                              hintText: loc.emergencyContactHint,
                              hintStyle: TextStyle(
                                color: context.textGreyColor,
                              ),
                              filled: true,
                              fillColor: context.bgColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: _savingEmergencyContact
                                  ? null
                                  : _saveEmergencyContact,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: TayarColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: _savingEmergencyContact
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: context.onPrimaryColor,
                                      ),
                                    )
                                  : Text(
                                      loc.saveButton,
                                      style: TextStyle(
                                        color: context.onPrimaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
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
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}
