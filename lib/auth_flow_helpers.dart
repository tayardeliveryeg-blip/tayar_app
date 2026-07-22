import 'package:flutter/material.dart';
import 'role_selection_screen.dart';
import 'passenger_home.dart';

// ====================================================
// ====== توجيه المستخدم بعد نجاح الدخول بجوجل أو بالموبايل ======
// مستخدم جديد → شاشة اختيار الدور (راكب / طيار)
// مستخدم قديم → الشاشة الرئيسية (AuthGate هيظبط الوضع الصح
// في المرات الجاية على حسب lastMode المحفوظة) ======
// ====================================================
void navigateAfterAuth(BuildContext context, {required bool isNewUser}) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => isNewUser
          ? const RoleSelectionScreen()
          : const PassengerHomeScreen(),
    ),
    (route) => false,
  );
}
