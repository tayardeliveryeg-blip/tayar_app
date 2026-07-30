import 'package:flutter/material.dart';

import 'package:tayay_app/theme/theme_extensions.dart';

// ====== زرار خدمة سريعة (وصلني / وصل طلباتي) — أيقونة ونص بس، جوه
// الشريط السفلي تحت الأماكن المحفوظة ======
class QuickServiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickServiceButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.dividerColor2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TayarColors.primary, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: context.textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
