import 'package:flutter/material.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';

// ====== حالة فارغة موحّدة لكل شاشات التطبيق (مفيش طلبات متاحة، مفيش
// رحلات سابقة، مفيش إشعارات، إلخ). بدل ما كل شاشة تعرض نص لوحده وسط
// مساحة فاضية، الـ widget ده بيدّي أيقونة جوه دائرة بتوهج بلون البراند +
// عنوان + وصف اختياري. أي شاشة فاضية جديدة أو حالية المفروض تستخدم
// EmptyState بدل ما تبني حالتها الفارغة من الصفر، عشان أي تعديل مستقبلي
// على شكل الحالات الفارغة (الحجم، اللون، الأنيميشن) يحصل من مكان واحد بس.
// الاستخدام: EmptyState(icon: Icons.moped_outlined, title: '...')
//
// ====== [تحديث دمج] كان فيه ملف تاني (tayar_empty_state.dart، كلاس
// TayarEmptyState) اتضاف في جلسة دمج UI kit منفصلة بنفس الغرض بالظبط —
// ازدواجية حصلت لأن الفحص الأول راجع بس AppButton/AppCard ومفوتش EmptyState
// (اتضافت في نفس الكوميت اللي سبق جلسة الدمج مباشرة). اتصلحت بدمج actionLabel/
// onAction وحركة الظهور (bounce) هنا بدل ما يفضل widget منفصل موازي —
// tayar_empty_state.dart اتمسح. أي استخدام حالي (driver_requests_tab.dart،
// my_drivers_screen.dart) بيمرر icon/title/subtitle بس، فمفيش تغيير سلوكي ======
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(scale: value, child: child);
              },
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: TayarColors.primary.withValues(alpha: 0.1),
                ),
                child: Icon(icon, size: 36, color: TayarColors.primary),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: context.textColor),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textGreyColor, fontSize: 13),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppPrimaryButton(
                onPressed: onAction,
                variant: AppButtonVariant.primary,
                isFullWidth: false,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
