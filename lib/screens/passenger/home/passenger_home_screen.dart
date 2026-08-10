import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tayay_app/screens/passenger/select_destination_screen.dart';
import 'package:tayay_app/screens/passenger/order_confirmation_screen.dart';
import 'package:tayay_app/screens/passenger/create_delivery_order_screen.dart';
import 'package:tayay_app/screens/shared/notifications_screen.dart';
import 'package:tayay_app/screens/passenger/passenger_bottom_sheets.dart';
import 'package:tayay_app/widgets/tayar_drawer.dart';
import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/pin_marker.dart';
import 'package:tayay_app/widgets/map_tile_layer.dart';
import 'package:tayay_app/main.dart' show navigatorKey;
import 'package:tayay_app/services/call_invitation_setup.dart';
import 'package:tayay_app/services/push_notification_service.dart';
import 'package:tayay_app/services/wallet_service.dart';
import 'package:tayay_app/services/vendor_service.dart';
import 'package:tayay_app/screens/passenger/become_vendor_screen.dart'
import 'package:tayay_app/theme/app_settings.dart';
export 'package:tayay_app/theme/theme_extensions.dart'; // مصدر TayarColors / TayarTheme / TayarThemeColors الوحيد

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}