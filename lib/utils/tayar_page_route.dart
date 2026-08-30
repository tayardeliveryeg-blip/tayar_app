import 'package:flutter/material.dart';

// ====== انتقال صفحات موحّد لكل التطبيق - بديل مباشر لـ MaterialPageRoute.
// المشكلة اللي بيحلّها: MaterialPageRoute بيدي انتقال مختلف حسب المنصة
// (slide كامل من الجنب على iOS، fade+scale خفيف بس على أندرويد)، فمفيش
// هوية بصرية موحّدة للتطبيق. هنا بنفرض نفس الانتقال (slide خفيف + fade)
// على المنصتين، وبيحترم اتجاه اللغة (RTL/LTR) تلقائيًا فالانتقال بيبان
// طبيعي مع العربي والإنجليزي مع بعض.
//
// الاستخدام: بديل مباشر - غيّر بس اسم الكلاس:
//   Navigator.push(context, TayarPageRoute(builder: (_) => MyScreen()));
//
// لو fullscreenDialog: true (شاشات زي "عدّل بروفايلك" اللي المفروض تبان
// "فوق" الشاشة الحالية مش "جنبها")، الانتقال بيبقى slide من تحت لفوق
// بدل الجنب، مطابق لتوقع المستخدم من شاشة مودال ======
class TayarPageRoute<T> extends PageRouteBuilder<T> {
  final WidgetBuilder builder;

  TayarPageRoute({
    required this.builder,
    super.settings,
    bool fullscreenDialog = false,
    bool maintainState = true,
  }) : super(
         fullscreenDialog: fullscreenDialog,
         maintainState: maintainState,
         transitionDuration: const Duration(milliseconds: 280),
         reverseTransitionDuration: const Duration(milliseconds: 220),
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final isRtl = Directionality.of(context) == TextDirection.rtl;
           final beginOffset = fullscreenDialog
               ? const Offset(0, 0.08)
               : Offset(isRtl ? -0.06 : 0.06, 0);
           final curved = CurvedAnimation(
             parent: animation,
             curve: Curves.easeOutCubic,
             reverseCurve: Curves.easeInCubic,
           );
           return FadeTransition(
             opacity: curved,
             child: SlideTransition(
               position: Tween<Offset>(
                 begin: beginOffset,
                 end: Offset.zero,
               ).animate(curved),
               child: child,
             ),
           );
         },
       );
}
