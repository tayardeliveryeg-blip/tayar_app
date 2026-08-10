import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/screens/passenger/passenger_home.dart' show TayarColors, TayarThemeColors;
import 'package:tayay_app/widgets/map_tile_layer.dart';
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/screens/passenger/trip_tracking_screen.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/searching_offers_widgets/driver_moto_marker.dart';
import 'package:tayay_app/screens/passenger/searching_offers_widgets/offer_cards.dart';
import 'package:tayay_app/services/fare_negotiation_rules.dart';

class SearchingOffersScreen extends StatefulWidget {
  final String orderId;
  final double proposedFare;
  final bool autoAccept;
  final String pickupAddress;
  final LatLng pickupLocation;
  final String destinationAddress;
  // ====== لو مش null، الرحلة دي محجوزة مقدمًا. بيتعرض بس كبانر إعلامي
  // فوق الخريطة - المطابقة الفعلية بتشتغل فورًا زي أي رحلة عادية ======
  final DateTime? scheduledFor;

  const SearchingOffersScreen({
    super.key,
    required this.orderId,
    required this.proposedFare,
    required this.autoAccept,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.destinationAddress,
    this.scheduledFor,
  });

  @override
  State<SearchingOffersScreen> createState() => _SearchingOffersScreenState();
}