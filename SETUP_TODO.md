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

## ✅ 3) applicationId + توقيع الإصدار — خلصوا (2026-08-09)

`applicationId`/`namespace` اتغيروا فعليًا لـ `com.tayar.app` (كانت
`com.example.tayay_app`)، وتوقيع إصدار حقيقي (release signing) اتظبط
في `android/app/build.gradle.kts` - بيقرا من `android/app/key.properties`
(ملف غير متتبع في git عمدًا، لازم يكون موجود على أي جهاز هتعمل منه
build فعلي)، ولو الملف مش موجود بيرجع تلقائيًا لتوقيع debug (fallback
آمن للتطوير اليومي - منعرفش الـ build يفشل بس لأن حد نسي يعمل الملف).

⚠️ **باقي عليك بس تتأكد إنت:**
1. `android/app/key.properties` + ملف الـ keystore الحقيقي (.jks/.keystore)
   موجودين فعليًا على جهازك (الملف مش هيبان في git status - ده متوقع ومقصود).
2. عملت build release فعلي (`flutter build appbundle --release` أو
   `flutter build apk --release`) وجربته على جهاز حقيقي مرة على الأقل.

## 4) تذكير الرحلة المجدولة (خطوة 5/5) — محتاج نشر + جدولة يدوية

الكود جاهز (`supabase/functions/scheduled-ride-reminder/`) بس محتاج 3
خطوات إعداد لازم تتعمل من عندك (معملهاش أي حاجة عن بعد هنا):

1. **سجّل السر الجديد** في Supabase Dashboard -> Edge Functions ->
   Secrets:
   - اسم السر: `CRON_SECRET`
   - القيمة: أي سلسلة عشوائية طويلة (ولّدها بنفسك، متستخدمش قيمة
     `SOS_WEBHOOK_SECRET` القديمة).
2. **انشر الدالة:**
   ```
   supabase functions deploy scheduled-ride-reminder
   ```
3. **فعّل الجدولة الدورية (كل 5 دقايق):** افتح
   `supabase/sql/scheduled_ride_reminder_cron.sql`، غيّر فيه
   `<project-ref>` و `<same-value-as-CRON_SECRET-secret>` بالقيم
   الحقيقية بتاعتك، وشغّله مرة واحدة من Supabase Dashboard -> SQL
   Editor.

بعد كده هتحتاج تختبر: تعمل حجز رحلة مقدمة بميعاد قريب (أقل من ساعة
مثلًا)، وتستنى لحد ما يفضلها 15 دقيقة، وتتأكد إن التذكير وصل فعليًا
كإشعار push على جهاز الراكب. ملحوظة: أول مرة الدالة تنفّذ query على
`orders` هتلاقي فيرستور طالب composite index (فيه رابط جاهز في رسالة
الخطأ نفسها بيعمله بضغطة واحدة) — ده طبيعي ومتوقع.

## 5) رسوم/سبب الإلغاء (بند 4 من gap analysis)

فيتشر كامل جديد: أي إلغاء من الراكب (بحث لسه شغال أو بعد ما طيار يقبل
العرض) بقى محتاج اختيار سبب، وممكن يترتب عليه رسوم إلغاء لو الطيار كان
قابل الرحلة فعلاً وعدّى على القبول أكتر من مهلة معينة (قابلة للتعديل).

ملحوظة: التطبيق لسه قبل الإطلاق ومترفعش على المتاجر، فمفيش خطر تجزئة
نسخ قديمة عند مستخدمين حقيقيين — تقدر تنشر القواعد فورًا من غير أي
ترتيب خاص:

1. اعمل `git pull` + `flutter gen-l10n` + `flutter analyze`.
2. شغّل `firebase deploy --only firestore:rules`.
3. جرّب على جهازك: إلغاء رحلة قبل ما طيار يقبلها (لازم يفضل مجاني
   ويطلب سبب)، وإلغاء بعد قبول الطيار وبعد ما تعدي 3 دقايق (لازم تظهر
   رسوم 10 جنيه في البوتوم شيت، وتتخصم من المحفظة لو الدفع محفظة
   إلكترونية).

إعدادين جداد في تبويب "Settings" بلوحة الأدمن تقدر تعدّلهم في أي وقت من
غير أي نشر: **Cancellation fee (EGP)** (افتراضي 10) و**Free cancellation
window (minutes)** (افتراضي 3 دقايق بعد ما الطيار يقبل الرحلة).

## 6) تصليح ربط الطيار المُضاف يدويًا (link-driver) — محتاج نشر

باج حرج اتصلح (2026-08-20): نظام ربط الطيار "المُضاف يدويًا" من لوحة
التحكم بحسابه الحقيقي بعد أول تسجيل دخول كان بقى معطّل بالكامل (صامت)
من يوم ما اتشال التحقق بالـ OTP (`77e35ce`، 2026-08-09) - راجع
`supabase/functions/link-driver/index.ts` للتفاصيل الكاملة. العملية دي
نُقلت بالكامل للسيرفر (Supabase Edge Function جديدة) بدل الاعتماد على
firestore.rules من جهة العميل.

1. **انشر الدالة الجديدة:**
   ```
   supabase functions deploy link-driver
   ```
   (مش محتاجة أي secret جديد - بتستخدم نفس الـ `FIREBASE_PROJECT_ID` /
   `FIREBASE_CLIENT_EMAIL` / `FIREBASE_PRIVATE_KEY` المسجلين بالفعل
   لباقي الدوال زي `create-order`.)
2. **اختبار:** من لوحة الأدمن، اعمل "+ Add driver" بطيار برقم موبايل
   تجريبي، وبعدين من جهاز/إيموليتور، سجّل دخول بجوجل أو أبل وابدأ
   تسجيل طيار جديد بنفس رقم الموبايل ده بالظبط في شاشة "المعلومات
   الشخصية". المفروض السجل القديم يتربط بحسابك تلقائيًا (تقدر تتأكد من
   Firestore Console: المستند القديم اختفى، والبيانات بقت في
   `drivers/{uid}` بتاعك مع `linkedFromPreInvite: true`).