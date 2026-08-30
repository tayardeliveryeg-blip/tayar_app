import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/app_card.dart';

// ====== زرار خدمة سريعة (وصلني / وصل طلباتي) — أيقونة ونص بس، جوه
// الشريط السفلي تحت الأماكن المحفوظة.
//
// ====== [تحديث] isPrimary: بيدّي شكل مختلف لأكتر خدمة مستخدمة (وصلني) —
// تدرّج برتقالي + توهج (glow) خفيف في الزاوية، بدل الكارت العادي، عشان
// يبقى فيه أولوية بصرية واضحة بين الخدمتين (زي زرار "Order Now" في UI kit
// المرجعي). الخدمة التانية (وصل طلباتي) فضلت كارت `glass` عادي ======
class QuickServiceButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const QuickServiceButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  State<QuickServiceButton> createState() => _QuickServiceButtonState();
}

class _QuickServiceButtonState extends State<QuickServiceButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isPrimary) {
      return AppCard(
        onTap: widget.onTap,
        glass: true,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        radius: AppRadius.lg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(widget.icon, color: TayarColors.primary, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.label,
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
      );
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF7A1A), Color(0xFFD94E00)],
            ),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: TayarColors.primary.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ====== توهج زخرفي في الزاوية العلوية — نفس فكرة الـ glow
                // في كارت العرض المرجعي، بس بدرجة خفيفة عشان مايبقاش زحمة ======
                Positioned(
                  top: -18,
                  right: -18,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, color: Colors.white, size: 24),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
