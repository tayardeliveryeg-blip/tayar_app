import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/helpers/auth_flow_helpers.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/google_signin_web_button_stub.dart'
    if (dart.library.js_interop) 'package:tayay_app/widgets/google_signin_web_button_web.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';

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

  // ====== موافقة المستخدم على شروط الاستخدام وسياسة الخصوصية - لازم
  // تتعلّم قبل ما يقدر يكمل بأي وسيلة تسجيل دخول (جوجل/آبل). نفس
  // الروابط المستضافة المستخدمة في شاشة الإعدادات (settings_screen.dart) ======
  bool _agreedToTerms = false;
  bool _showTermsError = false;

  static const String _privacyPolicyUrl =
      'https://b10-app-1e682.web.app/privacy.html';
  static const String _termsOfUseUrl =
      'https://b10-app-1e682.web.app/terms.html';

  Future<void> _openHostedPage(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.failedToOpenAppError,
        type: ToastType.error,
      );
    }
  }

  // ====== بترجع true لو المستخدم موافق فعلاً ومسموح يكمل، وإلا بتظهر
  // رسالة الخطأ تحت الـ checkbox وترجع false عشان الشاشة اللي بتنادي
  // ده توقف عملية تسجيل الدخول ======
  bool _ensureAgreedToTerms() {
    if (_agreedToTerms) return true;
    setState(() => _showTermsError = true);
    return false;
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    if (!_ensureAgreedToTerms()) return;
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
        TayarToast.show(
          context,
          AppLocalizations.of(context)!.signInFailedError(e.toString()),
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (context.mounted) {
        TayarToast.show(
          context,
          AppLocalizations.of(context)!.signInFailedError(e.toString()),
          type: ToastType.error,
        );
      }
    }
  }

  // ====== تسجيل الدخول بآبل ======
  Future<void> _signInWithApple(BuildContext context) async {
    if (!_ensureAgreedToTerms()) return;
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
        TayarToast.show(
          context,
          AppLocalizations.of(context)!.signInWithAppleFailedError(e.message.toString()),
          type: ToastType.error,
        );
      }
    } catch (e) {
      if (context.mounted) {
        TayarToast.show(
          context,
          AppLocalizations.of(context)!.signInFailedError(e.toString()),
          type: ToastType.error,
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
                  // خانة الموافقة على شروط الاستخدام وسياسة الخصوصية
                  _buildTermsAgreementCheckbox(context),
                  const SizedBox(height: 12),

                  // زر المتابعة باستخدام Google
                  // ====== على الويب: لازم نعرض زرار جوجل الرسمي (renderButton)
                  // لأن authenticate() برمجيًا مش مدعوم على الويب أصلًا، فبنحط
                  // طبقة شفافة فوقه توقف الضغطة وتوري خطأ الموافقة لو
                  // المستخدم لسه ماعلّمش الـ checkbox ======
                  if (kIsWeb)
                    Stack(
                      children: [
                        GoogleSignInWebButton(
                          onSignedIn: (ctx, isNewUser) async {
                            await navigateAfterAuth(ctx, isNewUser: isNewUser);
                          },
                          onError: (ctx, e) {
                            TayarToast.show(
                              ctx,
                              AppLocalizations.of(
                                ctx,
                              )!.signInFailedError(e.toString()),
                              type: ToastType.error,
                            );
                          },
                        ),
                        if (!_agreedToTerms)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _ensureAgreedToTerms,
                              child: const SizedBox.expand(),
                            ),
                          ),
                      ],
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====== خانة موافقة قابلة للتعليم + رابطين منفصلين (شروط الاستخدام /
  // سياسة الخصوصية) كل واحد بيفتح صفحته الحقيقية المستضافة لوحده، مش
  // نص واحد بيفتح حاجة واحدة بس. لازم تتعلّم قبل أي وسيلة تسجيل دخول ======
  Widget _buildTermsAgreementCheckbox(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: _showTermsError
                ? Border.all(color: Colors.red, width: 1.5)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: _agreedToTerms,
                activeColor: TayarColors.primary,
                onChanged: (v) => setState(() {
                  _agreedToTerms = v ?? false;
                  if (_agreedToTerms) _showTermsError = false;
                }),
              ),
              // ====== النص العادي بس (مش الروابط) بيعلّم/يشيل تعليم
              // الـ checkbox، عشان ميتعارضش مع recognizer الرابطين ======
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: context.textColor, fontSize: 13),
                    children: [
                      TextSpan(
                        text: loc.loginAgreementPrefix,
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => setState(() {
                            _agreedToTerms = !_agreedToTerms;
                            if (_agreedToTerms) _showTermsError = false;
                          }),
                      ),
                      TextSpan(
                        text: loc.termsOfUseLinkText,
                        style: const TextStyle(
                          color: TayarColors.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              _openHostedPage(context, _termsOfUseUrl),
                      ),
                      TextSpan(
                        text: loc.loginAgreementConnector,
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => setState(() {
                            _agreedToTerms = !_agreedToTerms;
                            if (_agreedToTerms) _showTermsError = false;
                          }),
                      ),
                      TextSpan(
                        text: loc.privacyPolicy,
                        style: const TextStyle(
                          color: TayarColors.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () =>
                              _openHostedPage(context, _privacyPolicyUrl),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_showTermsError)
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 2),
            child: Text(
              loc.loginAgreementRequiredError,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
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
