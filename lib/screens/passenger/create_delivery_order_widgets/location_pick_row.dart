import 'package:flutter/material.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

import 'package:tayay_app/theme/theme_extensions.dart';

// ====== صف اختيار موقع (استلام/تسليم) - بيتحول لزرار قابل للضغط ======
class LocationPickRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? address;
  final VoidCallback onTap;

  const LocationPickRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: context.textGreyColor, fontSize: 12),
                ),
                Text(
                  address ?? loc.tapToSelectLocationLabel,
                  style: TextStyle(
                    color: address != null
                        ? context.textColor
                        : context.textGreyColor,
                    fontSize: 15,
                    fontWeight: address != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left, color: context.textGreyColor, size: 20),
        ],
      ),
    );
  }
}
