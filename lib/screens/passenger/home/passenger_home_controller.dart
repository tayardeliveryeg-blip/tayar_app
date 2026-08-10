import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/services/push_notification_service.dart';
import 'package:tayay_app/services/call_invitation_setup.dart';
import 'package:tayay_app/services/vendor_service.dart';
import 'package:tayay_app/main.dart' show navigatorKey;

import 'models/nearby_driver.dart';

/// Controller منفصل لكل منطق شاشة الراكب الرئيسية
/// يستخدم ChangeNotifier عشان يحدّث الـ UI من غير setState
class PassengerHomeController extends ChangeNotifier {
  final TickerProvider vsync;
  final BuildContext context;

  PassengerHomeController({required this.vsync, required this.context}) {
    _init();
  }

  // ====== Controllers ======
  final MapController mapController = MapController();
  late final AnimationController sheetAnimController;
  late final AnimationController routeAnimController;
  late final AnimationController driversMoveController;

  // ====== Location ======
  LatLng currentLocation = const LatLng(30.7, 31.7);
  LatLng selectedLocation = const LatLng(30.7, 31.7);
  String? currentAddress;
  LatLng? liveUserLocation;
  double? liveUserHeading;
  double? liveUserAccuracy;
  StreamSubscription<Position>? liveLocationSub;

  // ====== Destination ======
  LatLng? destinationLocation;
  String? destinationAddress;
  List<LatLng> routePoints = [];
  List<LatLng> fullRoutePoints = [];
  double? routeDistanceKm;
  int? routeDurationMin;

  // ====== State ======
  String paymentMethod = 'كاش';
  bool isDraggingMap = false;
  Timer? debounce;

  // ====== Drivers ======
  final Map<String, NearbyDriver> nearbyDrivers = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? nearbyDriversSub;

  // ====== Sheet ======
  double sheetDragRange = 300;
  final GlobalKey sheetContainerKey = GlobalKey();
  double measuredSheetHeight = 0;

  // ====== Helpers ======
  static const double _nearbyDriversRadiusKm = 5.0;

  int? get nearbyDriversCount {
    final userLocation = liveUserLocation;
    if (userLocation == null) return null;
    const distanceCalc = Distance();
    return nearbyDrivers.values.where((driver) {
      return distanceCalc.as(
            LengthUnit.Kilometer,
            userLocation,
            driver.target,
          ) <=
          _nearbyDriversRadiusKm;
    }).length;
  }

  double get estimatedFare {
    if (routeDistanceKm == null) return 0;
    return AppSettings.instance.estimateFare(routeDistanceKm!);
  }

