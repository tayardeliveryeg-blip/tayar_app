import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== زرار أساسي موحّد: نفس شكل ElevatedButton القياسي بتاع الثيم
// (elevatedButtonTheme في theme_extensions.dart) + اهتزاز لمسي خفيف وتأثير
// تصغير بسيط عند الضغط، بدل ما نضيف السلوك ده يدويًا في كل شاشة عندها
// زرار أساسي. الاستخدام: AppPrimaryButton(onPressed: ..., child: ...)
// بدل ElevatedButton العادي — نفس الـ API تقريبًا عشان الاستبدال يبقى سهل.
//
// ====== [تحديث] دمج variants/sizes/glow/loading من UI kit التاني (كانت
// اسمها TayarButton) بدل ما يفضلوا widget منفصل موازي. كل الإضافات هنا
// اختيارية بالكامل (nullable / لها default) عشان الـ 33 استخدام الحالي في
// المشروع (اللي بيمرروا style و child يدويًا) يفضلوا شغالين زي ما هما بالظبط
// من غير أي تغيير. لو مُرّر `style` صريح زي ما بيحصل في كل الشاشات الحالية،
// بيتفضّل هو دايمًا على أي حساب تلقائي من variant/size ======
enum AppButtonVariant { primary, secondary, ghost, danger }

enum AppButtonSize { small, medium, large }

class AppPrimaryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;

  // ====== خصائص اختيارية جديدة (كلها null/false بالـ default عشان مفيش
  // تأثير على أي استخدام قديم متعمل من غيرها) ======
  final AppButtonVariant? variant;
  final AppButtonSize? size;
  final bool isLoading;
  final bool? glow; // null = توهّج تلقائي بس لو variant == primary/danger

  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.variant,
    this.size,
    this.isLoading = false,
    this.glow,
  });

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton> {
  bool _pressed = false;

  double? get _heightForSize {
    // لو مفيش size متحدد، سيبها زي ما هي (تاخد minimumSize 52 من
    // elevatedButtonTheme القياسي زي ما كانت دايمًا) — صفر تغيير سلوكي.
    if (widget.size == null) return null;
    return switch (widget.size!) {
      AppButtonSize.small => 40,
      AppButtonSize.medium => 52,
      AppButtonSize.large => 60,
    };
  }

  ButtonStyle? _styleForVariant(BuildContext context) {
    // لو فيه style صريح ممرر (زي كل الاستخدامات الحالية في المشروع)، هو اللي
    // بيتفضّل دايمًا — مفيش أي override تلقائي عليه.
    if (widget.style != null) return widget.style;

    // لو مفيش variant ولا style، برضه صفر تغيير — يفضل ياخد شكله من الثيم
    // العام (elevatedButtonTheme) زي ما كان دايمًا.
    if (widget.variant == null) return null;

    final height = _heightForSize;
    final baseShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );

    return switch (widget.variant!) {
      AppButtonVariant.primary => ElevatedButton.styleFrom(
        backgroundColor: TayarColors.primary,
        foregroundColor: context.onPrimaryColor,
        minimumSize: height != null ? Size.fromHeight(height) : null,
        shape: baseShape,
        elevation: 0,
      ),
      AppButtonVariant.danger => ElevatedButton.styleFrom(
        backgroundColor: TayarColors.error,
        foregroundColor: Colors.white,
        minimumSize: height != null ? Size.fromHeight(height) : null,
        shape: baseShape,
        elevation: 0,
      ),
      AppButtonVariant.secondary => ElevatedButton.styleFrom(
        backgroundColor: context.cardColor,
        foregroundColor: context.textColor,
        minimumSize: height != null ? Size.fromHeight(height) : null,
        shape: baseShape,
        elevation: 0,
        side: BorderSide(color: context.dividerColor2, width: 1.5),
      ),
      AppButtonVariant.ghost => ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: context.textGreyColor,
        minimumSize: height != null ? Size.fromHeight(height) : null,
        shape: baseShape,
        elevation: 0,
        shadowColor: Colors.transparent,
      ).copyWith(
        overlayColor: WidgetStateProperty.all(
          context.textGreyColor.withValues(alpha: 0.08),
        ),
      ),
    };
  }

  bool get _shouldGlow {
    // توهّج فقط لو مطلوب صراحة، أو تلقائيًا لو الزرار primary/danger وماحدش
    // قال لأ. مفيش توهّج خالص لو مفيش variant محدد (زرارات النظام القديمة).
    if (widget.glow != null) return widget.glow!;
    if (widget.variant == null) return false;
    return widget.variant == AppButtonVariant.primary ||
        widget.variant == AppButtonVariant.danger;
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null && !widget.isLoading;
    final resolvedStyle = _styleForVariant(context);

    final button = ElevatedButton(
      onPressed: enabled
          ? () {
              HapticFeedback.mediumImpact();
              widget.onPressed!();
            }
          : null,
      style: resolvedStyle,
      child: widget.isLoading
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: context.onPrimaryColor,
              ),
            )
          : widget.child,
    );

    final scaledButton = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Listener(
        onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onPointerUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onPointerCancel: enabled
            ? (_) => setState(() => _pressed = false)
            : null,
        child: button,
      ),
    );

    if (!_shouldGlow) return scaledButton;

    // التوهّج بيتحط في Container لف حوالين الزرار بدل ما يتغير الزرار نفسه،
    // عشان AppShadows.primaryGlow (المعرّفة أصلًا في theme_extensions.dart)
    // تتطبّق من غير أي تكرار للقيم هنا.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: widget.variant == AppButtonVariant.danger
            ? [
                BoxShadow(
                  color: TayarColors.error.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : AppShadows.primaryGlow,
      ),
      child: scaledButton,
    );
  }
}