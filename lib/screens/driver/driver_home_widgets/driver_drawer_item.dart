import 'package:flutter/material.dart';
import 'package:tayay_app/theme/theme_extensions.dart';

// ====== عنصر واحد في القايمة الجانبية لشاشة الطيار + أيقونة سوشيال ميديا ======
// (كانت قبل كده private classes جوه driver_home_screen.dart واتقسمت في ملف منفصل)
class DriverDrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDestructive;
  final VoidCallback? onTap;

  const DriverDrawerItem({
    super.key,
    required this.icon,
    required this.label,
    this.selected = false,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = isDestructive
        ? TayarColors.error
        : (selected ? TayarColors.primary : context.textColor);

    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive
            ? TayarColors.error
            : (selected ? TayarColors.primary : context.textGreyColor),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: itemColor,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ====== أيقونة سوشيال ميديا دايرية في أسفل القايمة الجانبية ======
class DriverSocialIcon extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onTap;
  const DriverSocialIcon({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: context.textGreyColor),
          shape: BoxShape.circle,
        ),
        child: Center(child: icon),
      ),
    );
  }
}

