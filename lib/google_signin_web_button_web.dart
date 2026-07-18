// ====== النسخة الحقيقية اللي بتشتغل على الويب بس ======
// على الويب، مكتبة google_sign_in_web (Google Identity Services) بترفض
// استدعاء GoogleSignIn.instance.authenticate() برمجيًا (UnimplementedError)،
// ولازم بدل منها نعرض الزرار الرسمي بتاع جوجل نفسه عن طريق renderButton()،
// وبعدين نتابع نتيجة تسجيل الدخول من خلال Stream اسمه authenticationEvents.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as web_gsi;

class GoogleSignInWebButton extends StatefulWidget {
  final void Function(BuildContext context, bool isNewUser) onSignedIn;
  final void Function(BuildContext context, Object error) onError;

  const GoogleSignInWebButton({
    super.key,
    required this.onSignedIn,
    required this.onError,
  });

  @override
  State<GoogleSignInWebButton> createState() => _GoogleSignInWebButtonState();
}

class _GoogleSignInWebButtonState extends State<GoogleSignInWebButton> {
  static bool _initialized = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  Future<void> _setup() async {
    if (!_initialized) {
      try {
        await GoogleSignIn.instance.initialize(
          clientId:
              '354477388400-ir73gp12hplk11kfkim9je588dp0gema.apps.googleusercontent.com',
        );
      } catch (e) {
        // ممكن يحصل init مرتين وقت الـ Hot Restart على الويب في وضع التطوير،
        // بنتجاهلها لأنها مش خطأ حقيقي.
        if (!e.toString().contains('has already been called')) {
          if (mounted) widget.onError(context, e);
          return;
        }
      }
      _initialized = true;
    }

    _subscription = GoogleSignIn.instance.authenticationEvents.listen((
      event,
    ) async {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        try {
          final auth = event.user.authentication;
          final credential = GoogleAuthProvider.credential(
            idToken: auth.idToken,
          );
          final userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential);
          if (mounted) {
            widget.onSignedIn(
              context,
              userCredential.additionalUserInfo?.isNewUser ?? false,
            );
          }
        } catch (e) {
          if (mounted) widget.onError(context, e);
        }
      }
    }, onError: (Object e) {
      if (mounted) widget.onError(context, e);
    });

    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SizedBox(
        height: 55,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    // ملحوظة: شكل الزرار ده بيتحدد من جوجل نفسها (اسم/لون/حجم بس القابلين
    // للتعديل)، مش زي زرارنا الكاستم بالظبط، وده قيد فرضته Google Identity
    // Services على الويب لأسباب أمنية.
    return SizedBox(width: double.infinity, height: 55, child: web_gsi.renderButton());
  }
}
