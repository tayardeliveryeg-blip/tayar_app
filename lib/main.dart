import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/firebase_options.dart';
import 'package:tayay_app/screens/auth/login_screen.dart';
import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart';
import 'package:tayay_app/screens/driver/driver_home_screen.dart';
import 'package:tayay_app/screens/auth/app_lock_screen.dart';
import 'package:tayay_app/services/push_notification_service.dart';
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/screens/onboarding/onboarding_screen.dart';
import 'package:tayay_app/screens/auth/terms_reconsent_screen.dart';
import 'package:tayay_app/screens/shared/app_blocked_screen.dart';
import 'package:tayay_app/services/analytics_service.dart';
import 'package:tayay_app/widgets/terms_acceptance_checkbox.dart'
    show kTermsAndConditionsVersion;

export 'package:tayay_app/screens/passenger/passenger_home.dart'
    show TayarColors, TayarTheme, TayarThemeColors;

// ====== مفتاح Navigator عام: محتاجه خدمة دعوة المكالمات (ZegoCloud) عشان
// تقدر تعرض واجهة "مكالمة واردة" فوق أي شاشة في التطبيق، حتى لو
// المستخدم مش في شاشة معينة بالذات وقت وصول الدعوة ======
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _initAppCheck();
  await _initMonitoring();
  // ====== لازم تتسجل قبل runApp عشان تشتغل حتى لو التطبيق مقفول تمامًا ======
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // ====== تحميل إعدادات التطبيق (الأسعار، العمولة، تليفون الدعم) من لوحة الأدمن ======
  await AppSettings.instance.load();
  // ====== رقم البيلد الحالي لمقارنته بـ minAppBuild (force-update). لو فشلت
  // القراءة يفضل 0 = مفيش حجب (fail-open) ======
  try {
    final info = await PackageInfo.fromPlatform();
    AppSettings.instance.currentBuild = int.tryParse(info.buildNumber) ?? 0;
  } catch (_) {}
  final prefs = await SharedPreferences.getInstance();
  final lockEnabled = prefs.getBool('appLockEnabled') ?? false;
  runApp(TayarApp(initiallyLocked: lockEnabled));
}

// ====== Firebase App Check: بيثبت إن الطلبات على Firestore جاية من نسخة
// التطبيق الأصلية (Play Integrity على Android) مش من سكريبت أو تطبيق معدّل.
// - release: Play Integrity (Android) / App Attest مع fallback لـ DeviceCheck (iOS)
// - debug: Debug provider (الـ token بيظهر في logcat/console وبيتسجل في
//   Firebase Console ← App Check ← Manage debug tokens)
// - الويب بنتخطاه (لوحة الأدمن لها تطبيق منفصل، ومحتاج reCAPTCHA provider
//   قبل ما نفعّل الـ enforce على Firestore)
// أي فشل هنا مايمنعش التطبيق يفتح: لحد ما الـ enforce يتفعّل في الـ Console
// الـ App Check في وضع المراقبة فقط ======
Future<void> _initAppCheck() async {
  if (kIsWeb) return;
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (e) {
    debugPrint('⚠️ تعذر تفعيل App Check: $e');
  }
}

// ====== مراقبة الأخطاء (Crashlytics) + تحليلات (Analytics). أي فشل هنا
// مايمنعش التطبيق يفتح. الاتنين متعطلين في debug عشان بيانات التطوير
// ماتلوّثش الأرقام الحقيقية (لو عايز تجرب: غيّر !kDebugMode مؤقتًا).
// Crashlytics مش مدعوم على الويب فبنتخطاه ======
Future<void> _initMonitoring() async {
  try {
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        !kDebugMode,
      );
      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(
      !kDebugMode,
    );
    // ====== معرّف المستخدم (UID بس، مفيش بيانات شخصية) بيتربط بأي تقرير
    // انهيار/حدث، وبيتمسح لما يسجل خروج ======
    FirebaseAuth.instance.authStateChanges().listen((user) {
      AnalyticsService.setUser(user?.uid);
      if (!kIsWeb) {
        FirebaseCrashlytics.instance.setUserIdentifier(user?.uid ?? '');
      }
    });
  } catch (e) {
    debugPrint('تعذر تهيئة Crashlytics/Analytics: $e');
  }
}

