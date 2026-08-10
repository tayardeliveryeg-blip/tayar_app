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

class OrderConfirmationScreen extends StatefulWidget {
  final String pickupAddress;
  final LatLng pickupLocation;
  final String destinationAddress;
  final LatLng destinationLocation;
  final double distanceKm;
  final int durationMin;
  final double fare;
  final String paymentMethod;

  const OrderConfirmationScreen({
    super.key,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.destinationAddress,
    required this.destinationLocation,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.paymentMethod,
  });

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}