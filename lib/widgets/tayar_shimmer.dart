import 'package:flutter/material.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== Shimmer Effect — Loading Skeleton ======
// Usage: TayarShimmer(child: YourWidget())
// Or: TayarShimmer.card(), TayarShimmer.list(), TayarShimmer.circle(size)
//
// ====== [ملاحظة دمج] ملف جديد بالكامل، مفيش مقابل قديم ليه في المشروع.
// الألوان بقت مسحوبة من context.cardColor بدل ما تكون hardcoded، عشان تتبع
// نفس نظام الوضع الفاتح/الغامق الموجود في theme_extensions.dart تلقائيًا ======

class TayarShimmer extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  final Color? baseColor;
  final Color? highlightColor;

  const TayarShimmer({
    super.key,
    required this.child,
    this.isLoading = true,
    this.baseColor,
    this.highlightColor,
  });

  // Pre-built shimmer cards
  static Widget card({double height = 120, double? width}) =>
      _ShimmerCard(height: height, width: width);
  static Widget circle(double size) => _ShimmerCircle(size: size);
  static Widget list({int count = 3}) => Column(
    children: List.generate(
      count,
      (_) => const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md),
        child: _ShimmerCard(height: 80),
      ),
    ),
  );

  @override
  State<TayarShimmer> createState() => _TayarShimmerState();
}

class _TayarShimmerState extends State<TayarShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) return widget.child;

    final base = widget.baseColor ?? context.cardColor;
    final highlight =
        widget.highlightColor ??
        (context.isDarkMode
            ? const Color(0xFF3A3836)
            : const Color(0xFFF5F5F5));

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + _controller.value * 2, 0),
              end: Alignment(1.0 + _controller.value * 2, 0),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;
  const _ShimmerCard({required this.height, this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
    );
  }
}

class _ShimmerCircle extends StatelessWidget {
  final double size;
  const _ShimmerCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: context.cardColor, shape: BoxShape.circle),
    );
  }
}
