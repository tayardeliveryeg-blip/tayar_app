import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'passenger_home.dart' show TayarColors;

/// ====== شاشة تتبع الرحلة اللحظي للراكب ======
/// بتفضل مفتوحة من لحظة قبول الطيار للعرض لحد ما الرحلة تخلص،
/// وبتعرض موقع الطيار وهو بيتحرك فعليًا على الخريطة بحركة ناعمة،
/// مع خط المسار المتبقي والمسافة والوقت المتوقع.
class TripTrackingScreen extends StatefulWidget {
  final String orderId;

  const TripTrackingScreen({super.key, required this.orderId});

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _moveController;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _orderSub;
  bool _endDialogShown = false;
  bool _mapReady = false;

  // ====== بيانات الرحلة (بتتحدث مع أي تغيير في الأوردر) ======
  String _status = 'accepted'; // accepted → in_progress → completed / cancelled
  String _driverName = 'الطيار';
  double _fare = 0;
  String _pickupAddress = '';
  String _destinationAddress = '';
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;

  // ====== موقع الطيار: نقطة سابقة وهدف حالي، بنتحرك بينهم بأنيميشن ======
  LatLng? _driverPrevPosition;
  LatLng? _driverTargetPosition;
  LatLng? _driverDisplayedPosition;
  double _driverPrevHeading = 0;
  double _driverTargetHeading = 0;
  double _driverDisplayedHeading = 0;

  List<LatLng> _routePoints = [];
  double? _remainingDistanceKm;
  int? _remainingDurationMin;
  DateTime? _lastRouteFetch;

