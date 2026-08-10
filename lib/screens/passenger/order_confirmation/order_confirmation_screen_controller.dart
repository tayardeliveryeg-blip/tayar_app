import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:tayay_app/services/fare_negotiation_rules.dart';
import 'package:tayay_app/services/wallet_service.dart';
import 'package:tayay_app/theme/app_settings.dart';

/// Controller لشاشة تأكيد الطلب
class OrderConfirmationController extends ChangeNotifier {
  final double initialFare;
  final String initialPaymentMethod;

  OrderConfirmationController({
    required this.initialFare,
    required this.initialPaymentMethod,
  }) {
    _init();
  }

  // ====== Route ======
  late double distanceKm;
  late int durationMin;

  // ====== Fare ======
  late double baseFare;
  late double proposedFare;
  late double minFare;
  late double maxFare;
  double? walletMaxFare;
  static const double step = 5.0;

  // ====== Schedule ======
  DateTime? scheduledFor;

  // ====== Auto Accept ======
  bool autoAccept = false;

  // ====== State ======
  bool isSubmitting = false;
  bool isUpdatingRoute = false;

  // ====== Supabase ======
  static const String _supabaseAnonKey =
      'sb_publishable_ltwC2X3e-F6nkAiPxszdlQ_x7xTNUC3';

  void _init() {
    baseFare = initialFare;
    proposedFare = initialFare;
    minFare = FareNegotiationRules.minFareFor(initialFare);
    maxFare = FareNegotiationRules.maxFareFor(initialFare);
    if (initialPaymentMethod == 'محفظة إلكترونية') {
      _loadWalletCap();
    }
  }

  void setRouteData(double dist, int dur) {
    distanceKm = dist;
    durationMin = dur;
  }

  Future<void> _loadWalletCap() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final balance = await getPassengerWalletBalance(uid);
      walletMaxFare = balance;
      if (proposedFare > balance) {
        proposedFare = balance;
        notifyListeners();
      }
    } catch (_) {}
  }

  void increaseFare() {
    final underNegotiationCap = proposedFare + step <= maxFare;
    final underWalletCap =
        walletMaxFare == null || proposedFare + step <= walletMaxFare!;
    if (underNegotiationCap && underWalletCap) {
      proposedFare += step;
      notifyListeners();
    }
  }

  void decreaseFare() {
    if (proposedFare - step >= minFare) {
      proposedFare -= step;
      notifyListeners();
    }
  }

  Future<void> recalculateRouteAndFare(
    LatLng pickupLocation,
    LatLng destinationLocation,
  ) async {
    isUpdatingRoute = true;
    notifyListeners();

    double newDistance;
    int newDuration;
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${pickupLocation.longitude},${pickupLocation.latitude};'
        '${destinationLocation.longitude},${destinationLocation.latitude}'
        '?overview=false',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) throw Exception('فشل الاتصال');
      final data = json.decode(response.body);
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) throw Exception('مفيش مسار');
      final route = routes[0];
      newDistance = (route['distance'] as num).toDouble() / 1000;
      newDuration = ((route['duration'] as num).toDouble() / 60).ceil();
    } catch (e) {
      debugPrint('❌ خطأ في إعادة حساب المسار: $e');
      final fallbackDistanceKm = const Distance().as(
        LengthUnit.Kilometer,
        pickupLocation,
        destinationLocation,
      );
      newDistance = fallbackDistanceKm;
      newDuration = (fallbackDistanceKm / 30 * 60).ceil();
    }

    distanceKm = newDistance;
    durationMin = newDuration;
    baseFare = AppSettings.instance.estimateFare(newDistance);
    proposedFare = baseFare;
    minFare = FareNegotiationRules.minFareFor(baseFare);
    maxFare = FareNegotiationRules.maxFareFor(baseFare);
    if (walletMaxFare != null && proposedFare > walletMaxFare!) {
      proposedFare = walletMaxFare!;
    }
    isUpdatingRoute = false;
    notifyListeners();
  }

  Future<void> pickScheduleDateTime(BuildContext context) async {
    final now = DateTime.now();
    final minDateTime = now.add(const Duration(minutes: 10));
    final maxDateTime = now.add(
      Duration(days: AppSettings.instance.maxScheduleAdvanceDays),
    );

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: scheduledFor != null && scheduledFor!.isAfter(minDateTime)
          ? scheduledFor!
          : minDateTime,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: maxDateTime,
    );
    if (pickedDate == null) return;
    if (!context.mounted) return;

    final initialTime = scheduledFor != null
        ? TimeOfDay.fromDateTime(scheduledFor!)
        : TimeOfDay.fromDateTime(minDateTime);
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (pickedTime == null) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (combined.isBefore(minDateTime)) {
      // Show error
      return;
    }
    if (combined.isAfter(maxDateTime)) {
      // Show error
      return;
    }

    scheduledFor = combined;
    notifyListeners();
  }

  String formatScheduledFor(DateTime dt) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(dt.day)}/${twoDigits(dt.month)} - '
        '${twoDigits(dt.hour)}:${twoDigits(dt.minute)}';
  }

  Future<void> searchForOffers(
    BuildContext context, {
    required String pickupAddress,
    required LatLng pickupLocation,
    required String destinationAddress,
    required LatLng destinationLocation,
    required String paymentMethod,
  }) async {
    isSubmitting = true;
    notifyListeners();

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) throw StateError('لازم تسجل الدخول');

      final response = await http
          .post(
            Uri.parse(
              'https://pctxhemhytzaufdzuhfz.supabase.co/functions/v1/create-order',
            ),
            headers: {
              'apikey': _supabaseAnonKey,
              'Authorization': 'Bearer $_supabaseAnonKey',
              'X-Firebase-Id-Token': idToken,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'pickupAddress': pickupAddress,
              'pickupLat': pickupLocation.latitude,
              'pickupLng': pickupLocation.longitude,
              'destinationAddress': destinationAddress,
              'destinationLat': destinationLocation.latitude,
              'destinationLng': destinationLocation.longitude,
              'proposedFare': proposedFare,
              'autoAccept': autoAccept,
              'paymentMethod': paymentMethod,
              if (scheduledFor != null)
                'scheduledFor': scheduledFor!.millisecondsSinceEpoch,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        final errorMessage = responseData['error'] as String?;
        debugPrint(
          '❌ خطأ من create-order: ${response.statusCode} - $errorMessage',
        );
        isSubmitting = false;
        notifyListeners();
        return;
      }

      isSubmitting = false;
      notifyListeners();

      // Navigate to SearchingOffersScreen
    } catch (e) {
      debugPrint('❌ خطأ في إرسال الطلب: $e');
      isSubmitting = false;
      notifyListeners();
    }
  }

  void toggleAutoAccept() {
    autoAccept = !autoAccept;
    notifyListeners();
  }

  void clearSchedule() {
    scheduledFor = null;
    notifyListeners();
  }
}
