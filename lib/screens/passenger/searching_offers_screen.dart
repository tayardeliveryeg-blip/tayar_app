import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/screens/passenger/home/passenger_home_screen.dart'
    show TayarColors, TayarThemeColors;
import 'package:tayay_app/theme/theme_extensions.dart' show AppShadows;
import 'package:tayay_app/widgets/map_tile_layer.dart';
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/screens/passenger/trip_tracking/trip_tracking_screen_screen.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';
import 'package:tayay_app/screens/passenger/searching_offers_widgets/driver_moto_marker.dart';
import 'package:tayay_app/screens/passenger/searching_offers_widgets/offer_cards.dart';
import 'package:tayay_app/services/fare_negotiation_rules.dart';
import 'package:tayay_app/widgets/app_card.dart';
import 'package:tayay_app/widgets/tayar_toast.dart';

/// ====== شاشة البحث عن عروض الطيارين (زي InDrive) ======
/// بتستنى عروض من مجموعة orders/{orderId}/offers وتعرضهم لايف،
/// مع خريطة في الخلفية ودوائر رادار نابضة حوالين نقطة الانطلاق.
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

class _SearchingOffersScreenState extends State<SearchingOffersScreen>
    with TickerProviderStateMixin {
  bool _isProcessingAccept = false;
  bool _autoAcceptHandled = false;

  String _formatScheduledFor(DateTime dt) {
    return '${_twoDigits(dt.day)}/${_twoDigits(dt.month)} - '
        '${_twoDigits(dt.hour)}:${_twoDigits(dt.minute)}';
  }

  // ====== تتبع العروض عشان نظهر إشعار قبول/رفض للعرض الجديد بس ======
  final Set<String> _seenOfferIds = {};
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _pendingOfferNotifications = [];
  bool _isShowingOfferNotification = false;

  late double _proposedFare;
  static const double _fareStep = 3.0;
  late bool _autoAccept;

  // ====== عداد الوقت وشريط التقدم ======
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  static const int _raiseFareThresholdSeconds =
      30; // بعد كام ثانية نقترح رفع السعر
  bool _dismissedRaiseFarePrompt = false;

  // ====== أنيميشن دوائر الرادار حوالين نقطة الانطلاق ======
  late final AnimationController _radarController;

  // ====== الطيارين المتاحين القريبين، بيظهروا كإيموجي موتوسيكل متحرك ======
  final Map<String, NearbyDriverMarker> _nearbyDrivers = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nearbyDriversSub;
  late final AnimationController _driversMoveController;

  // ====== نبضة خفيفة مستمرة (تكبير/تصغير بسيط) على أيقونة كل موتوسيكل، عشان
  // تحس إن الطيارين "شغالين" حتى في اللحظات اللي مفيش فيها تحديث موقع جديد
  // من Firestore، بدل ما يفضلوا واقفين ثابتين خالص بين تحديث وتاني ======
  late final AnimationController _idlePulseController;

  final MapController _mapController = MapController();
  static const double _initialMapZoom = 16;

  // ====== مفتاح لقياس ارتفاع الشيت السفلي (شامل شارة العروض) عشان نطلع
  // الدبوس فوقه بالظبط ======
  final GlobalKey _bottomSheetKey = GlobalKey();

  DocumentReference<Map<String, dynamic>> get _orderRef =>
      FirebaseFirestore.instance.collection('orders').doc(widget.orderId);

  @override
  void initState() {
    super.initState();
    _proposedFare = widget.proposedFare;
    _autoAccept = widget.autoAccept;

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // ====== أنيميشن حركة الطيارين القريبين على الخريطة: بنستخدم منحنى
    // easeOutCubic بدل الحركة الخطية عشان الانتقال يحس بسرعة في البداية
    // ويهدى في النهاية، فيبقى شكله "قفزة سريعة" مش انزلاق بطيء ممل ======
    final driversMoveCurve = CurvedAnimation(
      parent: _driversMoveController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      ),
      curve: Curves.easeOutCubic,
    );
    _driversMoveController.addListener(() {
      final t = driversMoveCurve.value;
      for (final marker in _nearbyDrivers.values) {
        marker.displayed = _lerpLatLng(marker.prev, marker.target, t);
      }
      if (mounted) setState(() {});
    });

    // ====== نبضة مستمرة بتلف من غير توقف، شغالة طول الوقت بغض النظر عن
    // تحديثات الموقع ======
    _idlePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _watchNearbyDrivers();

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
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
          final radiusMeters = AppSettings.instance.serviceRadiusKm * 1000;

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final geo = _extractGeoPoint(data['currentLocation']);
            if (geo == null) continue;

            // ====== نتجاهل أي سائق بعيد عن نقطة الانطلاق (مثلاً في مدينة
            // تانية) — مهم مع توسع التطبيق لمدن أكتر من العاشر من رمضان ======
            final distanceMeters = Geolocator.distanceBetween(
              widget.pickupLocation.latitude,
              widget.pickupLocation.longitude,
              geo.latitude,
              geo.longitude,
            );
            if (distanceMeters > radiusMeters) continue;

            currentIds.add(doc.id);
            final newPos = LatLng(geo.latitude, geo.longitude);
            final existing = _nearbyDrivers[doc.id];

            if (existing == null) {
              // ====== طيار جديد: يظهر على طول من غير أنيميشن ======
              _nearbyDrivers[doc.id] = NearbyDriverMarker(
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

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _radarController.dispose();
    _driversMoveController.dispose();
    _idlePulseController.dispose();
    _nearbyDriversSub?.cancel();
    super.dispose();
  }

  Future<void> _updateProposedFare(double newFare) async {
    setState(() => _proposedFare = newFare);
    try {
      await _orderRef.update({'proposedFare': _proposedFare});
    } catch (e) {
      debugPrint('❌ خطأ في تحديث السعر المقترح: $e');
    }
  }

  // ====== الحد الأقصى مبني على widget.proposedFare (قيمة الكونستركتور
  // الثابتة، وهي السعر الأصلي وقت فتح الشاشة) مش على _proposedFare
  // المتغيّرة، عشان السقف يفضل ثابت ومايزحفش لفوق مع كل تعديل ======
  double get _maxFare => FareNegotiationRules.maxFareFor(widget.proposedFare);
  double get _minFare => FareNegotiationRules.minFareFor(widget.proposedFare);

  void _increaseFare() {
    final next = _proposedFare + _fareStep;
    if (next <= _maxFare) _updateProposedFare(next);
  }

  void _decreaseFare() {
    if (_proposedFare - _fareStep >= _minFare) {
      _updateProposedFare(_proposedFare - _fareStep);
    }
  }

  Future<void> _raiseFareAndRetry() async {
    setState(() {
      _dismissedRaiseFarePrompt = true;
      _elapsedSeconds = 0;
    });
    final next = math.min(_proposedFare + (_fareStep * 3), _maxFare);
    await _updateProposedFare(next);
  }

  Future<void> _toggleAutoAccept(bool value) async {
    setState(() => _autoAccept = value);
    try {
      await _orderRef.update({'autoAccept': value});
    } catch (e) {
      debugPrint('❌ خطأ في تحديث القبول التلقائي: $e');
    }
  }

  Future<void> _acceptOffer(
    QueryDocumentSnapshot<Map<String, dynamic>> offer,
  ) async {
    if (_isProcessingAccept) return;
    setState(() => _isProcessingAccept = true);

    try {
      final data = offer.data();
      await _orderRef.update({
        'status': 'accepted',
        'driverId': data['driverId'],
        'driverName': data['driverName'],
        'acceptedFare': data['price'],
        'acceptedOfferId': offer.id,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showAcceptedDialog(
        driverName:
            (data['driverName'] as String?) ??
            AppLocalizations.of(context)!.defaultDriverName,
        price: (data['price'] as num?)?.toDouble() ?? _proposedFare,
      );
    } catch (e) {
      debugPrint('❌ خطأ في قبول العرض: $e');
      if (!mounted) return;
      setState(() => _isProcessingAccept = false);
      TayarToast.show(
        context,
        AppLocalizations.of(context)!.failedToAcceptOfferError,
        type: ToastType.error,
      );
    }
  }

  void _showAcceptedDialog({
    required String driverName,
    required double price,
  }) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          children: [
            const Icon(
              Icons.check_circle,
              color: TayarColors.primary,
              size: 56,
            ),
            const SizedBox(height: 12),
            Text(
              loc.offerAcceptedTitle,
              style: TextStyle(color: context.textColor),
            ),
          ],
        ),
        content: Text(
          loc.driverOnWayWithFareLabel(driverName, price.toStringAsFixed(0)),
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textGreyColor),
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // نقفل الـ dialog بس
                // ننتقل لشاشة التتبع الحية بدل ما نرجع للشاشة الرئيسية الثابتة
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => TripTrackingScreen(orderId: widget.orderId),
                  ),
                );
              },
              child: Text(
                loc.ok,
                style: const TextStyle(color: TayarColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelSearch() async {
    try {
      await _orderRef.update({'status': 'cancelled'});
    } catch (e) {
      debugPrint('❌ خطأ في إلغاء الطلب: $e');
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _confirmCancel() {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          loc.cancelSearchTitle,
          style: TextStyle(color: context.textColor),
        ),
        content: Text(
          loc.cancelSearchBody,
          style: TextStyle(color: context.textGreyColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              loc.goBackButton,
              style: TextStyle(color: context.textGreyColor),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelSearch();
            },
            child: Text(
              loc.cancelOrderButton,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  // ====== متر لكل بيكسل حسب خط العرض والزوم (معادلة Web Mercator قياسية) ======
  double _metersPerPixel(double latitude, double zoom) {
    return 156543.03392 *
        math.cos(latitude * math.pi / 180) /
        math.pow(2, zoom);
  }

  // ====== بنزوّد مركز الخريطة جنوب نقطة الانطلاق عشان الدبوس (اللي فوق نقطة
  // الانطلاق الحقيقية بالظبط) يظهر بصريًا في نص المساحة الظاهرة فوق الشيت
  // السفلي، بدل ما يتغطى تحته. الإحداثيات نفسها (widget.pickupLocation) متثبتة
  // وما بتتغيرش، إحنا بس بنحرك زاوية الكاميرا. ======
  void _centerMapAboveSheet() {
    if (!mounted) return;

    final sheetBox =
        _bottomSheetKey.currentContext?.findRenderObject() as RenderBox?;
    final double sheetHeight = (sheetBox != null && sheetBox.hasSize)
        ? sheetBox.size.height
        : 300.0; // تقدير احتياطي لحد ما الشيت يتقاس فعليًا

    final double shiftPixels = sheetHeight / 2;
    final double metersPerPixel = _metersPerPixel(
      widget.pickupLocation.latitude,
      _initialMapZoom,
    );
    final double deltaLatDegrees =
        (shiftPixels * metersPerPixel) / 111320.0; // متر تقريبي لكل درجة عرض

    final newCenter = LatLng(
      widget.pickupLocation.latitude - deltaLatDegrees,
      widget.pickupLocation.longitude,
    );

    _mapController.move(newCenter, _initialMapZoom);
  }

  // ====== بنسجل أي عرض جديد وصل عشان نعرضه كإشعار قبول/رفض ======
  void _registerNewOffers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> offers,
  ) {
    for (final offer in offers) {
      if (_seenOfferIds.contains(offer.id)) continue;
      _seenOfferIds.add(offer.id);

      // العرض اللي هيتقبل تلقائيًا مالوش داعي إشعار يدوي
      final price = (offer.data()['price'] as num?)?.toDouble();
      if (_autoAccept && price != null && price == _proposedFare) continue;

      _pendingOfferNotifications.add(offer);
    }
    _maybeShowNextOfferNotification();
  }

  void _maybeShowNextOfferNotification() {
    if (!mounted ||
        _isShowingOfferNotification ||
        _isProcessingAccept ||
        _autoAcceptHandled ||
        _pendingOfferNotifications.isEmpty) {
      return;
    }

    final offer = _pendingOfferNotifications.removeAt(0);
    _isShowingOfferNotification = true;

    final data = offer.data();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => OfferNotificationSheet(
        driverName:
            (data['driverName'] as String?) ??
            AppLocalizations.of(context)!.defaultDriverName,
        rating: (data['rating'] as num?)?.toDouble(),
        price: (data['price'] as num?)?.toDouble() ?? _proposedFare,
        photoUrl: data['driverPhotoUrl'] as String?,
        onAccept: () {
          Navigator.of(context).pop();
          _acceptOffer(offer);
        },
        onReject: () => Navigator.of(context).pop(),
      ),
    ).whenComplete(() {
      _isShowingOfferNotification = false;
      _maybeShowNextOfferNotification();
    });
  }

  String get _formattedElapsed {
    final m = (_elapsedSeconds ~/ 60).toString().padLeft(1, '0');
    final s = (_elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmCancel();
      },
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _orderRef
              .collection('offers')
              .orderBy('createdAt', descending: false)
              .snapshots(),
          builder: (context, snapshot) {
            final offers = snapshot.data?.docs ?? [];

            // ====== القبول التلقائي: أول عرض بنفس السعر المقترح بالظبط ======
            if (_autoAccept && !_autoAcceptHandled && offers.isNotEmpty) {
              for (final offer in offers) {
                final price = (offer.data()['price'] as num?)?.toDouble();
                if (price != null && price == _proposedFare) {
                  _autoAcceptHandled = true;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _acceptOffer(offer),
                  );
                  break;
                }
              }
            }

            final bool showRaiseFarePrompt =
                offers.isEmpty &&
                !_dismissedRaiseFarePrompt &&
                _elapsedSeconds >= _raiseFareThresholdSeconds &&
                _proposedFare < _maxFare;

            // ====== خريطة driverId -> السعر المقترح، عشان نعرف نربط كل عرض
            // بموتوسيكل الطيار بتاعه على الخريطة ونعرض السعر فوقه ======
            final Map<String, double> offerPriceByDriverId = {
              for (final offer in offers)
                if (offer.data()['driverId'] is String)
                  offer.data()['driverId'] as String:
                      (offer.data()['price'] as num?)?.toDouble() ??
                      _proposedFare,
            };

            // بنسجل أي عروض جديدة (لإشعار القبول/الرفض) وبنعيد حساب موضع
            // الدبوس فوق الشيت بعد كل تحديث، لأن ارتفاع الشيت بيتغير مع ظهور
            // شارة العروض أو كارت رفع السعر أو قائمة العروض نفسها
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _registerNewOffers(offers);
              _centerMapAboveSheet();
            });

            return Stack(
              children: [
                // ====== الخريطة في الخلفية ======
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: widget.pickupLocation,
                      initialZoom: _initialMapZoom,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                      onMapReady: () {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _centerMapAboveSheet(),
                        );
                      },
                    ),
                    children: [
                      const TayarTileLayer(),
                      const TayarMapAttribution(),
                      // ====== الدبوس + دوائر الرادار مربوطين بإحداثيات نقطة
                      // الانطلاق الحقيقية (widget.pickupLocation) ======
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: widget.pickupLocation,
                            width: 260,
                            height: 260,
                            alignment: Alignment.center,
                            rotate: true,
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _radarController,
                                builder: (context, child) {
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      _buildRadarRing(0),
                                      _buildRadarRing(0.33),
                                      _buildRadarRing(0.66),
                                      Container(
                                        width: 52,
                                        height: 52,
                                        decoration: BoxDecoration(
                                          color: context.textColor,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          boxShadow: AppShadows.marker,
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: TayarColors.primary,
                                          size: 34,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      // ====== الطيارين المتاحين القريبين: إيموجي موتوسيكل بيتحرك
                      // لايف، ولو حد منهم عمل عرض سعر على الطلب ده يظهر عليه
                      // بابل السعر وهالة مضيئة تميّزه عن باقي اللي لسه بيدوروا ======
                      if (_nearbyDrivers.isNotEmpty)
                        MarkerLayer(
                          markers: _nearbyDrivers.entries.map((entry) {
                            final driverId = entry.key;
                            final driver = entry.value;
                            final offerPrice = offerPriceByDriverId[driverId];
                            return Marker(
                              point: driver.displayed,
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              child: DriverMotoMarker(
                                key: ValueKey(driverId),
                                pulse: _idlePulseController,
                                hasOffer: offerPrice != null,
                                price: offerPrice,
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),

                // ====== بانر رحلة مجدولة: بيفضل ظاهر فوق الخريطة طول ما
                // الراكب بيدوّر على عروض عشان يفتكر إن الرحلة دي محجوزة
                // لميعاد معين، رغم إن المطابقة نفسها شغالة فورًا (شوف
                // تعليق orderType في supabase/functions/create-order) ======
                if (widget.scheduledFor != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: AppCard(
                          color: TayarColors.primary,
                          radius: 12,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.schedule,
                                size: 18,
                                color: context.onPrimaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  )!.scheduledRideSearchingBanner(
                                    _formatScheduledFor(widget.scheduledFor!),
                                  ),
                                  style: TextStyle(
                                    color: context.onPrimaryColor,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // ====== الشيت السفلي + شارة العروض فوقه مباشرة ======
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    key: _bottomSheetKey,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (offers.isNotEmpty) _buildOffersBadge(offers),
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        decoration: BoxDecoration(
                          color: context.bgColor,
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

                            if (showRaiseFarePrompt)
                              RaiseFareCard(
                                currentFare: _proposedFare,
                                suggestedFare: math.min(
                                  _proposedFare + (_fareStep * 3),
                                  _maxFare,
                                ),
                                onRaiseFare: _raiseFareAndRetry,
                                onDismiss: () => setState(
                                  () => _dismissedRaiseFarePrompt = true,
                                ),
                              )
                            else ...[
                              // ====== عداد الوقت + شريط التقدم ======
                              Row(
                                children: [
                                  Text(
                                    _formattedElapsed,
                                    style: TextStyle(
                                      color: context.textGreyColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      loc.clientOrderPriority,
                                      style: TextStyle(
                                        color: context.textGreyColor,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (_elapsedSeconds % 20) / 20,
                                  minHeight: 4,
                                  backgroundColor: context.dividerColor2,
                                  color: TayarColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // ====== تحكم السعر ======
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  FareStepButton(
                                    icon: Icons.remove,
                                    onTap: _proposedFare <= _minFare
                                        ? null
                                        : _decreaseFare,
                                  ),
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      loc.currencyEGP(
                                        _proposedFare.toStringAsFixed(0),
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: context.textColor,
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  FareStepButton(
                                    icon: Icons.add,
                                    onTap: _proposedFare >= _maxFare
                                        ? null
                                        : _increaseFare,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _proposedFare >= _maxFare
                                    ? null
                                    : _increaseFare,
                                child: Text(
                                  loc.increaseFareButton,
                                  style: TextStyle(
                                    color: _proposedFare >= _maxFare
                                        ? context.textGreyColor
                                        : TayarColors.primary,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 6),

                            // ====== خانة القبول التلقائي ======
                            AppCard(
                              onTap: () => _toggleAutoAccept(!_autoAccept),
                              radius: 12,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              showShadow: false,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.flash_on,
                                    color: TayarColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      loc.autoAcceptNearestDriverLabel(
                                        _proposedFare.toStringAsFixed(0),
                                      ),
                                      style: TextStyle(
                                        color: context.textColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: _autoAccept,
                                    activeThumbColor: TayarColors.primary,
                                    onChanged: _toggleAutoAccept,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ====== طريقة الدفع ======
                            AppCard(
                              radius: 12,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              showShadow: false,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.payments_outlined,
                                    color: TayarColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    loc.cashAmountLabel(
                                      _proposedFare.toStringAsFixed(0),
                                    ),
                                    style: TextStyle(
                                      color: context.textColor,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // ====== المسار: من - إلى ======
                            AppCard(
                              radius: 12,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              showShadow: false,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        color: TayarColors.primary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.pickupAddress,
                                          style: TextStyle(
                                            color: context.textColor,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 7),
                                        SizedBox(
                                          height: 12,
                                          child: VerticalDivider(
                                            color: context.dividerColor2,
                                            thickness: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.flag,
                                        color: TayarColors.primary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.destinationAddress,
                                          style: TextStyle(
                                            color: context.textColor,
                                            fontSize: 14,
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

                            // ====== قائمة العروض (لو موجودة) ======
                            if (offers.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 180,
                                ),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: offers.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final offer = offers[index];
                                    final data = offer.data();
                                    return OfferCard(
                                      driverName:
                                          (data['driverName'] as String?) ??
                                          loc.defaultDriverName,
                                      rating: (data['driverRating'] as num?)
                                          ?.toDouble(),
                                      price:
                                          (data['price'] as num?)?.toDouble() ??
                                          0,
                                      isProcessing: _isProcessingAccept,
                                      onAccept: () => _acceptOffer(offer),
                                    );
                                  },
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _confirmCancel,
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: context.textGreyColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  loc.cancelOrderButton,
                                  style: TextStyle(
                                    color: context.textGreyColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ====== شارة فوق الشيت: دوائر بروفايل الطيارين + عدد العروض، بتتحدث لايف
  // مع أنيميشن بسيط لظهور كل طيار جديد ======
  Widget _buildOffersBadge(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> offers,
  ) {
    final visibleOffers = offers.take(4).toList();
    const double avatarSize = 30;
    const double overlapStep = 20;
    final double stackWidth =
        avatarSize + (visibleOffers.length - 1) * overlapStep;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: context.bgColor.withValues(alpha: 0.95),
        radius: 30,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Text(
                key: ValueKey(offers.length),
                offers.length == 1
                    ? AppLocalizations.of(context)!.oneDriverViewingOrderLabel
                    : AppLocalizations.of(
                        context,
                      )!.multipleDriversViewingOrderLabel(offers.length),
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: stackWidth,
              height: avatarSize,
              child: Stack(
                children: [
                  for (int i = 0; i < visibleOffers.length; i++)
                    Positioned(
                      right: i * overlapStep,
                      child: OfferAvatarPop(
                        key: ValueKey(visibleOffers[i].id),
                        photoUrl:
                            visibleOffers[i].data()['driverPhotoUrl']
                                as String?,
                        size: avatarSize,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====== دائرة رادار واحدة، بتتحرك حسب قيمة الأنيميشن + إزاحة البداية ======
  Widget _buildRadarRing(double delay) {
    double progress = (_radarController.value + delay) % 1.0;
    return Opacity(
      opacity: (1 - progress).clamp(0.0, 1.0) * 0.5,
      child: Container(
        width: 60 + (200 * progress),
        height: 60 + (200 * progress),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: TayarColors.primary, width: 2),
        ),
      ),
    );
  }
}

String _twoDigits(int n) => n.toString().padLeft(2, '0');
