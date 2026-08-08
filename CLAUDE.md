# CLAUDE.md — تطبيق طيار (Tayar)

هذا الملف بيدي لأي جلسة Claude Code سياق سريع عن المشروع قبل ما تبدأ تعدّل فيه.
اقرأه الأول قبل أي تعديل.

## نظرة عامة

تطبيق توصيل/مشاوير موتوسيكل مصري (زي أوبر بس للموتوسيكلات)، فيه تطبيقين
جوه نفس الكود base: **الراكب (Passenger)** و**الطيار (Driver)**. الباك إند
Firebase (Auth, Firestore, Cloud Messaging) + **Supabase Edge Functions**
كبديل مجاني بالكامل لأي منطق سيرفر كان محتاج Cloud Functions (اللي
بيحتاج خطة Blaze الموقوفة بقرار مقصود). راجع قسم "الباك إند - Supabase
Edge Functions" تحت.

- **الاسم التقني للـ package**: `tayay_app` (لاحظ الاسم فيه غلطة إملائية
  مقصودة/تاريخية — `tayay` مش `tayar` — فكل الـ imports بتستخدم
  `package:tayay_app/...`). الاسم التسويقي/الظاهر للمستخدم هو "طيار".
- **Flutter SDK**: `^3.12.2`
- **الخريطة**: `flutter_map` (OpenStreetMap-based) — **مش** `google_maps_flutter`.
  لو محتاج تتعامل مع أي حاجة خرائط، فكر بمنطق `flutter_map` (Marker,
  MarkerLayer, LatLng من `latlong2`) مش Google Maps API.
- **المصادقة**: `firebase_auth` (Google Sign-In, Apple Sign-In, Phone OTP).
- **المكالمات الصوتية/الفيديو**: `zego_uikit_prebuilt_call` + `zego_uikit`
  (نسخة مقفولة `2.29.1` — دي بتحدد أعلى نسخة مسموحة لباكدجات تانية زي
  `connectivity_plus`، راجع قسم "تعارضات باكدجات معروفة" تحت).
- **الباك إند - Supabase Edge Functions**: مجلد `supabase/functions/`
  (Deno/TypeScript) — `create-order`، `chat-notify`، `general-notify`،
  `sos-notify`، + `_shared/firebase-admin.ts` (تحقق من Firebase ID Token
  + Firestore Admin عن طريق Service Account، بديل خفيف لـ Firebase
  Admin SDK). مجلد `functions/` (Cloud Functions القديمة، Node.js) لسه
  موجود كمرجع تاريخي بس **كل الدوال فيه superseded وغير منشورة** -
  الاعتماد على Blaze خلص خالص. أي فيتشر باك إند جديد يتعمل في
  `supabase/functions/` مش `functions/`.

## هيكل المجلدات الأساسي (`lib/`)

```
lib/
  main.dart                  # نقطة الدخول، فيها MaterialApp + AppLockScreen + NoInternetBanner (overlay دايمًا فوق كل شاشة)
  firebase_options.dart      # مولّد من FlutterFire CLI
  l10n/                      # ملفات الترجمة (شرح تفصيلي تحت)
  theme/
    theme_extensions.dart    # TayarColors / TayarTheme / TayarThemeColors — المصدر الوحيد لكل الألوان
    app_settings.dart
  screens/
    auth/                    # تسجيل الدخول، اختيار الدور، قفل التطبيق
    passenger/                # كل شاشات الراكب + مجلدات *_widgets فرعية لكل شاشة كبيرة
    driver/                  # كل شاشات الطيار + registration/ (تسجيل طيار جديد) + مجلدات *_widgets فرعية
    shared/                  # شاشات مشتركة بين الراكب والطيار (إعدادات، أمان، دعم...) + widgets مشتركة (profile_widgets.dart)
  services/                 # منطق بدون UI (wallet, sos, push notifications, fare rules...)
  widgets/                  # widgets عامة تستخدم من أي شاشة (pin_marker.dart, tayar_drawer.dart, no_internet_banner.dart...)
```

**قاعدة تنظيمية مهمة**: لو فيه widget بيتكرر استخدامه بين شاشة الراكب
وشاشة الطيار (زي حقول الفورم، أو التنبيهات العامة)، مكانه
`lib/widgets/` أو `lib/screens/shared/`، مش نسخة مكررة في كل مكان.

## نظام الترجمة (l10n) — **مهم جدًا، فيه خطوة يدوية**

المشروع بيدعم عربي/إنجليزي عبر `flutter gen-l10n` القياسي:

- `lib/l10n/app_ar.arb` و `lib/l10n/app_en.arb` — مصدر النصوص.
- `lib/l10n/generated/app_localizations*.dart` — **ملفات متولدة تلقائيًا**
  عادةً بأمر `flutter gen-l10n` (بيتشغل أوتوماتيك مع `flutter pub get`
  أو `flutter run`).

⚠️ **لو الجلسة الحالية (Claude Code) معندهاش Flutter SDK متاح فعليًا في
بيئتها** (زي ما حصل في جلسة سابقة)، لازم تضيف أي مفتاح ترجمة جديد **يدويًا
في التلات ملفات**: `app_ar.arb`, `app_en.arb`, وبعدين نفس الـ getter في
الثلاثة generated files (`app_localizations.dart` كـ abstract getter،
و `app_localizations_ar.dart` / `app_localizations_en.dart` كـ implementation)
— بنفس نمط أي مفتاح موجود جنبه بالظبط. لو الجلسة عندها Flutter شغال
فعليًا، الأسهل إنك تضيف المفتاح في الـ arb بس وتشغل `flutter gen-l10n`
أو `flutter pub get` وسيبها تتولد لوحدها.