class TayarApp extends StatefulWidget {
  final bool initiallyLocked;
  const TayarApp({super.key, this.initiallyLocked = false});

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

  // ====== بتغيّر وضع الإضاءة (فاتح/غامق/تلقائي حسب الجهاز) من أي شاشة.
  // الاستخدام من أي مكان:
  //   TayarApp.setThemeMode(context, ThemeMode.light);  // فاتح يدويًا
  //   TayarApp.setThemeMode(context, ThemeMode.dark);   // غامق يدويًا
  //   TayarApp.setThemeMode(context, ThemeMode.system); // يتبع وضع الجهاز ======
  static void setThemeMode(BuildContext context, ThemeMode mode) {
    final state = context.findAncestorStateOfType<_TayarAppState>();
    state?._setThemeMode(mode);
  }

  // ====== بترجع الوضع الحالي (فاتح/غامق/تلقائي) عشان شاشة الإعدادات تعرف
  // تحدد الاختيار الصح ======
  static ThemeMode getThemeMode(BuildContext context) {
    final state = context.findAncestorStateOfType<_TayarAppState>();
    return state?._themeMode ?? ThemeMode.dark;
  }

  @override
  State<TayarApp> createState() => _TayarAppState();
}

class _TayarAppState extends State<TayarApp> with WidgetsBindingObserver {
  // ====== اللغة المختارة يدويًا من المستخدم. لو null، معناها التطبيق
  // بيتبع لغة الجهاز تلقائيًا (السلوك الافتراضي) ======
  Locale? _locale;

  // ====== وضع الإضاءة الحالي. الافتراضي غامق عشان يفضل شكل التطبيق زي ما
  // كان قبل إضافة الوضع الفاتح، لحد ما المستخدم يغيّره بنفسه من الإعدادات ======
  ThemeMode _themeMode = ThemeMode.dark;

