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
import 'package:tayay_app/screens/passenger/order_confirmation/order_confirmation_screen_screen.dart';
import 'package:tayay_app/screens/passenger/create_delivery_order_screen.dart';
import 'package:tayay_app/screens/shared/notifications_screen.dart';

import 'package:tayay_app/screens/passenger/passenger_bottom_sheets.dart';
import 'package:tayay_app/widgets/tayar_drawer.dart';

import 'package:tayay_app/theme/theme_extensions.dart';
import 'package:tayay_app/widgets/pin_marker.dart';
import 'package:tayay_app/widgets/map_tile_layer.dart';
import 'package:tayay_app/widgets/no_internet_toast.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';
import 'package:tayay_app/utils/connectivity_check.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/app_primary_button.dart';
import 'package:tayay_app/main.dart' show navigatorKey;
import 'package:tayay_app/services/call_invitation_setup.dart';
import 'package:tayay_app/services/push_notification_service.dart';
import 'package:tayay_app/services/wallet_service.dart';
import 'package:tayay_app/services/vendor_service.dart';
import 'package:tayay_app/screens/passenger/become_vendor_screen.dart'
    show vendorBusinessTypeDisplay;
import 'package:tayay_app/theme/app_settings.dart';
export 'package:tayay_app/theme/theme_extensions.dart'; // مصدر TayarColors / TayarTheme / TayarThemeColors الوحيد

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
  static const String instagram = 'https://www.instagram.com/go.tayar/';
  static const String whatsapp = 'https://wa.me/201064286901';
  static const String tiktok = 'https://www.tiktok.com/@go.tayar';
}

