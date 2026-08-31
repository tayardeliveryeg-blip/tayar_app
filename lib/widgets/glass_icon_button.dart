import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== زرار دائري "زجاجي" (glassmorphism) للأزرار العايمة فوق الخريطة
// (الإشعارات، القايمة، تحديد الموقع). بيستخدم BackdropFilter حقيقي (blur)
// بدل الـ Container العادي اللي كان مستخدم قبل كده — الفرق إن اللي وراه
// (الخريطة) بيبان مموّه من تحت الزرار بدل ما يتغطي بالكامل بلون solid.
// شارة (badge) اختيارية بتتحط فوق يمين الزرار (مستخدمة لعلامة "فيه إشعار
// جديد" في زرار الإشعارات). أي مكان بيستخدم الـ Container القديم بنفس
// الشكل (50x50, دائرة, border, floating shadow) يقدر يتحول للـ widget ده
// من غير أي تغيير في السلوك أو الـ hit area ======
class GlassIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onTap;
  final double size;
  final Color? iconColor;
  final bool showBadge;
  // لو false، الزرار بيرجع للشكل القديم (solid لون الخلفية + ظل، من غير
  // BackdropFilter ولا border) بدل الزجاجي — نفس الـ hit area والحجم.
  final bool glass;

  const GlassIconButton({
    super.key,
    this.icon,
    this.child,
    this.onTap,
    this.size = 50,
    this.iconColor,
    this.showBadge = false,
    this.glass = true,
  }) : assert(
         icon != null || child != null,
         'لازم توفر icon أو child واحد على الأقل',
       );

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final iconChild =
        child ??
        Icon(icon, color: iconColor ?? context.textColor, size: size * 0.44);

    final Widget button;
    if (glass) {
      button = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: isDark ? 0.08 : 0.05,
              ),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: isDark ? 0.14 : 0.18,
                ),
                width: 1,
              ),
            ),
            child: iconChild,
          ),
        ),
      );
    } else {
      // ====== الشكل القديم (قبل الزجاجي): دائرة solid بلون الخلفية
      // وظل floating بس، من غير blur ولا border — نفس الشكل المستخدم في
      // زرار الرجوع بتاع pick_on_map_screen.dart ======
      button = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.bgColor.withValues(alpha: 0.9),
        ),
        child: iconChild,
      );
    }

    final withShadow = Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: AppShadows.floating(context),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          if (showBadge)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TayarColors.primary,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return withShadow;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap!();
      },
      child: withShadow,
    );
  }
}