  // ====== حالة القفل: بتتفعّل عند بدء التطبيق لو appLockEnabled محفوظة،
  // وبترجع تتفعّل تلقائيًا كل مرة التطبيق يرجع من الخلفية ======
  late bool _isLocked;
  // ====== حجب التطبيق (force-update / صيانة) - راجع app_blocked_screen.dart ======
  AppBlockReason _blockReason = AppBlockReason.none;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.initiallyLocked;
    _blockReason = AppSettings.instance.blockReason;
    WidgetsBinding.instance.addObserver(this);
    _loadSavedLocale();
    _loadSavedThemeMode();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckAppLock();
      _refreshBlockState();
    }
  }

  // ====== بتقرأ حالة القفل "فريش" من التخزين كل مرة التطبيق يرجع من
  // الخلفية، بدل ما تعتمد على القيمة القديمة المحفوظة في الذاكرة وقت
  // الفتح الأول (عشان لو المستخدم عطّل القفل وهو شغال، تتحدث فورًا) ======
  Future<void> _recheckAppLock() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('appLockEnabled') ?? false;
    if (enabled && mounted) {
      setState(() => _isLocked = true);
    }
  }

  // ====== بيعيد قراءة الإعدادات من السيرفر ويحدّث حالة الحجب - بيتنادى
  // لما التطبيق يرجع من الخلفية (عشان وضع الصيانة يوصل للي فاتح التطبيق
  // من ساعات) ومن زرار "إعادة المحاولة" في شاشة الحجب ======
  Future<void> _refreshBlockState() async {
    await AppSettings.instance.refresh();
    if (!mounted) return;
    final reason = AppSettings.instance.blockReason;
    if (reason != _blockReason) setState(() => _blockReason = reason);
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString('languageCode');
    // ====== لو مفيش قيمة محفوظة، سيبنا _locale = null عشان يستخدم لغة الجهاز ======
    if (savedCode != null && mounted) {
      setState(() => _locale = Locale(savedCode));
    }
  }

  Future<void> _loadSavedThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('themeMode');
    if (saved != null && mounted) {
      setState(() {
        _themeMode = switch (saved) {
          'light' => ThemeMode.light,
          'system' => ThemeMode.system,
          _ => ThemeMode.dark,
        };
      });
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

  // ====== بتغيّر وضع الإضاءة فورًا وتحفظ الاختيار عشان يفضل ثابت بعد إغلاق
  // التطبيق ======
  Future<void> _setThemeMode(ThemeMode mode) async {
    setState(() => _themeMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'طيار',
      debugShowCheckedModeBanner: false,
      theme: TayarTheme.lightTheme,
      darkTheme: TayarTheme.darkTheme,
      themeMode: _themeMode,
      // ====== locale: null → Flutter بيقرأ لغة الجهاز تلقائيًا ويطابقها مع
      // supportedLocales. لو المستخدم اختار لغة يدويًا، بتتفرض هنا مباشرة ======
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppEntryPoint(),
      // ====== بيعرض شاشة قفل الرقم السري فوق كل حاجة لو _isLocked = true،
      // من غير ما يأثر على الـ Navigator أو الشاشة الحالية تحته ======
      builder: (context, child) {
        // ====== تثبيت حجم الخط داخل حدود معقولة (0.9x - 1.2x) بدل ما
        // يتوارث مباشرة من إعداد "حجم الخط" في نظام الأندرويد. من غير
        // القفل ده، أي مستخدم غيّر إعداد حجم الخط من جهازه (كبير أو
        // صغير عن المتوسط) بيشوف نصوص وتخطيطات مختلفة تمامًا عن التصميم
        // الأصلي، وده كان سبب اختلاف الشكل بين الأجهزة اللي لوحظ ======
        final mq = MediaQuery.of(context);
        final clampedScaler = mq.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.2,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clampedScaler),
          child: Stack(
            children: [
              ?child,
              if (_isLocked)
                AppLockScreen(
                  onUnlocked: () => setState(() => _isLocked = false),
                ),
              // ====== فوق كل حاجة (حتى القفل): لو التطبيق محجوب ما ينفعش
              // حد يستخدمه أصلًا ======
              if (_blockReason != AppBlockReason.none)
                AppBlockedScreen(
                  reason: _blockReason,
                  onRetry: _refreshBlockState,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ====== بيفحص أولاً لو المستخدم شاف الـ Onboarding قبل كده.
// لو لأ → بيعرض شاشة الـ Onboarding.
// لو آه → بيروح لـ AuthGate عادي ======
class AppEntryPoint extends StatefulWidget {
  const AppEntryPoint({super.key});

  @override
  State<AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<AppEntryPoint> {
  bool? _hasSeenOnboarding;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('hasSeenOnboarding') ?? false;
    setState(() => _hasSeenOnboarding = hasSeen);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasSeenOnboarding == null) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: TayarColors.primary),
        ),
      );
    }

    if (!_hasSeenOnboarding!) {
      return const OnboardingScreen();
    }

    return const AuthGate();
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
          return Scaffold(
            backgroundColor: context.bgColor,
            body: const Center(
              child: CircularProgressIndicator(color: TayarColors.primary),
            ),
          );
        }

        // فيه مستخدم مسجل دخول بالفعل → أول حاجة نتأكد إن حسابه مش محظور
        if (snapshot.hasData) {
          final uid = snapshot.data!.uid;
          return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get(),
            builder: (context, userDocSnap) {
              if (userDocSnap.connectionState == ConnectionState.waiting) {
                return Scaffold(
                  backgroundColor: context.bgColor,
                  body: const Center(
                    child: CircularProgressIndicator(
                      color: TayarColors.primary,
                    ),
                  ),
                );
              }
              final status = userDocSnap.data?.data()?['status'] as String?;
              if (status == 'banned') {
                return const _BannedAccountScreen();
              }
              return FutureBuilder<SharedPreferences>(
                future: SharedPreferences.getInstance(),
                builder: (context, prefsSnapshot) {
                  if (!prefsSnapshot.hasData) {
                    return Scaffold(
                      backgroundColor: context.bgColor,
                      body: const Center(
                        child: CircularProgressIndicator(
                          color: TayarColors.primary,
                        ),
                      ),
                    );
                  }
                  final lastMode = prefsSnapshot.data!.getString('lastMode');

                  // ====== بند 8 من gap analysis: قبل ما نفتح الشاشة
                  // الرئيسية، نتأكد إن نسخة الشروط اللي وافق عليها
                  // المستخدم (termsVersion المحفوظة وقت التسجيل) لسه
                  // مطابقة لـ kTermsAndConditionsVersion الحالية. لو
                  // النسخة اتغيرت بعد ما وافق (زي 1.0 → 1.1)، بنوقفه
                  // على شاشة إعادة موافقة إجبارية بدل ما نفترض إن
                  // موافقته القديمة لسه سارية على شروط ماشافهاش أصلًا.
                  // لو الحقل مش موجود خالص (لسه في نص التسجيل ومروحش
                  // على ProfileSetupScreen/DriverRegistrationScreen بعد)
                  // بنسيبه يكمل عادي، هيوافق على أحدث نسخة وقتها ======
                  if (lastMode == 'driver') {
                    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection('drivers')
                          .doc(uid)
                          .get(),
                      builder: (context, driverDocSnap) {
                        if (driverDocSnap.connectionState ==
                            ConnectionState.waiting) {
                          return Scaffold(
                            backgroundColor: context.bgColor,
                            body: const Center(
                              child: CircularProgressIndicator(
                                color: TayarColors.primary,
                              ),
                            ),
                          );
                        }
                        final termsVersion =
                            driverDocSnap.data?.data()?['termsVersion']
                                as String?;
                        if (termsVersion != null &&
                            termsVersion != kTermsAndConditionsVersion) {
                          return const TermsReconsentScreen(
                            role: 'driver',
                            destination: DriverHomeScreen(),
                          );
                        }
                        return const DriverHomeScreen();
                      },
                    );
                  }

                  final passengerTermsVersion =
                      userDocSnap.data?.data()?['termsVersion'] as String?;
                  if (passengerTermsVersion != null &&
                      passengerTermsVersion != kTermsAndConditionsVersion) {
                    return const TermsReconsentScreen(
                      role: 'passenger',
                      destination: PassengerHomeScreen(),
                    );
                  }
                  return const PassengerHomeScreen();
                },
              );
            },
          );
        }

        // مفيش مستخدم مسجل → اعرض شاشة تسجيل الدخول
        return const LoginScreen();
      },
    );
  }
}

// ====== شاشة بسيطة تظهر للحساب المحظور بدل ما يدخل التطبيق، وتسجّله خروج تلقائيًا ======
class _BannedAccountScreen extends StatefulWidget {
  const _BannedAccountScreen();

  @override
  State<_BannedAccountScreen> createState() => _BannedAccountScreenState();
}

class _BannedAccountScreenState extends State<_BannedAccountScreen> {
  @override
  void initState() {
    super.initState();
    // نسجله خروج فورًا عشان لو رجع فتح التطبيق تاني يوصله لشاشة تسجيل الدخول العادية
    FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block, color: TayarColors.error, size: 56),
              const SizedBox(height: 16),
              Text(
                'تم تعليق هذا الحساب',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'لو حاسس إن ده حصل بالغلط، تواصل مع الدعم.',
                style: TextStyle(
                  color: context.textColor.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}