// ====== فتح رابط خارجي (سوشيال ميديا/واتساب) في تطبيق خارجي ======
Future<void> launchSocialUrl(BuildContext context, String url) async {
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
  if (!ok && context.mounted) {
    TayarToast.show(
      context,
      AppLocalizations.of(context)!.failedToOpenAppError,
      type: ToastType.error,
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
  double?
  _liveUserHeading; // اتجاه حركتك الفعلي (0 = شمال)، لسهم النقطة الزرقاء
  double? _liveUserAccuracy; // نطاق دقة الـ GPS بالمتر، لحجم هالة الدقة
  StreamSubscription<Position>? _liveLocationSub;

  // ====== الطيارين المتاحين القريبين، بيظهروا كإيموجي موتوسيكل متحرك ======
  final Map<String, _NearbyDriverMarker> _nearbyDrivers = {};

  // ====== عدد الطيارين المتاحين في نطاق قريب (كيلومترات) من موقع الراكب
  // اللحظي. null لو لسه مفيش موقع لحظي متاح (قبل ما GPS يجيب أول إحداثية) ======
  static const double _nearbyDriversRadiusKm = 5.0;
  int? get _nearbyDriversCount {
    final userLocation = _liveUserLocation;
    if (userLocation == null) return null;
    const distanceCalc = Distance();
    return _nearbyDrivers.values.where((driver) {
      return distanceCalc.as(
            LengthUnit.Kilometer,
            userLocation,
            driver.target,
          ) <=
          _nearbyDriversRadiusKm;
    }).length;
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nearbyDriversSub;
  late final AnimationController _driversMoveController;

  late final AnimationController _routeAnimController;

  // ====== أنيميشن توسيع/تصغير الشريط السفلي: 0 = الوضع الطبيعي (Collapsed)،
  // 1 = وضع ملء الشاشة (Expanded) بعد السحب لفوق. بيتشارك بين TayarIdleBottomSheet
  // و TayarBottomSheet، وبيترجع لـ 0 تلقائيًا كل ما الوجهة تتحدد أو تتلغي ======
  late final AnimationController _sheetAnimController;
  double _sheetDragRange =
      300; // بيتحسب فعليًا وقت بداية السحب (فرق الارتفاعين)

  // ====== مفتاح لقياس الارتفاع الحقيقي للشريط السفلي بعد ما يتبني فعليًا
  // (المحتوى بيحدد ارتفاعه لوحده جوه ConstrainedBox، فمش دايمًا بياخد كل
  // الارتفاع النظري اللي بنحسبه في _sheetHeights)، عشان زرار تحديد الموقع
  // يقدر يتثبت فوقه بالظبط من غير أي فراغ زيادة بينه وبين الشريط ======
  final GlobalKey _sheetContainerKey = GlobalKey();
  double _measuredSheetHeight = 0;

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
            setState(() {
              _liveUserLocation = LatLng(position.latitude, position.longitude);
              _liveUserAccuracy = position.accuracy;
              // ====== الاتجاه بييجي من الـ GPS بس وقت الحركة الفعلية،
              // فلو مفيش قراءة موثوقة (heading سالب) بنسيب آخر اتجاه معروف
              // زي ما هو بدل ما نمسحه ======
              if (position.heading >= 0) {
                _liveUserHeading = position.heading;
              }
            });
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

  // ====== بيظهر لما المستخدم يدوس على دبوس شريك تجاري على الخريطة - بيوريه
  // اسم المحل ونوعه، ومعاه زرار يفتحله شاشة طلب توصيل بنقطة استلام متملية
  // أوتوماتيك بموقع المحل ======
  void _showVendorPartnerSheet(VendorPartner partner) {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: TayarColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.storefront, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner.storeName,
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          vendorBusinessTypeDisplay(loc, partner.businessType),
                          style: TextStyle(
                            color: context.textGreyColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: AppPrimaryButton(
                  onPressed: () async {
                    if (!await _requireInternet()) return;
                    if (!sheetContext.mounted) return;
                    if (!mounted) return;
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CreateDeliveryOrderScreen(
                          initialPickupLocation: partner.location,
                          initialPickupAddress: partner.storeName,
                        ),
                      ),
                    );
                  },
                  variant: AppButtonVariant.primary,
                  size: AppButtonSize.medium,
                  child: Text(
                    loc.orderFromVendorButton,
                    style: TextStyle(
                      color: context.onPrimaryColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
  // ====== بيتنفّذ بعد كل فريم: بيقرأ الارتفاع الحقيقي اللي اتحسب فعليًا
  // للشريط السفلي (مش الرقم النظري)، ولو اتغيّر عن اللي متسجل، بنعمل
  // setState عشان زرار تحديد الموقع يتابعه. الشرط بالفرق (0.5) عشان منعملش
  // setState لانهائي بسبب فروق تقريب بسيطة جدًا ======
  void _measureSheetHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox =
          _sheetContainerKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;
      final newHeight = renderBox.size.height;
      if ((newHeight - _measuredSheetHeight).abs() > 0.5) {
        setState(() => _measuredSheetHeight = newHeight);
      }
    });
  }

  void _onSheetDragStart(double collapsedHeight, double expandedHeight) {
    _sheetDragRange = (expandedHeight - collapsedHeight).abs();
    if (_sheetDragRange < 1) _sheetDragRange = 1;
  }

  // ====== حساب ارتفاعات الشريط السفلي (طبيعي/ملء شاشة/حالي)، مستخدَمة في
  // أكتر من مكان (الشريط نفسه + زرار تحديد الموقع اللي بيتتبع حافته
  // العليا) عشان نتجنب تكرار نفس المعادلة أكتر من مرة ======
  ({double collapsed, double expanded, double current}) _sheetHeights(
    BuildContext context,
    double topSafeArea,
  ) {
    final screenHeight = MediaQuery.of(context).size.height;
    final expandedHeight = screenHeight - topSafeArea - AppSpacing.xxl;
    final collapsedHeight =
        screenHeight * (_destinationAddress == null ? 0.5 : 0.38);
    final t = _sheetAnimController.value;
    final currentHeight =
        collapsedHeight + (expandedHeight - collapsedHeight) * t;
    return (
      collapsed: collapsedHeight,
      expanded: expandedHeight,
      current: currentHeight,
    );
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

  // ====== فحص الاتصال قبل أي تنقل لشاشة تانية محتاجة إنترنت. لو مفيش
  // اتصال، بيوري رسالة مركزية مؤقتة (showNoInternetToast) ومبيسمحش
  // بالتنقل خالص - أحسن من إن الشاشة تفتح وتفشل في التحميل جواها ======
  Future<bool> _requireInternet() async {
    if (await hasInternetConnection()) return true;
    if (mounted) showNoInternetToast(context);
    return false;
  }

  Future<void> _openDestinationSearch() async {
    if (!await _requireInternet()) return;
    if (!mounted) return;
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

  // ====== زرار "+ إضافة" في صف الأماكن المحفوظة: بيفتح شاشة اختيار
  // الموقع الموجودة أصلاً، وبعدين بيطلب من المستخدم اسم للمكان ده (زي
  // "الجيم" أو "بيت ماما")، وأخيرًا بيحفظه في users/{uid}.savedAddresses
  // بمفتاح فريد (custom_<timestamp>) عشان يفضل متاح جنب البيت والشغل ======
  Future<void> _addCustomSavedPlace() async {
    final loc = AppLocalizations.of(context)!;
    if (!await _requireInternet()) return;
    if (!mounted) return;

    final result = await Navigator.push<PlaceResult>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectDestinationScreen(
          initialLocation: _currentLocation,
          title: loc.selectCustomPlaceTitle,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final name = await _promptForSavedPlaceName();
    if (name == null || !mounted) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final key = 'custom_${DateTime.now().millisecondsSinceEpoch}';

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'savedAddresses': {
          key: {
            'address': result.title,
            'lat': result.location.latitude,
            'lng': result.location.longitude,
            'label': name,
          },
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      TayarToast.show(context, loc.savedAddressSavedConfirmation, type: ToastType.success);
    } catch (e) {
      debugPrint('❌ خطأ في حفظ مكان محفوظ مخصص ($key): $e');
      if (!mounted) return;
      TayarToast.show(context, loc.savedAddressSaveError, type: ToastType.error);
    }
  }

  // ====== شيت بسيط بيطلب اسم قصير للمكان المحفوظ الجديد (نفس ستايل شيت
  // اختيار طريقة الدفع)، وبيرجع النص بعد الضغط على "حفظ"، أو null لو
  // المستخدم قفل الشيت من غير ما يكمل ======
  Future<String?> _promptForSavedPlaceName() {
    final loc = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    String? errorText;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.handleColor,
                            borderRadius: BorderRadius.circular(
                              AppRadius.handle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        loc.nameSavedPlaceTitle,
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        style: TextStyle(color: context.textColor),
                        decoration: InputDecoration(
                          hintText: loc.nameSavedPlaceHint,
                          hintStyle: TextStyle(color: context.textGreyColor),
                          errorText: errorText,
                          filled: true,
                          fillColor: context.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) {
                          final trimmed = controller.text.trim();
                          if (trimmed.isEmpty) {
                            setSheetState(
                              () => errorText = loc.nameSavedPlaceRequiredError,
                            );
                            return;
                          }
                          Navigator.pop(sheetContext, trimmed);
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppPrimaryButton(
                        variant: AppButtonVariant.primary,
                        onPressed: () {
                          final trimmed = controller.text.trim();
                          if (trimmed.isEmpty) {
                            setSheetState(
                              () => errorText = loc.nameSavedPlaceRequiredError,
                            );
                            return;
                          }
                          Navigator.pop(sheetContext, trimmed);
                        },
                        child: Text(loc.saveButton),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ====== حفظ عنوان "البيت" أو "الشغل": بيفتح نفس شاشة اختيار الوجهة
  // الموجودة أصلاً، وبعد ما المستخدم يختار مكان بيحفظه في
  // users/{uid}.savedAddresses.{key} على فيرستور.
  // ====== مهم: لازم نبني الـ Map متداخلة فعليًا زي
  // {'savedAddresses': {key: {...}}} مش نستخدم اسم حقل فيه نقطة زي
  // {'savedAddresses.$key': {...}}. الـ dot-notation في اسم الحقل بتشتغل
  // بس مع .update()، أما مع .set(..., merge:true) فبيتعامل معاها كاسم حقل
  // حرفي فيه نقطة (يعني بيتحفظ حقل غريب اسمه "savedAddresses.home") مش
  // كمسار متداخل — وده كان بيمنع SavedPlacesRow من قراءة العنوان تاني
  // أبدًا لأنها بتدور على حقل savedAddresses المتداخل الفعلي.
  // استخدام merge:true مع Map متداخلة فعليًا بيعمل deep-merge صح: بيعدّل
  // المفتاح (home أو work) بس من غير ما يمسح المفتاح التاني لو موجود ======
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
        'savedAddresses': {
          key: {
            'address': result.title,
            'lat': result.location.latitude,
            'lng': result.location.longitude,
          },
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.savedAddressSavedConfirmation,
        type: ToastType.success,
      );
    } catch (e) {
      debugPrint('❌ خطأ في حفظ العنوان المحفوظ ($key): $e');
      if (!mounted) return;
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.savedAddressSaveError,
        type: ToastType.error,
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

    // ====== رصيد المحفظة الحالي + مقارنته بالأجرة عشان نعرف نفعّل خيار
    // "محفظة إلكترونية" ولا نسيبه غير قابل للاختيار ======
    final uid = FirebaseAuth.instance.currentUser?.uid;
    double walletBalance = 0;
    if (uid != null) {
      try {
        walletBalance = await getPassengerWalletBalance(uid);
      } catch (_) {}
    }
    final fare = _estimatedFare;
    final walletCoversFare = walletBalance >= fare && fare > 0;

    if (!mounted) return;
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
                final isWalletOption = value == 'محفظة إلكترونية';
                final isDisabled = isWalletOption && !walletCoversFare;
                return ListTile(
                  onTap: isDisabled
                      ? null
                      : () => Navigator.pop(sheetContext, value),
                  leading: Icon(
                    option['icon'] as IconData,
                    color: isDisabled
                        ? context.textGreyColor.withValues(alpha: 0.4)
                        : isSelected
                        ? TayarColors.primary
                        : context.textGreyColor,
                  ),
                  title: Text(
                    label,
                    style: TextStyle(
                      color: isDisabled
                          ? context.textGreyColor.withValues(alpha: 0.5)
                          : context.textColor,
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: isWalletOption
                      ? Text(
                          isDisabled
                              ? loc.walletInsufficientBalanceLabel
                              : loc.walletAvailableBalanceLabel(
                                  walletBalance.toStringAsFixed(0),
                                ),
                          style: TextStyle(
                            color: isDisabled
                                ? TayarColors.error
                                : context.textGreyColor,
                            fontSize: 12,
                          ),
                        )
                      : null,
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

  // ====== فتح شاشة إنشاء طلب توصيل (زرار "Deliver My Orders" في الشاشة
  // الرئيسية) - بيتفحص الاتصال الأول زي باقي أزرار التنقل ======
  Future<void> _openDeliveryOrder() async {
    if (!await _requireInternet()) return;
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateDeliveryOrderScreen()),
    );
  }

  Future<void> _openOrderConfirmation() async {
    if (_destinationLocation == null || _routeDistanceKm == null) return;
    if (!await _requireInternet()) return;
    if (!mounted) return;
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
    _measureSheetHeight();
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
                // ====== 17 بدل 15 (18 أغسطس 2026): مستوى بيبان فيه أسماء
                // الشوارع الفرعية من أول ما الشاشة تفتح من غير ما المستخدم
                // يزوم يدويًا ======
                initialZoom: 17,
                // ====== minZoom بيمنع اليوزر إنه يزوم آوت لحد ما الخريطة
                // تتكرر جنب بعضها (بيحصل في flutter_map/OSM لو الزوم قل
                // عن حوالي 3). 4 رقم آمن كافي إنه يمنع التكرار ولسه
                // بيسمح بمشاهدة مساحة واسعة حوالين المدينة لو احتاج المستخدم ======
                minZoom: 4,
                cameraConstraint: tayarMapCameraConstraint,
                onMapEvent: _onMapEvent,
                // نسمح بالسحب (يمين/شمال/فوق/تحت) والزوم، ونمنع الدوران خالص
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                const TayarTileLayer(),
                // ====== أيقونة إسناد مصدر الخريطة اتنقلت برا هنا لتحت
                // يمين، محاذية لزرار تحديد الموقع (شوف الـ Positioned
                // بعد نهاية الخريطة) عشان تقدر تاخد نفس ارتفاع الشيت
                // الديناميكي ونفس منطق الاختفاء وقت السحب ======
                // دبابيس الشركاء التجاريين المؤكدين (محلات/مطاعم/
                // صيدليات) - بتتحدث لايف مع أي تحديث من لوحة الأدمن ======
                StreamBuilder<List<VendorPartner>>(
                  stream: streamVendorPartners(),
                  builder: (context, snapshot) {
                    final partners = snapshot.data ?? const [];
                    if (partners.isEmpty) return const SizedBox.shrink();
                    return MarkerLayer(
                      markers: partners.map((partner) {
                        return Marker(
                          point: partner.location,
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _showVendorPartnerSheet(partner),
                            child: Container(
                              decoration: BoxDecoration(
                                color: TayarColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: AppShadows.marker,
                              ),
                              child: const Icon(
                                Icons.storefront,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                if (_routePoints.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routePoints,
                        strokeWidth: 5,
                        // ====== أبيض في الغامق / أسود في الفاتح - عشان يبان
                        // واضح فوق شوارع الخريطة (Liberty) اللي لونها
                        // برتقالي قريب من TayarColors.primary القديم ======
                        color: context.textColor,
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
                        height: const PinMarkerWithStem().totalHeight,
                        child: const PinMarkerWithStem(type: PinType.pickup),
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
                // ====== هالة نطاق الدقة: دائرة جغرافية حقيقية بمقاس بالمتر
                // (نفس نطاق دقة الـ GPS)، فبتكبر مع الزوم إن (Zoom in) وتصغر
                // مع الزوم أوت — بالظبط زي دائرة الدقة في جوجل مابس ======
                if (_liveUserLocation != null && _liveUserAccuracy != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _liveUserLocation!,
                        radius: _liveUserAccuracy!,
                        useRadiusInMeter: true,
                        color: Colors.blue.withValues(alpha: 0.18),
                      ),
                    ],
                  ),
                // ====== النقطة الزرقاء الثابتة جغرافيًا: موقعك الحقيقي، بتتحرك لايف مع تحركك فعليًا ======
                if (_liveUserLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _liveUserLocation!,
                        width: LiveLocationDot.totalSize(18),
                        height: LiveLocationDot.totalSize(18),
                        child: LiveLocationDot(heading: _liveUserHeading),
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
                      child: AppCard(
                        radius: AppRadius.lg,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.md,
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
                    // أيقونة الماركر - ثابتة دايمًا (مش بتختفي)
                    const PinMarker(type: PinType.pickup),
                    // الخط الرفيع الواصل - ثابت دايمًا زي المربع بالظبط
                    Container(width: 2, height: 14, color: context.textColor),
                    // نقطة صغيرة صلبة + ظل خفيف حواليها (زي شكل الظل في
                    // خرائط جوجل): دي بس اللي بتبان وقت سحب الخريطة وتختفي
                    // بشفافية فور الإفلات، والمساحة بتاعتها بتفضل محجوزة
                    // زي ما هي عشان ارتفاع الـ Column ميتغيرش.
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isDraggingMap ? 1 : 0,
                      child: Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: context.textColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: context.textColor.withValues(alpha: 0.35),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ====== زرار جرس الإشعارات (أعلى الشاشة، شمال، بيختفي لفوق وقت سحب الخريطة زي زرار القايمة الجانبية بالظبط) ======
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
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                offset: _isDraggingMap ? const Offset(0, -2) : Offset.zero,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isDraggingMap ? 0 : 1,
                  child: IgnorePointer(
                    ignoring: _isDraggingMap,
                    child: GestureDetector(
                      onTap: () async {
                        if (!await _requireInternet()) return;
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: context.dividerColor2),
                          boxShadow: AppShadows.floating(context),
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
                            boxShadow: AppShadows.floating(context),
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
          // الشمال بالظبط. بنستخدم الارتفاع الحقيقي المقاس فعليًا للشريط
          // (_measuredSheetHeight) بدل الرقم النظري، لأن محتوى الشريط ممكن
          // ياخد مساحة أصغر من كده فبيسيب فراغ زيادة بين الزرار والشريط.
          // أول فريم قبل ما القياس يحصل، بنستخدم الرقم النظري كـ fallback
          // مؤقت لحد ما القياس الحقيقي يوصل. بيتزحلق لتحت ويختفي (نفس
          // حركة السحب اللي بيعملها الشريط السفلي نفسه) في حالتين: وقت
          // سحب الخريطة، أو بعد ما يتحدد وجهة (يعني بس موجود في الشاشة
          // الرئيسية قبل اختيار الوجهة) ======
          AnimatedBuilder(
            animation: _sheetAnimController,
            builder: (context, child) {
              final sheetHeight = _measuredSheetHeight > 0
                  ? _measuredSheetHeight
                  : _sheetHeights(context, topSafeArea).current;
              final t = _sheetAnimController.value;
              final hasDestination = _destinationAddress != null;
              return Positioned(
                left: 16,
                bottom: sheetHeight + 16,
                child: Opacity(
                  opacity: 1 - t,
                  child: IgnorePointer(
                    ignoring: hasDestination || t > 0.5,
                    child: child,
                  ),
                ),
              );
            },
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              offset: (_isDraggingMap || _destinationAddress != null)
                  ? const Offset(0, 2)
                  : Offset.zero,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (_isDraggingMap || _destinationAddress != null)
                    ? 0
                    : 1,
                child: IgnorePointer(
                  ignoring: _isDraggingMap || _destinationAddress != null,
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
                        boxShadow: AppShadows.floating(context),
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

          // ====== أيقونة إسناد مصدر الخريطة: بقت تحت يمين، محاذية بنفس
          // ارتفاع زرار تحديد الموقع (نفس sheetHeight+16)، وبتختفي بنفس
          // منطق السحب/اختيار الوجهة بتاع الزرار بالظبط ======
          AnimatedBuilder(
            animation: _sheetAnimController,
            builder: (context, child) {
              final sheetHeight = _measuredSheetHeight > 0
                  ? _measuredSheetHeight
                  : _sheetHeights(context, topSafeArea).current;
              final t = _sheetAnimController.value;
              final hasDestination = _destinationAddress != null;
              return Positioned(
                right: 16,
                bottom: sheetHeight + 16,
                child: Opacity(
                  opacity: 1 - t,
                  child: IgnorePointer(
                    ignoring: hasDestination || t > 0.5,
                    child: child,
                  ),
                ),
              );
            },
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              offset: (_isDraggingMap || _destinationAddress != null)
                  ? const Offset(0, 2)
                  : Offset.zero,
              child: TayarMapAttribution(
                hidden: _isDraggingMap || _destinationAddress != null,
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
                  final heights = _sheetHeights(context, topSafeArea);
                  final collapsedHeight = heights.collapsed;
                  final expandedHeight = heights.expanded;
                  final currentHeight = heights.current;

                  return ConstrainedBox(
                    key: _sheetContainerKey,
                    constraints: BoxConstraints(maxHeight: currentHeight),
                    child: _destinationAddress == null
                        ? TayarIdleBottomSheet(
                            onTapSearch: _openDestinationSearch,
                            onTapSavedPlace: _addCustomSavedPlace,
                            onSaveAddress: _pickAndSaveAddress,
                            onReorderTrip: _reorderLastTrip,
                            onTapRideService: _openDestinationSearch,
                            nearbyDriversCount: _nearbyDriversCount,
                            onTapDeliveryService: _openDeliveryOrder,
                            onDragStart: () => _onSheetDragStart(
                              collapsedHeight,
                              expandedHeight,
                            ),
                            onDragUpdate: _onSheetDragUpdate,
                            onDragEnd: _onSheetDragEnd,
                          )
                        : TripConfirmationSheet(
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
