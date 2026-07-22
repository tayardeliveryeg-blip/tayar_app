// ====== نسخة "وهمية" بتتستخدم على الموبايل (أندرويد/آيفون) بس ======
// مش بتتنفّذ فعليًا، غرضها الوحيد إنها تخلي الـ conditional import في
// login_screen.dart يترجم صح على المنصات اللي مش ويب.
import 'package:flutter/material.dart';

class GoogleSignInWebButton extends StatelessWidget {
  final void Function(BuildContext context, bool isNewUser) onSignedIn;
  final void Function(BuildContext context, Object error) onError;

  const GoogleSignInWebButton({
    super.key,
    required this.onSignedIn,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