  // ====== Init ======
  void _init() {
    sheetAnimController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 280),
      value: 0,
    );

    routeAnimController =
        AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 500),
        )..addListener(() {
          if (fullRoutePoints.isEmpty) return;
          final count = (fullRoutePoints.length * routeAnimController.value)
              .round()
              .clamp(2, fullRoutePoints.length);
          routePoints = fullRoutePoints.sublist(0, count);
          notifyListeners();
        });

    driversMoveController =
        AnimationController(
          vsync: vsync,
          duration: const Duration(milliseconds: 400),
        )..addListener(() {
          final t = driversMoveController.value;
          for (final marker in nearbyDrivers.values) {
            marker.displayed = _lerpLatLng(marker.prev, marker.target, t);
          }
          notifyListeners();
        });

    _getCurrentLocation();
    _startLiveLocationTracking();
    _watchNearbyDrivers();

    PushNotificationService.instance.init(isDriver: false);
    setupCallInvitationService(navigatorKey: navigatorKey);
  }

  // ====== Dispose ======
  void disposeController() {
    debounce?.cancel();
    routeAnimController.dispose();
    sheetAnimController.dispose();
    driversMoveController.dispose();
    liveLocationSub?.cancel();
    nearbyDriversSub?.cancel();
  }

  // ====== Location Methods ======
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      // آخر موقع معروف
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          currentLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
          selectedLocation = currentLocation;
          notifyListeners();
          mapController.move(currentLocation, 16);
          unawaited(
            _getAddressFromCoordinates(lastKnown.latitude, lastKnown.longitude),
          );
        }
      } catch (_) {}

      // قراءة جديدة
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } on TimeoutException {
        debugPrint('⏱️ تحديد الموقع استغرق وقت طويل');
        return;
      }

      currentLocation = LatLng(position.latitude, position.longitude);
      selectedLocation = currentLocation;
      notifyListeners();
      mapController.move(currentLocation, 16);
      await _getAddressFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('❌ خطأ في تحديد الموقع: $e');
    }
  }

  Future<void> refreshLocation() => _getCurrentLocation();

  Future<void> _startLiveLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      );
      liveLocationSub =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen((position) {
            liveUserLocation = LatLng(position.latitude, position.longitude);
            liveUserAccuracy = position.accuracy;
            if (position.heading >= 0) {
              liveUserHeading = position.heading;
            }
            notifyListeners();
          });
    } catch (e) {
      debugPrint('❌ خطأ في بث الموقع اللحظي: $e');
    }
  }

  // ====== Address ======
  Future<void> _getAddressFromCoordinates(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&accept-language=ar',
      );
      final response = await http
          .get(url, headers: {'User-Agent': 'com.tayar.app'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        final road = address?['road'] ?? address?['neighbourhood'] ?? '';
        final suburb = address?['suburb'] ?? address?['city'] ?? '';
        final displayName = [
          road,
          suburb,
        ].where((s) => s.toString().isNotEmpty).join('، ');

        currentAddress = displayName.isNotEmpty
            ? displayName
            : 'عنوان غير معروف';
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ خطأ في جلب العنوان: $e');
      currentAddress = 'تعذر جلب العنوان';
      notifyListeners();
    }
  }

  String addressDisplay(BuildContext context) {
    return currentAddress ?? 'جاري التحديد...';
  }

  // ====== Map Events ======
  void onMapEvent(MapEvent event) {
    if (event.source != MapEventSource.onDrag &&
        event.source != MapEventSource.flingAnimationController) {
      return;
    }

    if (destinationLocation != null) return;

    if (event is MapEventMoveStart) {
      isDraggingMap = true;
      notifyListeners();
    } else if (event is MapEventMoveEnd) {
      isDraggingMap = false;
      notifyListeners();
    }

    selectedLocation = _pinRealLocation(event.camera);
    currentAddress = null;
    notifyListeners();

    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 600), () async {
      currentLocation = selectedLocation;
      notifyListeners();
      await _getAddressFromCoordinates(
        selectedLocation.latitude,
        selectedLocation.longitude,
      );
    });
  }

  LatLng _pinRealLocation(MapCamera camera) {
    final size = camera.nonRotatedSize;
    final pinOffset = Offset(size.width / 2, size.height / 2);
    return camera.offsetToCrs(pinOffset);
  }

  // ====== Route ======
  Future<void> fetchRoute(
    LatLng origin,
    LatLng destination, {
    bool animateCamera = true,
  }) async {
    List<LatLng> points;
    double distanceKm;
    int durationMin;

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
          final coords = route['geometry']['coordinates'] as List;
          points = coords
              .map(
                (c) =>
                    LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
              )
              .toList();
          distanceKm = (route['distance'] as num).toDouble() / 1000;
          durationMin = ((route['duration'] as num).toDouble() / 60).ceil();
        } else {
          throw Exception('مفيش مسار');
        }
      } else {
        throw Exception('فشل الاتصال');
      }
    } catch (e) {
      debugPrint('❌ خطأ في جلب المسار: $e');
      final fallbackDistanceKm = const Distance().as(
        LengthUnit.Kilometer,
        origin,
        destination,
      );
      points = [origin, destination];
      distanceKm = fallbackDistanceKm;
      durationMin = (fallbackDistanceKm / 30 * 60).ceil();
    }

    fullRoutePoints = points;
    routePoints = [];
    routeDistanceKm = distanceKm;
    routeDurationMin = durationMin;
    notifyListeners();

    if (animateCamera) {
      mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(60, 150, 60, 320),
        ),
      );
    }
    routeAnimController
      ..reset()
      ..forward();
  }

  // ====== Drivers ======
  void _watchNearbyDrivers() {
    nearbyDriversSub = FirebaseFirestore.instance
        .collection('driver_locations')
        .where('isAvailable', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          final currentIds = <String>{};
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final geo = _extractGeoPoint(data['currentLocation']);
            if (geo == null) continue;

            currentIds.add(doc.id);
            final newPos = LatLng(geo.latitude, geo.longitude);
            final existing = nearbyDrivers[doc.id];

            if (existing == null) {
              nearbyDrivers[doc.id] = NearbyDriver(
                displayed: newPos,
                prev: newPos,
                target: newPos,
              );
            } else {
              existing.prev = existing.displayed;
              existing.target = newPos;
            }
          }

          nearbyDrivers.removeWhere((id, _) => !currentIds.contains(id));
          notifyListeners();
          driversMoveController.forward(from: 0);
        });
  }

  GeoPoint? _extractGeoPoint(dynamic raw) {
    if (raw is Map) return raw['geopoint'] as GeoPoint?;
    if (raw is GeoPoint) return raw;
    return null;
  }

  LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  // ====== Sheet Drag ======
  void onSheetDragStart(double collapsedHeight, double expandedHeight) {
    sheetDragRange = (expandedHeight - collapsedHeight).abs();
    if (sheetDragRange < 1) sheetDragRange = 1;
  }

  void onSheetDragUpdate(DragUpdateDetails details) {
    final delta = -details.delta.dy / sheetDragRange;
    sheetAnimController.value = (sheetAnimController.value + delta).clamp(
      0.0,
      1.0,
    );
  }

  void onSheetDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (velocity < -250) {
      sheetAnimController.animateTo(1.0, curve: Curves.easeOutCubic);
    } else if (velocity > 250) {
      sheetAnimController.animateTo(0.0, curve: Curves.easeOutCubic);
    } else if (sheetAnimController.value > 0.5) {
      sheetAnimController.animateTo(1.0, curve: Curves.easeOutCubic);
    } else {
      sheetAnimController.animateTo(0.0, curve: Curves.easeOutCubic);
    }
  }

  ({double collapsed, double expanded, double current}) sheetHeights(
    BuildContext context,
    double topSafeArea,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = screenHeight - topSafeArea - 24;
    final collapsedHeight =
        screenHeight * (destinationAddress == null ? 0.5 : 0.38);
    final t = sheetAnimController.value;
    final currentHeight =
        collapsedHeight + (expandedHeight - collapsedHeight) * t;
    return (
      collapsed: collapsedHeight,
      expanded: expandedHeight,
      current: currentHeight,
    );
  }

  void measureSheetHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox =
          sheetContainerKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;
      final newHeight = renderBox.size.height;
      if ((newHeight - measuredSheetHeight).abs() > 0.5) {
        measuredSheetHeight = newHeight;
        notifyListeners();
      }
    });
  }

  // ====== Destination Actions ======
  void setDestination(LatLng location, String address) {
    destinationLocation = location;
    destinationAddress = address;
    sheetAnimController.animateTo(0, curve: Curves.easeOutCubic);
    notifyListeners();
  }

  void clearDestination() {
    routeAnimController.stop();
    sheetAnimController.animateTo(0, curve: Curves.easeOutCubic);
    destinationLocation = null;
    destinationAddress = null;
    routePoints = [];
    fullRoutePoints = [];
    routeDistanceKm = null;
    routeDurationMin = null;
    notifyListeners();
  }

  void setPaymentMethod(String method) {
    paymentMethod = method;
    notifyListeners();
  }

  // ====== Navigation Helpers ======
  Future<void> openDestinationSearch(BuildContext context) async {
    // استدعي SelectDestinationScreen
    // final result = await Navigator.push(...);
    // if (result != null) {
    //   setDestination(result.location, result.title);
    //   await fetchRoute(currentLocation, result.location);
    // }
  }

  Future<void> reorderLastTrip(LatLng location, String address) async {
    setDestination(location, address);
    await fetchRoute(currentLocation, location);
  }

  Future<void> openOrderConfirmation(BuildContext context) async {
    if (destinationLocation == null || routeDistanceKm == null) return;
    // Navigator.push(...);
  }

  // ====== Vendor Partner ======
  void showVendorPartnerSheet(VendorPartner partner) {
    // showModalBottomSheet(...);
  }

  // ====== Payment Method ======
  Future<void> showPaymentMethodSheet(BuildContext context) async {
    // showModalBottomSheet(...);
  }

  // ====== Saved Places ======
  Future<void> addCustomSavedPlace(BuildContext context) async {
    // Navigator.push(...) then save to Firestore
  }

  Future<void> pickAndSaveAddress(
    BuildContext context,
    String key,
    String screenTitle,
  ) async {
    // Navigator.push(...) then save to Firestore
  }
}