  // ====== بيتفعّل تلقائيًا لما الطيار يوصل فعليًا لنقطة الوجهة وقت الرحلة ======
  bool _arrivedAtDestination = false;

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
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    _moveController.dispose();
    super.dispose();
  }

  // ====== دالة مساعدة موحّدة لاستخراج GeoPoint من حقول الموقع ======
  // بتدعم صيغة geoflutterfire_plus الجديدة (Map فيه geopoint + geohash)
  // وكمان الصيغة القديمة (GeoPoint مباشر) كـ fallback للبيانات اللي لسه متحدثش
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
    final oldTarget = _currentTarget;

    setState(() {
      _status = newStatus;
      _driverName = (data['driverName'] as String?) ?? 'الطيار';
      _fare = (data['acceptedFare'] as num?)?.toDouble() ?? 0;
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

    // ====== الرحلة خلصت أو اتلغت ======
    if (newStatus == 'completed' || newStatus == 'cancelled') {
      _showEndDialog(newStatus);
      return;
    }

    // ====== تحديث موقع الطيار اللحظي ======
    final driverGeo = _extractGeoPoint(data['driverLocation']);
    if (driverGeo != null) {
      final newPos = LatLng(driverGeo.latitude, driverGeo.longitude);
      final newHeading =
          (data['driverHeading'] as num?)?.toDouble() ?? _driverTargetHeading;
      _handleDriverPositionUpdate(newPos, newHeading);
    }

    // ====== لو الهدف اتغير (مثلاً الرحلة بدأت وبقى الهدف الوجهة بدل البيك أب) نجيب مسار جديد ======
    if (oldTarget != _currentTarget) {
      _arrivedAtDestination = false;
      if (_driverDisplayedPosition != null) {
        _fetchRouteToTarget(_driverDisplayedPosition!);
      }
    }
  }

  void _handleDriverPositionUpdate(LatLng newPos, double newHeading) {
    // أول موقع بييجي: نحطه على طول من غير أنيميشن، ونزوم يلم الطيار والهدف مع بعض
    if (_driverDisplayedPosition == null) {
      setState(() {
        _driverDisplayedPosition = newPos;
        _driverTargetPosition = newPos;
        _driverPrevPosition = newPos;
        _driverDisplayedHeading = newHeading;
        _driverTargetHeading = newHeading;
        _driverPrevHeading = newHeading;
      });
      _fitCameraToDriverAndTarget(newPos);
      _fetchRouteToTarget(newPos);
      _checkArrival(newPos);
      return;
    }

    _driverPrevPosition = _driverDisplayedPosition;
    _driverPrevHeading = _driverDisplayedHeading;
    _driverTargetPosition = newPos;
    _driverTargetHeading = newHeading;

    _moveController.forward(from: 0);
    _checkArrival(newPos);

    // نحدث خط المسار كل 8 ثواني كحد أقصى بدل كل تحديث موقع، توفيرًا للطلبات
    final now = DateTime.now();
    if (_lastRouteFetch == null ||
        now.difference(_lastRouteFetch!) > const Duration(seconds: 8)) {
      _lastRouteFetch = now;
      _fetchRouteToTarget(newPos);
    }
  }

  // ====== بتتأكد هل الطيار وصل فعليًا لنقطة الوجهة وقت الرحلة الفعلية
  // (in_progress)، وبتفعّل بانر تأكيد الوصول للراكب أول ما يقرب 40 متر ======
  void _checkArrival(LatLng driverPos) {
    if (_status != 'in_progress' ||
        _destinationLocation == null ||
        _arrivedAtDestination) {
      return;
    }
    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      driverPos,
      _destinationLocation!,
    );
    if (distanceMeters.isFinite && distanceMeters < 40) {
      setState(() => _arrivedAtDestination = true);
    }
  }

  // ====== بتتنفذ مع كل نبضة أنيميشن: بتحرك الماركر بسلاسة بين آخر نقطتين ======
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

  // ====== هدف الطيار الحالي: البيك أب لو لسه هيستلم الراكب، أو الوجهة لو الرحلة بدأت فعليًا ======
  LatLng? get _currentTarget =>
      _status == 'in_progress' ? _destinationLocation : _pickupLocation;

  void _fitCameraToDriverAndTarget(LatLng driverPos) {
    final target = _currentTarget;
    if (!_mapReady) return;
    if (target == null) {
      _mapController.move(driverPos, 15);
      return;
    }

    // ====== لو الطيار والهدف في نفس النقطة تقريبًا (زي وقت الاختبار على نفس
    // الجهاز، أو لما الطيار يوصل فعليًا)، fitCamera بيحاول يحسب زوم يلمّ
    // مساحة شبه صفرية فبيطلع زوم لا نهائي ويعمل Crash. في الحالة دي بنكتفي
    // بالتمركز على نقطة الطيار بزوم عادي بدل الملائمة. ======
    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      driverPos,
      target,
    );
    if (!distanceMeters.isFinite || distanceMeters < 30) {
      _mapController.move(driverPos, 16);
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [driverPos, target],
        padding: const EdgeInsets.fromLTRB(60, 150, 60, 280),
      ),
    );
  }

  Future<void> _fetchRouteToTarget(LatLng driverPos) async {
    final target = _currentTarget;
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

      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _remainingDistanceKm = distanceKm;
        _remainingDurationMin = durationMin;
      });
    } catch (e) {
      debugPrint('❌ خطأ في جلب مسار التتبع: $e');
    }
  }

  void _showEndDialog(String status) {
    if (_endDialogShown) return;
    _endDialogShown = true;
    final bool completed = status == 'completed';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
              Icon(
                completed ? Icons.flag_circle : Icons.cancel,
                color: completed ? TayarColors.primary : Colors.redAccent,
                size: 56,
              ),
              const SizedBox(height: 12),
              Text(
                completed ? 'وصلت لوجهتك!' : 'تم إلغاء الرحلة',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Text(
            completed
                ? 'شكرا لاسخدامك طيار!'
                : 'الرحلة اتلغت من الطيار أو من النظام',
            textAlign: TextAlign.center,
            style: const TextStyle(color: TayarColors.textGrey),
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text(
                  'تمام',
                  style: TextStyle(color: TayarColors.primary),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  String get _statusLabel {
    if (_status == 'in_progress' && _arrivedAtDestination) {
      return 'وصلتوا لوجهتكم 🎉';
    }
    switch (_status) {
      case 'accepted':
        return 'الطيار في الطريق ليك';
      case 'in_progress':
        return 'الرحلة بدأت - في الطريق للوجهة';
      default:
        return 'جاري التحديث...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TayarColors.background,
      body: Stack(
        children: [
          // ====== الخريطة ======
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  _driverDisplayedPosition ??
                  _pickupLocation ??
                  const LatLng(30.7, 31.7),
              initialZoom: 15,
              onMapReady: () {
                _mapReady = true;
                if (_driverDisplayedPosition != null) {
                  _fitCameraToDriverAndTarget(_driverDisplayedPosition!);
                }
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
                  // نقطة البيك أب: بتظهر بس لحد ما الطيار يستلم الراكب
                  if (_pickupLocation != null && _status == 'accepted')
                    Marker(
                      point: _pickupLocation!,
                      width: 40,
                      height: 40,
                      child: const _PinIcon(
                        icon: Icons.person,
                        iconColor: TayarColors.primary,
                      ),
                    ),
                  // نقطة الوجهة: بتظهر بعد ما الرحلة تبدأ فعليًا
                  if (_destinationLocation != null && _status == 'in_progress')
                    Marker(
                      point: _destinationLocation!,
                      width: 40,
                      height: 40,
                      child: const _PinIcon(
                        icon: Icons.flag,
                        iconColor: Colors.redAccent,
                      ),
                    ),
                  // ماركر الطيار: بيتحرك بسلاسة ويلف حسب اتجاه حركته
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

          // ====== بانر تأكيد الوصول للوجهة ======
          if (_arrivedAtDestination && _status == 'in_progress')
            Positioned(
              top: 120,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: TayarColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.celebration, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'وصلتوا لوجهتكم! في انتظار الطيار ينهي الرحلة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ====== رسالة انتظار لحد ما أول موقع للطيار يوصل ======
          if (_driverDisplayedPosition == null)
            Positioned(
              top: 120,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: TayarColors.background.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TayarColors.primary,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'في انتظار بدء الطيار مشاركة موقعه...',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
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
                    _statusLabel,
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
                              _driverName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '${_fare.toStringAsFixed(0)} جنيه',
                              style: const TextStyle(
                                color: TayarColors.textGrey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_remainingDistanceKm != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${_remainingDistanceKm!.toStringAsFixed(1)} كم',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${_remainingDurationMin ?? 0} دقيقة',
                              style: const TextStyle(
                                color: TayarColors.textGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        _status == 'in_progress'
                            ? Icons.flag
                            : Icons.radio_button_checked,
                        color: TayarColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _status == 'in_progress'
                              ? _destinationAddress
                              : _pickupAddress,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== أيقونة دبوس بيضاء بشكل موحد لنقاط البيك أب/الوجهة ======
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
