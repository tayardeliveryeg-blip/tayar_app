import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'passenger_home.dart' show TayarColors, paymentMethodDisplay;
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'trip_chat_screen.dart';
import 'call_screen.dart';

/// ====== شاشة تتبع الرحلة اللحظي من ناحية الطيار ======
/// بتتفتح فورًا لحظة قبول عرض الطيار، أو لما يدوس على كارت الرحلة النشطة
/// من تبويب "طلباتي". بتعرض نقطة الانطلاق والوصول والمسار بينهم، مع تفاصيل
/// الطلب (السعر المقترح، السعر المتفق عليه، طريقة الدفع)، وموقع الطيار
/// نفسه بيتحرك لايف على الخريطة أثناء الرحلة.
class DriverTripTrackingScreen extends StatefulWidget {
  final String orderId;

  const DriverTripTrackingScreen({super.key, required this.orderId});

  @override
  State<DriverTripTrackingScreen> createState() =>
      _DriverTripTrackingScreenState();
}

class _DriverTripTrackingScreenState extends State<DriverTripTrackingScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _moveController;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderSub;
  StreamSubscription<Position>? _positionSub;
  bool _mapReady = false;
  bool _hasFitInitialBounds = false;

  // ====== بيانات الرحلة (بتتحدث مع أي تغيير في الأوردر) ======
  String _status = 'accepted'; // accepted → in_progress → completed / cancelled
  String _customerName = '';
  double _proposedFare = 0;
  double _acceptedFare = 0;
  String _paymentMethod = 'كاش';
  double _distanceKm = 0;
  int _durationMin = 0;
  String _pickupAddress = '';
  String _destinationAddress = '';
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;

  // ====== موقع الطيار الحالي (من GPS الجهاز مباشرة، بحركة سلسة) ======
  LatLng? _driverPrevPosition;
  LatLng? _driverTargetPosition;
  LatLng? _driverDisplayedPosition;
  double _driverPrevHeading = 0;
  double _driverTargetHeading = 0;
  double _driverDisplayedHeading = 0;

  List<LatLng> _routePoints = [];
  bool _routeFetchedForCurrentLocations = false;

  bool _endDialogShown = false;

  DocumentReference<Map<String, dynamic>> get _orderRef =>
      FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..addListener(_onMoveTick);

    _orderSub = _orderRef.snapshots().listen(_onOrderUpdate);
    _startOwnLocationStream();
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _positionSub?.cancel();
    _moveController.dispose();
    super.dispose();
  }

  GeoPoint? _extractGeoPoint(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw['geopoint'] as GeoPoint?;
    } else if (raw is GeoPoint) {
      return raw;
    }
    return null;
  }

  void _onOrderUpdate(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null || !mounted) return;

    final newStatus = (data['status'] as String?) ?? _status;

    setState(() {
      _status = newStatus;
      _customerName =
          (data['customerName'] as String?) ??
          AppLocalizations.of(context)!.defaultCustomerName;
      _proposedFare = (data['proposedFare'] as num?)?.toDouble() ?? 0;
      _acceptedFare = (data['acceptedFare'] as num?)?.toDouble() ?? 0;
      _paymentMethod =
          (data['paymentMethod'] as String?) ??
          AppLocalizations.of(context)!.paymentMethodCash;
      _distanceKm = (data['distanceKm'] as num?)?.toDouble() ?? 0;
      _durationMin = (data['durationMin'] as num?)?.toInt() ?? 0;
      _pickupAddress = (data['pickupAddress'] as String?) ?? '';
      _destinationAddress = (data['destinationAddress'] as String?) ?? '';

      final pickupGeo = _extractGeoPoint(data['pickupLocation']);
      if (pickupGeo != null) {
        _pickupLocation = LatLng(pickupGeo.latitude, pickupGeo.longitude);
      }
      final destGeo = _extractGeoPoint(data['destinationLocation']);
      if (destGeo != null) {
        _destinationLocation = LatLng(destGeo.latitude, destGeo.longitude);
      }
    });

    // ====== أول ما العنوانين يبقوا جاهزين، نجيب المسار الكامل بينهم مرة واحدة ======
    if (!_routeFetchedForCurrentLocations &&
        _pickupLocation != null &&
        _destinationLocation != null) {
      _routeFetchedForCurrentLocations = true;
      _fetchFullRoute();
    }

    // ====== أول ما العنوانين يوصلوا، نلمّ الكاميرا عليهم مرة واحدة ======
    if (!_hasFitInitialBounds &&
        _pickupLocation != null &&
        _destinationLocation != null) {
      _hasFitInitialBounds = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitInitialBounds());
    }

    // ====== الرحلة اتلغت (نادرًا من ناحية الطيار، لكن للاحتياط) ======
    if (newStatus == 'cancelled') {
      _showEndDialog();
    }
  }

  Future<void> _startOwnLocationStream() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      return;
    }

    // ====== نجيب آخر موقع معروف فورًا عشان الماركر يظهر على طول من غير انتظار ======
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        _handleOwnPositionUpdate(
          LatLng(lastKnown.latitude, lastKnown.longitude),
          lastKnown.heading,
        );
      }
    } catch (_) {}

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            distanceFilter: 5,
          ),
        ).listen((position) {
          _handleOwnPositionUpdate(
            LatLng(position.latitude, position.longitude),
            position.heading,
          );
        });
  }

  void _handleOwnPositionUpdate(LatLng newPos, double newHeading) {
    if (!mounted) return;

    if (_driverDisplayedPosition == null) {
      setState(() {
        _driverDisplayedPosition = newPos;
        _driverTargetPosition = newPos;
        _driverPrevPosition = newPos;
        _driverDisplayedHeading = newHeading;
        _driverTargetHeading = newHeading;
        _driverPrevHeading = newHeading;
      });
      return;
    }

    _driverPrevPosition = _driverDisplayedPosition;
    _driverPrevHeading = _driverDisplayedHeading;
    _driverTargetPosition = newPos;
    _driverTargetHeading = newHeading;
    _moveController.forward(from: 0);
  }

  void _onMoveTick() {
    if (_driverPrevPosition == null || _driverTargetPosition == null) return;
    final t = _moveController.value;

    final lat = _lerp(
      _driverPrevPosition!.latitude,
      _driverTargetPosition!.latitude,
      t,
    );
    final lng = _lerp(
      _driverPrevPosition!.longitude,
      _driverTargetPosition!.longitude,
      t,
    );
    final heading = _lerpAngle(_driverPrevHeading, _driverTargetHeading, t);

    setState(() {
      _driverDisplayedPosition = LatLng(lat, lng);
      _driverDisplayedHeading = heading;
    });

    if (_mapReady) {
      _mapController.move(
        _driverDisplayedPosition!,
        _mapController.camera.zoom,
      );
    }
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  double _lerpAngle(double a, double b, double t) {
    double diff = (b - a) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return (a + diff * t) % 360;
  }

  void _fitInitialBounds() {
    if (!_mapReady || _pickupLocation == null || _destinationLocation == null) {
      return;
    }
    final points = <LatLng>[_pickupLocation!, _destinationLocation!];
    if (_driverDisplayedPosition != null) points.add(_driverDisplayedPosition!);

    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      _pickupLocation!,
      _destinationLocation!,
    );
    if (!distanceMeters.isFinite || distanceMeters < 30) {
      _mapController.move(_pickupLocation!, 16);
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(60, 150, 60, 300),
      ),
    );
  }

  // ====== يجيب المسار الكامل بين نقطة الانطلاق والوصول (مرة واحدة) ======
  Future<void> _fetchFullRoute() async {
    final pickup = _pickupLocation;
    final destination = _destinationLocation;
    if (pickup == null || destination == null) return;

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${pickup.longitude},${pickup.latitude};'
        '${destination.longitude},${destination.latitude}'
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

      if (!mounted) return;
      setState(() => _routePoints = points);
    } catch (e) {
      debugPrint('❌ خطأ في جلب مسار الرحلة: $e');
    }
  }

  Future<void> _startTrip() async {
    await _orderRef.update({'status': 'in_progress'});
  }

  Future<void> _completeTrip() async {
    await _orderRef.update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.of(context).maybePop();
  }

  void _showEndDialog() {
    if (_endDialogShown) return;
    _endDialogShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final loc = AppLocalizations.of(context)!;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          backgroundColor: TayarColors.cardDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Column(
            children: [
              const Icon(Icons.cancel, color: Colors.redAccent, size: 56),
              const SizedBox(height: 12),
              Text(
                loc.tripCancelledTitle,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: Text(
                  loc.ok,
                  style: const TextStyle(color: TayarColors.primary),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final bool inProgress = _status == 'in_progress';

    return Scaffold(
      backgroundColor: TayarColors.background,
      body: Stack(
        children: [
          // ====== الخريطة ======
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _pickupLocation ??
                  _driverDisplayedPosition ??
                  const LatLng(30.296, 31.742),
              initialZoom: 15,
              onMapReady: () {
                _mapReady = true;
                _fitInitialBounds();
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.tayar.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 5,
                      color: TayarColors.primary,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (_pickupLocation != null)
                    Marker(
                      point: _pickupLocation!,
                      width: 40,
                      height: 40,
                      child: const _PinIcon(
                        icon: Icons.radio_button_checked,
                        iconColor: TayarColors.primary,
                      ),
                    ),
                  if (_destinationLocation != null)
                    Marker(
                      point: _destinationLocation!,
                      width: 40,
                      height: 40,
                      child: const _PinIcon(
                        icon: Icons.flag,
                        iconColor: Colors.redAccent,
                      ),
                    ),
                  if (_driverDisplayedPosition != null)
                    Marker(
                      point: _driverDisplayedPosition!,
                      width: 46,
                      height: 46,
                      child: Transform.rotate(
                        angle: _driverDisplayedHeading * math.pi / 180,
                        child: Container(
                          decoration: BoxDecoration(
                            color: TayarColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // ====== زرار الرجوع ======
          Positioned(
            top: 50,
            right: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: TayarColors.background.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
            ),
          ),

          // ====== كارت تفاصيل الرحلة أسفل الشاشة ======
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: const BoxDecoration(
                color: TayarColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      inProgress
                          ? loc.tripInProgressLabel
                          : loc.tripAcceptedWaitingLabel,
                      style: const TextStyle(
                        color: TayarColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 24,
                          backgroundColor: TayarColors.primary,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _customerName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                loc.distanceDurationLabel(
                                  _distanceKm.toStringAsFixed(1),
                                  _durationMin,
                                ),
                                style: const TextStyle(
                                  color: TayarColors.textGrey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              loc.currencyEGP(_acceptedFare.toStringAsFixed(0)),
                              style: const TextStyle(
                                color: TayarColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            if (_proposedFare > 0 &&
                                _proposedFare != _acceptedFare)
                              Text(
                                loc.originalProposedFareLabel(
                                  _proposedFare.toStringAsFixed(0),
                                ),
                                style: const TextStyle(
                                  color: TayarColors.textGrey,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ====== العنوانين ======
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: TayarColors.cardDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.radio_button_checked,
                                color: TayarColors.primary,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _pickupAddress,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: SizedBox(
                              height: 12,
                              child: VerticalDivider(
                                color: Colors.white24,
                                thickness: 2,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.redAccent,
                                size: 14,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _destinationAddress,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                color: Colors.white.withValues(alpha: 0.7),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                paymentMethodDisplay(context, _paymentMethod),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ====== زرارين التواصل مع الراكب ======
                    Row(
                      children: [
                        Expanded(
                          child: _ContactActionButton(
                            icon: Icons.chat_bubble_outline,
                            label: loc.chatWithPassengerLabel,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TripChatScreen(
                                    orderId: widget.orderId,
                                    otherPartyName: _customerName,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ContactActionButton(
                            icon: Icons.call_outlined,
                            label: loc.callPassengerLabel,
                            onTap: () {
                              final user = FirebaseAuth.instance.currentUser;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CallScreen(
                                    orderId: widget.orderId,
                                    myUserId: user?.uid ?? '',
                                    myUserName:
                                        user?.displayName ??
                                        loc.defaultDriverName,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: inProgress ? _completeTrip : _startTrip,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TayarColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          inProgress ? loc.endTrip : loc.startTrip,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== زرار موحّد لأزرار "شات" و"مكالمة" ======
class _ContactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContactActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: TayarColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: TayarColors.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: TayarColors.primary, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: TayarColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== أيقونة دبوس بيضاء موحّدة لنقاط البيك أب/الوجهة ======
class _PinIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;

  const _PinIcon({required this.icon, required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6),
        ],
      ),
      child: Icon(icon, color: iconColor, size: 22),
    );
  }
}
