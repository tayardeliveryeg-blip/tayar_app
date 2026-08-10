// اختبار سلامة أساسي (smoke test) للتطبيق.
//
// ملحوظة: TayarApp بيعتمد في initState على Firebase (FirebaseAuth,
// Firestore) وعلى SharedPreferences، فمش ممكن نعمل pump كامل ليه هنا من
// غير تجهيز mocks لـ Firebase (firebase_core لسه معندوش دعم اختبار رسمي
// بسيط زي باقي حزم Firebase). اختبارات التطبيق الحقيقية (unit/widget tests)
// لسه بند مفتوح في الرودماب ومحتاج إضافة حزم mocking (زي fake_cloud_firestore
// و firebase_auth_mocks) بشكل منفصل.
//
// الاختبار ده بيتأكد بس إن أساسيات Flutter شغالة صح في بيئة الـ CI/التطوير.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp أساسي بيتبني وبيعرض النص المتوقع', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('تطبيق طيار'))),
      ),
    );

    expect(find.text('تطبيق طيار'), findsOneWidget);
  });
}
