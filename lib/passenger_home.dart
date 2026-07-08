import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import 'select_destination_screen.dart';
import 'order_confirmation_screen.dart';
import 'create_delivery_order_screen.dart';
import 'driver_registration_screen.dart';
import 'login_screen.dart';
import 'notifications_screen.dart';
import 'order_history_screen.dart';
import 'security_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import 'support_screen.dart';

// ====== القيمة الداخلية لطريقة الدفع بتفضل ثابتة (عربي) عشان التوافق مع
// Firestore وشاشة الطيار، والترجمة بتحصل بس وقت العرض عن طريق الدالة دي ======
String paymentMethodDisplay(BuildContext context, String value) {
  final loc = AppLocalizations.of(context)!;
  switch (value) {
    case 'محفظة إلكترونية':
      return loc.paymentMethodWallet;
    case 'إنستاباي':
      return loc.paymentMethodInstapay;
    default:
      return loc.paymentMethodCash;
  }
}

// ====== ألوان البراند ======
class TayarColors {
  static const Color primary = Color(0xFFFF6B00); // الأورانج الأساسي
  static const Color background = Color(0xFF1A1816); // الخلفية الداكنة
  static const Color cardDark = Color(0xFF2A2826);
  static const Color textWhite = Colors.white;
  static const Color textGrey = Color(0xFFB0B0B0);
}

// ====== روابط طيار الرسمية على السوشيال ميديا ======
class TayarSocialLinks {
  static const String facebook = 'https://www.facebook.com/tayardelivery/';
  static const String instagram = 'https://www.instagram.com/gotayar/';
  static const String whatsapp = 'https://wa.me/201142263460';
}

// ====== فتح رابط خارجي (سوشيال ميديا/واتساب) في تطبيق خارجي ======
Future<void> launchSocialUrl(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.failedToOpenAppError)),
    );
  }
}

class PassengerHomeScreen extends StatefulWidget {
  const PassengerHomeScreen({super.key});

  @override
  State<PassengerHomeScreen> createState() => _PassengerHomeScreenState();
}

