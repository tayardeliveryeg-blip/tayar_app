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
//
// ====== [تحديث] دمج تأثير الـ glass (شفافية + border أبيض خفيف) وتدرّجات
// الظل الإضافية (elevated/floating) من UI kit التاني (كانت اسمها TayarGlass)
// بدل ما تفضل كارت منفصل موازي. كل الإضافات هنا اختيارية بالكامل — لو مفيش
// glass أو shadowStyle متمررة، الكارت بيتصرف بالحرف زي دلوقتي، وأي `border`
// صريح متمرر (زي notifications_screen.dart) بيتفضّل هو دايمًا على أي border
// تلقائي من glass ======
enum AppCardShadow { none, soft, elevated, floating }

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

  // ====== خصائص اختيارية جديدة ======
  // shadowStyle: لو null، بيتبع showShadow القديمة زي ما هي (soft لو true،
  // none لو false) — صفر تغيير سلوكي. لو اتحدد صراحة، بياخد الأولوية.
  final AppCardShadow? shadowStyle;
  // glass: تأثير شفافية + border أبيض خفيف (زي كروت عروض السواقين/الشيتات).
  final bool glass;

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
    this.shadowStyle,
    this.glass = false,
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

  List<BoxShadow>? _resolveShadow(BuildContext context) {
    final style =
        widget.shadowStyle ??
        (widget.showShadow ? AppCardShadow.soft : AppCardShadow.none);
    return switch (style) {
      AppCardShadow.none => null,
      AppCardShadow.soft => AppShadows.soft(context),
      AppCardShadow.elevated => AppShadows.elevated(context),
      AppCardShadow.floating => AppShadows.floating(context),
    };
  }

  Color _resolveColor(BuildContext context) {
    if (widget.color != null) return widget.color!;
    if (!widget.glass) return context.cardColor;
    // شفافية أعلى شوية في الوضع الغامق (0.85) عشان يبين اللي وراه، وأقل
    // في الفاتح (0.95) عشان النص يفضل واضح.
    return context.cardColor.withValues(alpha: context.isDarkMode ? 0.85 : 0.95);
  }

  BoxBorder? _resolveBorder(BuildContext context) {
    // border صريح متمرر بييجي أولًا دايمًا (زي notifications_screen.dart
    // اللي بيلوّن الحدود حسب حالة القراءة).
    if (widget.border != null) return widget.border;
    if (!widget.glass) return null;
    return Border.all(
      color: Colors.white.withValues(alpha: context.isDarkMode ? 0.08 : 0.15),
      width: 1,
    );
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
          color: _resolveColor(context),
          borderRadius: BorderRadius.circular(widget.radius),
          border: _resolveBorder(context),
          boxShadow: _resolveShadow(context),
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