import 'package:flutter/material.dart';

import 'package:tayay_app/theme/theme_extensions.dart';

/// Shared circular action button used by map/tracking screens.
/// Keeps the floating map controls visually consistent across the app.
class TayarMapActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  const TayarMapActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = AppCard(
      padding: EdgeInsets.zero,
      radius: AppRadius.pill,
      color: context.cardColor.withValues(alpha: 0.9),
      showShadow: false,
      shadowStyle: AppCardShadow.floating,
      clipBehavior: Clip.antiAlias,
      onTap: onPressed,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, color: context.textColor, size: 22),
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
