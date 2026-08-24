import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== Tayar Bottom Sheet — شيت سفلي بأسلوب inDrive، بحركة bounce عند الفتح ======
// Usage: TayarBottomSheet.show(context, child: YourContent());
//
// ====== [ملاحظة دمج] ملف جديد بالكامل، مفيش مقابل قديم ليه في المشروع.
// التصحيح الوحيد المطلوب: Colors.black20 (مش موجودة في Flutter SDK، كانت
// هتوقف الـ build) اتبدلت بـ context.handleColor الموجود أصلًا في
// theme_extensions.dart ومخصص بالظبط لخط السحب فوق الـ Bottom Sheets ======

class TayarBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    double initialHeight = 0.45,
    double minHeight = 0.25,
    double maxHeight = 0.85,
    bool isDismissible = true,
    Color? backgroundColor,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BottomSheetContent(
        initialHeight: initialHeight,
        minHeight: minHeight,
        maxHeight: maxHeight,
        backgroundColor: backgroundColor,
        child: child,
      ),
    );
  }
}

class _BottomSheetContent extends StatefulWidget {
  final Widget child;
  final double initialHeight;
  final double minHeight;
  final double maxHeight;
  final Color? backgroundColor;

  const _BottomSheetContent({
    required this.child,
    required this.initialHeight,
    required this.minHeight,
    required this.maxHeight,
    this.backgroundColor,
  });

  @override
  State<_BottomSheetContent> createState() => _BottomSheetContentState();
}

class _BottomSheetContentState extends State<_BottomSheetContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _animation.value) * 200),
          child: child,
        );
      },
      child: DraggableScrollableSheet(
        initialChildSize: widget.initialHeight,
        minChildSize: widget.minHeight,
        maxChildSize: widget.maxHeight,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? context.bgColor.withValues(alpha: 0.98),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: context.dividerColor2, width: 1),
              boxShadow: AppShadows.elevated(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // مقبض السحب
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
                    width: 40,
                    height: AppRadius.handle * 2,
                    decoration: BoxDecoration(
                      color: context.handleColor,
                      borderRadius: BorderRadius.circular(AppRadius.handle),
                    ),
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: widget.child,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}