import 'package:flutter/material.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== سحب موحّد لتحديث أي قائمة بيانات. اللون والخلفية بيتبعوا الثيم
// الحالي عشان المؤشر يبان متسق في الوضعين بدل الـ RefreshIndicator الافتراضي ======
class TayarRefreshIndicator extends StatelessWidget {
  final RefreshCallback onRefresh;
  final Widget child;

  const TayarRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: TayarColors.primary,
      backgroundColor: context.cardColor,
      displacement: AppSpacing.xxl,
      onRefresh: onRefresh,
      child: child,
    );
  }
}
