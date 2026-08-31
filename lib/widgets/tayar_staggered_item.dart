import 'package:flutter/material.dart';

// ====== ظهور متتابع (stagger) لعناصر القوائم - كل عنصر بيتأخر شوية عن
// اللي قبله (fade + slide من تحت بمسافة بسيطة) عشان يديلك إحساس إن
// القايمة "حية" لحظة ما تفتح الشاشة، بدل ما كل العناصر تطلع فجأة مرة
// واحدة. الاستخدام: لف كل عنصر في itemBuilder بيه ومرّر رقمه:
//
//   itemBuilder: (context, index) => TayarStaggeredItem(
//     index: index,
//     child: MyCard(...),
//   ),
class TayarStaggeredItem extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration itemDelay;
  final Duration duration;

  const TayarStaggeredItem({
    super.key,
    required this.index,
    required this.child,
    this.itemDelay = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 320),
  });

  @override
  State<TayarStaggeredItem> createState() => _TayarStaggeredItemState();
}

class _TayarStaggeredItemState extends State<TayarStaggeredItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // ====== نكپّ عدد العناصر اللي بتاخد تأخير (12) عشان لو القايمة
    // طويلة، آخر عنصر ما يستناش تأخير طويل من غير داعي - بعد كده كله
    // بيظهر بنفس التوقيت تقريبًا ======
    final cappedIndex = widget.index.clamp(0, 12);
    final delay = widget.itemDelay * cappedIndex;
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