class _PassengerHomeScreenState extends State<PassengerHomeScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(
    30.7,
    31.7,
  ); // افتراضي: العاشر من رمضان تقريباً
  LatLng _selectedLocation = const LatLng(
    30.7,
    31.7,
  ); // الموقع المختار حاليًا (نص الخريطة)
  String? _currentAddress;

  // ====== بترجع عنوان النقطة الحالية، أو نص "جاري التحديد" مترجم لو لسه مفيش عنوان ======
  String _addressDisplay(BuildContext context) =>
      _currentAddress ?? AppLocalizations.of(context)!.locatingAddress;
  Timer? _debounce;

  LatLng? _destinationLocation;
  String? _destinationAddress;
  List<LatLng> _routePoints =
      []; // النقاط الظاهرة فعليًا على الخريطة (بتزيد تدريجيًا وقت الأنيميشن)
  List<LatLng> _fullRoutePoints =
      []; // كل نقاط المسار الكاملة اللي جايه من OSRM
  double? _routeDistanceKm;
  int? _routeDurationMin;
  String _paymentMethod = 'كاش'; // طريقة الدفع الحالية المختارة
  bool _isDraggingMap = false; // بنستخدمها لإخفاء الشريط السفلي وقت سحب الخريطة

  LatLng? _liveUserLocation; // موقعك الحقيقي الفعلي، بيتحدث لايف مع تحركك
  StreamSubscription<Position>? _liveLocationSub;

  // ====== الطيارين المتاحين القريبين، بيظهروا كإيموجي موتوسيكل متحرك ======
  final Map<String, _NearbyDriverMarker> _nearbyDrivers = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nearbyDriversSub;
  late final AnimationController _driversMoveController;

  late final AnimationController _routeAnimController;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLiveLocationTracking();

    // ====== أنيميشن رسم المسار تدريجيًا من نقطة الانطلاق للوجهة ======
    _routeAnimController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        )..addListener(() {
          if (_fullRoutePoints.isEmpty) return;
          final count = (_fullRoutePoints.length * _routeAnimController.value)
              .round()
              .clamp(2, _fullRoutePoints.length);
          setState(() => _routePoints = _fullRoutePoints.sublist(0, count));
        });

    // ====== أنيميشن حركة الطيارين القريبين على الخريطة ======
    _driversMoveController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 400),
        )..addListener(() {
          final t = _driversMoveController.value;
          for (final marker in _nearbyDrivers.values) {
            marker.displayed = _lerpLatLng(marker.prev, marker.target, t);
          }
          if (mounted) setState(() {});
        });
    _watchNearbyDrivers();
  }

  // ====== بث موقعك الحقيقي لايف (النقطة الزرقاء الثابتة جغرافيًا) ======
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
      _liveLocationSub =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen((position) {
            if (!mounted) return;
            setState(
              () => _liveUserLocation = LatLng(
                position.latitude,
                position.longitude,
              ),
            );
          });
    } catch (e) {
      debugPrint('❌ خطأ في بث الموقع اللحظي: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _routeAnimController.dispose();
    _driversMoveController.dispose();
    _liveLocationSub?.cancel();
    _nearbyDriversSub?.cancel();
    super.dispose();
  }

  // ====== دالة مساعدة موحّدة لاستخراج GeoPoint من حقول الموقع ======
  // بتدعم صيغة geoflutterfire_plus (Map فيه geopoint + geohash)
  // وكمان الصيغة القديمة (GeoPoint مباشر) كـ fallback
  GeoPoint? _extractGeoPoint(dynamic raw) {
    if (raw is Map<String, dynamic>) {
      return raw['geopoint'] as GeoPoint?;
    } else if (raw is GeoPoint) {
      return raw;
    }
    return null;
  }

  LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * t,
      a.longitude + (b.longitude - a.longitude) * t,
    );
  }

  // ====== تتبع كل الطيارين المتاحين (isAvailable == true) لحظيًا وعرضهم على الخريطة ======
  void _watchNearbyDrivers() {
    _nearbyDriversSub = FirebaseFirestore.instance
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
            final existing = _nearbyDrivers[doc.id];

            if (existing == null) {
              // ====== طيار جديد: يظهر على طول من غير أنيميشن ======
              _nearbyDrivers[doc.id] = _NearbyDriverMarker(
                displayed: newPos,
                prev: newPos,
                target: newPos,
              );
            } else {
              // ====== طيار موجود: يتحرك بسلاسة من مكانه الحالي للمكان الجديد ======
              existing.prev = existing.displayed;
              existing.target = newPos;
            }
          }

          // ====== شيل أي طيار بقى مش متاح (قبل رحلة أو قفل التطبيق) ======
          _nearbyDrivers.removeWhere((id, _) => !currentIds.contains(id));

          if (mounted) setState(() {});
          _driversMoveController.forward(from: 0);
        });
  }

  // ====== بترجع الإحداثية الحقيقية اللي فعليًا تحت الدبوس على الشاشة ======
  // الدبوس بقى ثابت في نص الشاشة بالظبط طول الوقت (وقت السحب ووقت الثبات)،
  // فمفيش داعي لأي تعويض/رفع (pinLift) — نص الشاشة الحقيقي هو نفسه مكان الدبوس دايمًا.
  LatLng _pinRealLocation(MapCamera camera) {
    final size = camera.nonRotatedSize; // Point<double> في نسخة flutter_map دي
    final pinPoint = math.Point<double>(size.x / 2, size.y / 2);
    return camera.pointToLatLng(pinPoint);
  }

  // ====== بيتنادى كل مرة الخريطة تتحرك (سحب أو زوم) ======
  void _onMapEvent(MapEvent event) {
    // بس لما المستخدم يسحب الخريطة بإيده (مش لما الكود هو اللي يحرك الخريطة)
    if (event.source != MapEventSource.onDrag &&
        event.source != MapEventSource.flingAnimationController) {
      return;
    }

    // ====== لو فيه وجهة متحددة بالفعل: السحب بقى تصفح عادي للخريطة بس ======
    // مفيش تحديث لنقطة الانطلاق، مفيش دبوس نص الشاشة، ومفيش إخفاء للشريط
    // السفلي. الماركرين (نقطة الانطلاق + الوجهة) ثابتين على إحداثياتهم
    // الحقيقية على الخريطة، فبيفضلوا واقفين في مكانهم الصح مهما اتحرك أو
    // اتزوم المستخدم جوه الخريطة.
    if (_destinationLocation != null) return;

    // ====== إخفاء الشريط السفلي وقت السحب، وإرجاعه لما المستخدم يسيب إيده ======
    if (event is MapEventMoveStart) {
      setState(() => _isDraggingMap = true);
    } else if (event is MapEventMoveEnd) {
      setState(() => _isDraggingMap = false);
    }

    setState(() {
      _selectedLocation = _pinRealLocation(event.camera);
      _currentAddress = null;
    });

    // نلغي أي طلب سابق لسه مستني، ونستنى نص ثانية بعد ما المستخدم يبطل يسحب
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      // نحدّث نقطة الانطلاق لمكان الخريطة الجديد
      setState(() => _currentLocation = _selectedLocation);
      await _getAddressFromCoordinates(
        _selectedLocation.latitude,
        _selectedLocation.longitude,
      );
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      // ====== أول حاجة: نجيب آخر موقع محفوظ (لو موجود) ونعرضه فورًا من غير
      // أي انتظار، عشان المستخدم مايشوفش "جاري التحميل" وهو أصلاً عنده
      // موقع معروف من قبل. لو مفيش، هنكمل عادي على القراءة الجديدة تحت. ======
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && mounted) {
          setState(() {
            _currentLocation = LatLng(lastKnown.latitude, lastKnown.longitude);
            _selectedLocation = _currentLocation;
          });
          _mapController.move(_currentLocation, 16);
          unawaited(
            _getAddressFromCoordinates(lastKnown.latitude, lastKnown.longitude),
          );
        }
      } catch (_) {
        // تجاهل أي خطأ هنا، مش حرج - هنكمل على القراءة الجديدة تحت
      }

      // ====== دلوقتي نجيب قراءة حقيقية جديدة. بدقة "متوسطة" بدل "عالية"
      // عشان تكون أسرع بكتير (خصوصًا على المتصفح/الديسكتوب اللي بياخد وقت
      // طويل قوي مع الدقة العالية)، ومع سقف وقت أقصى 8 ثواني عشان الشاشة
      // متفضلش عالقة على "جاري التحميل" للأبد لو الجهاز بطيء في التحديد ======
      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 8),
        );
      } on TimeoutException {
        debugPrint(
          '⏱️ تحديد الموقع الدقيق استغرق وقت طويل، هنكتفي بآخر قراءة متاحة',
        );
        return;
      }

      debugPrint(
        '✅ الموقع المُستلم من المتصفح: '
        'lat=${position.latitude}, lng=${position.longitude}, '
        'accuracy=${position.accuracy} متر',
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _selectedLocation = _currentLocation;
      });
      _mapController.move(_currentLocation, 16);
      await _getAddressFromCoordinates(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('❌ خطأ في تحديد الموقع: $e');
    }
  }

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

        setState(() {
          _currentAddress = displayName.isNotEmpty
              ? displayName
              : (mounted ? AppLocalizations.of(context)!.addressUnknown : null);
        });
      }
    } catch (e) {
      debugPrint('❌ خطأ في جلب اسم العنوان: $e');
      if (mounted) {
        setState(() {
          _currentAddress = AppLocalizations.of(context)!.addressFetchFailed;
        });
      }
    }
  }

  // ====== جلب مسار الطريق الحقيقي بين نقطة الانطلاق والوجهة ======
  // animateCamera: هل نعمل زوم يلم المسار كله ولا لأ (بنعطلها وقت السحب اليدوي للخريطة)
  Future<void> _fetchRoute(
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
          throw Exception('مفيش مسار متاح');
        }
      } else {
        throw Exception('فشل الاتصال بسيرفر المسارات');
      }
    } catch (e) {
      debugPrint('❌ خطأ في جلب المسار: $e');
      // لو OSRM فشل أو مرجعش مسار، نرسم خط مستقيم بديل ونحسب المسافة بخط مستقيم
      final fallbackDistanceKm = const Distance().as(
        LengthUnit.Kilometer,
        origin,
        destination,
      );
      points = [origin, destination];
      distanceKm = fallbackDistanceKm;
      durationMin = (fallbackDistanceKm / 30 * 60)
          .ceil(); // تقدير بمتوسط سرعة 30كم/س
    }

    if (!mounted) return;
    setState(() {
      _fullRoutePoints = points;
      _routePoints = []; // هيتملى تدريجيًا مع بداية الأنيميشن
      _routeDistanceKm = distanceKm;
      _routeDurationMin = durationMin;
    });

    // ====== الزوم على المسار وبداية رسمه بالأنيميشن في نفس اللحظة بالظبط ======
    if (animateCamera) {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(60, 150, 60, 320),
        ),
      );
    }
    _routeAnimController
      ..reset()
      ..forward();
  }

  // ====== حساب سعر الرحلة: 10 جنيه أساسي + 5 جنيه لكل كيلومتر ======
  double get _estimatedFare {
    if (_routeDistanceKm == null) return 0;
    return 10 + (5 * _routeDistanceKm!);
  }

  Future<void> _openDestinationSearch() async {
    final result = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SelectDestinationScreen(initialLocation: _currentLocation),
      ),
    );

    if (result != null) {
      setState(() {
        _destinationLocation = result.location;
        _destinationAddress = result.title;
      });
      // الزوم على المسار وبداية رسمه بالأنيميشن بيحصلوا مع بعض جوه _fetchRoute
      await _fetchRoute(_currentLocation, result.location);
    }
  }

  // ====== فتح شاشة "وصل طلباتي" (طلب توصيل طرد/بضاعة) ======
  Future<void> _openDeliveryOrder() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateDeliveryOrderScreen(
          initialPickupLocation: _currentLocation,
          initialPickupAddress: _currentAddress,
        ),
      ),
    );
  }

  void _clearDestination() {
    _routeAnimController.stop();
    setState(() {
      _destinationLocation = null;
      _destinationAddress = null;
      _routePoints = [];
      _fullRoutePoints = [];
      _routeDistanceKm = null;
      _routeDurationMin = null;
    });
  }

  // ====== فتح شاشة اختيار طريقة الدفع (كاش / محفظة إلكترونية / إنستاباي) ======
  Future<void> _showPaymentMethodSheet() async {
    final loc = AppLocalizations.of(context)!;
    final options = <Map<String, dynamic>>[
      {'value': 'كاش', 'icon': Icons.payments_outlined},
      {
        'value': 'محفظة إلكترونية',
        'icon': Icons.account_balance_wallet_outlined,
      },
      {'value': 'إنستاباي', 'icon': Icons.bolt_outlined},
    ];

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TayarColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
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
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    loc.choosePaymentMethodTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...options.map((option) {
                final value = option['value'] as String;
                final label = paymentMethodDisplay(sheetContext, value);
                final isSelected = value == _paymentMethod;
                return ListTile(
                  onTap: () => Navigator.pop(sheetContext, value),
                  leading: Icon(
                    option['icon'] as IconData,
                    color: isSelected
                        ? TayarColors.primary
                        : TayarColors.textGrey,
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(
                          Icons.check_circle,
                          color: TayarColors.primary,
                        )
                      : null,
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (selected != null) {
      setState(() => _paymentMethod = selected);
    }
  }

  Future<void> _openOrderConfirmation() async {
    if (_destinationLocation == null || _routeDistanceKm == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderConfirmationScreen(
          pickupAddress: _addressDisplay(context),
          pickupLocation: _currentLocation,
          destinationAddress: _destinationAddress ?? '',
          destinationLocation: _destinationLocation!,
          distanceKm: _routeDistanceKm!,
          durationMin: _routeDurationMin ?? 0,
          fare: _estimatedFare,
          paymentMethod: _paymentMethod,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TayarColors.background,
      drawer: const TayarDrawer(),
      body: Stack(
        children: [
          // ====== الخريطة (ملفوفة بـ Listener عشان نرصد بداية/نهاية اللمس أو ضغط الماوس بشكل موثوق) ======
          // بيتجاهل اللمس تمامًا لو فيه وجهة متحددة، عشان تصفح الخريطة في
          // وضع "عرض المسار" يفضل تصفح عادي من غير أي تأثيرات (إخفاء الشريط
          // السفلي أو زرار الموقع) كانت مرتبطة بوضع اختيار نقطة الانطلاق بس.
          Listener(
            onPointerDown: (_) {
              if (_destinationLocation == null) {
                setState(() => _isDraggingMap = true);
              }
            },
            onPointerUp: (_) {
              if (_destinationLocation == null) {
                setState(() => _isDraggingMap = false);
              }
            },
            onPointerCancel: (_) {
              if (_destinationLocation == null) {
                setState(() => _isDraggingMap = false);
              }
            },
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 15,
                onMapEvent: _onMapEvent,
                // نسمح بالسحب (يمين/شمال/فوق/تحت) والزوم، ونمنع الدوران خالص
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
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
                if (_destinationLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _destinationLocation!,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.flag,
                            color: TayarColors.primary,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),
                // ====== ماركر نقطة الانطلاق الثابت جغرافيًا ======
                // بيظهر بس لما يكون فيه وجهة متحددة (يعني الكاميرا زوّمت لتعرض
                // المسار كله وبقت مش متمركزة على نقطة الانطلاق). ده بيفضل
                // مثبّت على الإحداثية الحقيقية بتاعت نقطة الانطلاق زي ماركر
                // الوجهة بالظبط، عكس دبوس السحب في نص الشاشة اللي بيبقى غير
                // دقيق أول ما الكاميرا تتحرك بعيد عن نقطة الانطلاق.
                // بيتخفي وقت السحب عشان نرجع نستخدم دبوس السحب في نص الشاشة
                // بدل منه لحظة ما المستخدم يحاول يظبط نقطة الانطلاق تاني.
                if (_destinationLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation,
                        width: 44,
                        height: 44,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person,
                            color: TayarColors.primary,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                // ====== الطيارين المتاحين القريبين: إيموجي موتوسيكل بيتحرك لايف ======
                if (_nearbyDrivers.isNotEmpty)
                  MarkerLayer(
                    markers: _nearbyDrivers.values.map((driver) {
                      return Marker(
                        point: driver.displayed,
                        width: 34,
                        height: 34,
                        child: const Text(
                          '🏍️',
                          style: TextStyle(fontSize: 26),
                        ),
                      );
                    }).toList(),
                  ),
                // ====== النقطة الزرقاء الثابتة جغرافيًا: موقعك الحقيقي، بتتحرك لايف مع تحركك فعليًا ======
                if (_liveUserLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _liveUserLocation!,
                        width: 18,
                        height: 18,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // ====== الماركر الثابت في نص الشاشة + كارت "من أين" ======
          // ====== مهم جدًا ======
          // رأس الدبوس (النقطة الحمرا) ثابت في نص الشاشة بالظبط طول الوقت،
          // وقت السحب ووقت الثبات، من غير أي حركة رأسية أو "قفزة" لفوق.
          // ده لازم يفضل مطابق تمامًا للإحداثية اللي بتحسبها _pinRealLocation
          // (اللي بترجع نص الشاشة بالظبط دلوقتي، من غير أي pinLift).
          //
          // الكارت العلوي بس (من أين + العنوان) هو اللي بيظهر/يختفي بشفافية
          // (AnimatedOpacity) وقت السحب — والمساحة بتاعته بتفضل محجوزة زي
          // ما هي (مش بتتشال) عشان ارتفاع الـ Column يفضل ثابت، ومن غير كده
          // FractionalTranslation(-0.5) هتتغير نتيجتها كل مرة الكارت يختفي/يظهر.
          //
          // FractionalTranslation(Offset(0, -0.5)) بترفع الـ Column لفوق
          // بمقدار "نص ارتفاعها هي نفسها" (مش رقم ثابت)، فبكده أسفل
          // الـ Column (النقطة الحمرا) بيبقى بالظبط عند نقطة مركز الشاشة —
          // مهما كان طول العنوان أو حجم الكارت.
          //
          // بيتخفي لما يكون فيه وجهة متحددة والمستخدم مش بيسحب دلوقتي، لأن في
          // الحالة دي الكاميرا بتكون متمركزة على المسار كله (مش على نقطة
          // الانطلاق)، فدبوس نص الشاشة هيبقى مش واقف على المكان الصح —
          // وبيتعوض عنه بماركر نقطة الانطلاق الثابت جغرافيًا اللي فوق.
          if (_destinationLocation == null)
            Center(
              child: FractionalTranslation(
                translation: const Offset(0, -0.5),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // الكارت العلوي: من أين + العنوان (شفافية بس، بدون حركة مكان)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isDraggingMap ? 0 : 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: TayarColors.background,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.chevron_left,
                              color: TayarColors.textGrey,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.fromLabel,
                                  style: const TextStyle(
                                    color: TayarColors.textGrey,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  _addressDisplay(context),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // أيقونة الماركر
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        color: TayarColors.primary,
                        size: 26,
                      ),
                    ),
                    // الخط الواصل
                    Container(width: 2, height: 14, color: Colors.white54),
                    // نقطة صغيرة حمرا: دي رأس الدبوس الثابت اللي بيأشر فعليًا على المكان
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ====== زرار القايمة الجانبية ======
          Positioned(
            top: 50,
            right: 16,
            child: Builder(
              builder: (context) => GestureDetector(
                onTap: () => Scaffold.of(context).openDrawer(),
                child: Container(
                  width: 50,
                  height: 50,
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
                  child: const Icon(Icons.menu, color: Colors.white),
                ),
              ),
            ),
          ),

          // ====== زرار تحديد الموقع (بيختفي لتحت مع الشريط السفلي وقت سحب الخريطة) ======
          Positioned(
            bottom: 280,
            left: 16,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              offset: _isDraggingMap ? const Offset(0, 2) : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isDraggingMap ? 0 : 1,
                child: IgnorePointer(
                  ignoring: _isDraggingMap,
                  child: GestureDetector(
                    onTap: _getCurrentLocation,
                    child: Container(
                      width: 50,
                      height: 50,
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
                      child: const Icon(
                        Icons.navigation_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ====== الـ Bottom Sheet (بيختفي بحركة انزلاق وقت سحب الخريطة) ======
          AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            offset: _isDraggingMap ? const Offset(0, 1) : Offset.zero,
            child: TayarBottomSheet(
              destinationAddress: _destinationAddress,
              onTapSearch: _openDestinationSearch,
              distanceKm: _routeDistanceKm,
              durationMin: _routeDurationMin,
              fare: _estimatedFare,
              paymentMethod: _paymentMethod,
              onTapPaymentMethod: _showPaymentMethodSheet,
              onCancelDestination: _clearDestination,
              onConfirmOrder: _openOrderConfirmation,
              onTapRideMe: _openDestinationSearch,
              onTapDeliverOrders: _openDeliveryOrder,
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================
// ====== Bottom Sheet - عايز تروح فين؟ + الخدمات ======
// ====================================================
class TayarBottomSheet extends StatelessWidget {
  final String? destinationAddress;
  final VoidCallback onTapSearch;
  final double? distanceKm;
  final int? durationMin;
  final double fare;
  final String paymentMethod;
  final VoidCallback onTapPaymentMethod;
  final VoidCallback onCancelDestination;
  final VoidCallback onConfirmOrder;
  final VoidCallback onTapRideMe;
  final VoidCallback onTapDeliverOrders;

  const TayarBottomSheet({
    super.key,
    required this.destinationAddress,
    required this.onTapSearch,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.paymentMethod,
    required this.onTapPaymentMethod,
    required this.onCancelDestination,
    required this.onConfirmOrder,
    required this.onTapRideMe,
    required this.onTapDeliverOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
            // المقبض العلوي
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade700,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // شريط البحث "عايز تروح فين؟"
            GestureDetector(
              onTap: onTapSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: TayarColors.cardDark,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      color: destinationAddress != null
                          ? TayarColors.primary
                          : TayarColors.textGrey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        destinationAddress ??
                            AppLocalizations.of(context)!.chooseDestinationHint,
                        style: TextStyle(
                          color: destinationAddress != null
                              ? Colors.white
                              : TayarColors.textGrey,
                          fontSize: 16,
                          fontWeight: destinationAddress != null
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // لو فيه وجهة متحددة، نعرض ملخص الرحلة + زرار الطلب
            // لو لسه مفيش وجهة، نعرض كارتين الخدمات الأساسيين
            if (destinationAddress != null && distanceKm != null)
              _TripSummaryCard(
                distanceKm: distanceKm!,
                durationMin: durationMin ?? 0,
                fare: fare,
                paymentMethod: paymentMethod,
                onTapPaymentMethod: onTapPaymentMethod,
                onCancel: onCancelDestination,
                onConfirm: onConfirmOrder,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ServiceCard(
                      title: AppLocalizations.of(context)!.serviceRideMe,
                      icon: Icons.two_wheeler,
                      onTap: onTapRideMe,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ServiceCard(
                      title: AppLocalizations.of(context)!.serviceDeliverOrders,
                      icon: Icons.inventory_2_outlined,
                      onTap: onTapDeliverOrders,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ====== كارت ملخص الرحلة (المسافة + الوقت + السعر + زرار الطلب) ======
class _TripSummaryCard extends StatelessWidget {
  final double distanceKm;
  final int durationMin;
  final double fare;
  final String paymentMethod;
  final VoidCallback onTapPaymentMethod;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _TripSummaryCard({
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.paymentMethod,
    required this.onTapPaymentMethod,
    required this.onCancel,
    required this.onConfirm,
  });

  // ====== أيقونة طريقة الدفع الحالية (بتقارن على القيمة الداخلية الثابتة، مش النص المترجم) ======
  IconData get _paymentIcon {
    switch (paymentMethod) {
      case 'محفظة إلكترونية':
        return Icons.account_balance_wallet_outlined;
      case 'إنستاباي':
        return Icons.bolt_outlined;
      default:
        return Icons.payments_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TayarColors.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TayarColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TripStat(
                icon: Icons.route,
                label: AppLocalizations.of(
                  context,
                )!.distanceKmLabel(distanceKm.toStringAsFixed(1)),
              ),
              _TripStat(
                icon: Icons.access_time,
                label: AppLocalizations.of(
                  context,
                )!.durationMinLabel(durationMin),
              ),
              _TripStat(
                icon: Icons.payments_outlined,
                label: AppLocalizations.of(
                  context,
                )!.currencyEGP(fare.toStringAsFixed(0)),
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ====== طريقة الدفع: بتفتح شاشة اختيار لما تتدوس ======
          GestureDetector(
            onTap: onTapPaymentMethod,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: TayarColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(_paymentIcon, color: TayarColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    AppLocalizations.of(context)!.paymentMethodLabel,
                    style: const TextStyle(
                      color: TayarColors.textGrey,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    paymentMethodDisplay(context, paymentMethod),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_left,
                    color: TayarColors.textGrey,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: TayarColors.textGrey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: const TextStyle(color: TayarColors.textGrey),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TayarColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.confirmButton,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;

  const _TripStat({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: highlight ? TayarColors.primary : Colors.white70,
          size: 22,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: highlight ? TayarColors.primary : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

// ====== كارت الخدمة الواحدة ======
class ServiceCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const ServiceCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: TayarColors.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TayarColors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Icon(icon, color: TayarColors.primary, size: 42),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================
// ====================== Drawer =======================
// ====================================================
class TayarDrawer extends StatelessWidget {
  const TayarDrawer({super.key});

  // ====== تأكيد تسجيل الخروج قبل تنفيذه فعليًا ======
  Future<void> _confirmLogout(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: TayarColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(loc.logout, style: const TextStyle(color: Colors.white)),
        content: Text(
          loc.confirmLogoutMessage,
          style: const TextStyle(color: TayarColors.textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              loc.cancel,
              style: const TextStyle(color: TayarColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              loc.logout,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // ====== نسجل خروج من Google لو المستخدم داخل بيه، وبعدين من Firebase ======
      final googleSignIn = GoogleSignIn();
      if (await googleSignIn.isSignedIn()) {
        await googleSignIn.signOut();
      }
      await FirebaseAuth.instance.signOut();
      // ====== نمسح آخر وضع محفوظ عشان أي حساب تاني يسجل دخول من نفس الجهاز ما يفتحش غلط ======
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('lastMode');
    } catch (e) {
      debugPrint('❌ خطأ أثناء تسجيل الخروج: $e');
    }

    if (!context.mounted) return;

    // ====== نمسح كل الشاشات السابقة ونرجع لشاشة تسجيل الدخول من الأول ======
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: TayarColors.background,
      child: SafeArea(
        child: Column(
          children: [
            // ====== بيانات اليوزر (بتفتح البروفايل عند الدوس) ======
            InkWell(
              onTap: () {
                Navigator.pop(context);
                // TODO: اربطها بشاشة بروفايل الراكب لما تتضاف
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 28,
                      backgroundColor: TayarColors.primary,
                      child: Icon(Icons.person, color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.defaultUserName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              ...List.generate(
                                5,
                                (i) => const Icon(
                                  Icons.star,
                                  color: TayarColors.primary,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                '4.75 (5)',
                                style: TextStyle(
                                  color: TayarColors.textGrey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white),
                  ],
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),

            // ====== قايمة العناصر ======
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.two_wheeler,
                    label: AppLocalizations.of(context)!.serviceRideMe,
                    selected: true,
                  ),
                  _DrawerItem(
                    icon: Icons.delivery_dining,
                    label: AppLocalizations.of(context)!.serviceDeliverOrders,
                  ),
                  _DrawerItem(
                    icon: Icons.history,
                    label: AppLocalizations.of(context)!.orderHistoryLabel,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrderHistoryScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.notifications_none,
                    label: AppLocalizations.of(context)!.navNotifications,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.shield_outlined,
                    label: AppLocalizations.of(context)!.navSecurity,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SecurityScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.settings_outlined,
                    label: AppLocalizations.of(context)!.navSettings,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.info_outline,
                    label: AppLocalizations.of(context)!.navHelp,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.support_agent,
                    label: AppLocalizations.of(context)!.navSupport,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SupportScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(color: Colors.white24, height: 24),
                  _DrawerItem(
                    icon: Icons.logout,
                    label: AppLocalizations.of(context)!.logout,
                    isDestructive: true,
                    onTap: () => _confirmLogout(context),
                  ),
                ],
              ),
            ),

            // ====== زرار وضع الطيار ======
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DriverRegistrationScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TayarColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.driverModeButton,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // ====== أيقونات السوشيال ميديا ======
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialIcon(
                    icon: Icons.facebook,
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.facebook),
                  ),
                  const SizedBox(width: 20),
                  _SocialIcon(
                    icon: Icons.camera_alt_outlined, // إنستجرام
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.instagram),
                  ),
                  const SizedBox(width: 20),
                  _SocialIcon(
                    icon: Icons.chat_bubble_outline, // واتساب
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.whatsapp),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDestructive;
  final VoidCallback? onTap;

  const _DrawerItem({
    required this.icon,
    required this.label,
    this.selected = false,
    this.isDestructive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color itemColor = isDestructive
        ? Colors.redAccent
        : (selected ? TayarColors.primary : Colors.white);

    return Container(
      color: selected
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive
              ? Colors.redAccent
              : (selected ? TayarColors.primary : Colors.white70),
        ),
        title: Text(
          label,
          style: TextStyle(
            color: itemColor,
            fontSize: 16,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap:
            onTap ??
            () {
              // TODO: تنقل حسب العنصر
              Navigator.pop(context);
            },
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _SocialIcon({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white54),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ====== حالة أنيميشن حركة طيار قريب واحد على الخريطة الرئيسية ======
class _NearbyDriverMarker {
  LatLng displayed;
  LatLng prev;
  LatLng target;

  _NearbyDriverMarker({
    required this.displayed,
    required this.prev,
    required this.target,
  });
}
