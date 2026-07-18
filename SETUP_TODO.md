# خطوات إعداد متبقية (محتاجة بياناتك من Firebase/Google Console)

الخطوات دي مقدرش أعملها لوحدي لأنها محتاجة بيانات موجودة بس في حساب Firebase/Google
بتاعك (مفتاح، شهادة، أو ملف تنزّله من الكونسول). باقي كل حاجة تانية في المشروع
اتفحصت واتصلحت.

## 1) Google Sign-In على iOS (لسه ناقص)

التطبيق بيستخدم `google_sign_in` بس iOS مفهوش URL Scheme مسجّل، فبعد ما
المستخدم يسجّل دخول بجوجل، الصفحة هترجع للـ Safari وموش هترجعله للتطبيق تاني.

**الخطوات:**
1. من [Firebase Console](https://console.firebase.google.com) → إعدادات
   المشروع (`b10-app-1e682`) → نزّل ملف `GoogleService-Info.plist` بتاع تطبيق
   iOS المسجّل (Bundle ID: `com.example.tayayApp`).
2. حطّه في `ios/Runner/GoogleService-Info.plist`.
3. من جوه الملف، خد قيمة `REVERSED_CLIENT_ID`.
4. افتح `ios/Runner/Info.plist` وضيف الكود ده قبل `</dict>` الأخيرة:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>ضع REVERSED_CLIENT_ID هنا</string>
       </array>
     </dict>
   </array>
   ```

## 2) Google Sign-In على Android — لازم SHA-1

فحصت `android/app/google-services.json` ولقيت مفيش أي `oauth_client` مسجّل
خالص. ده معناه غالبًا إن شهادة الـ SHA-1 بتاعة مفتاح التوقيع (debug أو
release) لسه مش مضافة في Firebase، وده هيخلي تسجيل الدخول بجوجل يفشل برسالة
error زي `ApiException: 10 (DEVELOPER_ERROR)`.

**الخطوات:**
1. هات الـ SHA-1 بتاعك بالأمر:
   ```
   cd android && ./gradlew signingReport
   ```
2. من Firebase Console → إعدادات المشروع → تطبيق Android → أضف الـ
   fingerprint.
3. نزّل `google-services.json` الجديد (هيكون فيه الـ oauth_client دلوقتي)
   واستبدل بيه `android/app/google-services.json`.

## 3) Sign in with Apple — الـ capability لازم تتفعّل من حساب Apple Developer

ضفتلك ملف `ios/Runner/Runner.entitlements` وربطته في مشروع Xcode (Debug/
Release/Profile)، ده بيجهّز الكود بس مش كافي لوحده. لازم كمان:
1. تفتح المشروع في Xcode على جهاز Mac.
2. من تبويب Signing & Capabilities، تتأكد إن "Sign in with Apple" ظاهرة
   ومفعّلة (المفروض تظهر تلقائيًا بفضل الـ entitlements، بس لازم يكون عندك
   Apple Developer account مربوط بالـ Team الصحيح).
3. تتأكد إن الـ App ID بتاعك في Apple Developer portal مفعّل فيه
   "Sign In with Apple" capability.

## 4) applicationId لسه القيمة الافتراضية (لو ناوي تنشر على Google Play)

`android/app/build.gradle.kts` لسه فيه `com.example.tayay_app`. Google Play
بيرفض نشر أي تطبيق بالـ prefix ده. لو مستعجل النشر:
1. غيّر `applicationId` و `namespace` في `android/app/build.gradle.kts`
   لحاجة زي `com.gotayar.app`.
2. سجّل تطبيق Android جديد بنفس الاسم ده في Firebase Console.
3. نزّل `google-services.json` الجديد واستبدل بيه القديم.
4. حدّث `firebase_options.dart` لو استخدمت FlutterFire CLI
   (`flutterfire configure`) هيتحدث تلقائي.

ملحوظة: ما غيّرتش الـ applicationId دلوقتي عشان لو غيّرته من غير ما تحدّث
Firebase Console، التطبيق هيبطّل يشتغل خالص (mismatch)، فالخطوة دي المفروض
تتعمل مع بعض في وقت واحد.
