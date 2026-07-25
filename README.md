# tayay_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# تحديث: التحقق من صورة البروفايل (زي InDrive)

## اللي اتغيّر
- `driver_profile_screen.dart` و `passenger_profile_screen.dart`: أضفت فحص
  للصورة بعد ما المستخدم يختارها ومن قبل ما تتحفظ، باستخدام
  `ProfilePhotoValidator` الجديد.
- ملف جديد: `lib/services/profile_photo_validator.dart` — فيه منطق الفحص.

## الفحص بيتأكد من إيه
- فيه وجه واحد بس في الصورة
- الوجه قريب/كبير في الكادر (نسبة عرض الوجه لعرض الصورة ≥ 35%)
- الوجه في نص الصورة تقريبًا
- الوجه متجه للكاميرا (مش من الجنب) — زاوية الميل والدوران محدودة
- العينين مفتوحتين

لو الصورة معملتش الشروط، بيظهر Snackbar بالرسالة المناسبة ومفيش حفظ للصورة،
والمستخدم لازم يختار صورة تانية.

## ⚠️ اتخذت قرارين بناءً على الكود اللي شفته، لازم تتأكد منهم:

1. **مسار الـ import**: حطيت `import 'services/profile_photo_validator.dart';`
   افتراضًا إن `driver_profile_screen.dart` و `passenger_profile_screen.dart`
   في نفس مستوى مجلد `services/` جوه `lib/`. لو الترتيب الفعلي مختلف عندك
   (مثلاً الشاشات جوه `lib/screens/` والسيرفس جوه `lib/services/`)، عدّل
   المسار في الـ import لـ:
   ```dart
   import '../services/profile_photo_validator.dart';
   ```
   أو المسار الصحيح حسب مكان الملفين الفعلي عندك.

2. **الويب**: التطبيق عندك بيدعم الويب (لاحظت مجلد `web/`)، ومكتبة
   `google_mlkit_face_detection` مالهاش تنفيذ للويب. عشان كده الفحص بيتخطى
   نفسه تلقائيًا لو شغال على الويب (`kIsWeb`) ويقبل الصورة زي ما هي بدون
   فحص. لو عايز الفحص يبقى إجباري على الويب كمان، محتاج مكتبة تانية (زي
   MediaPipe عبر JS interop) وده تعديل أكبر — قولي لو عايز أبدأ فيه.

## المكتبة المطلوبة
أضف في `pubspec.yaml`:
```yaml
dependencies:
  google_mlkit_face_detection: ^0.12.0
```
وبعدين:
```bash
flutter pub get
```

### إعدادات Android/iOS
- **Android**: `minSdkVersion` لازم يبقى 21 أو أعلى في
  `android/app/build.gradle`.
- **iOS**: تأكد إن `ios/Runner/Info.plist` فيه أذونات الكاميرا والمعرض
  (على الأغلب موجودة عندك بالفعل بما إن `image_picker` شغال أصلاً).

## خطوة تالية لو حابب
لسه معنديش رؤية لباقي هيكل المشروع (مين بيستدعي الشاشتين دول، وهل فيه
provider/state management معين زي Riverpod أو Bloc). لو حصل أي خطأ في
الـ import أو التسمية، ابعتلي رسالة الخطأ أو محتوى مجلد `lib/` وهظبطها.