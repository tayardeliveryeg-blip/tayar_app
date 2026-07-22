import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'passenger_home.dart' show TayarColors, TayarThemeColors;
import 'map_tile_layer.dart';
import 'trip_tracking_screen.dart';
import 'package:tayay_app/l10n/generated/app_localizations.dart';

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

  const SearchingOffersScreen({
    super.key,
    required this.orderId,
    required this.proposedFare,
    required this.autoAccept,
    required this.pickupAddress,
    required this.pickupLocation,
    required this.destinationAddress,
  });

  @override
  State<SearchingOffersScreen> createState() => _SearchingOffersScreenState();
}

class _SearchingOffersScreenState extends State<SearchingOffersScreen>
    with TickerProviderStateMixin {
  bool _isProcessingAccept = false;
  bool _autoAcceptHandled = false;

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
  final Map<String, _NearbyDriverMarker> _nearbyDrivers = {};
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

  void _increaseFare() => _updateProposedFare(_proposedFare + _fareStep);

  void _decreaseFare() {
    if (_proposedFare - _fareStep >= (widget.proposedFare * 0.5)) {
      _updateProposedFare(_proposedFare - _fareStep);
    }
  }

  Future<void> _raiseFareAndRetry() async {
    setState(() {
      _dismissedRaiseFarePrompt = true;
      _elapsedSeconds = 0;
    });
    await _updateProposedFare(_proposedFare + (_fareStep * 3));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToAcceptOfferError),
        ),
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
      builder: (_) => _OfferNotificationSheet(
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
                _elapsedSeconds >= _raiseFareThresholdSeconds;

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
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.3,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ],
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
                              child: _DriverMotoMarker(
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
                              _RaiseFareCard(
                                currentFare: _proposedFare,
                                suggestedFare: _proposedFare + (_fareStep * 3),
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
                                  _FareStepButton(
                                    icon: Icons.remove,
                                    onTap: _decreaseFare,
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
                                  _FareStepButton(
                                    icon: Icons.add,
                                    onTap: _increaseFare,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: _increaseFare,
                                child: Text(
                                  loc.increaseFareButton,
                                  style: const TextStyle(
                                    color: TayarColors.primary,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 6),

                            // ====== خانة القبول التلقائي ======
                            InkWell(
                              onTap: () => _toggleAutoAccept(!_autoAccept),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: context.cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                            ),
                            const SizedBox(height: 8),

                            // ====== طريقة الدفع ======
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                                    return _OfferCard(
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: context.bgColor.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(30),
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
                      child: _OfferAvatarPop(
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

// ====== كارت اقتراح رفع السعر بعد ما البحث ياخد وقت طويل ======
class _RaiseFareCard extends StatelessWidget {
  final double currentFare;
  final double suggestedFare;
  final VoidCallback onRaiseFare;
  final VoidCallback onDismiss;

  const _RaiseFareCard({
    required this.currentFare,
    required this.suggestedFare,
    required this.onRaiseFare,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            // سبيسر فاضي بنفس عرض زرار الإغلاق عشان النص يتزن في النص بالظبط
            const SizedBox(width: 48),
            Expanded(
              child: Text(
                loc.tryRaisingFareTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: context.textGreyColor, size: 20),
              onPressed: onDismiss,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          loc.raiseFareHintBody,
          style: TextStyle(color: context.textGreyColor, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: onRaiseFare,
            style: ElevatedButton.styleFrom(
              backgroundColor: TayarColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              loc.searchWithFareLabel(suggestedFare.toStringAsFixed(0)),
              style: TextStyle(
                color: context.onPrimaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// ====== زرار +/- لتعديل السعر ======
class _FareStepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _FareStepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled
              ? context.cardColor
              : context.cardColor.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: TayarColors.primary.withValues(alpha: 0.5)),
        ),
        child: Icon(icon, color: context.textColor, size: 20),
      ),
    );
  }
}

// ====== كارت عرض الطيار الواحد ======
class _OfferCard extends StatelessWidget {
  final String driverName;
  final double? rating;
  final double price;
  final bool isProcessing;
  final VoidCallback onAccept;

  const _OfferCard({
    required this.driverName,
    required this.rating,
    required this.price,
    required this.isProcessing,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TayarColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: TayarColors.primary,
            child: Icon(Icons.person, color: context.onPrimaryColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driverName,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                if (rating != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: TayarColors.primary,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: TextStyle(
                          color: context.textGreyColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    AppLocalizations.of(context)!.newDriverLabel,
                    style: TextStyle(
                      color: context.textGreyColor,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            AppLocalizations.of(context)!.currencyEGP(price.toStringAsFixed(0)),
            style: const TextStyle(
              color: TayarColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: isProcessing ? null : onAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: TayarColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.acceptButton,
                style: TextStyle(color: context.onPrimaryColor, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ====== دائرة بروفايل طيار واحد بتظهر بأنيميشن بسيط (Scale) أول مرة تتبني ======
class _OfferAvatarPop extends StatelessWidget {
  final String? photoUrl;
  final double size;

  const _OfferAvatarPop({
    super.key,
    required this.photoUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(scale: value, child: child);
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: context.bgColor, width: 2),
        ),
        child: CircleAvatar(
          backgroundColor: TayarColors.primary,
          backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
              ? NetworkImage(photoUrl!)
              : null,
          child: (photoUrl == null || photoUrl!.isEmpty)
              ? Icon(Icons.person, color: context.onPrimaryColor, size: 16)
              : null,
        ),
      ),
    );
  }
}

// ====== إشعار عرض جديد: بيطلع تحت لما طيار يعمل عرض، وفيه قبول أو رفض ======
class _OfferNotificationSheet extends StatelessWidget {
  final String driverName;
  final double? rating;
  final double price;
  final String? photoUrl;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _OfferNotificationSheet({
    required this.driverName,
    required this.rating,
    required this.price,
    required this.photoUrl,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 24),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 16,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: TayarColors.primary,
                      backgroundImage:
                          (photoUrl != null && photoUrl!.isNotEmpty)
                          ? NetworkImage(photoUrl!)
                          : null,
                      child: (photoUrl == null || photoUrl!.isEmpty)
                          ? Icon(
                              Icons.person,
                              color: context.textColor,
                              size: 26,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.newOfferFromDriverLabel(driverName),
                            style: TextStyle(
                              color: context.textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (rating != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: TayarColors.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rating!.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: context.textGreyColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              AppLocalizations.of(context)!.newDriverLabel,
                              style: TextStyle(
                                color: context.textGreyColor,
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      loc.currencyEGP(price.toStringAsFixed(0)),
                      style: const TextStyle(
                        color: TayarColors.primary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton(
                          onPressed: onReject,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: context.textGreyColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            loc.rejectButton,
                            style: TextStyle(color: context.textGreyColor),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          onPressed: onAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TayarColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            loc.acceptButton,
                            style: TextStyle(
                              color: context.onPrimaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ====== أيقونة موتوسيكل طيار واحد على الخريطة: بتنبض باستمرار عشان تحس إنها
// "شغالة" حتى وهي مش بتتحرك، ولو الطيار عمل عرض سعر على الطلب ده بتظهر
// بابل السعر فوقها مع هالة مضيئة تفرقها عن باقي الطيارين ======
class _DriverMotoMarker extends StatelessWidget {
  final Animation<double> pulse;
  final bool hasOffer;
  final double? price;

  const _DriverMotoMarker({
    super.key,
    required this.pulse,
    required this.hasOffer,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, child) {
        // ====== لسه بيدور بس (من غير عرض): نبضة خفيفة جدًا (0.94 - 1.0)
        // عمل عرض سعر: نبضة أوضح شوية (1.0 - 1.12) عشان يلفت النظر ======
        final scale = hasOffer
            ? 1.0 + (pulse.value * 0.12)
            : 0.94 + (pulse.value * 0.06);
        return Transform.scale(scale: scale, child: child);
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (hasOffer)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TayarColors.primary.withValues(alpha: 0.22),
                border: Border.all(color: TayarColors.primary, width: 1.5),
              ),
            ),
          const Text('🏍️', style: TextStyle(fontSize: 26)),
          if (hasOffer && price != null)
            Positioned(
              top: -6,
              child: TweenAnimationBuilder<double>(
                // ====== المفتاح مربوط بالسعر عشان لو الطيار غيّر عرضه، البابل
                // تعمل "bounce" تاني وتلفت النظر إن فيه تحديث ======
                key: ValueKey(price),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, -34 * value),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: TayarColors.primary,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    price!.toStringAsFixed(0),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ====== حالة أنيميشن حركة طيار قريب واحد على الخريطة ======
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
