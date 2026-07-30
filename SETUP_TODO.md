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

## 2) إشعار شحن المحفظة (onWalletCredit) — الكود جاهز، محتاج ترقية + deploy (معلّق)

دالة `onWalletCredit` في `functions/index.js` مكتوبة وجاهزة (بتبعت إشعار
تلقائي للراكب لما الأدمن يشحن له رصيد من لوحة الإدارة). لسه مش منشورة لأن
المشروع محتاج ترقية لخطة **Blaze** على Firebase (شرط أساسي لأي Cloud
Function من الجيل التاني)، والترقية موقوفة دلوقتي بقرار مقصود. لما يجي وقتها:
1. فعّل الفوترة من Firebase Console:
   https://console.firebase.google.com/project/b10-app-1e682/usage/details
   (Modify plan → Blaze)، واربط حساب فوترة صحيح (لو فيه حساب قديم متعلّق
   بسبب مشكلة دفع، افتحه من: https://console.cloud.google.com/billing?project=b10-app-1e682)
2. من مجلد الريبو الرئيسي:
   ```
   firebase deploy --only functions:onWalletCredit
   ```
3. تأكد إن الدالة ظهرت في Firebase Console → Functions، وجرب شحن محفظة
   راكب تجريبي من لوحة الأدمن وتأكد إن الإشعار وصله.

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