import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/theme/app_settings.dart';
import 'package:tayay_app/services/fare_negotiation_rules.dart';

import 'models/nearby_driver_marker.dart';

/// Controller لشاشة البحث عن عروض الطيارين
class SearchingOffersController extends ChangeNotifier {
  final TickerProvider vsync;
  final String orderId;
  final double initialFare;
  final bool initialAutoAccept;
  final LatLng pickupLocation;

  SearchingOffersController({
    required this.vsync,
    required this.orderId,
    required this.initialFare,
    required this.initialAutoAccept,
    required this.pickupLocation,
  }) {
    _init();
  }

  // ====== State ======
  double proposedFare = 0;
  bool autoAccept = false;
  bool isProcessingAccept = false;
  bool autoAcceptHandled = false;

  // ====== Timer ======
  Timer? elapsedTimer;
  int elapsedSeconds = 0;
  static const int raiseFareThresholdSeconds = 30;
  bool dismissedRaiseFarePrompt = false;

  // ====== Animation ======
  late final AnimationController radarController;
  late final AnimationController driversMoveController;
  late final AnimationController idlePulseController;

  // ====== Drivers ======
  final Map<String, NearbyDriverMarker> nearbyDrivers = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? nearbyDriversSub;

  // ====== Offers ======
  final Set<String> seenOfferIds = {};
  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
  pendingOfferNotifications = [];
  bool isShowingOfferNotification = false;

  // ====== Helpers ======
  static const double fareStep = 3.0;

  double get maxFare => FareNegotiationRules.maxFareFor(initialFare);
  double get minFare => FareNegotiationRules.minFareFor(initialFare);

  DocumentReference<Map<String, dynamic>> get orderRef =>
      FirebaseFirestore.instance.collection('orders').doc(orderId);

  String get formattedElapsed {
    final m = (elapsedSeconds ~/ 60).toString().padLeft(1, '0');
    final s = (elapsedSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _init() {
    proposedFare = initialFare;
    autoAccept = initialAutoAccept;

    radarController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    final driversMoveCurve = CurvedAnimation(
      parent: driversMoveController = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 320),
      ),
      curve: Curves.easeOutCubic,
    );
    driversMoveController.addListener(() {
      final t = driversMoveCurve.value;
      for (final marker in nearbyDrivers.values) {
        marker.displayed = _lerpLatLng(marker.prev, marker.target, t);
      }
      notifyListeners();
    });

    idlePulseController = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _watchNearbyDrivers();

    elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds++;
      notifyListeners();
    });
  }

  void disposeController() {
    elapsedTimer?.cancel();
    radarController.dispose();
    driversMoveController.dispose();
    idlePulseController.dispose();
    nearbyDriversSub?.cancel();
  }

  // ====== Fare ======
  Future<void> updateProposedFare(double newFare) async {
    proposedFare = newFare;
    notifyListeners();
    try {
      await orderRef.update({'proposedFare': proposedFare});
    } catch (e) {
      debugPrint('❌ خطأ في تحديث السعر: $e');
    }
  }

  void increaseFare() {
    final next = proposedFare + fareStep;
    if (next <= maxFare) updateProposedFare(next);
  }

  void decreaseFare() {
    if (proposedFare - fareStep >= minFare) {
      updateProposedFare(proposedFare - fareStep);
    }
  }

  Future<void> raiseFareAndRetry() async {
    dismissedRaiseFarePrompt = true;
    elapsedSeconds = 0;
    notifyListeners();
    final next = math.min(proposedFare + (fareStep * 3), maxFare);
    await updateProposedFare(next);
  }

  Future<void> toggleAutoAccept(bool value) async {
    autoAccept = value;
    notifyListeners();
    try {
      await orderRef.update({'autoAccept': value});
    } catch (e) {
      debugPrint('❌ خطأ في تحديث القبول التلقائي: $e');
    }
  }

  // ====== Drivers ======
  void _watchNearbyDrivers() {
    nearbyDriversSub = FirebaseFirestore.instance
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

            final distanceMeters = Geolocator.distanceBetween(
              pickupLocation.latitude,
              pickupLocation.longitude,
              geo.latitude,
              geo.longitude,
            );
            if (distanceMeters > radiusMeters) continue;

            currentIds.add(doc.id);
            final newPos = LatLng(geo.latitude, geo.longitude);
            final existing = nearbyDrivers[doc.id];

            if (existing == null) {
              nearbyDrivers[doc.id] = NearbyDriverMarker(
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

  // ====== Offers ======
  void registerNewOffers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> offers,
  ) {
    for (final offer in offers) {
      if (seenOfferIds.contains(offer.id)) continue;
      seenOfferIds.add(offer.id);

      final price = (offer.data()['price'] as num?)?.toDouble();
      if (autoAccept && price != null && price == proposedFare) continue;

      pendingOfferNotifications.add(offer);
    }
    _maybeShowNextOfferNotification();
  }

  void _maybeShowNextOfferNotification() {
    if (isShowingOfferNotification ||
        isProcessingAccept ||
        autoAcceptHandled ||
        pendingOfferNotifications.isEmpty) {
      return;
    }

    pendingOfferNotifications.removeAt(0);
    isShowingOfferNotification = true;
    notifyListeners();

    // Show notification sheet...
    // When done: isShowingOfferNotification = false; _maybeShowNextOfferNotification();
  }

  Future<void> acceptOffer(
    QueryDocumentSnapshot<Map<String, dynamic>> offer,
  ) async {
    if (isProcessingAccept) return;
    isProcessingAccept = true;
    notifyListeners();

    try {
      final data = offer.data();
      await orderRef.update({
        'status': 'accepted',
        'driverId': data['driverId'],
        'driverName': data['driverName'],
        'acceptedFare': data['price'],
        'acceptedOfferId': offer.id,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      // Show accepted dialog & navigate to tracking
    } catch (e) {
      debugPrint('❌ خطأ في قبول العرض: $e');
      isProcessingAccept = false;
      notifyListeners();
    }
  }

  Future<void> cancelSearch() async {
    try {
      await orderRef.update({'status': 'cancelled'});
    } catch (e) {
      debugPrint('❌ خطأ في إلغاء الطلب: $e');
    }
  }

  // ====== Map ======
  double metersPerPixel(double latitude, double zoom) {
    return 156543.03392 *
        math.cos(latitude * math.pi / 180) /
        math.pow(2, zoom);
  }
}
