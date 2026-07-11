import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'phone_auth_screen.dart';
import 'passenger_home.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  // ====== تسجيل الدخول بجوجل ======
  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // المستخدم أغلق النافذة

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PassengerHomeScreen()),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.signInFailedError(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ====== تسجيل الدخول بآبل ======
  Future<void> _signInWithApple(BuildContext context) async {
    try {
      // ====== nonce عشوائي لحماية الجلسة من هجمات الإعادة (replay attacks) ======
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

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        oauthCredential,
      );

      // ====== آبل بتبعت الاسم أول مرة بس، فبنحفظه في Firebase لو موجود ======
      final fullName = [
        appleCredential.givenName,
        appleCredential.familyName,
      ].where((e) => e != null && e.trim().isNotEmpty).join(' ');
      if (fullName.isNotEmpty && userCredential.user?.displayName == null) {
        await userCredential.user?.updateDisplayName(fullName);
      }

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const PassengerHomeScreen()),
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      // ====== المستخدم لغى العملية بنفسه، مش لازم نظهرله رسالة خطأ ======
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              )!.signInWithAppleFailedError(e.message.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.signInFailedError(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
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

  // ====== آبل بيوجب إظهار زرارها لأي تطبيق فيه تسجيل دخول بجهة خارجية على iOS ======
  bool get _showAppleButton => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const Spacer(flex: 2),
            // لوجو التطبيق
            Image.asset('assets/icon/app_icon.png', width: 120, height: 120),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.appName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.textColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.chooseYourRideSubtitle,
              style: TextStyle(color: context.textGreyColor),
            ),
            const Spacer(),

            // زر المتابعة باستخدام Google
            _buildCustomButton(
              text: AppLocalizations.of(context)!.continueWithGoogleButton,
              icon: Icons.g_mobiledata,
              color: Colors.white,
              textColor: Colors.black,
              onPressed: () => _signInWithGoogle(context),
            ),
            const SizedBox(height: 15),

            // زر المتابعة باستخدام Apple (يظهر بس على iOS، حسب متطلبات آبل)
            if (_showAppleButton) ...[
              _buildCustomButton(
                text: AppLocalizations.of(context)!.continueWithAppleButton,
                icon: Icons.apple,
                color: Colors.black,
                textColor: Colors.white,
                onPressed: () => _signInWithApple(context),
              ),
              const SizedBox(height: 15),
            ],

            // زر المتابعة عبر الهاتف
            _buildCustomButton(
              text: AppLocalizations.of(context)!.continueWithPhoneButton,
              icon: Icons.phone,
              color: Colors.grey[800]!,
              textColor: Colors.white,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PhoneAuthScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 30),

            // النصوص القانونية في الأسفل
            Text(
              AppLocalizations.of(context)!.loginTermsAgreementNotice,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.textGreyColor),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomButton({
    required String text,
    required IconData icon,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: color == Colors.white
              ? const BorderSide(color: Colors.grey)
              : null,
        ),
        icon: Icon(icon, color: textColor),
        label: Text(
          text,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
