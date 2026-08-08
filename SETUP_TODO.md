# خطوات إعداد متبقية

## ✅ Google Sign-In على iOS و Android — خلصوا
تم التأكد من `ios/Runner/GoogleService-Info.plist` و `ios/Runner/Info.plist`
(الـ REVERSED_CLIENT_ID مسجل صح في CFBundleURLTypes) وكذلك
`android/app/google-services.json` (فيه oauth_client بشهادة SHA-1
`bd94b1025cb287a1957c21d7a9fc525271b1320c` + web client). تسجيل الدخول
بجوجل مفروض يشتغل عادي على المنصتين.

## 1) Sign in with Apple — محتاج جهاز Mac (معلّق)

`ios/Runner/Runner.entitlements` جاهز ومربوط في مشروع Xcode
(Debug/Release/Profile). الباقي لازم يتعمل على Mac:
1. تفتح المشروع في Xcode.
2. من تبويب Signing & Capabilities، تتأكد إن "Sign in with Apple" ظاهرة
   ومفعّلة (المفروض تظهر تلقائيًا بفضل الـ entitlements، بس لازم يكون عندك
   Apple Developer account مربوط بالـ Team الصحيح).
3. تتأكد إن الـ App ID بتاعك في Apple Developer portal مفعّل فيه
   "Sign In with Apple" capability.

## ✅ 2) إشعارات الشات/شحن المحفظة/الإشعار العام — خلصوا (بديل Supabase)

الدوال التلاتة اللي كانت في `functions/index.js` (`onNewChatMessage`،
`onWalletCredit`، `onNewGeneralNotification`) بقت **غير مستخدمة
(superseded)** — كانت محتاجة خطة Blaze عشان تتنشر، والترقية موقوفة
بقرار مقصود. بدلها اتعمل حل بديل مجاني بالكامل عن طريق Supabase Edge
Functions (نفس فكرة `create-order` و`sos-notify`):
- `supabase/functions/chat-notify/` — بديل `onNewChatMessage`، بتتنادى
  من `trip_chat_screen.dart` بعد كل رسالة شات.
- `supabase/functions/general-notify/` — بديل مدمج لـ `onWalletCredit` +
  `onNewGeneralNotification`، بتتنادى من لوحة الأدمن بعد شحن المحفظة.

منشورين وشغالين فعليًا (`supabase functions deploy chat-notify` /
`general-notify`). مفيش أي حاجة متبقية هنا — مجلد `functions/` القديم
(Firebase Cloud Functions) اتمسح بالكامل من الريبو بعد ما اتأكد إن كل
الدوال الخمسة اللي كانت فيه (`onNewChatMessage`، `onWalletCredit`،
`onNewGeneralNotification`، `createOrder`، `onSosAlertCreated`) بقالها
بدائل شغالة فعليًا على Supabase Edge Functions.

## 3) applicationId لسه القيمة الافتراضية (مؤجّل قصدًا لحد قبل النشر)

`android/app/build.gradle.kts` لسه فيه `com.example.tayay_app`. Google Play
بيرفض نشر أي تطبيق بالـ prefix ده. القرار: نسيبه زي ما هو لحد آخر خطوة قبل
النشر، عشان التغيير يتعمل مع تحديث Firebase Console سوا (لو اتغير من غير
تحديث الكونسول، التطبيق هيبطّل يشتغل خالص - mismatch). لما يجي وقتها:
1. غيّر `applicationId` و `namespace` في `android/app/build.gradle.kts`
   لحاجة زي `com.gotayar.app`.
2. سجّل تطبيق Android جديد بنفس الاسم ده في Firebase Console.
3. نزّل `google-services.json` الجديد واستبدل بيه القديم.
4. حدّث `firebase_options.dart` لو استخدمت FlutterFire CLI
   (`flutterfire configure`) هيتحدث تلقائي.