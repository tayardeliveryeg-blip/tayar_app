import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
import 'passenger_profile_screen.dart';
import 'security_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import 'support_screen.dart';

import 'theme_extensions.dart';
import 'pin_marker.dart';
import 'map_tile_layer.dart';
import 'main.dart' show navigatorKey;
import 'call_invitation_setup.dart';
import 'push_notification_service.dart';
import 'app_settings.dart';
export 'theme_extensions.dart'; // مصدر TayarColors / TayarTheme / TayarThemeColors الوحيد

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

// ====== روابط طيار الرسمية على السوشيال ميديا ======
class TayarSocialLinks {
  static const String facebook = 'https://www.facebook.com/tayardelivery/';
  static const String instagram = 'https://www.instagram.com/gotayar/';
  static const String whatsapp = 'https://wa.me/201142263460';
  static const String tiktok = 'https://www.tiktok.com/@go.tayar';
}

// ====== فتح رابط خارجي (سوشيال ميديا/واتساب) في تطبيق خارجي ======
Future<void> launchSocialUrl(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.failedToOpenAppError),
      ),
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

  // ====== بانر العرض الترويجي فوق الخريطة: بيقفل محليًا بس (مش متخزن)،
  // يرجع يظهر تاني لو المستخدم قفل وفتح التطبيق من جديد ======
  bool _promoDismissed = false;

  LatLng? _liveUserLocation; // موقعك الحقيقي الفعلي، بيتحدث لايف مع تحركك
  StreamSubscription<Position>? _liveLocationSub;

  // ====== الطيارين المتاحين القريبين، بيظهروا كإيموجي موتوسيكل متحرك ======
  final Map<String, _NearbyDriverMarker> _nearbyDrivers = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nearbyDriversSub;
  late final AnimationController _driversMoveController;

  late final AnimationController _routeAnimController;

  // ====== أنيميشن توسيع/تصغير الشريط السفلي: 0 = الوضع الطبيعي (Collapsed)،
  // 1 = وضع ملء الشاشة (Expanded) بعد السحب لفوق. بيتشارك بين TayarIdleBottomSheet
  // و TayarBottomSheet، وبيترجع لـ 0 تلقائيًا كل ما الوجهة تتحدد أو تتلغي ======
  late final AnimationController _sheetAnimController;
  double _sheetDragRange = 300; // بيتحسب فعليًا وقت بداية السحب (فرق الارتفاعين)

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _startLiveLocationTracking();
    // ====== تفعيل استقبال إشعارات الشات + دعوات المكالمات (لازم بعد تسجيل الدخول) ======
    PushNotificationService.instance.init(isDriver: false);
    setupCallInvitationService(navigatorKey: navigatorKey);

    // ====== أنيميشن توسيع الشريط السفلي (يبدأ دايمًا من الوضع الطبيعي) ======
    _sheetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: 0,
    );

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
    _sheetAnimController.dispose();
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
    final size = camera.nonRotatedSize;
    final pinOffset = Offset(size.width / 2, size.height / 2);
    return camera.offsetToCrs(pinOffset);
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
          locationSettings: LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 8),
          ),
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

  // ====== بداية سحب الشريط السفلي: بنحسب مدى السحب (الفرق بين الوضع
  // الطبيعي ووضع ملء الشاشة) عشان نحول حركة الإصبع بالبكسل لنسبة 0-1 ======
  void _onSheetDragStart(double collapsedHeight, double expandedHeight) {
    _sheetDragRange = (expandedHeight - collapsedHeight).abs();
    if (_sheetDragRange < 1) _sheetDragRange = 1;
  }

  void _onSheetDragUpdate(DragUpdateDetails details) {
    final delta = -details.delta.dy / _sheetDragRange;
    _sheetAnimController.value = (_sheetAnimController.value + delta).clamp(
      0.0,
      1.0,
    );
  }

  // ====== نهاية السحب: بنقرر نكمل لفوق (ملء الشاشة) أو نرجع تحت (الوضع
  // الطبيعي) حسب سرعة السحب، أو حسب أقرب نقطة لو السحب كان بطيء ======
  void _onSheetDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (velocity < -250) {
      _sheetAnimController.animateTo(1.0, curve: Curves.easeOutCubic);
    } else if (velocity > 250) {
      _sheetAnimController.animateTo(0.0, curve: Curves.easeOutCubic);
    } else if (_sheetAnimController.value > 0.5) {
      _sheetAnimController.animateTo(1.0, curve: Curves.easeOutCubic);
    } else {
      _sheetAnimController.animateTo(0.0, curve: Curves.easeOutCubic);
    }
  }

  // ====== حساب سعر الرحلة: 10 جنيه أساسي + 5 جنيه لكل كيلومتر ======
  double get _estimatedFare {
    if (_routeDistanceKm == null) return 0;
    return AppSettings.instance.estimateFare(_routeDistanceKm!);
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
      _sheetAnimController.animateTo(0, curve: Curves.easeOutCubic);
      // الزوم على المسار وبداية رسمه بالأنيميشن بيحصلوا مع بعض جوه _fetchRoute
      await _fetchRoute(_currentLocation, result.location);
    }
  }

  // ====== إعادة طلب رحلة سابقة: بناخد وجهتها القديمة ونحسب المسار
  // منها زي لو المستخدم اختارها دلوقتي من شاشة البحث ======
  Future<void> _reorderLastTrip(LatLng location, String address) async {
    setState(() {
      _destinationLocation = location;
      _destinationAddress = address;
    });
    _sheetAnimController.animateTo(0, curve: Curves.easeOutCubic);
    await _fetchRoute(_currentLocation, location);
  }

  // ====== الأماكن المحفوظة (البيت/الشغل) لسه مش متفعّلة، فبنوري المستخدم
  // إنها هتضاف قريبًا بدل ما الزرار يبقى ميت من غير أي رد فعل ======
  void _showSavedPlacesComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.savedPlacesComingSoonMessage,
        ),
      ),
    );
  }

  // ====== حفظ عنوان "البيت" أو "الشغل": بيفتح نفس شاشة اختيار الوجهة
  // الموجودة أصلاً، وبعد ما المستخدم يختار مكان بيحفظه في
  // users/{uid}.savedAddresses.{key} على فيرستور. بنستخدم dot-notation في
  // اسم الحقل (savedAddresses.$key) مع merge:true عشان نضمن إننا بنعدّل
  // المفتاح ده بس من غير ما نمسح باقي بيانات اليوزر أو المفتاح التاني
  // (home/work) لو موجود بالفعل ======
  Future<void> _pickAndSaveAddress(String key, String screenTitle) async {
    final result = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDestinationScreen(
          initialLocation: _currentLocation,
          title: screenTitle,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'savedAddresses.$key': {
          'address': result.title,
          'lat': result.location.latitude,
          'lng': result.location.longitude,
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.savedAddressSavedConfirmation,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ خطأ في حفظ العنوان المحفوظ ($key): $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.savedAddressSaveError),
        ),
      );
    }
  }

  void _clearDestination() {
    _routeAnimController.stop();
    _sheetAnimController.animateTo(0, curve: Curves.easeOutCubic);
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
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.handleColor,
                  borderRadius: BorderRadius.circular(AppRadius.handle),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    loc.choosePaymentMethodTitle,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
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
                        : context.textGreyColor,
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      color: context.textColor,
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
    // ارتفاع شريط الحالة (الساعة/البطارية) أو الـ notch، بيتغير حسب الجهاز.
    // بنضيفه لكل الـ Positioned اللي في أعلى الشاشة عشان محدش يتداخل معاه.
    final double topSafeArea = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.bgColor,
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
                const TayarTileLayer(),
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
                        child: const PinMarker(type: PinType.destination),
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
                        child: const PinMarker(type: PinType.pickup),
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
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
                        ),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
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
                            Icon(
                              Icons.chevron_left,
                              color: context.textGreyColor,
                              size: 20,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.fromLabel,
                                  style: TextStyle(
                                    color: context.textGreyColor,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _addressDisplay(context),
                                  style: TextStyle(
                                    color: context.textColor,
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
                    const SizedBox(height: AppSpacing.xs),
                    // أيقونة الماركر
                    const PinMarker(type: PinType.pickup),
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

          // ====== زرار جرس الإشعارات (أعلى الشاشة، شمال) ======
          Positioned(
            top: 8 + topSafeArea,
            left: 16,
            child: AnimatedBuilder(
              animation: _sheetAnimController,
              builder: (context, child) => Opacity(
                opacity: 1 - _sheetAnimController.value,
                child: IgnorePointer(
                  ignoring: _sheetAnimController.value > 0.5,
                  child: child,
                ),
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _isDraggingMap ? 0 : 1,
                child: IgnorePointer(
                  ignoring: _isDraggingMap,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    ),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.dividerColor2),
                      ),
                      child: Icon(
                        Icons.notifications_none,
                        color: context.textColor,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ====== بانر "أول توصيل مجانًا" (للعميل الجديد بس، وبيختفي
          // نهائيًا بمجرد ما يكمل أول رحلة، مش مجرد إغلاق مؤقت) ======
          if (!_promoDismissed)
            Positioned(
              top: 66 + topSafeArea,
              right: 16,
              left: 16,
              child: AnimatedBuilder(
                animation: _sheetAnimController,
                builder: (context, child) => Opacity(
                  opacity: 1 - _sheetAnimController.value,
                  child: IgnorePointer(
                    ignoring: _sheetAnimController.value > 0.5,
                    child: child,
                  ),
                ),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isDraggingMap ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: _isDraggingMap,
                    child: _NewCustomerPromoBanner(
                      onDismiss: () =>
                          setState(() => _promoDismissed = true),
                    ),
                  ),
                ),
              ),
            ),

          // ====== زرار القايمة الجانبية (بيختفي لفوق وقت سحب الخريطة) ======
          Positioned(
            top: 8 + topSafeArea,
            right: 16,
            child: AnimatedBuilder(
              animation: _sheetAnimController,
              builder: (context, child) => Opacity(
                opacity: 1 - _sheetAnimController.value,
                child: IgnorePointer(
                  ignoring: _sheetAnimController.value > 0.5,
                  child: child,
                ),
              ),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                offset: _isDraggingMap ? const Offset(0, -2) : Offset.zero,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isDraggingMap ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: _isDraggingMap,
                    child: Builder(
                      builder: (context) => GestureDetector(
                        onTap: () => Scaffold.of(context).openDrawer(),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.dividerColor2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Icon(Icons.menu, color: context.textColor),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ====== زرار تحديد الموقع: بيفضل مثبت فوق الشريط السفلي على
          // الشمال بالظبط (مش بأرقام ثابتة)، بنحسب ارتفاعه بنفس معادلة
          // ارتفاع الشريط في الأسفل (collapsedHeight/expandedHeight)
          // عشان يفضل ملتصق بحافته العلوية دايمًا مهما اتحرك، وبيختفي
          // تدريجيًا وقت ما نسحب الشريط لفوق (وبرضو وقت سحب الخريطة) ======
          AnimatedBuilder(
            animation: _sheetAnimController,
            builder: (context, child) {
              final screenHeight = MediaQuery.of(context).size.height;
              final expandedHeight =
                  screenHeight - topSafeArea - AppSpacing.xxl;
              final collapsedHeight = screenHeight *
                  (_destinationAddress == null ? 0.5 : 0.38);
              final t = _sheetAnimController.value;
              final sheetHeight =
                  collapsedHeight + (expandedHeight - collapsedHeight) * t;
              return Positioned(
                left: 16,
                bottom: sheetHeight + 16,
                child: Opacity(
                  opacity: 1 - t,
                  child: IgnorePointer(
                    ignoring: t > 0.5,
                    child: child,
                  ),
                ),
              );
            },
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
                        color: context.cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.dividerColor2,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.my_location,
                        color: TayarColors.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ====== الـ Bottom Sheet (بيختفي بحركة انزلاق وقت سحب الخريطة،
          // وقابل للسحب لفوق لوضع ملء الشاشة وللسحب لتحت للرجوع تاني) ======
          // قبل ما تتحدد وجهة: كارت البحث + الأماكن المحفوظة + الخدمات
          // السريعة + آخر رحلة. بعد ما تتحدد وجهة: كارت ملخص الرحلة.
          // ====== لازم Positioned(bottom: 0) عشان الشريط يفضل ملتصق
          // بأسفل الشاشة، من غير كده الـ Stack بيحطه حسب alignment
          // الافتراضي (فوق يسار) مش أسفل الشاشة ======
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              offset: _isDraggingMap ? const Offset(0, 1) : Offset.zero,
              child: AnimatedBuilder(
                animation: _sheetAnimController,
                builder: (context, _) {
                  final screenHeight = MediaQuery.of(context).size.height;
                  final expandedHeight =
                      screenHeight - topSafeArea - AppSpacing.xxl;
                  // ====== الوضع الطبيعي: كارت ملخص الرحلة أقصر من كارت
                  // البحث/الأماكن المحفوظة، فبنديله نسبة أصغر من الشاشة ======
                  final collapsedHeight = screenHeight *
                      (_destinationAddress == null ? 0.5 : 0.38);
                  final t = _sheetAnimController.value;
                  final currentHeight = collapsedHeight +
                      (expandedHeight - collapsedHeight) * t;

                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: currentHeight),
                    child: _destinationAddress == null
                        ? TayarIdleBottomSheet(
                            onTapSearch: _openDestinationSearch,
                            onTapSavedPlace: _showSavedPlacesComingSoon,
                            onSaveAddress: _pickAndSaveAddress,
                            onReorderTrip: _reorderLastTrip,
                            onTapRideService: _openDestinationSearch,
                            onTapDeliveryService: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const CreateDeliveryOrderScreen(),
                              ),
                            ),
                            onDragStart: () => _onSheetDragStart(
                              collapsedHeight,
                              expandedHeight,
                            ),
                            onDragUpdate: _onSheetDragUpdate,
                            onDragEnd: _onSheetDragEnd,
                          )
                        : TayarBottomSheet(
                            destinationAddress: _destinationAddress,
                            distanceKm: _routeDistanceKm,
                            durationMin: _routeDurationMin,
                            fare: _estimatedFare,
                            paymentMethod: _paymentMethod,
                            onTapPaymentMethod: _showPaymentMethodSheet,
                            onCancelDestination: _clearDestination,
                            onConfirmOrder: _openOrderConfirmation,
                            onDragStart: () => _onSheetDragStart(
                              collapsedHeight,
                              expandedHeight,
                            ),
                            onDragUpdate: _onSheetDragUpdate,
                            onDragEnd: _onSheetDragEnd,
                          ),
                  );
                },
              ),
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
  final double? distanceKm;
  final int? durationMin;
  final double fare;
  final String paymentMethod;
  final VoidCallback onTapPaymentMethod;
  final VoidCallback onCancelDestination;
  final VoidCallback onConfirmOrder;
  // ====== callbacks السحب: بتخلي المقبض العلوي يقدر يوسّع الشريط لملء
  // الشاشة أو يرجعه للوضع الطبيعي (شوف _onSheetDrag* في الشاشة الأب) ======
  final void Function()? onDragStart;
  final void Function(DragUpdateDetails)? onDragUpdate;
  final void Function(DragEndDetails)? onDragEnd;

  const TayarBottomSheet({
    super.key,
    required this.destinationAddress,
    required this.distanceKm,
    required this.durationMin,
    required this.fare,
    required this.paymentMethod,
    required this.onTapPaymentMethod,
    required this.onCancelDestination,
    required this.onConfirmOrder,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    // ====== لو لسه مفيش وجهة متحددة، مفيش حاجة نعرضها تحت ======
    // (البحث بقى فوق جنب زرار القايمة، وخدمات "وصلني/وصل طلباتي" بقت في القايمة الجانبية بس)
    if (destinationAddress == null || distanceKm == null) {
      return const SizedBox.shrink();
    }

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ====== المقبض العلوي: منطقة السحب اللي بتوسّع/تصغّر الشريط ======
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: onDragStart == null
                  ? null
                  : (_) => onDragStart!(),
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragEnd: onDragEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.md,
                ),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.handleColor,
                      borderRadius: BorderRadius.circular(AppRadius.handle),
                    ),
                  ),
                ),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ====== الوجهة المختارة: أول مكان بيتعرض فيه العنوان
                    // دلوقتي بعد ما شريط البحث العلوي اتشال ======
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: TayarColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              destinationAddress!,
                              style: TextStyle(
                                color: context.textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ملخص الرحلة + زرار الطلب
                    _TripSummaryCard(
                      distanceKm: distanceKm!,
                      durationMin: durationMin ?? 0,
                      fare: fare,
                      paymentMethod: paymentMethod,
                      onTapPaymentMethod: onTapPaymentMethod,
                      onCancel: onCancelDestination,
                      onConfirm: onConfirmOrder,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================
// ====== كارت الشاشة الرئيسية الافتراضي (قبل اختيار وجهة): بحث +
// أماكن محفوظة + آخر رحلة ======
// ====================================================
class TayarIdleBottomSheet extends StatelessWidget {
  final VoidCallback onTapSearch;
  final VoidCallback onTapSavedPlace;
  final void Function(String key, String screenTitle) onSaveAddress;
  final void Function(LatLng location, String address) onReorderTrip;
  final VoidCallback onTapRideService;
  final VoidCallback onTapDeliveryService;
  // ====== callbacks السحب: بتخلي المقبض العلوي يقدر يوسّع الشريط لملء
  // الشاشة أو يرجعه للوضع الطبيعي (شوف _onSheetDrag* في الشاشة الأب) ======
  final void Function()? onDragStart;
  final void Function(DragUpdateDetails)? onDragUpdate;
  final void Function(DragEndDetails)? onDragEnd;

  const TayarIdleBottomSheet({
    super.key,
    required this.onTapSearch,
    required this.onTapSavedPlace,
    required this.onSaveAddress,
    required this.onReorderTrip,
    required this.onTapRideService,
    required this.onTapDeliveryService,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ====== المقبض العلوي: منطقة السحب اللي بتوسّع/تصغّر الشريط ======
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: onDragStart == null
                  ? null
                  : (_) => onDragStart!(),
              onVerticalDragUpdate: onDragUpdate,
              onVerticalDragEnd: onDragEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.handleColor,
                      borderRadius: BorderRadius.circular(AppRadius.handle),
                    ),
                  ),
                ),
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.xxl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ====== شريط البحث: بيفتح شاشة اختيار الوجهة الموجودة أصلاً ======
                    GestureDetector(
                      onTap: onTapSearch,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              color: context.textGreyColor,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              loc.homeSearchHint,
                              style: TextStyle(
                                color: context.textGreyColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ====== أماكن محفوظة: البيت / الشغل / إضافة، بنفس
                    // المقاس بالظبط (كل واحدة Expanded) ======
                    Text(
                      loc.savedPlacesLabel,
                      style: TextStyle(
                        color: context.textGreyColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _SavedPlacesRow(
                      onUseAddress: onReorderTrip,
                      onSaveAddress: onSaveAddress,
                      onAddTap: onTapSavedPlace,
                      addLabel: loc.savedPlaceAdd,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ====== الخدمات السريعة: تحت الأماكن المحفوظة مباشرة ======
                    Row(
                      children: [
                        Expanded(
                          child: _QuickServiceButton(
                            icon: Icons.two_wheeler,
                            label: loc.serviceRideMe,
                            onTap: onTapRideService,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _QuickServiceButton(
                            icon: Icons.delivery_dining,
                            label: loc.serviceDeliverOrders,
                            onTap: onTapDeliveryService,
                          ),
                        ),
                      ],
                    ),

                    // ====== آخر رحلة: بتظهر بس لو فيه رحلة سابقة فعلًا في Firestore ======
                    _LastTripSection(onReorderTrip: onReorderTrip),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== صف "البيت" و"الشغل": بيسمعوا على users/{uid}.savedAddresses على
// فيرستور لايف. لو المكان لسه مش محفوظ، دوسة عليه بتفتح شاشة اختيار
// العنوان وتحفظه. لو محفوظ فعلًا، دوسة عادية بتستخدمه كوجهة على طول،
// وضغطة مطوّلة (long press) بتفتح شاشة الاختيار تاني عشان يتغيّر ======
class _SavedPlacesRow extends StatelessWidget {
  final void Function(LatLng location, String address) onUseAddress;
  final void Function(String key, String screenTitle) onSaveAddress;
  final VoidCallback onAddTap;
  final String addLabel;

  const _SavedPlacesRow({
    required this.onUseAddress,
    required this.onSaveAddress,
    required this.onAddTap,
    required this.addLabel,
  });

  void _handleTap(
    String key,
    Map<String, dynamic>? savedData,
    String screenTitle,
  ) {
    final lat = (savedData?['lat'] as num?)?.toDouble();
    final lng = (savedData?['lng'] as num?)?.toDouble();
    final address = savedData?['address'] as String?;

    if (lat == null || lng == null || address == null) {
      // مفيش عنوان محفوظ لسه: افتح شاشة الاختيار واحفظه
      onSaveAddress(key, screenTitle);
    } else {
      // العنوان محفوظ: استخدمه كوجهة على طول
      onUseAddress(LatLng(lat, lng), address);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Row(
        children: [
          Expanded(
            child: _SavedPlaceChip(
              icon: Icons.home_outlined,
              label: loc.savedPlaceHome,
              onTap: () => onSaveAddress('home', loc.selectHomeAddressTitle),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SavedPlaceChip(
              icon: Icons.work_outline,
              label: loc.savedPlaceWork,
              onTap: () => onSaveAddress('work', loc.selectWorkAddressTitle),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _SavedPlaceChip(
              icon: Icons.add,
              label: addLabel,
              onTap: onAddTap,
            ),
          ),
        ],
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final savedAddresses =
            snapshot.data?.data()?['savedAddresses'] as Map<String, dynamic>?;
        final home = savedAddresses?['home'] as Map<String, dynamic>?;
        final work = savedAddresses?['work'] as Map<String, dynamic>?;

        return Row(
          children: [
            Expanded(
              child: _SavedPlaceChip(
                icon: Icons.home_outlined,
                label: loc.savedPlaceHome,
                onTap: () => _handleTap('home', home, loc.savedPlaceHome),
                onLongPress: () =>
                    onSaveAddress('home', loc.selectHomeAddressTitle),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SavedPlaceChip(
                icon: Icons.work_outline,
                label: loc.savedPlaceWork,
                onTap: () => _handleTap('work', work, loc.savedPlaceWork),
                onLongPress: () =>
                    onSaveAddress('work', loc.selectWorkAddressTitle),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SavedPlaceChip(
                icon: Icons.add,
                label: addLabel,
                onTap: onAddTap,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ====== شريحة مكان محفوظ (البيت / الشغل / إضافة) ======
class _SavedPlaceChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _SavedPlaceChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TayarColors.primary, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== قسم "آخر رحلة": بيجيب آخر طلب رحلة مكتمل للراكب الحالي من
// collection('orders') على فيرستور، وبيخفي نفسه تمامًا لو مفيش رحلات سابقة ======
class _LastTripSection extends StatelessWidget {
  final void Function(LatLng location, String address) onReorderTrip;

  const _LastTripSection({required this.onReorderTrip});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      // بنجيب كل رحلات الراكب المكتملة ونرتبها ونفلترها محليًا، عشان نتجنب
      // الحاجة لعمل composite index في Firestore (نفس أسلوب order_history_screen).
      future: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: uid)
          .limit(30)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final docs =
            snapshot.data!.docs.where((doc) {
              final data = doc.data();
              return data['serviceType'] == 'passenger' &&
                  data['status'] == 'completed';
            }).toList()..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              if (aTime == null || bTime == null) return 0;
              return bTime.compareTo(aTime);
            });

        if (docs.isEmpty) return const SizedBox.shrink();

        final lastTrip = docs.first.data();
        final destinationAddress = lastTrip['destinationAddress'] as String?;
        final destinationGeoPoint =
            lastTrip['destinationLocation'] as GeoPoint?;
        final pickupAddress = lastTrip['pickupAddress'] as String?;
        if (destinationAddress == null || destinationGeoPoint == null) {
          return const SizedBox.shrink();
        }

        final loc = AppLocalizations.of(context)!;
        final routeLabel = pickupAddress != null
            ? '$pickupAddress ← $destinationAddress'
            : destinationAddress;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  loc.lastTripLabel,
                  style: TextStyle(
                    color: context.textGreyColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () => onReorderTrip(
                    LatLng(
                      destinationGeoPoint.latitude,
                      destinationGeoPoint.longitude,
                    ),
                    destinationAddress,
                  ),
                  child: Text(
                    loc.reorderTripLabel,
                    style: const TextStyle(
                      color: TayarColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => onReorderTrip(
                LatLng(
                  destinationGeoPoint.latitude,
                  destinationGeoPoint.longitude,
                ),
                destinationAddress,
              ),
              child: Row(
                children: [
                  Icon(Icons.history, color: context.textGreyColor, size: 16),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      routeLabel,
                      style: TextStyle(color: context.textColor, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ====== بانر "احصل على أول توصيل مجانًا": بيتشيك على Firestore هل الراكب
// عنده أي رحلة مكتملة قبل كده ولا لأ. لو عنده رحلة مكتملة واحدة على الأقل
// (يعني مش عميل جديد) بيختفي البانر نهائيًا من غير ما يحتاج زرار إغلاق ======
class _NewCustomerPromoBanner extends StatelessWidget {
  final VoidCallback onDismiss;

  const _NewCustomerPromoBanner({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('customerId', isEqualTo: uid)
          .where('serviceType', isEqualTo: 'passenger')
          .where('status', isEqualTo: 'completed')
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        // لسه البيانات بتتحمل أو مفيش يوزر: مانوريش حاجة لحد ما نتأكد
        if (!snapshot.hasData) return const SizedBox.shrink();
        // عنده رحلة مكتملة واحدة على الأقل: مش عميل جديد، مايظهرش البانر
        if (snapshot.data!.docs.isNotEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: TayarColors.primary,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_offer_outlined,
                color: Colors.white,
                size: 15,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.homePromoBannerText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  size: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ====== زرار خدمة سريعة (وصلني / وصل طلباتي) — أيقونة ونص بس، جوه
// الشريط السفلي تحت الأماكن المحفوظة ======
class _QuickServiceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickServiceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: context.dividerColor2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TayarColors.primary, size: 24),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: context.textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
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
          const SizedBox(height: AppSpacing.md),

          // ====== طريقة الدفع: بتفتح شاشة اختيار لما تتدوس ======
          GestureDetector(
            onTap: onTapPaymentMethod,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(_paymentIcon, color: TayarColors.primary, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    AppLocalizations.of(context)!.paymentMethodLabel,
                    style: TextStyle(
                      color: context.textGreyColor,
                      fontSize: 14,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    paymentMethodDisplay(context, paymentMethod),
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    Icons.keyboard_arrow_left,
                    color: context.textGreyColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    side: BorderSide(color: context.textGreyColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: TextStyle(color: context.textGreyColor),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TayarColors.primary,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.lg,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.confirmButton,
                    style: TextStyle(
                      color: context.onPrimaryColor,
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
          color: highlight ? TayarColors.primary : context.textGreyColor,
          size: 22,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: TextStyle(
            color: highlight ? TayarColors.primary : context.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
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
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text(loc.logout, style: TextStyle(color: context.textColor)),
        content: Text(
          loc.confirmLogoutMessage,
          style: TextStyle(color: context.textGreyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              loc.cancel,
              style: TextStyle(color: context.textGreyColor),
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
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
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
      backgroundColor: context.bgColor,
      child: SafeArea(
        child: Column(
          children: [
            // ====== بيانات اليوزر (بتفتح البروفايل عند الدوس) ======
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PassengerProfileScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseAuth.instance.currentUser == null
                      ? null
                      : FirebaseFirestore.instance
                            .collection('users')
                            .doc(FirebaseAuth.instance.currentUser!.uid)
                            .snapshots(),
                  builder: (context, snapshot) {
                    final personalInfo =
                        snapshot.data?.data()?['personalInfo']
                            as Map<String, dynamic>?;

                    final photoBase64 = personalInfo?['photoBase64'] as String?;
                    ImageProvider? photo;
                    if (photoBase64 != null && photoBase64.isNotEmpty) {
                      try {
                        photo = MemoryImage(base64Decode(photoBase64));
                      } catch (_) {
                        photo = null;
                      }
                    }

                    // ====== اسم المستخدم الحقيقي: من بيانات Firestore أولًا
                    // (firstName + lastName اللي المستخدم كتبهم في البروفايل)،
                    // وإلا اسم حساب Google المسجل بيه، وإلا اسم افتراضي
                    // كـ fallback أخير لو معندناش أي مصدر ======
                    final firstName = (personalInfo?['firstName'] as String?)
                        ?.trim();
                    final lastName = (personalInfo?['lastName'] as String?)
                        ?.trim();
                    final firestoreName = [
                      firstName,
                      lastName,
                    ].where((s) => s != null && s.isNotEmpty).join(' ');
                    final googleName = FirebaseAuth
                        .instance
                        .currentUser
                        ?.displayName
                        ?.trim();
                    final displayName = firestoreName.isNotEmpty
                        ? firestoreName
                        : (googleName != null && googleName.isNotEmpty)
                        ? googleName
                        : AppLocalizations.of(context)!.defaultUserName;

                    return Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: TayarColors.primary,
                          backgroundImage: photo,
                          child: photo == null
                              ? Icon(
                                  Icons.person,
                                  color: context.onPrimaryColor,
                                  size: 30,
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.chevron_right, color: context.textColor),
                      ],
                    );
                  },
                ),
              ),
            ),
            Divider(color: context.dividerColor2, height: 1),

            // ====== قايمة العناصر ======
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _DrawerItem(
                    icon: Icons.two_wheeler,
                    label: AppLocalizations.of(context)!.serviceRideMe,
                    selected: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _DrawerItem(
                    icon: Icons.delivery_dining,
                    label: AppLocalizations.of(context)!.serviceDeliverOrders,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateDeliveryOrderScreen(),
                        ),
                      );
                    },
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
                  Divider(color: context.dividerColor2, height: 24),
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
              padding: const EdgeInsets.all(AppSpacing.lg),
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
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.driverModeButton,
                    style: TextStyle(
                      color: context.onPrimaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            // ====== أيقونات السوشيال ميديا ======
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SocialIcon(
                    icon: Icon(
                      Icons.facebook,
                      color: context.textColor,
                      size: 20,
                    ),
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.facebook),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _SocialIcon(
                    icon: Icon(
                      Icons.camera_alt_outlined,
                      color: context.textColor,
                      size: 20,
                    ), // إنستجرام
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.instagram),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _SocialIcon(
                    icon: Icon(
                      Icons.chat_bubble_outline,
                      color: context.textColor,
                      size: 20,
                    ), // واتساب
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.whatsapp),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  _SocialIcon(
                    icon: FaIcon(
                      FontAwesomeIcons.tiktok,
                      color: context.textColor,
                      size: 20,
                    ),
                    onTap: () =>
                        launchSocialUrl(context, TayarSocialLinks.tiktok),
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
        : (selected ? TayarColors.primary : context.textColor);

    return Container(
      color: selected
          ? TayarColors.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive
              ? Colors.redAccent
              : (selected ? TayarColors.primary : context.textGreyColor),
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
  final Widget icon;
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
          border: Border.all(color: context.dividerColor2),
          shape: BoxShape.circle,
        ),
        child: Center(child: icon),
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
