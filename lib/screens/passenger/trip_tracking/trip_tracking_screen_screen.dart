import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:tayay_app/screens/passenger/passenger_home.dart' show TayarColors, TayarThemeColors, BackArrowIcon;
import 'package:tayay_app/widgets/pin_marker.dart';
import 'package:tayay_app/widgets/map_tile_layer.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/rate_trip_screen.dart';
import 'package:tayay_app/screens/passenger/trip_chat_screen.dart';
import 'package:tayay_app/services/call_invitation_helper.dart';
import 'package:tayay_app/services/wallet_service.dart';
import 'package:tayay_app/services/trip_share_helper.dart';
import 'package:tayay_app/widgets/contact_action_button.dart';
import 'package:tayay_app/widgets/sos_floating_button.dart';

class TripTrackingScreen extends StatefulWidget {
  final String orderId;

  const TripTrackingScreen({super.key, required this.orderId});

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}