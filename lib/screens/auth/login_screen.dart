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
import 'package:tayay_app/screens/auth/phone_auth_screen.dart';
import 'package:tayay_app/helpers/auth_flow_helpers.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/google_signin_web_button_stub.dart'
    if (dart.library.js_interop) 'package:tayay_app/widgets/google_signin_web_button_web.dart';

// ====================================================
// ====== شاشة تسجيل الدخول: جوجل + الموبايل بس ======
// (الشكل القديم، من غير إيميل/باسورد ومن غير إنشاء حساب منفصل) ======
// ====================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ====== تسجيل الدخول بجوجل ======
  static bool _googleSignInInitialized = false;

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      // ====== نتأكد إن GoogleSignIn.instance اتعمله initialize مرة واحدة بس ======
      // ملاحظة: على Flutter Web وقت الـ Hot Restart، الـ Dart state بيتصفّر
      // لكن سكريبت Google Identity Services جوه المتصفح لأ، فبيرمي "Bad state:
      // init() has already been called" حتى لو الـ flag بتاعنا قايل لأ.
      // الـ try/catch ده بيتعامل مع الحالة دي كأنها نجاح عادي.
      if (!_googleSignInInitialized) {
        try {
          // ====== على الويب: لازم نستخدم clientId مش serverClientId ======
          // (google_sign_in_web بيرفض serverClientId خالص ويرمي assertion error)
          // على الموبايل (أندرويد/آيفون): بنستخدم serverClientId عشان الـ ID
          // Token اللي بيرجع يبقى الـ audience بتاعه هو الـ Web Client ID،
          // وده اللي فايربيز محتاجاه عشان يتحقق من التوكن.
          const webClientId =
              '354477388400-ir73gp12hplk11kfkim9je588dp0gema.apps.googleusercontent.com';
          if (kIsWeb) {
            await GoogleSignIn.instance.initialize(clientId: webClientId);
          } else {
            await GoogleSignIn.instance.initialize(serverClientId: webClientId);
          }
        } catch (e) {
          final msg = e.toString();
          if (!msg.contains('has already been called')) rethrow;
        }
        _googleSignInInitialized = true;
      }

      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      if (context.mounted) {
        await navigateAfterAuth(
          context,
          isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
        );
      }
    } on GoogleSignInException catch (e) {
      // ====== المستخدم لغى العملية بنفسه، مش لازم نظهرله رسالة خطأ ======
      if (e.code == GoogleSignInExceptionCode.canceled) return;
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
        await navigateAfterAuth(
          context,
          isNewUser: userCredential.additionalUserInfo?.isNewUser ?? false,
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
  // بتظهر بس على أجهزة آيفون، ومختفية تمامًا على أندرويد وعلى الويب ======
  bool get _showAppleButton => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ====== الجزء العلوي: اللوجو + الاسم + الوصف ======
            // بياخد المساحة المتاحة كلها، ولو المحتوى طويل بيبقى قابل للسكرول،
            // من غير ما يأثر على مكان الأزرار تحت.
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: ConstrainedBox(
                      // ====== بيضمن إن الـ Column ياخد أقل ارتفاع = المساحة
                      // المتاحة كاملة، عشان الـ centering يشتغل فعليًا، وبرضه
                      // يفضل قابل للسكرول لو المحتوى طويل على شاشة صغيرة ======
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          Image.asset(
                            'assets/icon/app_icon.png',
                            width: 120,
                            height: 120,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            AppLocalizations.of(context)!.appName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: context.textColor,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.chooseYourRideSubtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.textGreyColor),
                          ),
                          const SizedBox(height: 14),
                          // ====== أكبر سلاح تنافسي: موتوسيكل بدل عربية = وصول
                          // أسرع وأرخص وقت الزحمة. لازم يكون واضح من أول شاشة
                          // يشوفها أي مستخدم جديد قبل حتى ما يسجّل دخول ======
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: TayarColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.two_wheeler,
                                  color: TayarColors.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    AppLocalizations.of(
                                      context,
                                    )!.bikeAdvantageHighlight,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: TayarColors.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ====== الجزء السفلي: أزرار تسجيل الدخول + النص القانوني ======
            // ثابت دايمًا في أسفل الشاشة (مش بيسكرول مع المحتوى فوق)
            // في كل الحالات: أندرويد، آيفون، أو الويب.
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 16.0,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // زر المتابعة باستخدام Google
                  // ====== على الويب: لازم نعرض زرار جوجل الرسمي (renderButton)
                  // لأن authenticate() برمجيًا مش مدعوم على الويب أصلًا ======
                  if (kIsWeb)
                    GoogleSignInWebButton(
                      onSignedIn: (ctx, isNewUser) async {
                        await navigateAfterAuth(ctx, isNewUser: isNewUser);
                      },
                      onError: (ctx, e) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              AppLocalizations.of(
                                ctx,
                              )!.signInFailedError(e.toString()),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                    )
                  else
                    _buildCustomButton(
                      text: AppLocalizations.of(
                        context,
                      )!.continueWithGoogleButton,
                      icon: Icons.g_mobiledata,
                      color: Colors.white,
                      textColor: Colors.black,
                      onPressed: () => _signInWithGoogle(context),
                    ),
                  const SizedBox(height: 15),

                  // زر المتابعة باستخدام Apple (يظهر بس على iOS، حسب متطلبات آبل)
                  if (_showAppleButton) ...[
                    _buildCustomButton(
                      text: AppLocalizations.of(
                        context,
                      )!.continueWithAppleButton,
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
                  const SizedBox(height: 20),

                  // النصوص القانونية في الأسفل
                  Text(
                    AppLocalizations.of(context)!.loginTermsAgreementNotice,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textGreyColor,
                    ),
                  ),
                ],
              ),
            ),
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
