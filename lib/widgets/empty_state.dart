import 'package:flutter/material.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== حالة فارغة موحّدة لكل شاشات التطبيق (مفيش طلبات متاحة، مفيش
// رحلات سابقة، مفيش إشعارات، إلخ). بدل ما كل شاشة تعرض نص لوحده وسط
// مساحة فاضية، الـ widget ده بيدّي أيقونة جوه دائرة بتوهج بلون البراند +
// عنوان + وصف اختياري. أي شاشة فاضية جديدة أو حالية المفروض تستخدم
// EmptyState بدل ما تبني حالتها الفارغة من الصفر، عشان أي تعديل مستقبلي
// على شكل الحالات الفارغة (الحجم، اللون، الأنيميشن) يحصل من مكان واحد بس.
// الاستخدام: EmptyState(icon: Icons.moped_outlined, title: '...')
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TayarColors.primary.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 36, color: TayarColors.primary),
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
          ],
        ),
      ),
    );
  }
}
