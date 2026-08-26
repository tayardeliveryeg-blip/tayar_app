import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/screens/auth/role_selection_screen.dart';
import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart';
import 'package:tayay_app/screens/driver/driver_home_screen.dart';
import 'package:tayay_app/screens/driver/registration/driver_registration_screen.dart';
import 'package:tayay_app/services/driver_invite_link_helper.dart';

// ====================================================
// ====== توجيه المستخدم بعد نجاح الدخول (جوجل / أبل) ======
// قبل أي حاجة: بندور لو رقم موبايله (لو موجود أصلاً في الـ Auth من
// حساب قديم قبل إلغاء تسجيل الدخول بالـ OTP) متسجل كطيار "مُضاف
// يدويًا" من لوحة التحكم (isPreInvited) — لو لقيناه بنربطه بالـ UID
// الحقيقي بتاعه على طول ونوجهه كطيار مباشرة. عمليًا بقى no-op دايمًا
// لحسابات الدخول الجديدة (Google/Apple معندهمش phoneNumber)، والربط
// بقى شغل يدوي من الأدمن — سايبين الكود ده تحسّبًا لأي حساب قديم لسه
// معاه phone claim من قبل إلغاء الـ OTP.
// غير كده:
// مستخدم جديد → شاشة اختيار الدور (راكب / طيار)
// مستخدم قديم → الشاشة الرئيسية (AuthGate هيظبط الوضع الصح
// في المرات الجاية على حسب lastMode المحفوظة) ======
// ====================================================
Future<void> navigateAfterAuth(
  BuildContext context, {
  required bool isNewUser,
}) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    final linkResult = await linkPreInvitedDriverIfNeeded(
      uid: user.uid,
      phoneNumber: user.phoneNumber,
    );

    if (!context.mounted) return;

    if (linkResult.linked) {
      final status = linkResult.driverData?['status'];
      if (status == 'approved') {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DriverHomeScreen()),
          (route) => false,
        );
      } else {
        // ====== لسه ناقص بيانات (رخصة، مستندات، إلخ) → نوديه لشاشة إكمال
        // التسجيل، وبنسيب PassengerHomeScreen تحتها عشان لو قفل يرجع
        // مكان سليم (نفس سلوك اختيار "طيار" من شاشة الدور العادية) ======
        final navigator = Navigator.of(context);
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const PassengerHomeScreen()),
          (route) => false,
        );
        navigator.push(
          MaterialPageRoute(builder: (_) => const DriverRegistrationScreen()),
        );
      }
      return;
    }
  }

  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) =>
          isNewUser ? const RoleSelectionScreen() : const PassengerHomeScreen(),
    ),
    (route) => false,
  );
}
