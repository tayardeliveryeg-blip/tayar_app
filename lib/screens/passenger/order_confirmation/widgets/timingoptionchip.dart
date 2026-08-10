import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart'
import 'package:tayay_app/screens/passenger/searching_offers_screen.dart';
import 'package:tayay_app/screens/passenger/select_destination_screen.dart'
import 'package:tayay_app/services/fare_negotiation_rules.dart';
import 'package:tayay_app/services/wallet_service.dart';
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/widgets/pin_marker.dart' show PinType;

class _TimingOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TimingOptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? TayarColors.primary
              : context.bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? TayarColors.primary
                : context.dividerColor2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? context.onPrimaryColor : context.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}