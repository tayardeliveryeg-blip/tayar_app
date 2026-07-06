import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'passenger_home.dart';
import 'driver_home_screen.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TayarApp());
}

class TayarApp extends StatefulWidget {
  const TayarApp({super.key});

  // ====== بيدور على أقرب TayarApp في الشجرة عشان أي شاشة تقدر تغيّر اللغة ======
  // الاستخدام من أي مكان:
  //   TayarApp.setLocale(context, const Locale('en'));  // تغيير يدوي لإنجليزي
  //   TayarApp.setLocale(context, const Locale('ar'));  // تغيير يدوي لعربي
  //   TayarApp.setLocale(context, null);                // رجوع لاستخدام لغة الجهاز
  static void setLocale(BuildContext context, Locale? locale) {
    final state = context.findAncestorStateOfType<_TayarAppState>();
    state?._setLocale(locale);
  }

  // ====== بترجع اللغة المختارة يدويًا حاليًا، أو null لو التطبيق شغال
  // على لغة الجهاز تلقائيًا (مفيدة لعرض الاختيار الصح في شاشة الإعدادات) ======
  static Locale? getManualLocale(BuildContext context) {
    final state = context.findAncestorStateOfType<_TayarAppState>();
    return state?._locale;
  }

  @override
  State<TayarApp> createState() => _TayarAppState();
}

class _TayarAppState extends State<TayarApp> {
  // ====== اللغة المختارة يدويًا من المستخدم. لو null، معناها التطبيق
  // بيتبع لغة الجهاز تلقائيًا (السلوك الافتراضي) ======
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('languageCode');
    // ====== لو مفيش قيمة محفوظة، سيبنا _locale = null عشان يستخدم لغة الجهاز ======
    if (savedCode != null && mounted) {
      setState(() => _locale = Locale(savedCode));
    }
  }

  // ====== بتغيّر اللغة فورًا وتحفظ الاختيار عشان يفضل ثابت بعد إغلاق التطبيق.
  // لو اتبعتلها null، بتمسح الاختيار المحفوظ ويرجع التطبيق يتبع لغة الجهاز ======
  Future<void> _setLocale(Locale? locale) async {
    setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove('languageCode');
    } else {
      await prefs.setString('languageCode', locale.languageCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'طيار',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFFF6B00),
        fontFamily: 'Arial',
      ),
      // ====== locale: null → Flutter بيقرأ لغة الجهاز تلقائيًا ويطابقها مع
      // supportedLocales. لو المستخدم اختار لغة يدويًا، بتتفرض هنا مباشرة ======
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SplashScreen(),
    );
  }
}

// ====== بيقرر يفتح على شاشة تسجيل الدخول ولا على الشاشة الرئيسية ======
// حسب حالة تسجيل الدخول المحفوظة في Firebase على الجهاز
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // لسه بيتأكد من حالة تسجيل الدخول (بياخد أجزاء من الثانية)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1A1816),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
            ),
          );
        }

        // فيه مستخدم مسجل دخول بالفعل → نتأكد آخر وضع كان فاتحه (راكب/طيار)
        if (snapshot.hasData) {
          return FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, prefsSnapshot) {
              if (!prefsSnapshot.hasData) {
                return const Scaffold(
                  backgroundColor: Color(0xFF1A1816),
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF6B00)),
                  ),
                );
              }
              final lastMode = prefsSnapshot.data!.getString('lastMode');
              if (lastMode == 'driver') {
                return const DriverHomeScreen();
              }
              return const PassengerHomeScreen();
            },
          );
        }

        // مفيش مستخدم مسجل → اعرض شاشة تسجيل الدخول
        return const LoginScreen();
      },
    );
  }
}
