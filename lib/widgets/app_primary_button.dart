import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// زرار أساسي موحّد للـ UI Kit. يدعم variants/sizes/glow/loading مع الحفاظ
// على الـ API القديم (child/style) حتى لا نكسر الاستخدامات الحالية.
enum AppButtonVariant { primary, secondary, outline, ghost, danger }

enum AppButtonSize { small, medium, large }

class AppPrimaryButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final AppButtonVariant? variant;
  final AppButtonSize? size;
  final bool isLoading;
  final bool? glow;
  final Color? disabledBackgroundColor;

  const AppPrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.variant,
    this.size,
    this.isLoading = false,
    this.glow,
    this.disabledBackgroundColor,
  });

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton> {
  bool _pressed = false;

  double? get _heightForSize {
    if (widget.size == null) return null;
    return switch (widget.size!) {
      AppButtonSize.small => 40,
      AppButtonSize.medium => 52,
      AppButtonSize.large => 60,
    };
  }

  ButtonStyle? _styleForVariant(BuildContext context) {
    // Explicit styles remain backward-compatible. New screens should prefer
    // the variant API so styling stays centralized in the UI Kit.
    if (widget.style != null) return widget.style;
    if (widget.variant == null) return null;

    final height = _heightForSize;
    final baseShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
    );
    final minimumSize = height != null ? Size.fromHeight(height) : null;

    return switch (widget.variant!) {
      AppButtonVariant.primary => ElevatedButton.styleFrom(
        backgroundColor: TayarColors.primary,
        foregroundColor: context.onPrimaryColor,
        minimumSize: minimumSize,
        shape: baseShape,
        elevation: 0,
        disabledBackgroundColor: widget.disabledBackgroundColor,
      ),
      AppButtonVariant.danger => ElevatedButton.styleFrom(
        backgroundColor: TayarColors.error,
        foregroundColor: Colors.white,
        minimumSize: minimumSize,
        shape: baseShape,
        elevation: 0,
      ),
      AppButtonVariant.secondary => ElevatedButton.styleFrom(
        backgroundColor: context.cardColor,
        foregroundColor: context.textColor,
        minimumSize: minimumSize,
        shape: baseShape,
        elevation: 0,
        side: BorderSide(color: context.dividerColor2, width: 1.5),
      ),
      AppButtonVariant.outline => ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: TayarColors.primary,
        minimumSize: minimumSize,
        shape: baseShape,
        elevation: 0,
        side: BorderSide(color: TayarColors.primary, width: 1.2),
      ),
      AppButtonVariant.ghost =>
        ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: context.textGreyColor,
          minimumSize: minimumSize,
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
    if (widget.glow != null) return widget.glow!;
    if (widget.variant == null) return false;
    return widget.variant == AppButtonVariant.primary ||
        widget.variant == AppButtonVariant.danger;
  }

  Color _loadingColor(BuildContext context) {
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return context.onPrimaryColor;
      case AppButtonVariant.danger:
        return Colors.white;
      case AppButtonVariant.secondary:
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        return TayarColors.primary;
      case null:
        return context.onPrimaryColor;
    }
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
                color: _loadingColor(context),
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
