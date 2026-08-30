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
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? iconColor;
  final bool showBadge;

  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 50,
    this.iconColor,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    final button = ClipOval(
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
          child: Icon(
            icon,
            color: iconColor ?? context.textColor,
            size: size * 0.44,
          ),
        ),
      ),
    );

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
