import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:tayay_app/screens/auth/login_screen.dart';
import 'package:tayay_app/screens/auth/phone_auth_screen.dart'
    show OtpVerificationScreen;
import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/services/sos_service.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';

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
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.savedSuccessfully,
        type: ToastType.success,
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
    if (providers.contains('apple.com')) return loc.appleAccountLabel;
    if (providers.contains('phone')) {
      return loc.phoneNumberProviderLabel(user.phoneNumber ?? '');
    }
    if (providers.contains('password')) return loc.emailPasswordProviderLabel;
    return loc.unknownProviderLabel;
  }

  // ====== نقطة البداية: بندوس على "حذف الحساب" فبنثبت هوية المستخدم الأول
  // بنفس وسيلة تسجيل الدخول اللي داخل بيها (جوجل/أبل/رقم الموبايل)، وبعد
  // ما ينجح نظهرله رسالة التأكيد النهائية (تأكيد/إلغاء) ======
  Future<void> _startDeleteAccountFlow() async {
    final loc = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final providers = user.providerData.map((p) => p.providerId).toList();

    bool reauthenticated;
    try {
      if (providers.contains('google.com')) {
        reauthenticated = await _reauthenticateWithGoogle();
      } else if (providers.contains('apple.com')) {
        reauthenticated = await _reauthenticateWithApple();
      } else if (providers.contains('phone')) {
        reauthenticated = await _reauthenticateWithPhone();
      } else {
        // ====== وسيلة دخول مش مدعومة لإعادة التحقق (نادر) - نجرب الحذف
        // المباشر، ولو محتاج جلسة أحدث هيظهر رسالة الخطأ المعتادة ======
        reauthenticated = true;
      }
    } catch (e) {
      debugPrint('❌ خطأ في إعادة التحقق من الهوية: $e');
      reauthenticated = false;
    }

    if (!reauthenticated) {
      if (!mounted) return;
      TayarToast.show(
        context,
        loc.reauthRequiredForDeleteError,
        type: ToastType.error,
      );
      return;
    }

    if (!mounted) return;
    await _confirmDeleteAccount();
  }

  // ====== إعادة تسجيل الدخول بجوجل (نفس منطق login_screen.dart) لإثبات
  // الهوية قبل الحذف - بترجع true لو نجحت ======
  static bool _googleSignInInitialized = false;

  Future<bool> _reauthenticateWithGoogle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      if (!_googleSignInInitialized) {
        try {
          const webClientId =
              '354477388400-ir73gp12hplk11kfkim9je588dp0gema.apps.googleusercontent.com';
          if (kIsWeb) {
            await GoogleSignIn.instance.initialize(clientId: webClientId);
          } else {
            await GoogleSignIn.instance.initialize(serverClientId: webClientId);
          }
        } catch (e) {
          if (!e.toString().contains('has already been called')) rethrow;
        }
        _googleSignInInitialized = true;
      }

      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } on GoogleSignInException catch (e) {
      // ====== المستخدم لغى العملية بنفسه ======
      if (e.code == GoogleSignInExceptionCode.canceled) return false;
      rethrow;
    }
  }

  // ====== إعادة تسجيل الدخول بآبل (نفس منطق login_screen.dart) ======
  Future<bool> _reauthenticateWithApple() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      final oauthCredential = OAuthProvider(
        'apple.com',
      ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);
      await user.reauthenticateWithCredential(oauthCredential);
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return false;
      rethrow;
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDUQDvDUxFShoWWbHougyHjr0tFz3E38fX8e0bnTUpya-P0mXW._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ====== إعادة التحقق برقم الموبايل: بنبعت OTP لنفس رقم المستخدم المسجل،
  // وبنفتح نفس شاشة الكود (6 خانات) بس في وضع reauth - بترجع true لو
  // المستخدم أثبت هويته بنجاح، وfalse لو لغى أو فشل ======
  Future<bool> _reauthenticateWithPhone() async {
    final user = FirebaseAuth.instance.currentUser;
    final phone = user?.phoneNumber;
    if (user == null || phone == null) return false;

    final completer = Completer<bool>();
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        try {
          await user.reauthenticateWithCredential(credential);
          if (!completer.isCompleted) completer.complete(true);
        } catch (_) {
          if (!completer.isCompleted) completer.complete(false);
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.complete(false);
      },
      codeSent: (String verificationId, int? resendToken) async {
        if (!mounted) {
          if (!completer.isCompleted) completer.complete(false);
          return;
        }
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              verificationId: verificationId,
              phoneNumber: phone,
              resendToken: resendToken,
              reauthMode: true,
            ),
          ),
        );
        if (!completer.isCompleted) completer.complete(result ?? false);
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
    return completer.future;
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
        TayarToast.show(context, loc.reauthRequiredForDeleteError, type: ToastType.error);
      } else {
        TayarToast.show(
          context,
          loc.errorOccurredWithMessage(e.message ?? ''),
          type: ToastType.error,
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
                            child: AppPrimaryButton(
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
                      onTap: _startDeleteAccountFlow,
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
    return AppCard(
      radius: 14,
      padding: EdgeInsets.zero,
      showShadow: false,
      child: Column(children: children),
    );
  }
}
