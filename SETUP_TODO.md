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

## 5) رسوم/سبب الإلغاء (بند 4 من gap analysis) — ⚠️ ترتيب النشر مهم

فيتشر كامل جديد: أي إلغاء من الراكب (بحث لسه شغال أو بعد ما طيار يقبل
العرض) بقى محتاج اختيار سبب، وممكن يترتب عليه رسوم إلغاء لو الطيار كان
قابل الرحلة فعلاً وعدّى على القبول أكتر من مهلة معينة (قابلة للتعديل).

**⚠️ لازم تنشر بالترتيب ده بالظبط، ومتنشرش القواعد (firestore.rules)
لوحدها من غير التطبيق المحدّث معاها:**

القواعد الجديدة في `firestore.rules` بتطلب إن أي إلغاء يبعت
`cancellationReason` + `cancelledBy` + `cancellationFee` مع الـ status —
مش `status` لوحده زي التطبيق القديم. لو نشرت القواعد قبل ما التطبيق
الجديد يوصل لكل المستخدمين، هيبقى فيه فترة (لحد ما الكل يحدّث التطبيق)
الإلغاء فيها **مش هيشتغل خالص** لأي حد لسه شغال بنسخة قديمة من التطبيق.

الخطوات الآمنة:
1. اعمل `git pull` + `flutter gen-l10n` + `flutter analyze` كالمعتاد.
2. ابني نسخة جديدة من التطبيق وانشرها (Play Store / التوزيع اللي بتستخدمه).
3. استنى لحد ما تتأكد إن أغلبية المستخدمين حدّثوا (أو على الأقل خلاص من
   مرحلة الاختبار الداخلي بتاعتك).
4. **بعد كده بس** شغّل `firebase deploy --only firestore:rules`.

إعدادين جداد في تبويب "Settings" بلوحة الأدمن تقدر تعدّلهم في أي وقت من
غير أي نشر: **Cancellation fee (EGP)** (افتراضي 10) و**Free cancellation
window (minutes)** (افتراضي 3 دقايق بعد ما الطيار يقبل الرحلة).