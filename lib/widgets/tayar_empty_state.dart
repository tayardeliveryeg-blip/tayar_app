import 'package:flutter/material.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';

// ====== Empty State — حالة "مفيش بيانات" بشكل بصري بدل النص المجرد ======
// Usage: TayarEmptyState(
//   icon: Icons.search_off,
//   title: 'مفيش طلبات قريبة',
//   subtitle: 'جرب تغيّر موقعك أو انتظر شوية',
//   actionLabel: 'تحديث',
//   onAction: () {},
// )
//
// ====== [ملاحظة دمج] ملف جديد بالكامل، مفيش مقابل قديم ليه في المشروع.
// استخدمنا TayarColors.primary و context.textColor/textGreyColor بدل ما
// نكرر شرط isDark يدويًا زي الملف الأصلي، وزرار الإجراء بقى AppPrimaryButton
// بدل ElevatedButton منفصل عشان ياخد نفس الـ press animation والـ haptic
// الموحّدين في التطبيق كله ======

class TayarEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double iconSize;

  const TayarEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // أيقونة عائمة بأنيميشن bounce خفيف عند الظهور
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: iconSize + 40,
                    height: iconSize + 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          TayarColors.primary.withValues(alpha: 0.15),
                          TayarColors.primary.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                      border: Border.all(
                        color: TayarColors.primary.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Icon(icon, size: iconSize * 0.5, color: TayarColors.primary),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),

            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.textColor,
                height: 1.3,
              ),
            ),

            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: context.textGreyColor,
                  height: 1.5,
                ),
              ),
            ],

            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              AppPrimaryButton(
                onPressed: onAction,
                variant: AppButtonVariant.primary,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
