import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

/// Controller لشاشة تتبع الرحلة
class TripTrackingController extends ChangeNotifier {
  final TickerProvider vsync;
  final String orderId;

  TripTrackingController({required this.vsync, required this.orderId}) {
    _init();
  }

  final MapController mapController = MapController();
  late final AnimationController moveController;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? orderSub;
  bool endDialogShown = false;
  bool mapReady = false;

  // ====== Order Data ======
  String status = 'accepted';
  String driverName = '';
  String driverId = '';
  double fare = 0;
  String paymentMethod = 'كاش';
  String pickupAddress = '';
  String destinationAddress = '';
  LatLng? pickupLocation;
  LatLng? destinationLocation;

  // ====== Driver Position ======
  LatLng? driverPrevPosition;
  LatLng? driverTargetPosition;
  LatLng? driverDisplayedPosition;
  double driverPrevHeading = 0;
  double driverTargetHeading = 0;
  double driverDisplayedHeading = 0;

  // ====== Route ======
  List<LatLng> routePoints = [];
  double? remainingDistanceKm;
  int? remainingDurationMin;
  DateTime? lastRouteFetch;

  // ====== Arrival ======
  bool arrivedAtDestination = false;
  bool arrivedAtPickup = false;

  DocumentReference<Map<String, dynamic>> get orderRef =>
      FirebaseFirestore.instance.collection('orders').doc(orderId);

  LatLng? get currentTarget =>
      status == 'in_progress' ? destinationLocation : pickupLocation;

  void _init() {
    moveController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_onMoveTick);