النصوص كلها بالعامية المصرية (مش فصحى)، وده أسلوب متعمّد في كل التطبيق —
حافظ على نفس النبرة لو بتضيف نص جديد.

## نظام الألوان والثيم

كل الألوان بتتاخد من `context` extensions المعرّفة في
`lib/theme/theme_extensions.dart`، **مايتكتبش لون Hex أو `Colors.x` مباشر
إلا لو مفيش بديل في الثيم** (زي `Colors.red` لإطار خطأ، أو `Colors.white`
فوق خلفية ملونة صريحة). أهم الـ extensions:

- `context.bgColor`, `context.cardColor`, `context.textColor`,
  `context.textGreyColor`, `context.dividerColor2` — بتتغير تلقائيًا مع
  الوضع الفاتح/الداكن.
- `TayarColors.primary` (البرتقالي المميز للتطبيق)، `TayarColors.error`،
  وغيرهم — دول ثابتين مش بيتغيروا مع الثيم.

`passenger_home.dart` بيعمل `export 'package:tayay_app/theme/theme_extensions.dart';`
لأسباب تاريخية، لكن **استورد من `theme_extensions.dart` مباشرة** في أي
ملف جديد، مش عن طريق `passenger_home.dart`.

## أسلوب الكود والتعليقات (اتبعه حرفيًا)

- التعليقات المهمة (شرح "ليه" مش "إيه") بتتكتب بالعامية المصرية جوه
  `// ====== ... ======`. مثال:
  ```dart
  // ====== بتتحط true بعد محاولة "حفظ" فاشلة والحقل المطلوب لسه فاضي،
  // عشان نعرض إطار أحمر حواليه ======
  bool _firstNameError = false;
  ```
- أي widget فورم (حقل نص) بيتحقق منه، بيتبع نفس الباترن: `bool _xError`
  state + `controller.addListener` بينضف الـ error تلقائيًا أول ما
  المستخدم يعبّي الحقل + `showError` param في الـ widget المشترك
  (`ProfileTextField` في `profile_widgets.dart`, `FormTextField` و
  `PhotoUploadTile` في `registration_shared_widgets.dart`) بيرسم إطار
  أحمر (`Colors.red`, width 1.5) لو `true`.
- شاشات فيها زرار رجوع "يدوي" (مش `AppBar.leading`) بترسم دائرة
  `GestureDetector` + `Positioned` فوق الخريطة. **دايمًا `left: 16` مش
  `right: 16`** (كانت فيها باجات قبل كده بسبب `right:` غلط — راجع
  `pick_on_map_screen.dart` و`trip_tracking_screen.dart` و
  `driver_trip_tracking_screen.dart` كمرجع للـ pattern الصح). لو فيه
  زرار SOS أو زرار تاني على نفس الـ `top`, خليه على `right: 16` عشان
  مايتصادمش مع زرار الرجوع.
- شاشات الـ `AppBar` العادية (`leading:`) بتتظبط مكانها تلقائيًا حسب
  اتجاه اللغة، مش محتاجة تدخل يدوي.

## Firestore — أهم الـ collections والحقول

- `users/{uid}` — بيانات الراكب. حقول التقييم: `ratingSum` (num) +
  `ratingCount` (int) → المتوسط = `ratingSum / ratingCount`. لو
  `ratingCount == 0` يبقى "راكب جديد" (`newRiderLabel`).
- `drivers/{uid}` — بيانات الطيار، بنفس منطق `ratingSum`/`ratingCount`
  بالظبط (`newDriverLabel` بدلها).
- `orders/{orderId}` — الرحلات.

قاعدة عامة: لو شاشة أصلاً بتسمع (`StreamBuilder`/`snapshot`) على مستند
معين، **استخدم نفس الـ snapshot** لأي حقل تاني تحتاجه من نفس المستند
بدل ما تعمل query إضافي منفصل (زي ما حصل مع تقييم الراكب في
`tayar_drawer.dart`).

## تعارضات باكدجات معروفة

- `zego_uikit: ^2.29.1` بيقفل `connectivity_plus` على `^6.1.0` بالظبط.
  **متحطش نسخة `connectivity_plus` أعلى من `^6.x`** إلا لو `zego_uikit`
  نفسه اتحدّث الأول (تأكد بمحاولة `flutter pub get` وشوف رسالة
  version solving لو فشلت).

## أوامر مهمة

```bash
flutter pub get          # لازم بعد أي تعديل في pubspec.yaml
flutter gen-l10n         # لو عدّلت أي .arb يدويًا وعايز تتولد الملفات (أو بيتشغل تلقائي مع pub get)
flutter run
```

## حاجات لازم تتأكد منها قبل ما تسلّم أي تعديل

1. لو عدّلت `pubspec.yaml`، جرب `flutter pub get` فعليًا وشوف مفيش
   version conflicts (خصوصًا مع `zego_uikit`).
2. لو ضفت مفتاح ترجمة جديد، اتأكد إنه اتضاف في الأربع/خمس أماكن مع
   بعض (`app_ar.arb`, `app_en.arb`, والثلاث generated files).
3. لو لمست أي `Positioned` widget فوق خريطة، اتأكد الأقواس متوازنة كويس
   بعد التعديل (`grep -o "(" file | wc -l` لازم يساوي `grep -o ")" file | wc -l`) —
   ده باج حصل فعليًا قبل كده من تعديل جزئي بـ str_replace.
