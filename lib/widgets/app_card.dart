import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== كارت موحّد لأي مكان في التطبيق بيستخدم Container + BoxDecoration
// يدويًا بدل الـ Card widget القياسي (وده أغلب "الكروت" الموجودة فعليًا
// في المشروع). بيدّي نفس الظل، نفس الاستدارة، ونفس تأثير الضغط (تصغير
// خفيف + اهتزاز لمسي) في كل مكان يُستخدم فيه. أي تعديل مستقبلي على شكل
// الكروت (الظل، الاستدارة، سلوك الضغط) بيتم من هنا بس وينعكس على كل شاشة
// بتستخدم AppCard تلقائيًا، بدل ما نعدّل كل شاشة لوحدها.
// الاستخدام: AppCard(onTap: () {...}, child: ...)
class AppCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final bool showShadow;
  final BoxBorder? border;
  final EdgeInsetsGeometry? margin;
  final Clip clipBehavior;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.radius = AppRadius.xl,
    this.color,
    this.showShadow = true,
    this.border,
    this.margin,
    this.clipBehavior = Clip.none,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final Widget card = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Container(
        margin: widget.margin,
        padding: widget.padding,
        clipBehavior: widget.clipBehavior,
        decoration: BoxDecoration(
          color: widget.color ?? context.cardColor,
          borderRadius: BorderRadius.circular(widget.radius),
          border: widget.border,
          boxShadow: widget.showShadow ? AppShadows.soft(context) : null,
        ),
        child: widget.child,
      ),
    );

    if (widget.onTap == null) return card;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap!();
      },
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: card,
    );
  }
}