    orderSub = orderRef.snapshots().listen(_onOrderUpdate);
  }

  void disposeController() {
    orderSub?.cancel();
    moveController.dispose();
  }

  void _onOrderUpdate(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return;

    final newStatus = (data['status'] as String?) ?? status;
    final oldTarget = currentTarget;

    status = newStatus;
    driverName = (data['driverName'] as String?) ?? 'سائق';
    driverId = (data['driverId'] as String?) ?? '';
    fare = (data['acceptedFare'] as num?)?.toDouble() ?? 0;
    paymentMethod = (data['paymentMethod'] as String?) ?? paymentMethod;
    pickupAddress = (data['pickupAddress'] as String?) ?? '';
    destinationAddress = (data['destinationAddress'] as String?) ?? '';

    final pickupGeo = _extractGeoPoint(data['pickupLocation']);
    if (pickupGeo != null) {
      pickupLocation = LatLng(pickupGeo.latitude, pickupGeo.longitude);
    }
    final destGeo = _extractGeoPoint(data['destinationLocation']);
    if (destGeo != null) {
      destinationLocation = LatLng(destGeo.latitude, destGeo.longitude);
    }

    if (newStatus == 'completed') {
      _goToRateTripScreen();
      notifyListeners();
      return;
    }

    if (newStatus == 'cancelled') {
      _showEndDialog();
      notifyListeners();
      return;
    }

    final driverGeo = _extractGeoPoint(data['driverLocation']);
    if (driverGeo != null) {
      final newPos = LatLng(driverGeo.latitude, driverGeo.longitude);
      final newHeading =
          (data['driverHeading'] as num?)?.toDouble() ?? driverTargetHeading;
      _handleDriverPositionUpdate(newPos, newHeading);
    }

    if (oldTarget != currentTarget) {
      arrivedAtDestination = false;
      if (driverDisplayedPosition != null) {
        _fetchRouteToTarget(driverDisplayedPosition!);
      }
    }

    notifyListeners();
  }

  void _handleDriverPositionUpdate(LatLng newPos, double newHeading) {
    if (driverDisplayedPosition == null) {
      driverDisplayedPosition = newPos;
      driverTargetPosition = newPos;
      driverPrevPosition = newPos;
      driverDisplayedHeading = newHeading;
      driverTargetHeading = newHeading;
      driverPrevHeading = newHeading;
      _fitCameraToDriverAndTarget(newPos);
      _fetchRouteToTarget(newPos);
      _checkArrival(newPos);
      notifyListeners();
      return;
    }

    driverPrevPosition = driverDisplayedPosition;
    driverPrevHeading = driverDisplayedHeading;
    driverTargetPosition = newPos;
    driverTargetHeading = newHeading;

    moveController.forward(from: 0);
    _checkArrival(newPos);

    final now = DateTime.now();
    if (lastRouteFetch == null ||
        now.difference(lastRouteFetch!) > const Duration(seconds: 8)) {
      lastRouteFetch = now;
      _fetchRouteToTarget(newPos);
    }
  }

  void _onMoveTick() {
    if (driverPrevPosition == null || driverTargetPosition == null) return;
    final t = moveController.value;

    final lat = _lerp(
      driverPrevPosition!.latitude,
      driverTargetPosition!.latitude,
      t,
    );
    final lng = _lerp(
      driverPrevPosition!.longitude,
      driverTargetPosition!.longitude,
      t,
    );
    final heading = _lerpAngle(driverPrevHeading, driverTargetHeading, t);

    driverDisplayedPosition = LatLng(lat, lng);
    driverDisplayedHeading = heading;

    if (mapReady) {
      mapController.move(driverDisplayedPosition!, mapController.camera.zoom);
    }
    notifyListeners();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _lerpAngle(double a, double b, double t) {
    double diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (a + diff * t) % 360;
  }

  void _fitCameraToDriverAndTarget(LatLng driverPos) {
    final target = currentTarget;
    if (!mapReady) return;
    if (target == null) {
      mapController.move(driverPos, 15);
      return;
    }

    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      driverPos,
      target,
    );
    if (!distanceMeters.isFinite || distanceMeters < 30) {
      mapController.move(driverPos, 16);
      return;
    }

    mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [driverPos, target],
        padding: const EdgeInsets.fromLTRB(60, 150, 60, 280),
      ),
    );
  }

  Future<void> _fetchRouteToTarget(LatLng driverPos) async {
    final target = currentTarget;
    if (target == null) return;

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${driverPos.longitude},${driverPos.latitude};'
        '${target.longitude},${target.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return;

      final route = routes[0];
      final coords = route['geometry']['coordinates'] as List;
      final points = coords
          .map(
            (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          )
          .toList();
      final distanceKm = (route['distance'] as num).toDouble() / 1000;
      final durationMin = ((route['duration'] as num).toDouble() / 60).ceil();

      routePoints = points;
      remainingDistanceKm = distanceKm;
      remainingDurationMin = durationMin;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ خطأ في جلب مسار التتبع: $e');
    }
  }

  void _checkArrival(LatLng driverPos) {
    _checkPickupArrival(driverPos);

    if (status != 'in_progress' ||
        destinationLocation == null ||
        arrivedAtDestination) {
      return;
    }
    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      driverPos,
      destinationLocation!,
    );
    if (distanceMeters.isFinite && distanceMeters < 40) {
      arrivedAtDestination = true;
      notifyListeners();
    }
  }

  void _checkPickupArrival(LatLng driverPos) {
    if (status != 'accepted' || pickupLocation == null || arrivedAtPickup) {
      return;
    }
    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      driverPos,
      pickupLocation!,
    );
    if (distanceMeters.isFinite && distanceMeters < 40) {
      arrivedAtPickup = true;
      notifyListeners();
      _notifyDriverArrivedAtPickup();
    }
  }

  void _notifyDriverArrivedAtPickup() {
    HapticFeedback.mediumImpact();
  }

  void _goToRateTripScreen() {
    if (endDialogShown) return;
    endDialogShown = true;
    // Deduct wallet if needed, then navigate to RateTripScreen
  }

  void _showEndDialog() {
    if (endDialogShown) return;
    endDialogShown = true;
    // Show cancelled dialog
  }

  GeoPoint? _extractGeoPoint(dynamic raw) {
    if (raw is Map) return raw['geopoint'] as GeoPoint?;
    if (raw is GeoPoint) return raw;
    return null;
  }
}
